// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationIdentity is Ownable {
    
    struct MultiDimensionalReputation {uint256 identityId;uint256 trustworthiness;uint256 competence;uint256 reliability;uint256 benevolence;uint256 integrity;uint256 overallScore;uint256 lastUpdate;}
    struct ContextualReputation {uint256 worldId;string context;uint256 score;uint256 interactions;uint256 lastUpdate;}
    
    mapping(uint256 => MultiDimensionalReputation) public reputations;
    mapping(uint256 => mapping(uint256 => ContextualReputation)) public contextualReps;
    mapping(uint256 => uint256[]) public worldContexts;
    
    event ReputationInitialized(uint256 indexed identityId);
    event ReputationUpdated(uint256 indexed identityId, uint256 dimension, uint256 newScore);
    event ContextualReputationRecorded(uint256 indexed identityId, uint256 indexed worldId, uint256 score);
    
    constructor() Ownable(msg.sender) {}
    
    function initializeReputation(uint256 identityId) external {require(reputations[identityId].identityId == 0);reputations[identityId] = MultiDimensionalReputation(identityId,50,50,50,50,50,50,block.timestamp);emit ReputationInitialized(identityId);}
    
    function updateReputation(uint256 identityId,uint256 trust,uint256 competence,uint256 reliability,uint256 benevolence,uint256 integrity) external {MultiDimensionalReputation storage rep = reputations[identityId];rep.trustworthiness = trust;rep.competence = competence;rep.reliability = reliability;rep.benevolence = benevolence;rep.integrity = integrity;rep.overallScore = (trust + competence + reliability + benevolence + integrity) / 5;rep.lastUpdate = block.timestamp;emit ReputationUpdated(identityId, 0, rep.overallScore);}
    
    function recordContextualReputation(uint256 identityId,uint256 worldId,string memory context,uint256 score) external {ContextualReputation storage ctx = contextualReps[identityId][worldId];if(ctx.interactions == 0){worldContexts[identityId].push(worldId);}ctx.worldId = worldId;ctx.context = context;ctx.score = ((ctx.score * ctx.interactions) + score) / (ctx.interactions + 1);ctx.interactions++;ctx.lastUpdate = block.timestamp;emit ContextualReputationRecorded(identityId, worldId, score);}
    
    function aggregateReputation(uint256 identityId) external view returns (uint256) {MultiDimensionalReputation storage rep = reputations[identityId];uint256 baseScore = rep.overallScore;uint256 contextualScore = 0;uint256 worldCount = worldContexts[identityId].length;if(worldCount > 0){for(uint256 i = 0; i < worldCount; i++){contextualScore += contextualReps[identityId][worldContexts[identityId][i]].score;}contextualScore = contextualScore / worldCount;return (baseScore + contextualScore) / 2;}return baseScore;}
}
