// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EmotionalState is Ownable {
    
    enum Emotion {Fear, Greed, Trust, Anger, Joy, Sadness, Confidence, Stress}
    enum ResponseType {Flee, Attack, Cooperate, Freeze, Celebrate, Mourn, Boast, Panic}
    
    struct EntityEmotions {uint256 entityId;uint256 fear;uint256 greed;uint256 trust;uint256 anger;uint256 joy;uint256 sadness;uint256 confidence;uint256 stress;uint256 lastUpdate;}
    struct EmotionalTrigger {uint256 triggerId;Emotion emotion;int256 intensity;uint256 timestamp;bytes32 causeHash;}
    struct EmotionalProfile {uint256 volatility;uint256 resilience;uint256 empathy;}
    
    mapping(uint256 => EntityEmotions) public entityEmotions;
    mapping(uint256 => EmotionalProfile) public emotionalProfiles;
    mapping(uint256 => EmotionalTrigger[]) public emotionalHistory;
    mapping(uint256 => mapping(Emotion => uint256)) public emotionThresholds;
    
    event EmotionUpdated(uint256 indexed entityId, Emotion emotion, uint256 oldValue, uint256 newValue);
    event EmotionalResponseTriggered(uint256 indexed entityId, ResponseType response);
    event ThresholdTriggered(uint256 indexed entityId, Emotion emotion, uint256 value);
    
    constructor() Ownable(msg.sender) {}
    
    function initializeEmotions(uint256 entityId) external {require(entityEmotions[entityId].lastUpdate == 0);entityEmotions[entityId] = EntityEmotions(entityId,0,0,50,0,50,0,50,0,block.timestamp);emotionalProfiles[entityId] = EmotionalProfile(50,50,50);emotionThresholds[entityId][Emotion.Fear] = 80;emotionThresholds[entityId][Emotion.Anger] = 80;}
    
    function updateEmotionValue(uint256 entityId, Emotion emotion, int256 delta) public {EntityEmotions storage emotions = entityEmotions[entityId];require(emotions.lastUpdate > 0);uint256 oldValue = _getEmotionValue(emotions, emotion);int256 newValue = int256(oldValue) + delta;if(newValue < 0) newValue = 0;if(newValue > 100) newValue = 100;_setEmotionValue(emotions, emotion, uint256(newValue));emotions.lastUpdate = block.timestamp;emotionalHistory[entityId].push(EmotionalTrigger(emotionalHistory[entityId].length,emotion,delta,block.timestamp,bytes32(0)));emit EmotionUpdated(entityId, emotion, oldValue, uint256(newValue));if(uint256(newValue) >= emotionThresholds[entityId][emotion]){emit ThresholdTriggered(entityId, emotion, uint256(newValue));_triggerResponse(entityId, emotion);}}
    
    function updateFear(uint256 entityId, int256 delta) external {updateEmotionValue(entityId, Emotion.Fear, delta);}
    
    function updateTrust(uint256 entityId, int256 delta) external {updateEmotionValue(entityId, Emotion.Trust, delta);}
    
    function _triggerResponse(uint256 entityId, Emotion emotion) internal {ResponseType response;if(emotion == Emotion.Fear) response = ResponseType.Flee;else if(emotion == Emotion.Anger) response = ResponseType.Attack;else if(emotion == Emotion.Trust) response = ResponseType.Cooperate;else if(emotion == Emotion.Joy) response = ResponseType.Celebrate;else response = ResponseType.Freeze;emit EmotionalResponseTriggered(entityId, response);}
    
    function _getEmotionValue(EntityEmotions storage emotions, Emotion emotion) internal view returns (uint256) {if(emotion == Emotion.Fear) return emotions.fear;if(emotion == Emotion.Greed) return emotions.greed;if(emotion == Emotion.Trust) return emotions.trust;if(emotion == Emotion.Anger) return emotions.anger;if(emotion == Emotion.Joy) return emotions.joy;if(emotion == Emotion.Sadness) return emotions.sadness;if(emotion == Emotion.Confidence) return emotions.confidence;if(emotion == Emotion.Stress) return emotions.stress;return 0;}
    
    function _setEmotionValue(EntityEmotions storage emotions, Emotion emotion, uint256 value) internal {if(emotion == Emotion.Fear) emotions.fear = value;else if(emotion == Emotion.Greed) emotions.greed = value;else if(emotion == Emotion.Trust) emotions.trust = value;else if(emotion == Emotion.Anger) emotions.anger = value;else if(emotion == Emotion.Joy) emotions.joy = value;else if(emotion == Emotion.Sadness) emotions.sadness = value;else if(emotion == Emotion.Confidence) emotions.confidence = value;else if(emotion == Emotion.Stress) emotions.stress = value;}
    
    function getEmotions(uint256 entityId) external view returns (EntityEmotions memory) {return entityEmotions[entityId];}
}
