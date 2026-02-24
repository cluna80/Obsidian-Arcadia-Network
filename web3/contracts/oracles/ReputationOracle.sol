// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ReputationOracle
 * @dev On-chain reputation system for OAN entities
 */
contract ReputationOracle is AccessControl {
    
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    
    struct ReputationData {
        int256 score;
        uint256 totalActions;
        uint256 successfulActions;
        uint256 lastUpdate;
        bool initialized;
    }
    
    mapping(uint256 => ReputationData) public reputation;
    
    int256 public constant MIN_REPUTATION = -100;
    int256 public constant MAX_REPUTATION = 1000;
    
    event ReputationUpdated(uint256 indexed entityId, int256 oldScore, int256 newScore);
    event ActionRecorded(uint256 indexed entityId, bool success);
    event ReputationInitialized(uint256 indexed entityId, int256 initialScore);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
    }
    
    /**
     * @notice Initialize reputation for an entity
     * @dev Removed the check that prevented re-initialization for cross-world scenarios
     */
    function initializeReputation(uint256 entityId, int256 initialScore) 
        external 
        onlyRole(UPDATER_ROLE) 
    {
        // Allow re-initialization for cross-world identity
        reputation[entityId] = ReputationData({
            score: initialScore,
            totalActions: 0,
            successfulActions: 0,
            lastUpdate: block.timestamp,
            initialized: true
        });
        
        emit ReputationInitialized(entityId, initialScore);
    }
    
    /**
     * @notice Update reputation score
     */
    function updateReputation(uint256 entityId, int256 scoreChange) 
        external 
        onlyRole(UPDATER_ROLE) 
    {
        require(reputation[entityId].initialized, "Reputation not initialized");
        
        ReputationData storage data = reputation[entityId];
        int256 oldScore = data.score;
        int256 newScore = oldScore + scoreChange;
        
        // Enforce bounds
        if (newScore > MAX_REPUTATION) {
            newScore = MAX_REPUTATION;
        } else if (newScore < MIN_REPUTATION) {
            newScore = MIN_REPUTATION;
        }
        
        data.score = newScore;
        data.lastUpdate = block.timestamp;
        
        emit ReputationUpdated(entityId, oldScore, newScore);
    }
    
    /**
     * @notice Record an action (success/failure)
     */
    function recordAction(uint256 entityId, bool success) 
        external 
        onlyRole(UPDATER_ROLE) 
    {
        require(reputation[entityId].initialized, "Reputation not initialized");
        
        ReputationData storage data = reputation[entityId];
        data.totalActions++;
        
        if (success) {
            data.successfulActions++;
            // Positive action: increase reputation
            int256 oldScore = data.score;
            int256 newScore = oldScore + 10;
            if (newScore > MAX_REPUTATION) newScore = MAX_REPUTATION;
            data.score = newScore;
            emit ReputationUpdated(entityId, oldScore, newScore);
        } else {
            // Negative action: decrease reputation
            int256 oldScore = data.score;
            int256 newScore = oldScore - 5;
            if (newScore < MIN_REPUTATION) newScore = MIN_REPUTATION;
            data.score = newScore;
            emit ReputationUpdated(entityId, oldScore, newScore);
        }
        
        data.lastUpdate = block.timestamp;
        emit ActionRecorded(entityId, success);
    }
    
    /**
     * @notice Get reputation score
     */
    function getScore(uint256 entityId) external view returns (int256) {
        return reputation[entityId].score;
    }
    
    /**
     * @notice Get full reputation data
     */
    function getReputationData(uint256 entityId) 
        external 
        view 
        returns (
            int256 score,
            uint256 totalActions,
            uint256 successfulActions,
            uint256 lastUpdate
        ) 
    {
        ReputationData storage data = reputation[entityId];
        return (
            data.score,
            data.totalActions,
            data.successfulActions,
            data.lastUpdate
        );
    }
    
    /**
     * @notice Check if entity reputation is initialized
     */
    function isInitialized(uint256 entityId) external view returns (bool) {
        return reputation[entityId].initialized;
    }
}
