// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WorldPhysics
 * @dev Tokenize physics rules - gravity, energy, time flow as NFTs
 * 
 * Revolutionary: Reality itself becomes programmable
 */
contract WorldPhysics is ERC721, Ownable {
    
    uint256 private _physicsIds;
    
    enum PhysicsType {
        Gravity,
        Energy,
        TimeFlow,
        Causality,
        Entropy,
        Quantum
    }
    
    struct PhysicsModule {
        uint256 id;
        string name;
        PhysicsType physicsType;
        address creator;
        uint256 createdAt;
        bool isActive;
        uint256 usageCount;
        bytes32 parametersHash;
    }
    
    struct PhysicsParameters {
        int256 gravityStrength;      // -100 to 100 (0 = normal, negative = anti-gravity)
        uint256 energyDrainRate;     // 0-10000 basis points
        uint256 timeFlowRate;        // 0-10000 (100 = normal speed)
        uint256 causalityStrength;   // How strong cause-effect is
        uint256 entropyRate;         // Rate of chaos/disorder
        uint256 quantumFluctuation;  // Randomness level
    }
    
    mapping(uint256 => PhysicsModule) public physicsModules;
    mapping(uint256 => PhysicsParameters) public moduleParameters;
    mapping(uint256 => uint256[]) public worldPhysics; // worldId => physicsIds
    mapping(address => uint256[]) public creatorModules;
    
    event PhysicsModuleCreated(uint256 indexed moduleId, string name, PhysicsType physicsType, address creator);
    event PhysicsAttached(uint256 indexed worldId, uint256 indexed moduleId);
    event PhysicsDetached(uint256 indexed worldId, uint256 indexed moduleId);
    event ParametersUpdated(uint256 indexed moduleId);
    
    constructor() ERC721("OAN World Physics", "OANWP") Ownable(msg.sender) {}
    
    /**
     * @dev Create a physics module NFT
     */
    function createPhysicsModule(
        string memory name,
        PhysicsType physicsType,
        PhysicsParameters memory params
    ) external returns (uint256) {
        _physicsIds++;
        uint256 moduleId = _physicsIds;
        
        _safeMint(msg.sender, moduleId);
        
        bytes32 paramsHash = keccak256(abi.encode(params));
        
        physicsModules[moduleId] = PhysicsModule({
            id: moduleId,
            name: name,
            physicsType: physicsType,
            creator: msg.sender,
            createdAt: block.timestamp,
            isActive: true,
            usageCount: 0,
            parametersHash: paramsHash
        });
        
        moduleParameters[moduleId] = params;
        creatorModules[msg.sender].push(moduleId);
        
        emit PhysicsModuleCreated(moduleId, name, physicsType, msg.sender);
        return moduleId;
    }
    
    /**
     * @dev Attach physics module to a world
     */
    function attachToWorld(uint256 worldId, uint256 moduleId) external {
        require(_ownerOf(moduleId) == msg.sender, "Not module owner");
        require(physicsModules[moduleId].isActive, "Module inactive");
        
        worldPhysics[worldId].push(moduleId);
        physicsModules[moduleId].usageCount++;
        
        emit PhysicsAttached(worldId, moduleId);
    }
    
    /**
     * @dev Detach physics module from world
     */
    function detachFromWorld(uint256 worldId, uint256 moduleId) external {
        uint256[] storage modules = worldPhysics[worldId];
        for (uint256 i = 0; i < modules.length; i++) {
            if (modules[i] == moduleId) {
                modules[i] = modules[modules.length - 1];
                modules.pop();
                emit PhysicsDetached(worldId, moduleId);
                break;
            }
        }
    }
    
    /**
     * @dev Update physics parameters
     */
    function updateParameters(uint256 moduleId, PhysicsParameters memory newParams) external {
        require(_ownerOf(moduleId) == msg.sender, "Not owner");
        
        moduleParameters[moduleId] = newParams;
        physicsModules[moduleId].parametersHash = keccak256(abi.encode(newParams));
        
        emit ParametersUpdated(moduleId);
    }
    
    /**
     * @dev Get world's physics modules
     */
    function getWorldPhysics(uint256 worldId) external view returns (uint256[] memory) {
        return worldPhysics[worldId];
    }
    
    /**
     * @dev Get physics parameters
     */
    function getParameters(uint256 moduleId) external view returns (PhysicsParameters memory) {
        return moduleParameters[moduleId];
    }
    
    /**
     * @dev Get creator's modules
     */
    function getCreatorModules(address creator) external view returns (uint256[] memory) {
        return creatorModules[creator];
    }
}
