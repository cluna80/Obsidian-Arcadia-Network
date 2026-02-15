// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SoulboundCredentials
 * @dev Non-transferable credentials for OAN entities
 */
contract SoulboundCredentials is AccessControl {
    
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    
    struct Credential {
        uint256 id;
        address holder;
        address issuer;
        string credentialType;
        string credentialData;  // IPFS hash or JSON
        uint256 issuedAt;
        uint256 expiresAt;
        bool revoked;
        bool soulbound;         // Cannot be transferred
    }
    
    mapping(uint256 => Credential) public credentials;
    mapping(address => uint256[]) public holderCredentials;
    mapping(address => mapping(string => uint256[])) public credentialsByType;
    
    uint256 private _nextCredentialId = 1;
    uint256 public totalCredentials;
    
    event CredentialIssued(
        uint256 indexed credentialId,
        address indexed holder,
        address indexed issuer,
        string credentialType
    );
    event CredentialRevoked(uint256 indexed credentialId, address indexed issuer);
    event TransferAttempted(uint256 indexed credentialId, address from, address to);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
    }
    
    function issueCredential(
        address holder,
        string memory credentialType,
        string memory credentialData,
        uint256 validityDuration,
        bool soulbound
    ) external onlyRole(ISSUER_ROLE) returns (uint256) {
        require(holder != address(0), "Invalid holder");
        
        uint256 credentialId = _nextCredentialId++;
        uint256 expiresAt = validityDuration == 0 ? 0 : block.timestamp + validityDuration;
        
        credentials[credentialId] = Credential({
            id: credentialId,
            holder: holder,
            issuer: msg.sender,
            credentialType: credentialType,
            credentialData: credentialData,
            issuedAt: block.timestamp,
            expiresAt: expiresAt,
            revoked: false,
            soulbound: soulbound
        });
        
        holderCredentials[holder].push(credentialId);
        credentialsByType[holder][credentialType].push(credentialId);
        totalCredentials++;
        
        emit CredentialIssued(credentialId, holder, msg.sender, credentialType);
        return credentialId;
    }
    
    function revokeCredential(uint256 credentialId) external {
        Credential storage cred = credentials[credentialId];
        require(cred.issuer == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        require(!cred.revoked, "Already revoked");
        
        cred.revoked = true;
        
        emit CredentialRevoked(credentialId, msg.sender);
    }
    
    function transferCredential(uint256 credentialId, address newHolder) external {
        Credential storage cred = credentials[credentialId];
        require(cred.holder == msg.sender, "Not holder");
        require(!cred.soulbound, "Credential is soulbound");
        require(!cred.revoked, "Credential revoked");
        
        if (cred.soulbound) {
            emit TransferAttempted(credentialId, msg.sender, newHolder);
            revert("Cannot transfer soulbound credential");
        }
        
        address oldHolder = cred.holder;
        cred.holder = newHolder;
        
        holderCredentials[newHolder].push(credentialId);
        credentialsByType[newHolder][cred.credentialType].push(credentialId);
    }
    
    function getCredential(uint256 credentialId) external view returns (Credential memory) {
        return credentials[credentialId];
    }
    
    function getHolderCredentials(address holder) external view returns (uint256[] memory) {
        return holderCredentials[holder];
    }
    
    function getCredentialsByType(address holder, string memory credentialType) 
        external view returns (uint256[] memory) {
        return credentialsByType[holder][credentialType];
    }
    
    function isValid(uint256 credentialId) public view returns (bool) {
        Credential memory cred = credentials[credentialId];
        if (cred.revoked) return false;
        if (cred.expiresAt != 0 && block.timestamp > cred.expiresAt) return false;
        return true;
    }
    
    function hasCredential(address holder, string memory credentialType) external view returns (bool) {
        uint256[] memory creds = credentialsByType[holder][credentialType];
        for (uint256 i = 0; i < creds.length; i++) {
            if (isValid(creds[i])) return true;
        }
        return false;
    }
}
