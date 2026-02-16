// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EconomicLaws is ERC721, Ownable {
    
    uint256 private _lawIds;
    
    enum EconomyType {PostScarcity, HyperCapitalism, Communal, Barter, ReputationBased, ResourceBased}
    
    struct EconomicSystem {uint256 id;string name;EconomyType economyType;address creator;uint256 createdAt;bool isActive;bytes32 rulesHash;}
    struct EconomicRules {bool infiniteResources;uint256 inflationRate;uint256 taxRate;uint256 tradeFrequency;bool priceControls;bool resourceDecay;uint256 wealthDistribution;}
    
    mapping(uint256 => EconomicSystem) public economicSystems;
    mapping(uint256 => EconomicRules) public systemRules;
    mapping(uint256 => uint256[]) public worldEconomics;
    
    event EconomicSystemCreated(uint256 indexed systemId, string name, EconomyType economyType);
    event SystemAttached(uint256 indexed worldId, uint256 indexed systemId);
    
    constructor() ERC721("OAN Economic Law", "OANEL") Ownable(msg.sender) {}
    
    function createEconomicSystem(string memory name,EconomyType economyType,EconomicRules memory rules) external returns (uint256) {_lawIds++;uint256 systemId = _lawIds;_safeMint(msg.sender, systemId);economicSystems[systemId] = EconomicSystem(systemId,name,economyType,msg.sender,block.timestamp,true,keccak256(abi.encode(rules)));systemRules[systemId] = rules;emit EconomicSystemCreated(systemId, name, economyType);return systemId;}
    
    function attachToWorld(uint256 worldId, uint256 systemId) external {require(_ownerOf(systemId) == msg.sender);worldEconomics[worldId].push(systemId);emit SystemAttached(worldId, systemId);}
    
    function getRules(uint256 systemId) external view returns (EconomicRules memory) {return systemRules[systemId];}
}
