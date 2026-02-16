// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LegacySystem is Ownable {
    struct Legacy {uint256 parentId;uint256 heirId;uint256 inheritedReputation;uint256 inheritedWealth;uint256[] transferredMemories;uint256 transferTime;bool isActive;}
    struct Dynasty {uint256 founderId;uint256[] generations;uint256 totalHeirs;uint256 establishedAt;}
    
    mapping(uint256 => Legacy) public legacies;
    mapping(uint256 => uint256) public entityToLegacy;
    mapping(uint256 => Dynasty) public dynasties;
    mapping(uint256 => uint256) public entityToDynasty;
    uint256 public legacyCount;
    uint256 public dynastyCount;
    
    event HeirCreated(uint256 indexed parentId, uint256 indexed heirId);
    event LegacyTransferred(uint256 indexed legacyId, uint256 reputation, uint256 wealth);
    event DynastyEstablished(uint256 indexed dynastyId, uint256 indexed founderId);
    
    constructor() Ownable(msg.sender) {}
    
    function createHeir(uint256 parentId,uint256 heirId,uint256 inheritedReputation,uint256 inheritedWealth) external returns (uint256) {legacyCount++;legacies[legacyCount] = Legacy(parentId,heirId,inheritedReputation,inheritedWealth,new uint256[](0),block.timestamp,true);entityToLegacy[heirId] = legacyCount;if(entityToDynasty[parentId] == 0){dynastyCount++;Dynasty storage newDynasty = dynasties[dynastyCount];newDynasty.founderId = parentId;newDynasty.establishedAt = block.timestamp;newDynasty.generations.push(parentId);entityToDynasty[parentId] = dynastyCount;emit DynastyEstablished(dynastyCount, parentId);}uint256 dynastyId = entityToDynasty[parentId];dynasties[dynastyId].generations.push(heirId);dynasties[dynastyId].totalHeirs++;entityToDynasty[heirId] = dynastyId;emit HeirCreated(parentId, heirId);emit LegacyTransferred(legacyCount, inheritedReputation, inheritedWealth);return legacyCount;}
    
    function transferMemory(uint256 legacyId, uint256 memoryId) external {legacies[legacyId].transferredMemories.push(memoryId);}
    
    function getDynastyTree(uint256 founderId) external view returns (uint256[] memory) {uint256 dynastyId = entityToDynasty[founderId];return dynasties[dynastyId].generations;}
}
