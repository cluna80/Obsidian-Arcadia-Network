// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title UniversalStats - Standardized cross-sport metrics
/// @notice Layer 5, Phase 5.6
contract UniversalStats is AccessControl {
    bytes32 public constant STATS_RECORDER = keccak256("STATS_RECORDER");

    struct UniversalMetric {
        uint256 athleteId;
        uint256 overallRating;          // 0-1000 universal score
        uint256 athleticism;            // Physical capability composite
        uint256 technicalMastery;       // Technique composite
        uint256 mentalStrength;         // Mental composite
        uint256 competitiveness;        // How well they perform under pressure
        uint256 consistency;            // How consistent across matches
        uint256 peakPerformance;        // Best recorded performance
        uint256 valueScore;             // Market/economic value score
        uint256 lastUpdated;
    }

    struct CrossSportRecord {
        uint256 athleteId;
        uint8[] sportsCompeted;
        uint256[] sportsRatings;        // Rating per sport (same index)
        uint256 bestSport;              // uint8 sport with highest rating
        uint256 bestSportRating;
        uint256 totalGamesPlayed;
        uint256 crossSportWinRate;      // basis points
    }

    mapping(uint256 => UniversalMetric) public universalMetrics;
    mapping(uint256 => CrossSportRecord) public crossSportRecords;
    mapping(uint256 => uint256[]) public ratingHistory;  // athleteId => historical ratings

    event UniversalRatingUpdated(uint256 indexed athleteId, uint256 newRating);
    event CrossSportRecordUpdated(uint256 indexed athleteId, uint256 totalSports);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STATS_RECORDER, msg.sender);
    }

    function updateUniversalMetrics(
        uint256 athleteId,
        uint256 athleticism,
        uint256 technicalMastery,
        uint256 mentalStrength,
        uint256 competitiveness,
        uint256 consistency,
        uint256 peakPerformance,
        uint256 valueScore
    ) external onlyRole(STATS_RECORDER) {
        uint256 overall = (athleticism * 25 + technicalMastery * 25 + mentalStrength * 20 + competitiveness * 15 + consistency * 15) / 100;

        universalMetrics[athleteId] = UniversalMetric({
            athleteId: athleteId,
            overallRating: overall,
            athleticism: athleticism,
            technicalMastery: technicalMastery,
            mentalStrength: mentalStrength,
            competitiveness: competitiveness,
            consistency: consistency,
            peakPerformance: peakPerformance,
            valueScore: valueScore,
            lastUpdated: block.timestamp
        });

        ratingHistory[athleteId].push(overall);
        emit UniversalRatingUpdated(athleteId, overall);
    }

    function updateCrossSportRecord(
        uint256 athleteId,
        uint8[] memory sports,
        uint256[] memory ratings,
        uint256 totalGames,
        uint256 totalWins
    ) external onlyRole(STATS_RECORDER) {
        require(sports.length == ratings.length, "Mismatched arrays");

        uint256 bestSport = 0;
        uint256 bestRating = 0;
        for (uint256 i = 0; i < sports.length; i++) {
            if (ratings[i] > bestRating) {
                bestRating = ratings[i];
                bestSport = sports[i];
            }
        }

        uint256 winRate = totalGames > 0 ? (totalWins * 10000) / totalGames : 0;

        crossSportRecords[athleteId] = CrossSportRecord({
            athleteId: athleteId,
            sportsCompeted: sports,
            sportsRatings: ratings,
            bestSport: bestSport,
            bestSportRating: bestRating,
            totalGamesPlayed: totalGames,
            crossSportWinRate: winRate
        });

        emit CrossSportRecordUpdated(athleteId, sports.length);
    }

    function getUniversalMetric(uint256 athleteId) external view returns (UniversalMetric memory) {
        return universalMetrics[athleteId];
    }

    function getCrossSportRecord(uint256 athleteId) external view returns (CrossSportRecord memory) {
        return crossSportRecords[athleteId];
    }

    function getRatingHistory(uint256 athleteId) external view returns (uint256[] memory) {
        return ratingHistory[athleteId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// ============================================================
