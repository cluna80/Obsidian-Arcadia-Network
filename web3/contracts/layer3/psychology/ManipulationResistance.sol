// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ManipulationResistance is Ownable {
    
    struct ResistanceProfile {uint256 entityId;uint256 skepticism;uint256 criticalThinking;uint256 emotionalAwareness;uint256 experienceLevel;uint256 manipulationAttempts;uint256 successfulManipulations;}
    struct ManipulationAttempt {uint256 attemptId;uint256 manipulatorId;uint256 targetId;string technique;bool detected;bool successful;uint256 timestamp;}
    
    mapping(uint256 => ResistanceProfile) public resistanceProfiles;
    mapping(uint256 => ManipulationAttempt[]) public manipulationHistory;
    
    event ManipulationDetected(uint256 indexed targetId, uint256 indexed manipulatorId);
    event ManipulationResisted(uint256 indexed targetId, uint256 resistanceScore);
    event ManipulationSucceeded(uint256 indexed targetId, uint256 indexed manipulatorId);
    
    constructor() Ownable(msg.sender) {}
    
    function initializeResistance(uint256 entityId,uint256 skepticism,uint256 criticalThinking,uint256 emotionalAwareness) external {resistanceProfiles[entityId] = ResistanceProfile(entityId,skepticism,criticalThinking,emotionalAwareness,0,0,0);}
    
    function attemptManipulation(uint256 manipulatorId,uint256 targetId,string memory technique,uint256 manipulationPower) external returns (bool) {ResistanceProfile storage profile = resistanceProfiles[targetId];profile.manipulationAttempts++;uint256 resistanceScore = (profile.skepticism + profile.criticalThinking + profile.emotionalAwareness + profile.experienceLevel) / 4;bool detected = resistanceScore > manipulationPower / 2;bool successful = !detected && (manipulationPower > resistanceScore);ManipulationAttempt memory attempt = ManipulationAttempt(manipulationHistory[targetId].length,manipulatorId,targetId,technique,detected,successful,block.timestamp);manipulationHistory[targetId].push(attempt);if(detected){emit ManipulationDetected(targetId, manipulatorId);profile.experienceLevel += 5;if(profile.experienceLevel > 100) profile.experienceLevel = 100;emit ManipulationResisted(targetId, resistanceScore);}else if(successful){profile.successfulManipulations++;emit ManipulationSucceeded(targetId, manipulatorId);}return successful;}
    
    function getResistanceScore(uint256 entityId) external view returns (uint256) {ResistanceProfile storage profile = resistanceProfiles[entityId];return (profile.skepticism + profile.criticalThinking + profile.emotionalAwareness + profile.experienceLevel) / 4;}
}
