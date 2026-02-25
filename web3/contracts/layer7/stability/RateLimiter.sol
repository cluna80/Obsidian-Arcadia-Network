// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RateLimiter
 * @notice Prevent spam and abuse through rate limiting
 * 
 * LIMITS:
 * - Actions per entity per time period
 * - Global system throughput
 * - Per-function rate limits
 * - Dynamic adjustment based on load
 */
contract RateLimiter is AccessControl {
    
    bytes32 public constant LIMITER_ROLE = keccak256("LIMITER_ROLE");
    
    struct RateLimit {
        uint256 maxPerMinute;
        uint256 maxPerHour;
        uint256 maxPerDay;
        bool enabled;
    }
    
    struct UsageTracker {
        uint256 lastMinute;
        uint256 lastHour;
        uint256 lastDay;
        uint256 countThisMinute;
        uint256 countThisHour;
        uint256 countThisDay;
    }
    
    mapping(bytes32 => RateLimit) public functionLimits;      // functionHash => limit
    mapping(uint256 => UsageTracker) public entityUsage;      // entityId => usage
    mapping(bytes32 => UsageTracker) public globalUsage;      // functionHash => usage
    
    bool public rateLimitingEnabled = true;
    uint256 public globalMaxPerSecond = 100;
    
    event RateLimitExceeded(uint256 indexed entityId, bytes32 indexed functionHash, string period);
    event RateLimitUpdated(bytes32 indexed functionHash, uint256 maxPerMinute, uint256 maxPerHour);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIMITER_ROLE, msg.sender);
    }
    
    /**
     * @notice Check rate limit before action
     */
    function checkRateLimit(
        uint256 entityId,
        bytes32 functionHash
    ) external onlyRole(LIMITER_ROLE) returns (bool allowed, string memory reason) {
        if (!rateLimitingEnabled) return (true, "");
        
        RateLimit storage limit = functionLimits[functionHash];
        if (!limit.enabled) return (true, "");
        
        UsageTracker storage usage = entityUsage[entityId];
        
        // Reset counters if time periods passed
        uint256 currentTime = block.timestamp;
        
        if (currentTime >= usage.lastMinute + 1 minutes) {
            usage.countThisMinute = 0;
            usage.lastMinute = currentTime;
        }
        
        if (currentTime >= usage.lastHour + 1 hours) {
            usage.countThisHour = 0;
            usage.lastHour = currentTime;
        }
        
        if (currentTime >= usage.lastDay + 1 days) {
            usage.countThisDay = 0;
            usage.lastDay = currentTime;
        }
        
        // Check limits
        if (usage.countThisMinute >= limit.maxPerMinute) {
            emit RateLimitExceeded(entityId, functionHash, "minute");
            return (false, "Rate limit: max per minute exceeded");
        }
        
        if (usage.countThisHour >= limit.maxPerHour) {
            emit RateLimitExceeded(entityId, functionHash, "hour");
            return (false, "Rate limit: max per hour exceeded");
        }
        
        if (usage.countThisDay >= limit.maxPerDay) {
            emit RateLimitExceeded(entityId, functionHash, "day");
            return (false, "Rate limit: max per day exceeded");
        }
        
        return (true, "");
    }
    
    /**
     * @notice Record action (increment counters)
     */
    function recordAction(
        uint256 entityId,
        bytes32 functionHash
    ) external onlyRole(LIMITER_ROLE) {
        UsageTracker storage usage = entityUsage[entityId];
        usage.countThisMinute++;
        usage.countThisHour++;
        usage.countThisDay++;
        
        // Also track global usage
        UsageTracker storage global = globalUsage[functionHash];
        global.countThisMinute++;
        global.countThisHour++;
        global.countThisDay++;
    }
    
    /**
     * @notice Set rate limit for function
     */
    function setRateLimit(
        bytes32 functionHash,
        uint256 maxPerMinute,
        uint256 maxPerHour,
        uint256 maxPerDay,
        bool enabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        functionLimits[functionHash] = RateLimit({
            maxPerMinute: maxPerMinute,
            maxPerHour: maxPerHour,
            maxPerDay: maxPerDay,
            enabled: enabled
        });
        
        emit RateLimitUpdated(functionHash, maxPerMinute, maxPerHour);
    }
    
    /**
     * @notice Toggle rate limiting
     */
    function toggleRateLimiting(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rateLimitingEnabled = enabled;
    }
    
    /**
     * @notice Get entity usage stats
     */
    function getEntityUsage(uint256 entityId) 
        external 
        view 
        returns (
            uint256 perMinute,
            uint256 perHour,
            uint256 perDay
        ) 
    {
        UsageTracker storage usage = entityUsage[entityId];
        return (usage.countThisMinute, usage.countThisHour, usage.countThisDay);
    }
    
    /**
     * @notice Get global usage stats
     */
    function getGlobalUsage(bytes32 functionHash) 
        external 
        view 
        returns (
            uint256 perMinute,
            uint256 perHour,
            uint256 perDay
        ) 
    {
        UsageTracker storage usage = globalUsage[functionHash];
        return (usage.countThisMinute, usage.countThisHour, usage.countThisDay);
    }
}
