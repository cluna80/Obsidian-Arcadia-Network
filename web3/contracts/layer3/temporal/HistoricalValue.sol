// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract HistoricalValue is Ownable {
    enum EventType {Achievement, Milestone, Victory, Defeat, RareEvent, LegendaryMoment}
    enum Trajectory {Rising, Stable, Falling, Legendary}
    
    struct HistoricalEvent {uint256 id;uint256 entityId;EventType eventType;string description;uint256 timestamp;uint256 impactScore;bytes32 dataHash;}
    struct EntityHistory {uint256 totalEvents;uint256 achievementCount;uint256 totalImpact;uint256 firstEventTime;uint256 lastEventTime;Trajectory currentTrajectory;}
    
    mapping(uint256 => HistoricalEvent[]) public entityEvents;
    mapping(uint256 => EntityHistory) public entityHistory;
    uint256 public eventCount;
    
    event EventRecorded(uint256 indexed entityId, EventType eventType, uint256 impactScore);
    event TrajectoryChanged(uint256 indexed entityId, Trajectory newTrajectory);
    
    constructor() Ownable(msg.sender) {}
    
    function recordEvent(uint256 entityId,EventType eventType,string memory description,uint256 impactScore,bytes32 dataHash) external {eventCount++;HistoricalEvent memory newEvent = HistoricalEvent(eventCount,entityId,eventType,description,block.timestamp,impactScore,dataHash);entityEvents[entityId].push(newEvent);EntityHistory storage history = entityHistory[entityId];if(history.totalEvents == 0){history.firstEventTime = block.timestamp;}history.totalEvents++;history.totalImpact += impactScore;history.lastEventTime = block.timestamp;if(eventType == EventType.Achievement || eventType == EventType.LegendaryMoment){history.achievementCount++;}emit EventRecorded(entityId, eventType, impactScore);}
    
    function calculateTrajectory(uint256 entityId) public returns (Trajectory) {EntityHistory storage history = entityHistory[entityId];if(history.totalEvents < 3) return Trajectory.Stable;uint256 recentScore = 0;uint256 recentCount = 0;uint256 cutoff = block.timestamp - 30 days;HistoricalEvent[] storage events = entityEvents[entityId];for(uint256 i = events.length; i > 0 && recentCount < 10; i--){if(events[i-1].timestamp > cutoff){recentScore += events[i-1].impactScore;recentCount++;}}if(recentCount == 0) return Trajectory.Falling;uint256 avgRecent = recentScore / recentCount;uint256 avgAll = history.totalImpact / history.totalEvents;Trajectory newTraj;if(avgRecent > avgAll * 15 / 10) newTraj = Trajectory.Legendary;else if(avgRecent > avgAll * 11 / 10) newTraj = Trajectory.Rising;else if(avgRecent < avgAll * 9 / 10) newTraj = Trajectory.Falling;else newTraj = Trajectory.Stable;if(newTraj != history.currentTrajectory){history.currentTrajectory = newTraj;emit TrajectoryChanged(entityId, newTraj);}return newTraj;}
    
    function calculateHistoricalValue(uint256 entityId,uint256 baseValue) external view returns (uint256) {EntityHistory storage history = entityHistory[entityId];uint256 achievementBonus = history.achievementCount * 50;uint256 trajectoryMultiplier = 100;if(history.currentTrajectory == Trajectory.Rising) trajectoryMultiplier = 150;else if(history.currentTrajectory == Trajectory.Legendary) trajectoryMultiplier = 200;uint256 narrativeValue = _calculateNarrativeValue(entityId);return ((baseValue + achievementBonus) * trajectoryMultiplier / 100) + narrativeValue;}
    
    function _calculateNarrativeValue(uint256 entityId) internal view returns (uint256) {HistoricalEvent[] storage events = entityEvents[entityId];if(events.length < 5) return 0;uint256 score = 0;bool hasVictory = false;bool hasDefeat = false;bool hasLegendary = false;for(uint256 i = 0; i < events.length; i++){if(events[i].eventType == EventType.Victory) hasVictory = true;if(events[i].eventType == EventType.Defeat) hasDefeat = true;if(events[i].eventType == EventType.LegendaryMoment) hasLegendary = true;}if(hasVictory && hasDefeat) score += 200;if(hasLegendary) score += 300;return score;}
    
    function getEvents(uint256 entityId) external view returns (HistoricalEvent[] memory) {return entityEvents[entityId];}
}
