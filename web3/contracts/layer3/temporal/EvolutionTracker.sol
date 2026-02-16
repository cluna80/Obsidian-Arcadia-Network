// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EvolutionTracker is Ownable {
    struct Milestone {uint256 id;string name;uint256 timestamp;uint256 significance;}
    struct Mutation {uint256 id;string traitName;string oldValue;string newValue;uint256 timestamp;}
    struct Evolution {uint256 entityId;uint256 generation;uint256 mutationCount;uint256 milestoneCount;uint256 evolutionScore;}
    
    mapping(uint256 => Evolution) public evolutions;
    mapping(uint256 => Milestone[]) public entityMilestones;
    mapping(uint256 => Mutation[]) public entityMutations;
    
    event MilestoneReached(uint256 indexed entityId, string milestone);
    event MutationOccurred(uint256 indexed entityId, string trait);
    
    constructor() Ownable(msg.sender) {}
    
    function trackMilestone(uint256 entityId,string memory name,uint256 significance) external {uint256 id = entityMilestones[entityId].length;entityMilestones[entityId].push(Milestone(id,name,block.timestamp,significance));evolutions[entityId].milestoneCount++;evolutions[entityId].evolutionScore += significance;emit MilestoneReached(entityId, name);}
    
    function recordMutation(uint256 entityId,string memory traitName,string memory oldValue,string memory newValue) external {uint256 id = entityMutations[entityId].length;entityMutations[entityId].push(Mutation(id,traitName,oldValue,newValue,block.timestamp));evolutions[entityId].mutationCount++;emit MutationOccurred(entityId, traitName);}
    
    function getEvolutionPath(uint256 entityId) external view returns (Milestone[] memory, Mutation[] memory) {return (entityMilestones[entityId], entityMutations[entityId]);}
}
