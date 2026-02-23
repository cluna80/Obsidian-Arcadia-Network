// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title PerformanceMetrics - Track and analyze athlete stats on-chain
/// @notice Layer 5, Phase 5.3 - OAN Metaverse Sports Arena
contract PerformanceMetrics is AccessControl {
    bytes32 public constant RECORDER_ROLE = keccak256("RECORDER_ROLE");

    struct CareerStats {
        uint256 athleteId;
        uint256 totalMatches;
        uint256 wins;
        uint256 losses;
        uint256 draws;
        uint256 knockouts;
        uint256 submissions;
        uint256 decisions;
        uint256 totalRounds;
        uint256 avgRoundsPerFight;
        uint256 winStreak;
        uint256 lossStreak;
        uint256 longestWinStreak;
        uint256 totalFanVotes;
        uint256 performanceScore;   // Computed composite score 0-1000
        uint256 lastUpdated;
    }

    struct MatchPerformance {
        uint256 matchId;
        uint256 athleteId;
        uint256 roundsWon;
        uint256 roundsLost;
        uint256 knockdownsLanded;
        uint256 knockdownsReceived;
        uint256 significantStrikes;
        uint256 accuracy;           // Basis points (e.g., 5500 = 55%)
        uint256 fightIQ;            // 0-100, how smart their decisions were
        uint256 crowdRating;        // Fan rating 0-100
        uint256 timestamp;
    }

    struct Milestone {
        string name;
        string description;
        uint256 achievedAt;
        uint256 matchId;
    }

    mapping(uint256 => CareerStats) public careerStats;
    mapping(uint256 => MatchPerformance[]) public matchPerformances;
    mapping(uint256 => Milestone[]) public athleteMilestones;
    mapping(uint256 => uint256[]) public rankingHistory;  // athleteId => historical ranks
    
    // Global rankings by sport
    mapping(uint8 => uint256[]) public sportRankings;  // SportType enum => ordered athleteIds
    mapping(uint8 => mapping(uint256 => uint256)) public athleteRank; // sport => athleteId => rank

    uint256 public totalAthletesTracked;

    event CareerStatsUpdated(uint256 indexed athleteId, uint256 newPerformanceScore);
    event MatchPerformanceRecorded(uint256 indexed athleteId, uint256 indexed matchId);
    event MilestoneAchieved(uint256 indexed athleteId, string milestoneName);
    event RankingUpdated(uint256 indexed athleteId, uint8 sport, uint256 newRank);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RECORDER_ROLE, msg.sender);
    }

    /// @notice Initialize or update career stats for an athlete
    function initializeAthlete(uint256 athleteId) external onlyRole(RECORDER_ROLE) {
        if (careerStats[athleteId].athleteId == 0) {
            careerStats[athleteId] = CareerStats({
                athleteId: athleteId,
                totalMatches: 0,
                wins: 0,
                losses: 0,
                draws: 0,
                knockouts: 0,
                submissions: 0,
                decisions: 0,
                totalRounds: 0,
                avgRoundsPerFight: 0,
                winStreak: 0,
                lossStreak: 0,
                longestWinStreak: 0,
                totalFanVotes: 0,
                performanceScore: 500,
                lastUpdated: block.timestamp
            });
            totalAthletesTracked++;
        }
    }

    /// @notice Record a match performance for an athlete
    function recordMatchPerformance(
        uint256 athleteId,
        uint256 matchId,
        bool won,
        bool knockout,
        bool submission,
        uint256 roundsWon,
        uint256 roundsLost,
        uint256 knockdownsLanded,
        uint256 knockdownsReceived,
        uint256 significantStrikes,
        uint256 accuracy,
        uint256 crowdRating
    ) external onlyRole(RECORDER_ROLE) {
        CareerStats storage stats = careerStats[athleteId];

        stats.totalMatches++;
        uint256 totalRoundsThisFight = roundsWon + roundsLost;
        stats.totalRounds += totalRoundsThisFight;

        if (stats.totalMatches > 0) {
            stats.avgRoundsPerFight = stats.totalRounds / stats.totalMatches;
        }

        if (won) {
            stats.wins++;
            stats.winStreak++;
            stats.lossStreak = 0;
            if (stats.winStreak > stats.longestWinStreak) {
                stats.longestWinStreak = stats.winStreak;
            }
            if (knockout) stats.knockouts++;
            if (submission) stats.submissions++;
            if (!knockout && !submission) stats.decisions++;
        } else {
            stats.losses++;
            stats.lossStreak++;
            stats.winStreak = 0;
        }

        // Compute new performance score
        stats.performanceScore = _computePerformanceScore(stats);
        stats.lastUpdated = block.timestamp;

        // Store detailed match performance
        uint256 fightIQ = _computeFightIQ(knockdownsLanded, knockdownsReceived, accuracy, roundsWon, totalRoundsThisFight);

        matchPerformances[athleteId].push(MatchPerformance({
            matchId: matchId,
            athleteId: athleteId,
            roundsWon: roundsWon,
            roundsLost: roundsLost,
            knockdownsLanded: knockdownsLanded,
            knockdownsReceived: knockdownsReceived,
            significantStrikes: significantStrikes,
            accuracy: accuracy,
            fightIQ: fightIQ,
            crowdRating: crowdRating,
            timestamp: block.timestamp
        }));

        // Check for milestones
        _checkMilestones(athleteId, stats, matchId);

        emit CareerStatsUpdated(athleteId, stats.performanceScore);
        emit MatchPerformanceRecorded(athleteId, matchId);
    }

    /// @notice Update athlete ranking for a sport
    function updateRanking(uint256 athleteId, uint8 sport, uint256 rank) external onlyRole(RECORDER_ROLE) {
        athleteRank[sport][athleteId] = rank;
        rankingHistory[athleteId].push(rank);
        emit RankingUpdated(athleteId, sport, rank);
    }

    function _computePerformanceScore(CareerStats memory stats) internal pure returns (uint256) {
        if (stats.totalMatches == 0) return 500;

        uint256 winRate = (stats.wins * 10000) / stats.totalMatches; // basis points
        uint256 finishRate = stats.totalMatches > 0
            ? ((stats.knockouts + stats.submissions) * 10000) / stats.totalMatches
            : 0;

        // Weighted: 60% win rate, 40% finish rate, bonus for streaks
        uint256 base = (winRate * 60 + finishRate * 40) / 100;
        uint256 streakBonus = stats.winStreak * 50;  // +50 per win in current streak

        return _min(base / 10 + streakBonus, 1000); // scale to 0-1000
    }

    function _computeFightIQ(
        uint256 kd_landed,
        uint256 kd_received,
        uint256 accuracy,
        uint256 rounds_won,
        uint256 total_rounds
    ) internal pure returns (uint256) {
        uint256 kd_ratio = kd_received == 0 ? 100 : _min((kd_landed * 100) / (kd_received + 1), 100);
        uint256 acc_score = _min(accuracy / 100, 100); // convert from basis points
        uint256 round_score = total_rounds == 0 ? 50 : (rounds_won * 100) / total_rounds;

        return (kd_ratio * 30 + acc_score * 40 + round_score * 30) / 100;
    }

    function _checkMilestones(uint256 athleteId, CareerStats memory stats, uint256 matchId) internal {
        if (stats.wins == 10) _awardMilestone(athleteId, matchId, "10 Wins", "Achieved 10 career wins");
        if (stats.wins == 50) _awardMilestone(athleteId, matchId, "50 Wins", "Achieved 50 career wins");
        if (stats.knockouts == 10) _awardMilestone(athleteId, matchId, "KO Artist", "10 career knockouts");
        if (stats.longestWinStreak >= 10) _awardMilestone(athleteId, matchId, "Unstoppable", "10 fight win streak");
        if (stats.totalMatches == 100) _awardMilestone(athleteId, matchId, "Century", "100 career fights");
    }

    function _awardMilestone(uint256 athleteId, uint256 matchId, string memory name, string memory desc) internal {
        // Check not already awarded
        Milestone[] storage milestones = athleteMilestones[athleteId];
        for (uint256 i = 0; i < milestones.length; i++) {
            if (keccak256(bytes(milestones[i].name)) == keccak256(bytes(name))) return;
        }

        milestones.push(Milestone({
            name: name,
            description: desc,
            achievedAt: block.timestamp,
            matchId: matchId
        }));

        emit MilestoneAchieved(athleteId, name);
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }

    // View
    function getCareerStats(uint256 athleteId) external view returns (CareerStats memory) {
        return careerStats[athleteId];
    }

    function getMatchPerformances(uint256 athleteId) external view returns (MatchPerformance[] memory) {
        return matchPerformances[athleteId];
    }

    function getMilestones(uint256 athleteId) external view returns (Milestone[] memory) {
        return athleteMilestones[athleteId];
    }

    function getAthleteRank(uint256 athleteId, uint8 sport) external view returns (uint256) {
        return athleteRank[sport][athleteId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
