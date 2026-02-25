// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BehaviorAuditor
 * @notice Detect anomalous entity behavior
 * 
 * DETECTS:
 * - Unusual action patterns
 * - Rapid reputation changes
 * - Suspicious transactions
 * - Bot-like behavior
 */
contract BehaviorAuditor is AccessControl {
    
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    
    struct BehaviorProfile {
        uint256 entityId;
        uint256 totalActions;
        uint256 suspiciousActions;
        uint256 lastAuditTime;
        uint256 riskScore;           // 0-100
        bool flaggedForReview;
        string[] anomalies;
    }
    
    struct AnomalyRule {
        bytes32 ruleId;
        string description;
        uint256 threshold;
        uint256 severity;            // 1-10
        bool isActive;
    }
    
    mapping(uint256 => BehaviorProfile) public profiles;
    mapping(bytes32 => AnomalyRule) public rules;
    mapping(uint256 => bytes32[]) public entityAnomalies;  // entityId => ruleIds triggered
    
    uint256 public constant HIGH_RISK_THRESHOLD = 70;
    uint256 public auditCount;
    
    event AnomalyDetected(uint256 indexed entityId, bytes32 indexed ruleId, uint256 severity);
    event EntityFlagged(uint256 indexed entityId, uint256 riskScore);
    event AuditCompleted(uint256 indexed entityId, uint256 riskScore);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
        
        // Initialize default rules
        _createDefaultRules();
    }
    
    /**
     * @notice Audit entity behavior
     */
    function auditEntity(
        uint256 entityId,
        uint256 recentActions,
        uint256 recentFailures,
        int256 reputationDelta
    ) external onlyRole(AUDITOR_ROLE) returns (uint256 riskScore) {
        BehaviorProfile storage profile = profiles[entityId];
        
        profile.entityId = entityId;
        profile.totalActions += recentActions;
        profile.lastAuditTime = block.timestamp;
        
        riskScore = 0;
        
        // Check failure rate
        if (recentActions > 0) {
            uint256 failureRate = (recentFailures * 100) / recentActions;
            if (failureRate > 50) {
                riskScore += 20;
                _recordAnomaly(entityId, keccak256("HIGH_FAILURE_RATE"), 6);
            }
        }
        
        // Check reputation manipulation
        if (reputationDelta > 100 || reputationDelta < -100) {
            riskScore += 30;
            _recordAnomaly(entityId, keccak256("REPUTATION_MANIPULATION"), 8);
        }
        
        // Check action spam
        if (recentActions > 100) {
            riskScore += 25;
            _recordAnomaly(entityId, keccak256("ACTION_SPAM"), 7);
        }
        
        profile.riskScore = riskScore;
        
        if (riskScore >= HIGH_RISK_THRESHOLD) {
            profile.flaggedForReview = true;
            emit EntityFlagged(entityId, riskScore);
        }
        
        auditCount++;
        emit AuditCompleted(entityId, riskScore);
        
        return riskScore;
    }
    
    /**
     * @notice Record anomaly
     */
    function _recordAnomaly(
        uint256 entityId,
        bytes32 ruleId,
        uint256 severity
    ) internal {
        entityAnomalies[entityId].push(ruleId);
        profiles[entityId].suspiciousActions++;
        
        emit AnomalyDetected(entityId, ruleId, severity);
    }
    
    /**
     * @notice Create anomaly detection rule
     */
    function createRule(
        bytes32 ruleId,
        string memory description,
        uint256 threshold,
        uint256 severity
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rules[ruleId] = AnomalyRule({
            ruleId: ruleId,
            description: description,
            threshold: threshold,
            severity: severity,
            isActive: true
        });
    }
    
    /**
     * @notice Initialize default rules
     */
    function _createDefaultRules() internal {
        rules[keccak256("HIGH_FAILURE_RATE")] = AnomalyRule({
            ruleId: keccak256("HIGH_FAILURE_RATE"),
            description: "Action failure rate > 50%",
            threshold: 50,
            severity: 6,
            isActive: true
        });
        
        rules[keccak256("REPUTATION_MANIPULATION")] = AnomalyRule({
            ruleId: keccak256("REPUTATION_MANIPULATION"),
            description: "Reputation change > 100 in short period",
            threshold: 100,
            severity: 8,
            isActive: true
        });
        
        rules[keccak256("ACTION_SPAM")] = AnomalyRule({
            ruleId: keccak256("ACTION_SPAM"),
            description: "More than 100 actions in audit period",
            threshold: 100,
            severity: 7,
            isActive: true
        });
    }
    
    /**
     * @notice Get entity risk profile
     */
    function getRiskProfile(uint256 entityId) 
        external 
        view 
        returns (
            uint256 riskScore,
            bool flagged,
            uint256 suspiciousActions,
            uint256 totalActions
        ) 
    {
        BehaviorProfile storage profile = profiles[entityId];
        return (
            profile.riskScore,
            profile.flaggedForReview,
            profile.suspiciousActions,
            profile.totalActions
        );
    }
    
    /**
     * @notice Clear entity flag (after manual review)
     */
    function clearFlag(uint256 entityId) external onlyRole(AUDITOR_ROLE) {
        profiles[entityId].flaggedForReview = false;
        profiles[entityId].riskScore = 0;
    }
}
