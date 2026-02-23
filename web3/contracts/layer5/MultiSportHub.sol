// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MultiSportHub - Unified sports platform for all OAN sports
/// @notice Layer 5, Phase 5.6
contract MultiSportHub is AccessControl {
    bytes32 public constant HUB_MANAGER = keccak256("HUB_MANAGER");

    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }

    struct SportConfig {
        SportType sport;
        string name;
        bool isActive;
        uint256 totalAthletes;
        uint256 totalMatches;
        uint256 totalTournaments;
        address matchSimulatorContract;
        address tournamentContract;
        uint256 prizePoolTotal;
    }

    struct GlobalLeaderboard {
        uint256 athleteId;
        uint256 totalPoints;        // Across ALL sports
        uint256 totalWins;
        uint256 totalMatches;
        uint8[] sportsParticipated;
        uint256 rank;
    }

    mapping(uint8 => SportConfig) public sportConfigs;
    mapping(uint256 => GlobalLeaderboard) public globalLeaderboard;
    mapping(uint8 => uint256[]) public topAthletesBySport; // sport => top 100 athleteIds
    mapping(uint256 => mapping(uint8 => uint256)) public athleteSportPoints; // athleteId => sport => points

    uint256 public totalCrossoverAthletes;
    uint256[] public rankedAthletes;

    event SportActivated(SportType sport, string name);
    event GlobalRankUpdated(uint256 indexed athleteId, uint256 newRank, uint256 totalPoints);
    event CrossSportMilestone(uint256 indexed athleteId, string milestone);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(HUB_MANAGER, msg.sender);

        // Initialize all sports
        string[8] memory sportNames = ["Boxing", "MMA", "Racing", "Soccer", "Basketball", "Esports", "Tennis", "Wrestling"];
        for (uint8 i = 0; i < 8; i++) {
            sportConfigs[i] = SportConfig(SportType(i), sportNames[i], true, 0, 0, 0, address(0), address(0), 0);
            emit SportActivated(SportType(i), sportNames[i]);
        }
    }

    function setSportContracts(
        uint8 sport,
        address matchSimulator,
        address tournament
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sportConfigs[sport].matchSimulatorContract = matchSimulator;
        sportConfigs[sport].tournamentContract = tournament;
    }

    function recordSportActivity(uint256 athleteId, uint8 sport, uint256 points, bool isMatch, bool isTournament) external onlyRole(HUB_MANAGER) {
        athleteSportPoints[athleteId][sport] += points;

        if (isMatch) sportConfigs[sport].totalMatches++;
        if (isTournament) sportConfigs[sport].totalTournaments++;

        // Update global leaderboard
        GlobalLeaderboard storage entry = globalLeaderboard[athleteId];
        entry.athleteId = athleteId;
        entry.totalPoints += points;

        // Check cross-sport milestones
        uint256 sportsCount = _countSports(athleteId);
        if (sportsCount == 3) emit CrossSportMilestone(athleteId, "Triple Threat");
        if (sportsCount == 5) emit CrossSportMilestone(athleteId, "Renaissance Athlete");
        if (sportsCount == 8) emit CrossSportMilestone(athleteId, "Omni Athlete");

        emit GlobalRankUpdated(athleteId, 0, entry.totalPoints);
    }

    function _countSports(uint256 athleteId) internal view returns (uint256 count) {
        for (uint8 i = 0; i < 8; i++) {
            if (athleteSportPoints[athleteId][i] > 0) count++;
        }
    }

    function getAthleteSportPoints(uint256 athleteId) external view returns (uint256[8] memory) {
        uint256[8] memory points;
        for (uint8 i = 0; i < 8; i++) {
            points[i] = athleteSportPoints[athleteId][i];
        }
        return points;
    }

    function getSportConfig(uint8 sport) external view returns (SportConfig memory) {
        return sportConfigs[sport];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// ============================================================
