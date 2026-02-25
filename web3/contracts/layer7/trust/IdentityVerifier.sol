// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title IdentityVerifier
/// @notice KYC and identity proof management for OAN entities
contract IdentityVerifier is AccessControl, ReentrancyGuard {

    bytes32 public constant KYC_PROVIDER_ROLE = keccak256("KYC_PROVIDER_ROLE");
    bytes32 public constant REVOKER_ROLE      = keccak256("REVOKER_ROLE");

    enum VerificationLevel { None, Basic, Standard, Enhanced, Full }
    enum ProofType         { GovernmentID, Biometric, AddressProof, SocialProof, EntityProof }

    struct IdentityProof {
        uint256        id;
        address        subject;
        ProofType      proofType;
        VerificationLevel level;
        bytes32        proofHash;       // hash of proof data (stored off-chain)
        uint256        issuedAt;
        uint256        expiresAt;
        bool           revoked;
        address        provider;
        string         jurisdiction;    // e.g. "US", "EU", "GLOBAL"
    }

    struct IdentityRecord {
        VerificationLevel highestLevel;
        uint256[]         proofIds;
        bool              sanctioned;
        bool              active;
        uint256           lastVerified;
    }

    uint256 public proofCounter;
    uint256 public constant PROOF_TTL = 2 * 365 days;

    mapping(uint256 => IdentityProof)   public proofs;
    mapping(address => IdentityRecord)  public records;
    mapping(bytes32 => bool)            public usedProofHashes; // prevent replay
    mapping(address => bool)            public sanctionedList;

    event ProofIssued(uint256 indexed proofId, address indexed subject, VerificationLevel level);
    event ProofRevoked(uint256 indexed proofId, address indexed subject, string reason);
    event IdentityVerified(address indexed subject, VerificationLevel level);
    event SubjectSanctioned(address indexed subject);
    event SubjectCleared(address indexed subject);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KYC_PROVIDER_ROLE,  msg.sender);
        _grantRole(REVOKER_ROLE,       msg.sender);
    }

    /// @notice Issue an identity proof to a subject
    function issueProof(
        address subject,
        ProofType proofType,
        VerificationLevel level,
        bytes32 proofHash,
        string calldata jurisdiction
    ) external onlyRole(KYC_PROVIDER_ROLE) returns (uint256 proofId) {
        require(!sanctionedList[subject],     "Subject is sanctioned");
        require(!usedProofHashes[proofHash],  "Proof hash already used");

        proofCounter++;
        proofId = proofCounter;

        usedProofHashes[proofHash] = true;

        proofs[proofId] = IdentityProof({
            id:           proofId,
            subject:      subject,
            proofType:    proofType,
            level:        level,
            proofHash:    proofHash,
            issuedAt:     block.timestamp,
            expiresAt:    block.timestamp + PROOF_TTL,
            revoked:      false,
            provider:     msg.sender,
            jurisdiction: jurisdiction
        });

        IdentityRecord storage record = records[subject];
        record.proofIds.push(proofId);
        record.active       = true;
        record.lastVerified = block.timestamp;

        if (uint8(level) > uint8(record.highestLevel)) {
            record.highestLevel = level;
        }

        emit ProofIssued(proofId, subject, level);
        emit IdentityVerified(subject, record.highestLevel);
    }

    /// @notice Revoke an identity proof
    function revokeProof(uint256 proofId, string calldata reason) external onlyRole(REVOKER_ROLE) {
        IdentityProof storage proof = proofs[proofId];
        require(!proof.revoked, "Already revoked");
        proof.revoked = true;
        _recalculateLevel(proof.subject);
        emit ProofRevoked(proofId, proof.subject, reason);
    }

    /// @notice Sanction an address (blocks new proofs, flags record)
    function sanctionSubject(address subject) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sanctionedList[subject]      = true;
        records[subject].sanctioned  = true;
        records[subject].highestLevel = VerificationLevel.None;
        emit SubjectSanctioned(subject);
    }

    /// @notice Remove sanction from an address
    function clearSanction(address subject) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sanctionedList[subject]     = false;
        records[subject].sanctioned = false;
        _recalculateLevel(subject);
        emit SubjectCleared(subject);
    }

    function _recalculateLevel(address subject) internal {
        IdentityRecord storage record = records[subject];
        VerificationLevel highest     = VerificationLevel.None;

        for (uint256 i = 0; i < record.proofIds.length; i++) {
            IdentityProof storage p = proofs[record.proofIds[i]];
            if (!p.revoked && block.timestamp <= p.expiresAt) {
                if (uint8(p.level) > uint8(highest)) {
                    highest = p.level;
                }
            }
        }
        record.highestLevel = highest;
    }

    /// @notice Check if a subject meets a minimum verification level
    function meetsLevel(address subject, VerificationLevel required) external view returns (bool) {
        if (sanctionedList[subject]) return false;
        return uint8(records[subject].highestLevel) >= uint8(required);
    }

    /// @notice Get verification level for a subject
    function getVerificationLevel(address subject) external view returns (VerificationLevel) {
        return records[subject].highestLevel;
    }

    /// @notice Get all proof IDs for a subject
    function getProofIds(address subject) external view returns (uint256[] memory) {
        return records[subject].proofIds;
    }

    /// @notice Check if an individual proof is currently valid
    function isProofValid(uint256 proofId) external view returns (bool) {
        IdentityProof storage p = proofs[proofId];
        return !p.revoked && block.timestamp <= p.expiresAt;
    }
}
