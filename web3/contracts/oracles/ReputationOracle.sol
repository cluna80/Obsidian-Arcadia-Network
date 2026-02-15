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
    
    // Reputation bounds
    int256 public constant MIN_REPUTATION = -100;
    int256 public constant MAX_REPUTATION = 1000;
    
    event ReputationUpdated(uint256 indexed entityId, int256 oldScore, int256 newScore);
    event ActionRecorded(uint256 indexed entityId, bool success);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
    }
    
    function initializeReputation(uint256 entityId) external onlyRole(ORACLE_ROLE) {
        require(!reputation[entityId].initialized, "Already initialized");
        
        reputation[entityId] = ReputationData({
            score: 0,
            totalActions: 0,
            successfulActions: 0,
            lastUpdate: block.timestamp,
            initialized: true
        });
    }
    
    function updateReputation(uint256 entityId, int256 delta) external onlyRole(UPDATER_ROLE) {
        require(reputation[entityId].initialized, "Not initialized");
        
        int256 oldScore = reputation[entityId].score;
        int256 newScore = oldScore + delta;
        
        // Enforce bounds
        if (newScore < MIN_REPUTATION) newScore = MIN_REPUTATION;
        if (newScore > MAX_REPUTATION) newScore = MAX_REPUTATION;
        
        reputation[entityId].score = newScore;
        reputation[entityId].lastUpdate = block.timestamp;
        
        emit ReputationUpdated(entityId, oldScore, newScore);
    }
    
    function recordAction(uint256 entityId, bool success) external onlyRole(UPDATER_ROLE) {
        require(reputation[entityId].initialized, "Not initialized");
        
        reputation[entityId].totalActions++;
        if (success) {
            reputation[entityId].successfulActions++;
        }
        
        emit ActionRecorded(entityId, success);
    }
    
    function getReputation(uint256 entityId) external view returns (ReputationData memory) {
        return reputation[entityId];
    }
    
    function getScore(uint256 entityId) external view returns (int256) {
        return reputation[entityId].score;
    }
    
    function getSuccessRate(uint256 entityId) external view returns (uint256) {
        if (reputation[entityId].totalActions == 0) return 0;
        return (reputation[entityId].successfulActions * 100) / reputation[entityId].totalActions;
    }
}
