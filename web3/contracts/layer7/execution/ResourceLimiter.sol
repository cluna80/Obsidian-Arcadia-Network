// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ResourceLimiter
 * @notice Prevent resource exhaustion attacks
 * 
 * PREVENTS:
 * - Gas exhaustion
 * - Storage bloat
 * - Network spam
 * - Computational DoS
 */
contract ResourceLimiter is AccessControl {
    
    bytes32 public constant LIMITER_ROLE = keccak256("LIMITER_ROLE");
    
    struct ResourceQuota {
        uint256 gasPerAction;
        uint256 gasPerDay;
        uint256 storagePerEntity;
        uint256 actionsPerHour;
        uint256 actionsPerDay;
    }
    
    struct ResourceUsage {
        uint256 gasUsedToday;
        uint256 storageUsed;
        uint256 actionsThisHour;
        uint256 actionsToday;
        uint256 hourResetTime;
        uint256 dayResetTime;
    }
    
    mapping(uint256 => ResourceQuota) public quotas;      // entityId => quota
    mapping(uint256 => ResourceUsage) public usage;       // entityId => usage
    
    ResourceQuota public defaultQuota;
    
    event QuotaExceeded(uint256 indexed entityId, string resourceType);
    event QuotaSet(uint256 indexed entityId, ResourceQuota quota);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIMITER_ROLE, msg.sender);
        
        // Set reasonable defaults
        defaultQuota = ResourceQuota({
            gasPerAction: 500000,
            gasPerDay: 10000000,
            storagePerEntity: 100000,
            actionsPerHour: 100,
            actionsPerDay: 1000
        });
    }
    
    /**
     * @notice Check if entity can perform action
     */
    function checkResourceAvailability(
        uint256 entityId,
        uint256 estimatedGas
    ) external onlyRole(LIMITER_ROLE) returns (bool allowed, string memory reason) {
        ResourceQuota storage quota = quotas[entityId].gasPerAction > 0 
            ? quotas[entityId] 
            : defaultQuota;
        
        ResourceUsage storage used = usage[entityId];
        
        // Reset counters if time passed
        if (block.timestamp >= used.hourResetTime) {
            used.actionsThisHour = 0;
            used.hourResetTime = block.timestamp + 1 hours;
        }
        
        if (block.timestamp >= used.dayResetTime) {
            used.gasUsedToday = 0;
            used.actionsToday = 0;
            used.dayResetTime = block.timestamp + 1 days;
        }
        
        // Check limits
        if (estimatedGas > quota.gasPerAction) {
            emit QuotaExceeded(entityId, "gasPerAction");
            return (false, "Gas per action exceeded");
        }
        
        if (used.gasUsedToday + estimatedGas > quota.gasPerDay) {
            emit QuotaExceeded(entityId, "gasPerDay");
            return (false, "Daily gas limit exceeded");
        }
        
        if (used.actionsThisHour >= quota.actionsPerHour) {
            emit QuotaExceeded(entityId, "actionsPerHour");
            return (false, "Hourly action limit exceeded");
        }
        
        if (used.actionsToday >= quota.actionsPerDay) {
            emit QuotaExceeded(entityId, "actionsPerDay");
            return (false, "Daily action limit exceeded");
        }
        
        if (used.storageUsed >= quota.storagePerEntity) {
            emit QuotaExceeded(entityId, "storage");
            return (false, "Storage limit exceeded");
        }
        
        return (true, "");
    }
    
    /**
     * @notice Record resource consumption
     */
    function recordResourceUsage(
        uint256 entityId,
        uint256 gasUsed,
        uint256 storageAdded
    ) external onlyRole(LIMITER_ROLE) {
        ResourceUsage storage used = usage[entityId];
        
        used.gasUsedToday += gasUsed;
        used.storageUsed += storageAdded;
        used.actionsThisHour++;
        used.actionsToday++;
    }
    
    /**
     * @notice Set custom quota for entity
     */
    function setEntityQuota(
        uint256 entityId,
        ResourceQuota memory quota
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        quotas[entityId] = quota;
        emit QuotaSet(entityId, quota);
    }
    
    /**
     * @notice Update default quota
     */
    function setDefaultQuota(ResourceQuota memory quota) external onlyRole(DEFAULT_ADMIN_ROLE) {
        defaultQuota = quota;
    }
    
    /**
     * @notice Get current usage
     */
    function getUsage(uint256 entityId) 
        external 
        view 
        returns (ResourceUsage memory) 
    {
        return usage[entityId];
    }
}
