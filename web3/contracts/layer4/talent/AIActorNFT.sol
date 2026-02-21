// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIActorNFT
 * @notice AI entities as actors with performance tracking
 * 
 * INNOVATION: Layer 3 BehavioralIdentity entities become AI actors
 * - Entity's behavioral patterns = acting style
 * - Entity's reputation = actor credibility
 * - Entity's cognitive style = character portrayal ability
 */
contract AIActorNFT is ERC721, Ownable {
    
    uint256 private _actorIds;
    
    struct AIActor {
        uint256 actorId;
        uint256 entityId;                // Link to Layer 3 entity
        string stageName;
        ActorType actorType;
        uint256[] specializations;       // What genres/roles they excel at
        uint256 baseRate;                // OAN per scene
        uint256 reputationScore;         // Performance reputation (0-10000)
        uint256 totalScenes;
        uint256 totalMovies;
        uint256 totalEarnings;
        bool available;
        uint256 lastPerformance;
    }
    
    struct ActingStyle {
        uint256 emotionalRange;          // 0-100
        uint256 versatility;             // 0-100
        uint256 consistency;             // 0-100
        uint256 charisma;                // 0-100
        uint256 improvisation;           // 0-100
    }
    
    enum ActorType {
        LeadActor, SupportingActor, CharacterActor, 
        VoiceActor, ActionStar, Comedian
    }
    
    enum Specialization {
        Action, Drama, Comedy, Horror, Romance,
        SciFi, Historical, Thriller, Animation
    }
    
    mapping(uint256 => AIActor) public actors;
    mapping(uint256 => ActingStyle) public actingStyles;
    mapping(uint256 => mapping(uint256 => bool)) public actorSpecializations; // actorId => specialization => hasIt
    mapping(uint256 => uint256[]) public actorRoles; // actorId => movieIds
    
    event ActorMinted(uint256 indexed actorId, uint256 indexed entityId, string stageName);
    event ActorHired(uint256 indexed actorId, uint256 indexed movieId, uint256 fee);
    event PerformanceRated(uint256 indexed actorId, uint256 rating);
    event ActorRetired(uint256 indexed actorId);
    
    constructor() ERC721("OAN AI Actor", "ACTOR") Ownable(msg.sender) {}
    
    /**
     * @notice Mint AI actor from existing entity
     * @dev Requires entity to have behavioral identity
     */
    function mintActor(
        uint256 entityId,
        string memory stageName,
        ActorType actorType,
        uint256 baseRate
    ) external returns (uint256) {
        _actorIds++;
        uint256 actorId = _actorIds;
        
        _safeMint(msg.sender, actorId);
        
        actors[actorId] = AIActor({
            actorId: actorId,
            entityId: entityId,
            stageName: stageName,
            actorType: actorType,
            specializations: new uint256[](0),
            baseRate: baseRate,
            reputationScore: 5000, // Start at 50%
            totalScenes: 0,
            totalMovies: 0,
            totalEarnings: 0,
            available: true,
            lastPerformance: 0
        });
        
        // Initialize acting style based on entity's behavioral DNA
        actingStyles[actorId] = ActingStyle({
            emotionalRange: 50,
            versatility: 50,
            consistency: 50,
            charisma: 50,
            improvisation: 50
        });
        
        emit ActorMinted(actorId, entityId, stageName);
        return actorId;
    }
    
    /**
     * @notice Add specialization to actor
     * @dev Actors can specialize in multiple genres
     */
    function addSpecialization(uint256 actorId, Specialization spec) external {
        require(ownerOf(actorId) == msg.sender, "Not owner");
        
        actors[actorId].specializations.push(uint256(spec));
        actorSpecializations[actorId][uint256(spec)] = true;
    }
    
    /**
     * @notice Hire actor for a scene/movie
     * @dev Payment in OAN, increases actor stats
     */
    function hireActor(uint256 actorId, uint256 movieId) external payable {
        AIActor storage actor = actors[actorId];
        require(actor.available, "Actor not available");
        require(msg.value >= actor.baseRate, "Insufficient payment");
        
        actor.totalScenes++;
        actor.totalEarnings += msg.value;
        actor.lastPerformance = block.timestamp;
        actorRoles[actorId].push(movieId);
        
        // Pay actor owner
        payable(ownerOf(actorId)).transfer(msg.value);
        
        emit ActorHired(actorId, movieId, msg.value);
    }
    
    /**
     * @notice Rate actor performance
     * @dev Called after movie completion, affects reputation
     */
    function ratePerformance(uint256 actorId, uint256 rating) external {
        require(rating <= 100, "Rating too high");
        
        AIActor storage actor = actors[actorId];
        
        // Update reputation (weighted average)
        uint256 totalWeight = actor.totalScenes;
        actor.reputationScore = ((actor.reputationScore * totalWeight) + (rating * 100)) / (totalWeight + 1);
        
        // Update acting style based on performance
        ActingStyle storage style = actingStyles[actorId];
        if (rating > 80) {
            style.consistency = _increaseSkill(style.consistency, 2);
            style.charisma = _increaseSkill(style.charisma, 1);
        }
        
        emit PerformanceRated(actorId, rating);
    }
    
    /**
     * @notice Set actor availability
     */
    function setAvailability(uint256 actorId, bool available) external {
        require(ownerOf(actorId) == msg.sender, "Not owner");
        actors[actorId].available = available;
    }
    
    /**
     * @notice Update base rate
     */
    function updateBaseRate(uint256 actorId, uint256 newRate) external {
        require(ownerOf(actorId) == msg.sender, "Not owner");
        actors[actorId].baseRate = newRate;
    }
    
    /**
     * @notice Retire actor (permanently unavailable)
     */
    function retireActor(uint256 actorId) external {
        require(ownerOf(actorId) == msg.sender, "Not owner");
        actors[actorId].available = false;
        emit ActorRetired(actorId);
    }
    
    function _increaseSkill(uint256 current, uint256 amount) internal pure returns (uint256) {
        uint256 newValue = current + amount;
        return newValue > 100 ? 100 : newValue;
    }
    
    function getActor(uint256 actorId) external view returns (AIActor memory) {
        return actors[actorId];
    }
    
    function getActingStyle(uint256 actorId) external view returns (ActingStyle memory) {
        return actingStyles[actorId];
    }
    
    function getActorRoles(uint256 actorId) external view returns (uint256[] memory) {
        return actorRoles[actorId];
    }
}
