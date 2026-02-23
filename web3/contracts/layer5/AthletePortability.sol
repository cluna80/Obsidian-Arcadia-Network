// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title AthletePortability - Athletes compete across multiple sports
/// @notice Layer 5, Phase 5.6
contract AthletePortability is AccessControl {
    bytes32 public constant PORTABILITY_MANAGER = keccak256("PORTABILITY_MANAGER");

    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }

    struct SportTransfer {
        uint256 transferId;
        uint256 athleteId;
        SportType fromSport;
        SportType toSport;
        uint256 timestamp;
        uint256 statPenalty;       // Temporary penalty for switching sports (%)
        uint256 penaltyExpiresAt;  // When penalty wears off
        bool completed;
    }

    struct SportLicence {
        uint256 athleteId;
        SportType sport;
        uint256 licenceLevel;      // 0=Amateur, 1=Pro, 2=Elite, 3=Champion
        uint256 grantedAt;
        bool isActive;
    }

    // Stat translation tables: how stats carry between sports
    struct StatTranslation {
        SportType fromSport;
        SportType toSport;
        uint256 strengthCarryover;     // % of strength that transfers (basis points)
        uint256 speedCarryover;
        uint256 enduranceCarryover;
        uint256 techniqueCarryover;
        uint256 learningCurveDays;     // Days before full stats restored
    }

    uint256 private _transferIdCounter;

    mapping(uint256 => SportTransfer[]) public athleteTransfers;   // athleteId => transfers
    mapping(uint256 => mapping(uint8 => SportLicence)) public licences;  // athleteId => sport => licence
    mapping(uint8 => mapping(uint8 => StatTranslation)) public translations; // fromSport => toSport => translation
    mapping(uint256 => uint8) public currentSport;  // athleteId => current primary sport

    event SportSwitched(uint256 indexed athleteId, SportType fromSport, SportType toSport, uint256 penalty);
    event LicenceGranted(uint256 indexed athleteId, SportType sport, uint256 level);
    event PenaltyExpired(uint256 indexed athleteId, SportType sport);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PORTABILITY_MANAGER, msg.sender);

        // Set default stat translations (simplified)
        // Boxing -> MMA: high technique and strength carry over
        translations[0][1] = StatTranslation(SportType.Boxing, SportType.MMA, 9000, 8000, 8500, 8000, 30);
        // MMA -> Boxing: most skills transfer
        translations[1][0] = StatTranslation(SportType.MMA, SportType.Boxing, 8500, 8500, 9000, 7500, 14);
        // Boxing -> Wrestling: strength and endurance carry
        translations[0][7] = StatTranslation(SportType.Boxing, SportType.Wrestling, 9000, 7000, 8500, 5000, 60);
    }

    function switchPrimarySport(uint256 athleteId, SportType newSport) external onlyRole(PORTABILITY_MANAGER) {
        SportType oldSport = SportType(currentSport[athleteId]);
        uint256 penalty = _calculatePenalty(oldSport, newSport);
        uint256 penaltyDuration = _getPenaltyDuration(oldSport, newSport);

        uint256 transferId = ++_transferIdCounter;
        athleteTransfers[athleteId].push(SportTransfer({
            transferId: transferId,
            athleteId: athleteId,
            fromSport: oldSport,
            toSport: newSport,
            timestamp: block.timestamp,
            statPenalty: penalty,
            penaltyExpiresAt: block.timestamp + penaltyDuration,
            completed: true
        }));

        currentSport[athleteId] = uint8(newSport);
        emit SportSwitched(athleteId, oldSport, newSport, penalty);
    }

    function grantLicence(uint256 athleteId, SportType sport, uint256 level) external onlyRole(PORTABILITY_MANAGER) {
        licences[athleteId][uint8(sport)] = SportLicence(athleteId, sport, level, block.timestamp, true);
        emit LicenceGranted(athleteId, sport, level);
    }

    function _calculatePenalty(SportType from, SportType to) internal view returns (uint256) {
        StatTranslation memory t = translations[uint8(from)][uint8(to)];
        if (t.strengthCarryover == 0) return 3000; // 30% default penalty if no translation defined
        // Average carryover inverse = penalty
        uint256 avgCarryover = (t.strengthCarryover + t.speedCarryover + t.enduranceCarryover + t.techniqueCarryover) / 4;
        return 10000 - avgCarryover;
    }

    function _getPenaltyDuration(SportType from, SportType to) internal view returns (uint256) {
        StatTranslation memory t = translations[uint8(from)][uint8(to)];
        return t.learningCurveDays == 0 ? 60 days : t.learningCurveDays * 1 days;
    }

    function getCurrentPenalty(uint256 athleteId) external view returns (uint256 penalty, uint256 expiresAt) {
        SportTransfer[] memory transfers = athleteTransfers[athleteId];
        if (transfers.length == 0) return (0, 0);
        SportTransfer memory latest = transfers[transfers.length - 1];
        if (block.timestamp >= latest.penaltyExpiresAt) return (0, 0);
        return (latest.statPenalty, latest.penaltyExpiresAt);
    }

    function getAthleteTransfers(uint256 athleteId) external view returns (SportTransfer[] memory) {
        return athleteTransfers[athleteId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// ============================================================
