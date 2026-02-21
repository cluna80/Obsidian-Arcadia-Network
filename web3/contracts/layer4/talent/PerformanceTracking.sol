// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PerformanceTracking
 * @notice Track actor/director performance across productions
 */
contract PerformanceTracking {
    
    struct Performance {
        uint256 performanceId;
        uint256 talentId;
        uint256 movieId;
        uint256 role;                    // Actor: character ID, Director: 0
        uint256 rating;                  // 0-10000
        uint256 boxOfficeContribution;   // Revenue attributed to this talent
        uint256 criticalScore;           // Reviews/critics score
        uint256 audienceScore;           // Audience score
        uint256 timestamp;
        address ratedBy;
    }
    
    struct CareerStats {
        uint256 talentId;
        uint256 totalPerformances;
        uint256 averageRating;
        uint256 totalBoxOffice;
        uint256 peakRating;
        uint256 currentStreak;           // Consecutive good performances
        uint256 awards;
    }
    
    mapping(uint256 => Performance) public performances;
    mapping(uint256 => CareerStats) public careerStats;
    mapping(uint256 => uint256[]) public talentPerformances; // talentId => performanceIds
    
    uint256 public performanceCount;
    
    event PerformanceRecorded(uint256 indexed performanceId, uint256 indexed talentId, uint256 rating);
    event AwardReceived(uint256 indexed talentId, string awardName);
    
    function recordPerformance(
        uint256 talentId,
        uint256 movieId,
        uint256 role,
        uint256 rating,
        uint256 boxOffice,
        uint256 criticalScore,
        uint256 audienceScore
    ) external returns (uint256) {
        performanceCount++;
        uint256 performanceId = performanceCount;
        
        performances[performanceId] = Performance({
            performanceId: performanceId,
            talentId: talentId,
            movieId: movieId,
            role: role,
            rating: rating,
            boxOfficeContribution: boxOffice,
            criticalScore: criticalScore,
            audienceScore: audienceScore,
            timestamp: block.timestamp,
            ratedBy: msg.sender
        });
        
        talentPerformances[talentId].push(performanceId);
        
        // Update career stats
        CareerStats storage stats = careerStats[talentId];
        stats.totalPerformances++;
        stats.totalBoxOffice += boxOffice;
        
        // Update average rating
        stats.averageRating = ((stats.averageRating * (stats.totalPerformances - 1)) + rating) / stats.totalPerformances;
        
        // Update peak
        if (rating > stats.peakRating) {
            stats.peakRating = rating;
        }
        
        // Update streak
        if (rating >= 7000) {
            stats.currentStreak++;
        } else {
            stats.currentStreak = 0;
        }
        
        emit PerformanceRecorded(performanceId, talentId, rating);
        return performanceId;
    }
    
    function awardTalent(uint256 talentId, string memory awardName) external {
        CareerStats storage stats = careerStats[talentId];
        stats.awards++;
        emit AwardReceived(talentId, awardName);
    }
    
    function getPerformance(uint256 performanceId) external view returns (Performance memory) {
        return performances[performanceId];
    }
    
    function getCareerStats(uint256 talentId) external view returns (CareerStats memory) {
        return careerStats[talentId];
    }
    
    function getTalentPerformances(uint256 talentId) external view returns (uint256[] memory) {
        return talentPerformances[talentId];
    }
    
    function calculateTalentScore(uint256 talentId) external view returns (uint256) {
        CareerStats storage stats = careerStats[talentId];
        
        // Weighted score: 40% avg rating, 30% box office, 20% awards, 10% streak
        uint256 ratingScore = (stats.averageRating * 40) / 100;
        uint256 boxOfficeScore = (stats.totalBoxOffice * 30) / 100;
        uint256 awardScore = (stats.awards * 2000); // Each award = 2000 points
        uint256 streakScore = (stats.currentStreak * 1000); // Each streak = 1000 points
        
        return ratingScore + boxOfficeScore + awardScore + streakScore;
    }
}
