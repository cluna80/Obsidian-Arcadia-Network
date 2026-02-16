// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TrustDynamics is Ownable {
    
    struct TrustRelationship {uint256 trustScore;uint256 interactions;uint256 positiveInteractions;uint256 betrayals;uint256 lastInteraction;bool isActive;}
    struct TrustNetwork {uint256 entityId;uint256 totalTrustedEntities;uint256 totalTrustScore;uint256 averageTrust;}
    
    mapping(uint256 => mapping(uint256 => TrustRelationship)) public trustRelationships;
    mapping(uint256 => TrustNetwork) public trustNetworks;
    mapping(uint256 => uint256[]) public trustedEntities;
    
    event TrustBuilt(uint256 indexed entity1, uint256 indexed entity2, uint256 newTrustScore);
    event Betrayal(uint256 indexed betrayer, uint256 indexed victim, uint256 severity);
    event TrustRestored(uint256 indexed entity1, uint256 indexed entity2);
    
    constructor() Ownable(msg.sender) {}
    
    function buildTrust(uint256 entity1,uint256 entity2,uint256 interactionQuality) external {TrustRelationship storage trust = trustRelationships[entity1][entity2];trust.interactions++;if(interactionQuality > 50){trust.positiveInteractions++;trust.trustScore += interactionQuality / 10;if(trust.trustScore > 100) trust.trustScore = 100;}else{if(trust.trustScore > interactionQuality / 10){trust.trustScore -= interactionQuality / 10;}else{trust.trustScore = 0;}}trust.lastInteraction = block.timestamp;trust.isActive = true;emit TrustBuilt(entity1, entity2, trust.trustScore);if(trust.trustScore > 50 && !_isInArray(trustedEntities[entity1], entity2)){trustedEntities[entity1].push(entity2);trustNetworks[entity1].totalTrustedEntities++;}_updateTrustNetwork(entity1);}
    
    function recordBetrayal(uint256 betrayer,uint256 victim,uint256 severity) external {TrustRelationship storage trust = trustRelationships[victim][betrayer];trust.betrayals++;if(trust.trustScore > severity){trust.trustScore -= severity;}else{trust.trustScore = 0;}emit Betrayal(betrayer, victim, severity);_updateTrustNetwork(victim);}
    
    function getTrustScore(uint256 entity1, uint256 entity2) external view returns (uint256) {return trustRelationships[entity1][entity2].trustScore;}
    
    function getTrustNetwork(uint256 entityId) external view returns (uint256[] memory) {return trustedEntities[entityId];}
    
    function _updateTrustNetwork(uint256 entityId) internal {TrustNetwork storage network = trustNetworks[entityId];uint256 totalTrust = 0;for(uint256 i = 0; i < trustedEntities[entityId].length; i++){totalTrust += trustRelationships[entityId][trustedEntities[entityId][i]].trustScore;}network.totalTrustScore = totalTrust;if(trustedEntities[entityId].length > 0){network.averageTrust = totalTrust / trustedEntities[entityId].length;}}
    
    function _isInArray(uint256[] storage arr, uint256 value) internal view returns (bool) {for(uint256 i = 0; i < arr.length; i++){if(arr[i] == value) return true;}return false;}
}
