// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TrustOracle
/// @notice Verify and score trust claims across the OAN protocol
contract TrustOracle is AccessControl, ReentrancyGuard {

    bytes32 public constant ORACLE_ROLE    = keccak256("ORACLE_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    enum ClaimStatus  { Pending, Verified, Rejected, Expired }
    enum ClaimType    { Identity, Behavior, Reputation, Credential, Custom }

    struct TrustClaim {
        uint256 id;
        address subject;
        ClaimType claimType;
        bytes32   dataHash;        // hash of off-chain claim data
        uint256   score;           // 0-1000
        uint256   issuedAt;
        uint256   expiresAt;
        ClaimStatus status;
        address   issuer;
        string    metadataURI;
    }

    struct TrustProfile {
        uint256 overallScore;      // weighted average 0-1000
        uint256 totalClaims;
        uint256 verifiedClaims;
        uint256 lastUpdated;
        bool    isActive;
    }

    uint256 public claimCounter;
    uint256 public constant MAX_SCORE      = 1000;
    uint256 public constant CLAIM_TTL      = 365 days;
    uint256 public constant MIN_VALIDATORS = 2;

    mapping(uint256 => TrustClaim)                       public claims;
    mapping(address => TrustProfile)                     public profiles;
    mapping(address => uint256[])                        public subjectClaims;
    mapping(uint256 => mapping(address => bool))         public claimVotes;
    mapping(uint256 => uint256)                          public approvalCount;
    mapping(uint256 => uint256)                          public rejectionCount;

    event ClaimSubmitted(uint256 indexed claimId, address indexed subject, ClaimType claimType);
    event ClaimVerified(uint256 indexed claimId, address indexed subject, uint256 score);
    event ClaimRejected(uint256 indexed claimId, address indexed subject, string reason);
    event TrustScoreUpdated(address indexed subject, uint256 newScore);
    event ValidatorVoted(uint256 indexed claimId, address indexed validator, bool approved);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE,        msg.sender);
        _grantRole(VALIDATOR_ROLE,     msg.sender);
    }

    /// @notice Submit a new trust claim for verification
    function submitClaim(
        address subject,
        ClaimType claimType,
        bytes32 dataHash,
        string calldata metadataURI
    ) external onlyRole(ORACLE_ROLE) returns (uint256 claimId) {
        claimCounter++;
        claimId = claimCounter;

        claims[claimId] = TrustClaim({
            id:          claimId,
            subject:     subject,
            claimType:   claimType,
            dataHash:    dataHash,
            score:       0,
            issuedAt:    block.timestamp,
            expiresAt:   block.timestamp + CLAIM_TTL,
            status:      ClaimStatus.Pending,
            issuer:      msg.sender,
            metadataURI: metadataURI
        });

        subjectClaims[subject].push(claimId);

        if (!profiles[subject].isActive) {
            profiles[subject].isActive = true;
        }
        profiles[subject].totalClaims++;

        emit ClaimSubmitted(claimId, subject, claimType);
    }

    /// @notice Validator votes on a pending claim
    function voteClaim(uint256 claimId, bool approve, uint256 score) external onlyRole(VALIDATOR_ROLE) {
        TrustClaim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Pending, "Claim not pending");
        require(!claimVotes[claimId][msg.sender],    "Already voted");
        require(score <= MAX_SCORE,                   "Score exceeds max");

        claimVotes[claimId][msg.sender] = true;

        if (approve) {
            approvalCount[claimId]++;
            claim.score = (claim.score + score) / approvalCount[claimId] == 0
                ? score
                : (claim.score * (approvalCount[claimId] - 1) + score) / approvalCount[claimId];
        } else {
            rejectionCount[claimId]++;
        }

        emit ValidatorVoted(claimId, msg.sender, approve);

        if (approvalCount[claimId] >= MIN_VALIDATORS) {
            _verifyClaim(claimId);
        } else if (rejectionCount[claimId] >= MIN_VALIDATORS) {
            claim.status = ClaimStatus.Rejected;
            emit ClaimRejected(claimId, claim.subject, "Validator consensus: rejected");
        }
    }

    /// @notice Directly verify a claim (oracle shortcut)
    function verifyClaim(uint256 claimId, uint256 score) external onlyRole(ORACLE_ROLE) {
        require(score <= MAX_SCORE, "Score exceeds max");
        TrustClaim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Pending, "Claim not pending");
        claim.score = score;
        _verifyClaim(claimId);
    }

    function _verifyClaim(uint256 claimId) internal {
        TrustClaim storage claim = claims[claimId];
        claim.status = ClaimStatus.Verified;
        profiles[claim.subject].verifiedClaims++;
        _recalculateScore(claim.subject);
        emit ClaimVerified(claimId, claim.subject, claim.score);
    }

    function _recalculateScore(address subject) internal {
        TrustProfile storage profile = profiles[subject];
        uint256[] storage ids = subjectClaims[subject];
        uint256 total;
        uint256 count;

        for (uint256 i = 0; i < ids.length; i++) {
            TrustClaim storage c = claims[ids[i]];
            if (c.status == ClaimStatus.Verified && block.timestamp <= c.expiresAt) {
                total += c.score;
                count++;
            }
        }

        profile.overallScore = count > 0 ? total / count : 0;
        profile.lastUpdated  = block.timestamp;
        emit TrustScoreUpdated(subject, profile.overallScore);
    }

    /// @notice Get trust score for an address
    function getTrustScore(address subject) external view returns (uint256) {
        return profiles[subject].overallScore;
    }

    /// @notice Get all claims for a subject
    function getSubjectClaims(address subject) external view returns (uint256[] memory) {
        return subjectClaims[subject];
    }

    /// @notice Check if a claim is currently valid
    function isClaimValid(uint256 claimId) external view returns (bool) {
        TrustClaim storage c = claims[claimId];
        return c.status == ClaimStatus.Verified && block.timestamp <= c.expiresAt;
    }
}
