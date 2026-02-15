// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedIdentity
 * @dev DID (Decentralized Identifier) system for OAN entities
 */
contract DecentralizedIdentity is Ownable {
    
    struct DID {
        string identifier;          // did:oan:entity:{id}
        address controller;         // Who controls this DID
        uint256 entityId;          // Link to entity
        bool active;
        uint256 createdAt;
        uint256 updatedAt;
        string metadata;           // IPFS hash to full DID document
    }
    
    struct DIDDocument {
        string context;
        string didMethod;
        address[] verificationMethods;
        address[] authentication;
        string[] serviceEndpoints;
    }
    
    // DID string => DID data
    mapping(string => DID) public dids;
    
    // Address => DID string
    mapping(address => string) public addressToDID;
    
    // Entity ID => DID string
    mapping(uint256 => string) public entityToDID;
    
    uint256 public totalDIDs;
    
    event DIDCreated(string indexed did, address indexed controller, uint256 indexed entityId);
    event DIDUpdated(string indexed did, address indexed controller);
    event DIDDeactivated(string indexed did);
    event ControllerChanged(string indexed did, address indexed oldController, address indexed newController);
    
    constructor() Ownable(msg.sender) {}
    
    function createDID(
        uint256 entityId,
        address controller,
        string memory metadata
    ) external returns (string memory) {
        require(bytes(entityToDID[entityId]).length == 0, "DID already exists for entity");
        
        // Generate DID: did:oan:entity:{entityId}
        string memory did = string(abi.encodePacked("did:oan:entity:", uint2str(entityId)));
        
        dids[did] = DID({
            identifier: did,
            controller: controller,
            entityId: entityId,
            active: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            metadata: metadata
        });
        
        addressToDID[controller] = did;
        entityToDID[entityId] = did;
        totalDIDs++;
        
        emit DIDCreated(did, controller, entityId);
        return did;
    }
    
    function updateDIDMetadata(string memory did, string memory newMetadata) external {
        require(dids[did].controller == msg.sender, "Not controller");
        require(dids[did].active, "DID inactive");
        
        dids[did].metadata = newMetadata;
        dids[did].updatedAt = block.timestamp;
        
        emit DIDUpdated(did, msg.sender);
    }
    
    function transferControl(string memory did, address newController) external {
        require(dids[did].controller == msg.sender, "Not controller");
        require(dids[did].active, "DID inactive");
        require(newController != address(0), "Invalid address");
        
        address oldController = dids[did].controller;
        dids[did].controller = newController;
        dids[did].updatedAt = block.timestamp;
        
        delete addressToDID[oldController];
        addressToDID[newController] = did;
        
        emit ControllerChanged(did, oldController, newController);
    }
    
    function deactivateDID(string memory did) external {
        require(dids[did].controller == msg.sender || msg.sender == owner(), "Not authorized");
        require(dids[did].active, "Already inactive");
        
        dids[did].active = false;
        dids[did].updatedAt = block.timestamp;
        
        emit DIDDeactivated(did);
    }
    
    function getDID(string memory did) external view returns (DID memory) {
        return dids[did];
    }
    
    function getDIDByAddress(address addr) external view returns (string memory) {
        return addressToDID[addr];
    }
    
    function getDIDByEntity(uint256 entityId) external view returns (string memory) {
        return entityToDID[entityId];
    }
    
    function isActiveDID(string memory did) external view returns (bool) {
        return dids[did].active;
    }
    
    // Helper function to convert uint to string
    function uint2str(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
