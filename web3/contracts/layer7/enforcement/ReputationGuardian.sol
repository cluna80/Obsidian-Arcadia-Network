// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ReputationGuardian
 * @notice Enforce reputation rules and prevent manipulation
 * 
 * ENFORCES:
 * - Minimum reputation thresholds
 * - Reputation decay over time
 * - Anti-gaming mechanics
 * - Reputation recovery paths
 */
contract ReputationGuardian is AccessControl {
    
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    
    struct ReputationRules {
        int256 minimumReputation;
        int256 maximumReputation;
        uint256 decayRate;               // Basis points per day
        uint256 decayInterval;           // Seconds between decay
        bool decayEnabled;
        uint256 penaltyMultiplier;       // For violations
    }
    
    struct ReputationStatus {
        int256 currentReputation;
        int256 baseReputation;
        uint256 lastDecayTime;
        uint256 violationCount;
        bool isRestricted;
        string restrictionReason;
    }
    
    struct Violation {
        uint256 violationId;
        uint256 entityId;
        ViolationType violationType;
        int256 penaltyAmount;
        uint256 timestamp;
        string description;
    }
    
    enum ViolationType {
        Manipulation,
        Spam,
        Abuse,
        Fraud,
        Collusion,
        Sybil
    }
    
    ReputationRules public rules;
    mapping(uint256 => ReputationStatus) public reputationStatus;
    mapping(uint256 => Violation[]) public violations;
    
    uint256 public violationCount;
    
    event ReputationDecayed(uint256 indexed entityId, int256 oldRep, int256 newRep);
    event ViolationRecorded(uint256 indexed entityId, ViolationType violationType, int256 penalty);
    event ReputationRestricted(uint256 indexed entityId, string reason);
    event RestrictionLifted(uint256 indexed entityId);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        
        // Set default rules
        rules = ReputationRules({
            minimumReputation: -100,
            maximumReputation: 1000,
            decayRate: 10,              // 0.1% per day
            decayInterval: 1 days,
            decayEnabled: true,
            penaltyMultiplier: 2
        });
    }
    
    /**
     * @notice Apply reputation decay
     */
    function applyDecay(uint256 entityId) external onlyRole(GUARDIAN_ROLE) {
        ReputationStatus storage status = reputationStatus[entityId];
        
        if (!rules.decayEnabled) return;
        if (block.timestamp < status.lastDecayTime + rules.decayInterval) return;
        
        int256 oldRep = status.currentReputation;
        
        // Calculate decay periods
        uint256 periods = (block.timestamp - status.lastDecayTime) / rules.decayInterval;
        
        // Apply decay (lose reputation over time if inactive)
        int256 decayAmount = (oldRep * int256(rules.decayRate) * int256(periods)) / 10000;
        int256 newRep = oldRep - decayAmount;
        
        // Enforce bounds
        if (newRep < rules.minimumReputation) newRep = rules.minimumReputation;
        
        status.currentReputation = newRep;
        status.lastDecayTime = block.timestamp;
        
        emit ReputationDecayed(entityId, oldRep, newRep);
    }
    
    /**
     * @notice Record reputation violation
     */
    function recordViolation(
        uint256 entityId,
        ViolationType violationType,
        string memory description
    ) external onlyRole(GUARDIAN_ROLE) {
        violationCount++;
        
        // Calculate penalty
        int256 basePenalty = _getViolationPenalty(violationType);
        int256 penalty = basePenalty * int256(rules.penaltyMultiplier);
        
        Violation memory violation = Violation({
            violationId: violationCount,
            entityId: entityId,
            violationType: violationType,
            penaltyAmount: penalty,
            timestamp: block.timestamp,
            description: description
        });
        
        violations[entityId].push(violation);
        
        ReputationStatus storage status = reputationStatus[entityId];
        status.violationCount++;
        status.currentReputation -= penalty;
        
        // Enforce minimum
        if (status.currentReputation < rules.minimumReputation) {
            status.currentReputation = rules.minimumReputation;
        }
        
        emit ViolationRecorded(entityId, violationType, penalty);
        
        // Auto-restrict if violations exceed threshold
        if (status.violationCount >= 3) {
            _restrictEntity(entityId, "Multiple violations");
        }
    }
    
    /**
     * @notice Get violation penalty amount
     */
    function _getViolationPenalty(ViolationType violationType) 
        internal 
        pure 
        returns (int256) 
    {
        if (violationType == ViolationType.Fraud) return 200;
        if (violationType == ViolationType.Manipulation) return 150;
        if (violationType == ViolationType.Collusion) return 100;
        if (violationType == ViolationType.Sybil) return 100;
        if (violationType == ViolationType.Abuse) return 50;
        if (violationType == ViolationType.Spam) return 25;
        return 10;
    }
    
    /**
     * @notice Restrict entity
     */
    function _restrictEntity(uint256 entityId, string memory reason) internal {
        ReputationStatus storage status = reputationStatus[entityId];
        status.isRestricted = true;
        status.restrictionReason = reason;
        
        emit ReputationRestricted(entityId, reason);
    }
    
    /**
     * @notice Restrict entity (external call)
     */
    function restrictEntity(uint256 entityId, string memory reason) 
        external 
        onlyRole(GUARDIAN_ROLE) 
    {
        _restrictEntity(entityId, reason);
    }
    
    /**
     * @notice Lift restriction
     */
    function liftRestriction(uint256 entityId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ReputationStatus storage status = reputationStatus[entityId];
        status.isRestricted = false;
        status.restrictionReason = "";
        
        emit RestrictionLifted(entityId);
    }
    
    /**
     * @notice Check if entity meets reputation requirement
     */
    function meetsReputationRequirement(
        uint256 entityId,
        int256 requiredReputation
    ) external view returns (bool) {
        ReputationStatus storage status = reputationStatus[entityId];
        return !status.isRestricted && status.currentReputation >= requiredReputation;
    }
    
    /**
     * @notice Update rules
     */
    function updateRules(ReputationRules memory newRules) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        rules = newRules;
    }
    
    /**
     * @notice Get violation history
     */
    function getViolations(uint256 entityId) 
        external 
        view 
        returns (Violation[] memory) 
    {
        return violations[entityId];
    }
}
