// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CircuitBreaker
 * @notice Automatic system pause on anomalies
 * 
 * TRIGGERS:
 * - Abnormal transaction volume
 * - Price manipulation
 * - Rapid reputation changes
 * - Smart contract exploits
 */
contract CircuitBreaker is AccessControl {
    
    bytes32 public constant BREAKER_ROLE = keccak256("BREAKER_ROLE");
    
    struct Threshold {
        uint256 maxTransactionsPerBlock;
        uint256 maxValuePerBlock;
        uint256 maxReputationChange;
        uint256 maxFailureRate;          // Basis points
        bool enabled;
    }
    
    struct BreakerState {
        bool isTripped;
        uint256 trippedAt;
        TripReason reason;
        uint256 cooldownPeriod;
        uint256 tripCount;
    }
    
    struct Metric {
        uint256 blockNumber;
        uint256 transactionCount;
        uint256 totalValue;
        uint256 failureCount;
        int256 maxReputationDelta;
    }
    
    enum TripReason {
        None,
        HighVolume,
        HighValue,
        HighFailures,
        ReputationSpike,
        ManualTrip
    }
    
    Threshold public thresholds;
    BreakerState public breakerState;
    mapping(uint256 => Metric) public blockMetrics;  // blockNumber => metrics
    
    uint256 public constant DEFAULT_COOLDOWN = 1 hours;
    uint256 public currentBlock;
    
    event CircuitTripped(TripReason reason, uint256 timestamp);
    event CircuitReset(uint256 timestamp);
    event ThresholdUpdated(string parameter, uint256 newValue);
    event AnomalyDetected(TripReason reason, uint256 value, uint256 threshold);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BREAKER_ROLE, msg.sender);
        
        // Set default thresholds
        thresholds = Threshold({
            maxTransactionsPerBlock: 1000,
            maxValuePerBlock: 1000 ether,
            maxReputationChange: 500,
            maxFailureRate: 5000,    // 50%
            enabled: true
        });
        
        breakerState.cooldownPeriod = DEFAULT_COOLDOWN;
    }
    
    /**
     * @notice Record transaction metrics
     */
    function recordTransaction(
        uint256 value,
        bool success,
        int256 reputationChange
    ) external onlyRole(BREAKER_ROLE) {
        if (breakerState.isTripped) return;
        
        uint256 blockNum = block.number;
        Metric storage metric = blockMetrics[blockNum];
        
        // Initialize if first tx in block
        if (metric.blockNumber == 0) {
            metric.blockNumber = blockNum;
        }
        
        // Update metrics
        metric.transactionCount++;
        metric.totalValue += value;
        if (!success) metric.failureCount++;
        
        // Track max reputation change
        if (reputationChange > metric.maxReputationDelta) {
            metric.maxReputationDelta = reputationChange;
        } else if (reputationChange < -metric.maxReputationDelta) {
            metric.maxReputationDelta = -reputationChange;
        }
        
        // Check thresholds
        _checkThresholds(metric);
    }
    
    /**
     * @notice Check if metrics exceed thresholds
     */
    function _checkThresholds(Metric storage metric) internal {
        if (!thresholds.enabled) return;
        
        // Check transaction volume
        if (metric.transactionCount > thresholds.maxTransactionsPerBlock) {
            _tripCircuit(TripReason.HighVolume);
            emit AnomalyDetected(
                TripReason.HighVolume,
                metric.transactionCount,
                thresholds.maxTransactionsPerBlock
            );
            return;
        }
        
        // Check value
        if (metric.totalValue > thresholds.maxValuePerBlock) {
            _tripCircuit(TripReason.HighValue);
            emit AnomalyDetected(
                TripReason.HighValue,
                metric.totalValue,
                thresholds.maxValuePerBlock
            );
            return;
        }
        
        // Check failure rate
        if (metric.transactionCount > 0) {
            uint256 failureRate = (metric.failureCount * 10000) / metric.transactionCount;
            if (failureRate > thresholds.maxFailureRate) {
                _tripCircuit(TripReason.HighFailures);
                emit AnomalyDetected(
                    TripReason.HighFailures,
                    failureRate,
                    thresholds.maxFailureRate
                );
                return;
            }
        }
        
        // Check reputation spike
        if (uint256(metric.maxReputationDelta) > thresholds.maxReputationChange) {
            _tripCircuit(TripReason.ReputationSpike);
            emit AnomalyDetected(
                TripReason.ReputationSpike,
                uint256(metric.maxReputationDelta),
                thresholds.maxReputationChange
            );
            return;
        }
    }
    
    /**
     * @notice Trip the circuit breaker
     */
    function _tripCircuit(TripReason reason) internal {
        breakerState.isTripped = true;
        breakerState.trippedAt = block.timestamp;
        breakerState.reason = reason;
        breakerState.tripCount++;
        
        emit CircuitTripped(reason, block.timestamp);
    }
    
    /**
     * @notice Manual circuit trip
     */
    function tripCircuit(string memory reason) external onlyRole(BREAKER_ROLE) {
        _tripCircuit(TripReason.ManualTrip);
    }
    
    /**
     * @notice Reset circuit breaker
     */
    function resetCircuit() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(breakerState.isTripped, "Not tripped");
        require(
            block.timestamp >= breakerState.trippedAt + breakerState.cooldownPeriod,
            "Cooldown not met"
        );
        
        breakerState.isTripped = false;
        breakerState.reason = TripReason.None;
        
        emit CircuitReset(block.timestamp);
    }
    
    /**
     * @notice Update thresholds
     */
    function updateThresholds(
        uint256 maxTxPerBlock,
        uint256 maxValuePerBlock,
        uint256 maxRepChange,
        uint256 maxFailRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        thresholds.maxTransactionsPerBlock = maxTxPerBlock;
        thresholds.maxValuePerBlock = maxValuePerBlock;
        thresholds.maxReputationChange = maxRepChange;
        thresholds.maxFailureRate = maxFailRate;
    }
    
    /**
     * @notice Check if system is operational
     */
    function isOperational() external view returns (bool) {
        return !breakerState.isTripped;
    }
    
    /**
     * @notice Get current metrics
     */
    function getCurrentMetrics() external view returns (Metric memory) {
        return blockMetrics[block.number];
    }
}
