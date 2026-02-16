// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WorldComposer is ERC721, Ownable {
    
    uint256 private _worldIds;
    
    struct World {uint256 id;string name;address creator;uint256[] physicsModules;uint256[] economicSystems;uint256[] psychologyModules;uint256 createdAt;bool isPublished;uint256 price;}
    
    mapping(uint256 => World) public worlds;
    mapping(address => uint256[]) public creatorWorlds;
    
    event WorldComposed(uint256 indexed worldId, string name, address creator);
    event WorldPublished(uint256 indexed worldId, uint256 price);
    event ModuleAdded(uint256 indexed worldId, uint256 moduleId, string moduleType);
    
    constructor() ERC721("OAN Composed World", "OANCW") Ownable(msg.sender) {}
    
    function composeWorld(string memory name,uint256[] memory physicsModules,uint256[] memory economicSystems) external returns (uint256) {_worldIds++;uint256 worldId = _worldIds;_safeMint(msg.sender, worldId);worlds[worldId] = World(worldId,name,msg.sender,physicsModules,economicSystems,new uint256[](0),block.timestamp,false,0);creatorWorlds[msg.sender].push(worldId);emit WorldComposed(worldId, name, msg.sender);return worldId;}
    
    function publishWorld(uint256 worldId, uint256 price) external {require(_ownerOf(worldId) == msg.sender);worlds[worldId].isPublished = true;worlds[worldId].price = price;emit WorldPublished(worldId, price);}
    
    function addPhysicsModule(uint256 worldId, uint256 moduleId) external {require(_ownerOf(worldId) == msg.sender);worlds[worldId].physicsModules.push(moduleId);emit ModuleAdded(worldId, moduleId, "physics");}
    
    function addEconomicSystem(uint256 worldId, uint256 systemId) external {require(_ownerOf(worldId) == msg.sender);worlds[worldId].economicSystems.push(systemId);emit ModuleAdded(worldId, systemId, "economic");}
    
    function getWorld(uint256 worldId) external view returns (World memory) {return worlds[worldId];}
}
