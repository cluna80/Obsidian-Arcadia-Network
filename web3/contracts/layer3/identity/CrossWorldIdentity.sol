// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CrossWorldIdentity is Ownable {
    
    struct UniversalIdentity {uint256 identityId;address owner;uint256[] linkedWorlds;uint256 totalReputation;uint256 totalAchievements;bytes32 identityHash;bool isVerified;uint256 createdAt;}
    struct WorldLink {uint256 worldId;uint256 entityId;uint256 reputation;uint256 achievements;bool isActive;uint256 linkedAt;}
    
    mapping(uint256 => UniversalIdentity) public universalIdentities;
    mapping(uint256 => mapping(uint256 => WorldLink)) public worldLinks;
    mapping(bytes32 => bool) public verifiedIdentities;
    
    event IdentityLinked(uint256 indexed identityId, uint256 indexed worldId);
    event ReputationTransferred(uint256 indexed identityId, uint256 fromWorld, uint256 toWorld);
    event IdentityVerified(uint256 indexed identityId);
    
    constructor() Ownable(msg.sender) {}
    
    function createUniversalIdentity(uint256 identityId, address owner) external {require(universalIdentities[identityId].identityId == 0);universalIdentities[identityId] = UniversalIdentity(identityId,owner,new uint256[](0),0,0,keccak256(abi.encodePacked(identityId, owner)),false,block.timestamp);}
    
    function linkWorld(uint256 identityId,uint256 worldId,uint256 entityId,uint256 reputation) external {UniversalIdentity storage identity = universalIdentities[identityId];require(identity.owner == msg.sender);worldLinks[identityId][worldId] = WorldLink(worldId,entityId,reputation,0,true,block.timestamp);identity.linkedWorlds.push(worldId);identity.totalReputation += reputation;emit IdentityLinked(identityId, worldId);}
    
    function transferReputation(uint256 identityId,uint256 fromWorldId,uint256 toWorldId,uint256 amount) external {UniversalIdentity storage identity = universalIdentities[identityId];require(identity.owner == msg.sender);WorldLink storage fromWorld = worldLinks[identityId][fromWorldId];WorldLink storage toWorld = worldLinks[identityId][toWorldId];require(fromWorld.reputation >= amount);fromWorld.reputation -= amount;toWorld.reputation += amount;emit ReputationTransferred(identityId, fromWorldId, toWorldId);}
    
    function verifyIdentity(uint256 identityId) external {UniversalIdentity storage identity = universalIdentities[identityId];require(identity.linkedWorlds.length >= 3);identity.isVerified = true;verifiedIdentities[identity.identityHash] = true;emit IdentityVerified(identityId);}
    
    function getUniversalProfile(uint256 identityId) external view returns (UniversalIdentity memory) {return universalIdentities[identityId];}
}
