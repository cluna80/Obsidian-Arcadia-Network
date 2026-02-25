// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ActionLogger
 * @notice Immutable action history for all entities
 * 
 * KEY FEATURES:
 * - Append-only log
 * - Gas-efficient storage
 * - Indexed for fast queries
 * - Tamper-proof audit trail
 */
contract ActionLogger {
    
    struct ActionLog {
        uint256 logId;
        uint256 entityId;
        bytes32 actionHash;
        address executor;
        uint256 timestamp;
        uint256 gasUsed;
        bool success;
        bytes32 resultHash;
        bytes metadata;
    }
    
    mapping(uint256 => ActionLog) public logs;
    mapping(uint256 => uint256[]) public entityLogs;    // entityId => logIds
    mapping(address => uint256[]) public executorLogs;   // executor => logIds
    mapping(bytes32 => uint256[]) public actionTypeLogs; // actionHash => logIds
    
    uint256 public logCount;
    uint256 public totalGasLogged;
    
    event ActionLogged(
        uint256 indexed logId,
        uint256 indexed entityId,
        bytes32 indexed actionHash,
        bool success
    );
    
    /**
     * @notice Log an entity action (append-only)
     */
    function logAction(
        uint256 entityId,
        bytes32 actionHash,
        address executor,
        uint256 gasUsed,
        bool success,
        bytes32 resultHash,
        bytes memory metadata
    ) external returns (uint256) {
        logCount++;
        uint256 logId = logCount;
        
        logs[logId] = ActionLog({
            logId: logId,
            entityId: entityId,
            actionHash: actionHash,
            executor: executor,
            timestamp: block.timestamp,
            gasUsed: gasUsed,
            success: success,
            resultHash: resultHash,
            metadata: metadata
        });
        
        entityLogs[entityId].push(logId);
        executorLogs[executor].push(logId);
        actionTypeLogs[actionHash].push(logId);
        
        totalGasLogged += gasUsed;
        
        emit ActionLogged(logId, entityId, actionHash, success);
        return logId;
    }
    
    /**
     * @notice Get entity's action history
     */
    function getEntityHistory(uint256 entityId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return entityLogs[entityId];
    }
    
    /**
     * @notice Get executor's action history
     */
    function getExecutorHistory(address executor) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return executorLogs[executor];
    }
    
    /**
     * @notice Get all logs for action type
     */
    function getActionTypeLogs(bytes32 actionHash) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return actionTypeLogs[actionHash];
    }
    
    /**
     * @notice Get action statistics
     */
    function getActionStats(uint256 entityId) 
        external 
        view 
        returns (
            uint256 totalActions,
            uint256 successfulActions,
            uint256 failedActions,
            uint256 totalGasConsumed
        ) 
    {
        uint256[] storage entityLogIds = entityLogs[entityId];
        totalActions = entityLogIds.length;
        
        uint256 gasConsumed = 0;
        uint256 successes = 0;
        
        for (uint256 i = 0; i < entityLogIds.length; i++) {
            ActionLog storage log = logs[entityLogIds[i]];
            gasConsumed += log.gasUsed;
            if (log.success) successes++;
        }
        
        return (
            totalActions,
            successes,
            totalActions - successes,
            gasConsumed
        );
    }
    
    /**
     * @notice Verify action occurred
     */
    function verifyAction(
        uint256 logId,
        uint256 entityId,
        bytes32 actionHash,
        bytes32 resultHash
    ) external view returns (bool) {
        ActionLog storage log = logs[logId];
        return (
            log.entityId == entityId &&
            log.actionHash == actionHash &&
            log.resultHash == resultHash
        );
    }
}
