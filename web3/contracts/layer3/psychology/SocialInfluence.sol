// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SocialInfluence is Ownable {
    
    struct Influence {uint256 sourceId;uint256 targetId;uint256 strength;string influenceType;uint256 timestamp;}
    struct Opinion {string topic;int256 stance;uint256 confidence;uint256 lastUpdate;}
    struct NetworkEffect {uint256 entityId;uint256 influenceScore;uint256 followerCount;uint256 totalInfluence;}
    
    mapping(uint256 => mapping(uint256 => Influence)) public influences;
    mapping(uint256 => mapping(string => Opinion)) public opinions;
    mapping(uint256 => NetworkEffect) public networkEffects;
    mapping(uint256 => uint256[]) public followers;
    mapping(uint256 => uint256[]) public following;
    
    event InfluenceRecorded(uint256 indexed sourceId, uint256 indexed targetId, uint256 strength);
    event OpinionChanged(uint256 indexed entityId, string topic, int256 oldStance, int256 newStance);
    event OpinionPropagated(uint256 indexed sourceId, string topic, uint256 affectedCount);
    
    constructor() Ownable(msg.sender) {}
    
    function recordInfluence(uint256 sourceId,uint256 targetId,uint256 strength,string memory influenceType) external {influences[sourceId][targetId] = Influence(sourceId,targetId,strength,influenceType,block.timestamp);networkEffects[sourceId].totalInfluence += strength;emit InfluenceRecorded(sourceId, targetId, strength);}
    
    function setOpinion(uint256 entityId,string memory topic,int256 stance,uint256 confidence) external {opinions[entityId][topic] = Opinion(topic,stance,confidence,block.timestamp);}
    
    function propagateOpinion(uint256 sourceId,string memory topic) external {Opinion storage sourceOpinion = opinions[sourceId][topic];uint256 affectedCount = 0;for(uint256 i = 0; i < followers[sourceId].length; i++){uint256 followerId = followers[sourceId][i];Influence storage inf = influences[sourceId][followerId];if(inf.strength > 50){Opinion storage followerOpinion = opinions[followerId][topic];int256 oldStance = followerOpinion.stance;int256 influence = (sourceOpinion.stance * int256(inf.strength)) / 100;followerOpinion.stance = (followerOpinion.stance + influence) / 2;if(followerOpinion.stance > 100) followerOpinion.stance = 100;if(followerOpinion.stance < -100) followerOpinion.stance = -100;followerOpinion.lastUpdate = block.timestamp;affectedCount++;emit OpinionChanged(followerId, topic, oldStance, followerOpinion.stance);}}emit OpinionPropagated(sourceId, topic, affectedCount);}
    
    function follow(uint256 followerId, uint256 targetId) external {followers[targetId].push(followerId);following[followerId].push(targetId);networkEffects[targetId].followerCount++;}
    
    function getInfluenceScore(uint256 entityId) external view returns (uint256) {return networkEffects[entityId].influenceScore;}
}
