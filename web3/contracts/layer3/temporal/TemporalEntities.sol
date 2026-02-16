// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TemporalEntities
 * @dev Entities that age, decay, and evolve over time
 * 
 * Revolutionary: Assets become dynamic, not static
 */
contract TemporalEntities is Ownable {
    
    enum LifeStage {Youth, Adult, Prime, Elder, Deceased}
    
    struct TemporalEntity {
        uint256 entityId;
        uint256 birthTime;
        uint256 lastUpdate;
        uint256 age;                    // In seconds
        LifeStage lifeStage;
        uint256 lifeExpectancy;         // In seconds
        bool isActive;
        uint256 deathTime;
    }
    
    struct SkillData {
        uint256 level;
        uint256 lastUsed;
        uint256 decayRate;              // Decay per day (basis points)
        uint256 maxLevel;
    }
    
    struct ReputationData {
        int256 baseReputation;
        uint256 lastDecayTime;
        uint256 halfLifePeriod;         // Time for 50% decay
    }
    
    mapping(uint256 => TemporalEntity) public entities;
    mapping(uint256 => mapping(string => SkillData)) public entitySkills;
    mapping(uint256 => ReputationData) public entityReputation;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DEFAULT_LIFE_EXPECTANCY = 80 * 365 days;
    uint256 public constant DEFAULT_HALF_LIFE = 365 days;
    
    event EntityCreated(uint256 indexed entityId, uint256 birthTime, uint256 lifeExpectancy);
    event EntityAged(uint256 indexed entityId, uint256 newAge, LifeStage newStage);
    event SkillDecayed(uint256 indexed entityId, string skill, uint256 oldLevel, uint256 newLevel);
    event ReputationDecayed(uint256 indexed entityId, int256 oldRep, int256 newRep);
    event EntityDied(uint256 indexed entityId, uint256 deathTime, uint256 finalAge);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Create a temporal entity
     */
    function createTemporalEntity(
        uint256 entityId,
        uint256 startingAge,
        uint256 lifeExpectancy
    ) external returns (bool) {
        require(!entities[entityId].isActive, "Entity already exists");
        
        uint256 birthTime = block.timestamp - startingAge;
        
        entities[entityId] = TemporalEntity({
            entityId: entityId,
            birthTime: birthTime,
            lastUpdate: block.timestamp,
            age: startingAge,
            lifeStage: _calculateLifeStage(startingAge, lifeExpectancy),
            lifeExpectancy: lifeExpectancy > 0 ? lifeExpectancy : DEFAULT_LIFE_EXPECTANCY,
            isActive: true,
            deathTime: 0
        });
        
        entityReputation[entityId] = ReputationData({
            baseReputation: 0,
            lastDecayTime: block.timestamp,
            halfLifePeriod: DEFAULT_HALF_LIFE
        });
        
        emit EntityCreated(entityId, birthTime, entities[entityId].lifeExpectancy);
        return true;
    }
    
    /**
     * @dev Update entity age
     */
    function updateAge(uint256 entityId) public {
        TemporalEntity storage entity = entities[entityId];
        require(entity.isActive, "Entity not active");
        
        uint256 oldAge = entity.age;
        entity.age = block.timestamp - entity.birthTime;
        entity.lastUpdate = block.timestamp;
        
        LifeStage oldStage = entity.lifeStage;
        entity.lifeStage = _calculateLifeStage(entity.age, entity.lifeExpectancy);
        
        if (entity.lifeStage != oldStage || entity.age != oldAge) {
            emit EntityAged(entityId, entity.age, entity.lifeStage);
        }
        
        // Check for natural death
        if (entity.age >= entity.lifeExpectancy) {
            _triggerDeath(entityId);
        }
    }
    
    /**
     * @dev Add/update a skill
     */
    function setSkill(
        uint256 entityId,
        string memory skillName,
        uint256 level,
        uint256 decayRate
    ) external {
        entitySkills[entityId][skillName] = SkillData({
            level: level,
            lastUsed: block.timestamp,
            decayRate: decayRate,
            maxLevel: level
        });
    }
    
    /**
     * @dev Record skill usage (prevents decay)
     */
    function useSkill(uint256 entityId, string memory skillName) external {
        SkillData storage skill = entitySkills[entityId][skillName];
        require(skill.maxLevel > 0, "Skill not found");
        
        skill.lastUsed = block.timestamp;
    }
    
    /**
     * @dev Apply skill decay
     */
    function applySkillDecay(uint256 entityId, string memory skillName) public {
        SkillData storage skill = entitySkills[entityId][skillName];
        require(skill.maxLevel > 0, "Skill not found");
        
        uint256 daysSinceUse = (block.timestamp - skill.lastUsed) / 1 days;
        
        if (daysSinceUse > 7) {
            uint256 oldLevel = skill.level;
            uint256 decayAmount = ((daysSinceUse - 7) * skill.decayRate) / BASIS_POINTS;
            
            if (decayAmount > skill.level) {
                skill.level = 0;
            } else {
                skill.level -= decayAmount;
            }
            
            emit SkillDecayed(entityId, skillName, oldLevel, skill.level);
        }
    }
    
    /**
     * @dev Calculate reputation decay (half-life)
     */
    function applyReputationDecay(uint256 entityId) public {
        ReputationData storage repData = entityReputation[entityId];
        
        uint256 timeElapsed = block.timestamp - repData.lastDecayTime;
        
        if (timeElapsed > 0) {
            int256 oldRep = repData.baseReputation;
            
            // Calculate decay using half-life formula
            // rep = base * (0.5 ^ (time / halfLife))
            uint256 periods = (timeElapsed * BASIS_POINTS) / repData.halfLifePeriod;
            uint256 decayFactor = _calculateDecayFactor(periods);
            
            repData.baseReputation = (repData.baseReputation * int256(decayFactor)) / int256(BASIS_POINTS);
            repData.lastDecayTime = block.timestamp;
            
            emit ReputationDecayed(entityId, oldRep, repData.baseReputation);
        }
    }
    
    /**
     * @dev Update reputation
     */
    function updateReputation(uint256 entityId, int256 newReputation) external {
        entityReputation[entityId].baseReputation = newReputation;
        entityReputation[entityId].lastDecayTime = block.timestamp;
    }
    
    /**
     * @dev Mark entity as deceased
     */
    function markDeceased(uint256 entityId) external {
        _triggerDeath(entityId);
    }
    
    /**
     * @dev Internal death trigger
     */
    function _triggerDeath(uint256 entityId) internal {
        TemporalEntity storage entity = entities[entityId];
        require(entity.isActive, "Already deceased");
        
        entity.isActive = false;
        entity.lifeStage = LifeStage.Deceased;
        entity.deathTime = block.timestamp;
        
        emit EntityDied(entityId, block.timestamp, entity.age);
    }
    
    /**
     * @dev Calculate life stage based on age
     */
    function _calculateLifeStage(uint256 age, uint256 lifeExpectancy) internal pure returns (LifeStage) {
        uint256 agePercent = (age * 100) / lifeExpectancy;
        
        if (agePercent < 30) return LifeStage.Youth;
        if (agePercent < 50) return LifeStage.Adult;
        if (agePercent < 75) return LifeStage.Prime;
        if (agePercent < 100) return LifeStage.Elder;
        return LifeStage.Deceased;
    }
    
    /**
     * @dev Calculate decay factor for reputation half-life
     */
    function _calculateDecayFactor(uint256 periods) internal pure returns (uint256) {
        // Simplified exponential decay approximation
        // For small periods: factor ≈ 1 - (periods / 2)
        if (periods > BASIS_POINTS) return 0;
        return BASIS_POINTS - (periods / 2);
    }
    
    /**
     * @dev Get entity age in years
     */
    function getAgeInYears(uint256 entityId) external view returns (uint256) {
        return entities[entityId].age / 365 days;
    }
    
    /**
     * @dev Get skill level
     */
    function getSkillLevel(uint256 entityId, string memory skillName) 
        external 
        view 
        returns (uint256) 
    {
        return entitySkills[entityId][skillName].level;
    }
    
    /**
     * @dev Get current reputation
     */
    function getCurrentReputation(uint256 entityId) external view returns (int256) {
        return entityReputation[entityId].baseReputation;
    }
    
    /**
     * @dev Check if entity is alive
     */
    function isAlive(uint256 entityId) external view returns (bool) {
        return entities[entityId].isActive;
    }
}
