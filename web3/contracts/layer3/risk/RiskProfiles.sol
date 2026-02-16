// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract RiskProfiles is Ownable {
    
    enum RiskRating {VeryLow, Low, Moderate, High, VeryHigh, Extreme}
    enum RiskTolerance {Conservative, Moderate, Aggressive}
    
    struct EntityRiskProfile {uint256 entityId;RiskRating riskRating;uint256 volatility;uint256 stabilityScore;uint256 failureProbability;uint256 historicalVariance;RiskTolerance riskTolerance;uint256 lastAssessment;}
    struct PerformanceData {uint256 totalAttempts;uint256 successfulAttempts;uint256 failedAttempts;int256 averageReturn;uint256 maxDrawdown;}
    struct WorldRiskProfile {uint256 worldId;uint256 dangerLevel;uint256 rewardPotential;uint256 economicStability;RiskRating overallRisk;}
    
    mapping(uint256 => EntityRiskProfile) public entityRiskProfiles;
    mapping(uint256 => PerformanceData) public performanceData;
    mapping(uint256 => WorldRiskProfile) public worldRiskProfiles;
    mapping(uint256 => uint256[]) public riskHistory;
    
    event RiskProfileCreated(uint256 indexed entityId, RiskRating rating);
    event RiskRatingUpdated(uint256 indexed entityId, RiskRating oldRating, RiskRating newRating);
    event VolatilityCalculated(uint256 indexed entityId, uint256 volatility);
    
    constructor() Ownable(msg.sender) {}
    
    function createRiskProfile(uint256 entityId,uint256 volatility,uint256 stabilityScore,RiskTolerance tolerance) external returns (bool) {require(entityRiskProfiles[entityId].lastAssessment == 0);RiskRating rating = _calculateRiskRating(volatility, stabilityScore);entityRiskProfiles[entityId] = EntityRiskProfile(entityId,rating,volatility,stabilityScore,_calculateFailureProbability(volatility, stabilityScore),0,tolerance,block.timestamp);emit RiskProfileCreated(entityId, rating);return true;}
    
    function updateRiskProfile(uint256 entityId, uint256 newVolatility) public {EntityRiskProfile storage profile = entityRiskProfiles[entityId];require(profile.lastAssessment > 0);RiskRating oldRating = profile.riskRating;profile.volatility = newVolatility;profile.riskRating = _calculateRiskRating(newVolatility, profile.stabilityScore);profile.failureProbability = _calculateFailureProbability(newVolatility, profile.stabilityScore);profile.lastAssessment = block.timestamp;riskHistory[entityId].push(newVolatility);if(oldRating != profile.riskRating){emit RiskRatingUpdated(entityId, oldRating, profile.riskRating);}emit VolatilityCalculated(entityId, newVolatility);}
    
    function recordPerformance(uint256 entityId, bool success, int256 returnValue) external {PerformanceData storage perf = performanceData[entityId];perf.totalAttempts++;if(success){perf.successfulAttempts++;}else{perf.failedAttempts++;}perf.averageReturn = (perf.averageReturn * int256(perf.totalAttempts - 1) + returnValue) / int256(perf.totalAttempts);uint256 newVolatility = _calculateVolatilityFromPerformance(entityId);updateRiskProfile(entityId, newVolatility);}
    
    function createWorldRiskProfile(uint256 worldId,uint256 dangerLevel,uint256 rewardPotential,uint256 economicStability) external {RiskRating rating = _calculateWorldRiskRating(dangerLevel, economicStability);worldRiskProfiles[worldId] = WorldRiskProfile(worldId,dangerLevel,rewardPotential,economicStability,rating);}
    
    function _calculateRiskRating(uint256 volatility, uint256 stability) internal pure returns (RiskRating) {uint256 riskScore = volatility + (100 - stability);if(riskScore < 40) return RiskRating.VeryLow;if(riskScore < 70) return RiskRating.Low;if(riskScore < 100) return RiskRating.Moderate;if(riskScore < 130) return RiskRating.High;if(riskScore < 160) return RiskRating.VeryHigh;return RiskRating.Extreme;}
    
    function _calculateFailureProbability(uint256 volatility, uint256 stability) internal pure returns (uint256) {uint256 baseProb = volatility * 50;uint256 stabilityAdjustment = (100 - stability) * 25;uint256 totalProb = baseProb + stabilityAdjustment;return totalProb > 10000 ? 10000 : totalProb;}
    
    function _calculateVolatilityFromPerformance(uint256 entityId) internal view returns (uint256) {PerformanceData storage perf = performanceData[entityId];if(perf.totalAttempts < 5) return 50;uint256 successRate = (perf.successfulAttempts * 100) / perf.totalAttempts;if(successRate > 80) return 20;if(successRate > 60) return 40;if(successRate > 40) return 60;if(successRate > 20) return 80;return 95;}
    
    function _calculateWorldRiskRating(uint256 danger, uint256 stability) internal pure returns (RiskRating) {uint256 score = danger + (100 - stability);if(score < 50) return RiskRating.Low;if(score < 100) return RiskRating.Moderate;if(score < 150) return RiskRating.High;return RiskRating.VeryHigh;}
    
    function getRiskProfile(uint256 entityId) external view returns (EntityRiskProfile memory) {return entityRiskProfiles[entityId];}
    
    function getRiskScore(uint256 entityId) external view returns (uint256) {EntityRiskProfile storage profile = entityRiskProfiles[entityId];return profile.volatility + (100 - profile.stabilityScore);}
}
