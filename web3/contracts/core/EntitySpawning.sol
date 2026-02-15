// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EntitySpawning
 * @dev Advanced spawning mechanics with reputation requirements and bonuses
 */
contract EntitySpawning is Ownable {
    
    struct SpawnConfig {
        uint256 energyCost;
        uint256 cooldownBlocks;
        int256 minReputationRequired;
        bool requiresParent;
        bool enabled;
    }
    
    struct SpawnRecord {
        uint256 parentId;
        uint256 childId;
        address spawner;
        uint256 spawnedAt;
        uint256 generation;
    }
    
    mapping(uint256 => SpawnConfig) public spawnTiers;
    mapping(uint256 => SpawnRecord[]) public spawnHistory;
    mapping(uint256 => uint256) public lastSpawnBlock;
    
    uint256 public totalSpawns;
    
    // Default spawn costs by generation
    uint256 public constant BASE_ENERGY_COST = 20;
    uint256 public constant BASE_COOLDOWN = 100;
    
    event EntitySpawned(
        uint256 indexed parentId,
        uint256 indexed childId,
        uint256 generation,
        address indexed spawner
    );
    event SpawnTierConfigured(uint256 tier, uint256 energyCost, int256 minReputation);
    
    constructor() Ownable(msg.sender) {
        // Configure default tiers
        spawnTiers[1] = SpawnConfig(20, 100, 0, false, true);      // Genesis
        spawnTiers[2] = SpawnConfig(30, 150, 10, true, true);      // Second gen
        spawnTiers[3] = SpawnConfig(40, 200, 25, true, true);      // Third gen
    }
    
    function configureSpawnTier(
        uint256 tier,
        uint256 energyCost,
        uint256 cooldownBlocks,
        int256 minReputation,
        bool requiresParent
    ) external onlyOwner {
        spawnTiers[tier] = SpawnConfig({
            energyCost: energyCost,
            cooldownBlocks: cooldownBlocks,
            minReputationRequired: minReputation,
            requiresParent: requiresParent,
            enabled: true
        });
        
        emit SpawnTierConfigured(tier, energyCost, minReputation);
    }
    
    function canSpawn(
        uint256 parentId,
        uint256 generation,
        int256 reputation,
        uint256 energy
    ) public view returns (bool, string memory) {
        SpawnConfig memory config = spawnTiers[generation];
        
        if (!config.enabled) {
            return (false, "Spawn tier not enabled");
        }
        
        if (config.requiresParent && parentId == 0) {
            return (false, "Parent required");
        }
        
        if (reputation < config.minReputationRequired) {
            return (false, "Insufficient reputation");
        }
        
        if (energy < config.energyCost) {
            return (false, "Insufficient energy");
        }
        
        if (block.number < lastSpawnBlock[parentId] + config.cooldownBlocks) {
            return (false, "Cooldown active");
        }
        
        return (true, "Can spawn");
    }
    
    function recordSpawn(
        uint256 parentId,
        uint256 childId,
        address spawner,
        uint256 generation
    ) external {
        spawnHistory[parentId].push(SpawnRecord({
            parentId: parentId,
            childId: childId,
            spawner: spawner,
            spawnedAt: block.timestamp,
            generation: generation
        }));
        
        lastSpawnBlock[parentId] = block.number;
        totalSpawns++;
        
        emit EntitySpawned(parentId, childId, generation, spawner);
    }
    
    function getSpawnHistory(uint256 parentId) external view returns (SpawnRecord[] memory) {
        return spawnHistory[parentId];
    }
    
    function getSpawnCost(uint256 generation) external view returns (uint256) {
        return spawnTiers[generation].energyCost;
    }
    
    function getSpawnRequirements(uint256 generation) external view returns (SpawnConfig memory) {
        return spawnTiers[generation];
    }
}
