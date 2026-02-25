// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title HealthMonitor
 * @notice Monitor system health and performance
 * 
 * MONITORS:
 * - Transaction success rates
 * - Gas usage patterns
 * - Response times
 * - Error frequencies
 */
contract HealthMonitor is AccessControl {
    
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");
    
    struct HealthMetrics {
        uint256 totalTransactions;
        uint256 successfulTransactions;
        uint256 failedTransactions;
        uint256 totalGasUsed;
        uint256 averageGasPerTx;
        uint256 errorCount;
        uint256 lastUpdateTime;
    }
    
    struct SystemHealth {
        HealthStatus status;
        uint256 healthScore;         // 0-100
        uint256 lastCheckTime;
        string[] warnings;
        string[] errors;
    }
    
    enum HealthStatus {
        Healthy,
        Degraded,
        Critical,
        Offline
    }
    
    HealthMetrics public metrics;
    SystemHealth public systemHealth;
    
    mapping(bytes32 => uint256) public errorCounts;     // errorHash => count
    mapping(uint256 => HealthMetrics) public historicalMetrics;  // timestamp => metrics
    
    uint256 public constant HEALTH_CHECK_INTERVAL = 5 minutes;
    uint256 public constant HISTORY_RETENTION = 7 days;
    
    event HealthStatusChanged(HealthStatus oldStatus, HealthStatus newStatus, uint256 healthScore);
    event WarningIssued(string warning);
    event ErrorRecorded(bytes32 errorHash, string description);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MONITOR_ROLE, msg.sender);
        
        systemHealth.status = HealthStatus.Healthy;
        systemHealth.healthScore = 100;
    }
    
    /**
     * @notice Record transaction result
     */
    function recordTransaction(
        bool success,
        uint256 gasUsed
    ) external onlyRole(MONITOR_ROLE) {
        metrics.totalTransactions++;
        metrics.totalGasUsed += gasUsed;
        
        if (success) {
            metrics.successfulTransactions++;
        } else {
            metrics.failedTransactions++;
        }
        
        // Update average gas
        metrics.averageGasPerTx = metrics.totalGasUsed / metrics.totalTransactions;
        metrics.lastUpdateTime = block.timestamp;
        
        // Check if health check needed
        if (block.timestamp >= systemHealth.lastCheckTime + HEALTH_CHECK_INTERVAL) {
            _performHealthCheck();
        }
    }
    
    /**
     * @notice Record error
     */
    function recordError(bytes32 errorHash, string memory description) 
        external 
        onlyRole(MONITOR_ROLE) 
    {
        metrics.errorCount++;
        errorCounts[errorHash]++;
        
        emit ErrorRecorded(errorHash, description);
        
        // Check for critical error frequency
        if (errorCounts[errorHash] > 10) {
            _issueWarning(string(abi.encodePacked("High frequency error: ", description)));
        }
    }
    
    /**
     * @notice Perform system health check
     */
    function _performHealthCheck() internal {
        uint256 healthScore = 100;
        
        // Check success rate
        if (metrics.totalTransactions > 0) {
            uint256 successRate = (metrics.successfulTransactions * 100) / metrics.totalTransactions;
            
            if (successRate < 50) {
                healthScore -= 40;
                _issueWarning("Critical: Success rate below 50%");
            } else if (successRate < 80) {
                healthScore -= 20;
                _issueWarning("Warning: Success rate below 80%");
            }
        }
        
        // Check error frequency
        if (metrics.errorCount > 100) {
            healthScore -= 30;
            _issueWarning("High error frequency detected");
        }
        
        // Check gas usage
        if (metrics.averageGasPerTx > 500000) {
            healthScore -= 10;
            _issueWarning("High average gas consumption");
        }
        
        // Determine status
        HealthStatus oldStatus = systemHealth.status;
        HealthStatus newStatus;
        
        if (healthScore >= 80) newStatus = HealthStatus.Healthy;
        else if (healthScore >= 50) newStatus = HealthStatus.Degraded;
        else if (healthScore >= 20) newStatus = HealthStatus.Critical;
        else newStatus = HealthStatus.Offline;
        
        systemHealth.status = newStatus;
        systemHealth.healthScore = healthScore;
        systemHealth.lastCheckTime = block.timestamp;
        
        if (oldStatus != newStatus) {
            emit HealthStatusChanged(oldStatus, newStatus, healthScore);
        }
        
        // Store historical metrics
        historicalMetrics[block.timestamp] = metrics;
    }
    
    /**
     * @notice Issue warning
     */
    function _issueWarning(string memory warning) internal {
        systemHealth.warnings.push(warning);
        emit WarningIssued(warning);
    }
    
    /**
     * @notice Force health check
     */
    function forceHealthCheck() external onlyRole(MONITOR_ROLE) {
        _performHealthCheck();
    }
    
    /**
     * @notice Get system health
     */
    function getSystemHealth() 
        external 
        view 
        returns (
            HealthStatus status,
            uint256 healthScore,
            uint256 successRate,
            uint256 errorCount
        ) 
    {
        uint256 rate = 0;
        if (metrics.totalTransactions > 0) {
            rate = (metrics.successfulTransactions * 100) / metrics.totalTransactions;
        }
        
        return (
            systemHealth.status,
            systemHealth.healthScore,
            rate,
            metrics.errorCount
        );
    }
    
    /**
     * @notice Clear warnings
     */
    function clearWarnings() external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete systemHealth.warnings;
        delete systemHealth.errors;
    }
}
