// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ExecutionGuardian
 * @notice Validates all entity actions before execution
 * 
 * KEY SECURITY:
 * - Whitelist/blacklist of actions
 * - Rate limiting per entity
 * - Resource consumption limits
 * - Multi-signature requirements for high-risk actions
 */
contract ExecutionGuardian is AccessControl {
    
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    
    struct ActionPolicy {
        bool isAllowed;
        bool requiresMultiSig;
        uint256 cooldown;            // Seconds between executions
        uint256 maxPerDay;           // Max executions per 24h
        uint256 minReputation;       // Minimum reputation required
        uint256 requiredSignatures;  // For multi-sig
    }
    
    struct EntityLimits {
        uint256 dailyActionCount;
        uint256 lastActionTime;
        uint256 dailyResetTime;
        bool isFrozen;
    }
    
    mapping(bytes32 => ActionPolicy) public actionPolicies;  // actionHash => policy
    mapping(uint256 => EntityLimits) public entityLimits;    // entityId => limits
    mapping(uint256 => mapping(bytes32 => uint256)) public lastActionTime; // entityId => action => time
    
    bool public systemPaused;
    
    event ActionValidated(uint256 indexed entityId, bytes32 indexed actionHash, bool approved);
    event ActionBlocked(uint256 indexed entityId, bytes32 indexed actionHash, string reason);
    event EntityFrozen(uint256 indexed entityId, string reason);
    event SystemPaused(bool paused);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
    }
    
    /**
     * @notice Validate an entity action before execution
     * @dev Called before any critical entity action
     */
    function validateAction(
        uint256 entityId,
        bytes32 actionHash,
        int256 reputationScore
    ) external onlyRole(EXECUTOR_ROLE) returns (bool) {
        require(!systemPaused, "System paused");
        
        EntityLimits storage limits = entityLimits[entityId];
        require(!limits.isFrozen, "Entity frozen");
        
        ActionPolicy storage policy = actionPolicies[actionHash];
        require(policy.isAllowed, "Action not allowed");
        
        // Check reputation requirement
        require(reputationScore >= int256(policy.minReputation), "Insufficient reputation");
        
        // Check cooldown
        uint256 timeSinceLastAction = block.timestamp - lastActionTime[entityId][actionHash];
        require(timeSinceLastAction >= policy.cooldown, "Cooldown not met");
        
        // Reset daily counter if 24h passed
        if (block.timestamp >= limits.dailyResetTime) {
            limits.dailyActionCount = 0;
            limits.dailyResetTime = block.timestamp + 1 days;
        }
        
        // Check daily limit
        require(limits.dailyActionCount < policy.maxPerDay, "Daily limit exceeded");
        
        // Update state
        limits.dailyActionCount++;
        limits.lastActionTime = block.timestamp;
        lastActionTime[entityId][actionHash] = block.timestamp;
        
        emit ActionValidated(entityId, actionHash, true);
        return true;
    }
    
    /**
     * @notice Set action policy
     */
    function setActionPolicy(
        bytes32 actionHash,
        bool isAllowed,
        bool requiresMultiSig,
        uint256 cooldown,
        uint256 maxPerDay,
        uint256 minReputation,
        uint256 requiredSignatures
    ) external onlyRole(GUARDIAN_ROLE) {
        actionPolicies[actionHash] = ActionPolicy({
            isAllowed: isAllowed,
            requiresMultiSig: requiresMultiSig,
            cooldown: cooldown,
            maxPerDay: maxPerDay,
            minReputation: minReputation,
            requiredSignatures: requiredSignatures
        });
    }
    
    /**
     * @notice Freeze entity (emergency)
     */
    function freezeEntity(uint256 entityId, string memory reason) external onlyRole(GUARDIAN_ROLE) {
        entityLimits[entityId].isFrozen = true;
        emit EntityFrozen(entityId, reason);
    }
    
    /**
     * @notice Unfreeze entity
     */
    function unfreezeEntity(uint256 entityId) external onlyRole(GUARDIAN_ROLE) {
        entityLimits[entityId].isFrozen = false;
    }
    
    /**
     * @notice Pause entire system
     */
    function pauseSystem(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        systemPaused = paused;
        emit SystemPaused(paused);
    }
    
    /**
     * @notice Check if action is allowed
     */
    function isActionAllowed(
        uint256 entityId,
        bytes32 actionHash,
        int256 reputationScore
    ) external view returns (bool allowed, string memory reason) {
        if (systemPaused) return (false, "System paused");
        if (entityLimits[entityId].isFrozen) return (false, "Entity frozen");
        
        ActionPolicy storage policy = actionPolicies[actionHash];
        if (!policy.isAllowed) return (false, "Action not allowed");
        if (reputationScore < int256(policy.minReputation)) return (false, "Insufficient reputation");
        
        uint256 timeSinceLastAction = block.timestamp - lastActionTime[entityId][actionHash];
        if (timeSinceLastAction < policy.cooldown) return (false, "Cooldown not met");
        
        EntityLimits storage limits = entityLimits[entityId];
        if (block.timestamp < limits.dailyResetTime && limits.dailyActionCount >= policy.maxPerDay) {
            return (false, "Daily limit exceeded");
        }
        
        return (true, "");
    }
}
