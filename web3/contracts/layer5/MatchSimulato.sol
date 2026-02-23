// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MatchSimulator - AI-powered sports match simulation
/// @notice Layer 5, Phase 5.3 - OAN Metaverse Sports Arena
contract MatchSimulator is AccessControl, ReentrancyGuard {
    bytes32 public constant SIMULATOR_ROLE = keccak256("SIMULATOR_ROLE");

    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }
    enum FinishType { Decision, KO, TKO, Submission, Disqualification, Draw }
    enum MatchStatus { Scheduled, InProgress, Completed, Cancelled }

    struct MatchSetup {
        uint256 matchId;
        uint256 athlete1Id;
        uint256 athlete2Id;
        uint256 stadiumId;
        SportType sport;
        uint256 scheduledTime;
        uint256 prizePool;         // In wei
        uint256 maxRounds;
        uint256 roundDurationSecs;
        bool teamMatch;
        uint256 team1Id;
        uint256 team2Id;
    }

    struct MatchOutcome {
        uint256 winnerId;
        uint256 loserId;
        FinishType finishType;
        uint256 finishRound;
        uint256[] roundScores1;   // Points per round for athlete 1
        uint256[] roundScores2;   // Points per round for athlete 2
        uint256 viewerCount;
        uint256 totalBets;
        uint256 startTime;
        uint256 endTime;
        bool isDraw;
    }

    struct RoundEvent {
        uint256 round;
        string eventType;          // "knockdown", "submission_attempt", "point", "warning"
        uint256 athleteId;
        uint256 timestamp;
    }

    mapping(uint256 => MatchSetup) public matches;
    mapping(uint256 => MatchOutcome) public outcomes;
    mapping(uint256 => MatchStatus) public matchStatus;
    mapping(uint256 => RoundEvent[]) public matchEvents;
    mapping(uint256 => uint256[]) public athleteMatches;  // athleteId => matchIds

    uint256 private _matchIdCounter;
    uint256 public totalMatches;
    uint256 public totalCompletedMatches;

    address public athleteContract;  // AthleteNFT contract
    address public treasury;
    uint256 public protocolFeePercent = 500; // 5% of prize pool

    event MatchScheduled(uint256 indexed matchId, uint256 athlete1Id, uint256 athlete2Id, SportType sport);
    event MatchStarted(uint256 indexed matchId, uint256 startTime);
    event MatchCompleted(uint256 indexed matchId, uint256 winnerId, FinishType finishType);
    event RoundCompleted(uint256 indexed matchId, uint256 round, uint256 score1, uint256 score2);
    event MatchCancelled(uint256 indexed matchId, string reason);

    constructor(address _treasury, address _athleteContract) {
        treasury = _treasury;
        athleteContract = _athleteContract;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SIMULATOR_ROLE, msg.sender);
    }

    /// @notice Schedule a new match
    function scheduleMatch(
        uint256 athlete1Id,
        uint256 athlete2Id,
        uint256 stadiumId,
        SportType sport,
        uint256 scheduledTime,
        uint256 maxRounds,
        uint256 roundDurationSecs
    ) external payable returns (uint256) {
        require(athlete1Id != athlete2Id, "Cannot fight yourself");
        require(scheduledTime > block.timestamp, "Must be future");
        require(maxRounds >= 1 && maxRounds <= 15, "Invalid rounds");

        uint256 matchId = ++_matchIdCounter;

        matches[matchId] = MatchSetup({
            matchId: matchId,
            athlete1Id: athlete1Id,
            athlete2Id: athlete2Id,
            stadiumId: stadiumId,
            sport: sport,
            scheduledTime: scheduledTime,
            prizePool: msg.value,
            maxRounds: maxRounds,
            roundDurationSecs: roundDurationSecs,
            teamMatch: false,
            team1Id: 0,
            team2Id: 0
        });

        matchStatus[matchId] = MatchStatus.Scheduled;
        athleteMatches[athlete1Id].push(matchId);
        athleteMatches[athlete2Id].push(matchId);
        totalMatches++;

        emit MatchScheduled(matchId, athlete1Id, athlete2Id, sport);
        return matchId;
    }

    /// @notice Simulate a match and record outcome (called by authorized simulator)
    /// @dev In production, this would integrate with Chainlink VRF for randomness
    function simulateMatch(
        uint256 matchId,
        uint256 athlete1Strength,
        uint256 athlete1Speed,
        uint256 athlete1Endurance,
        uint256 athlete1Technique,
        uint256 athlete2Strength,
        uint256 athlete2Speed,
        uint256 athlete2Endurance,
        uint256 athlete2Technique,
        uint256 viewerCount
    ) external onlyRole(SIMULATOR_ROLE) nonReentrant returns (MatchOutcome memory) {
        MatchSetup storage setup = matches[matchId];
        require(matchStatus[matchId] == MatchStatus.Scheduled, "Match not scheduled");
        require(block.timestamp >= setup.scheduledTime, "Too early");

        matchStatus[matchId] = MatchStatus.InProgress;
        emit MatchStarted(matchId, block.timestamp);

        // Compute composite scores
        uint256 score1 = (athlete1Strength * 3 + athlete1Speed * 2 + athlete1Endurance * 2 + athlete1Technique * 3) / 10;
        uint256 score2 = (athlete2Strength * 3 + athlete2Speed * 2 + athlete2Endurance * 2 + athlete2Technique * 3) / 10;

        // Add pseudo-randomness using block data (use Chainlink VRF in production)
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, matchId)));
        uint256 random1 = seed % 20;         // 0-19 bonus for athlete 1
        uint256 random2 = (seed >> 8) % 20;  // 0-19 bonus for athlete 2

        score1 += random1;
        score2 += random2;

        // Simulate rounds
        uint256[] memory roundScores1 = new uint256[](setup.maxRounds);
        uint256[] memory roundScores2 = new uint256[](setup.maxRounds);
        uint256 total1 = 0;
        uint256 total2 = 0;
        uint256 finishRound = setup.maxRounds;
        FinishType finishType = FinishType.Decision;

        for (uint256 r = 0; r < setup.maxRounds; r++) {
            uint256 roundSeed = uint256(keccak256(abi.encodePacked(seed, r)));
            uint256 rs1 = 5 + (score1 * (80 + roundSeed % 40)) / (100 * 100);
            uint256 rs2 = 5 + (score2 * (80 + (roundSeed >> 4) % 40)) / (100 * 100);

            roundScores1[r] = rs1;
            roundScores2[r] = rs2;
            total1 += rs1;
            total2 += rs2;

            emit RoundCompleted(matchId, r + 1, rs1, rs2);

            // Check for early finish (KO/TKO chance increases with dominant score)
            if (score1 > score2 + 20 && roundSeed % 10 == 0) {
                finishRound = r + 1;
                finishType = (roundSeed % 2 == 0) ? FinishType.KO : FinishType.TKO;
                break;
            } else if (score2 > score1 + 20 && (roundSeed >> 8) % 10 == 0) {
                finishRound = r + 1;
                finishType = ((roundSeed >> 8) % 2 == 0) ? FinishType.KO : FinishType.TKO;
                total1 = 0; // reset to mark loser
                total2 = 1;
                break;
            }

            // Submission chance for MMA
            if (setup.sport == SportType.MMA && athlete1Technique > 80 && roundSeed % 15 == 0) {
                finishRound = r + 1;
                finishType = FinishType.Submission;
                break;
            }
        }

        bool isDraw = (total1 == total2);
        uint256 winnerId = isDraw ? 0 : (total1 > total2 ? setup.athlete1Id : setup.athlete2Id);
        uint256 loserId = isDraw ? 0 : (total1 > total2 ? setup.athlete2Id : setup.athlete1Id);

        MatchOutcome memory outcome = MatchOutcome({
            winnerId: winnerId,
            loserId: loserId,
            finishType: finishType,
            finishRound: finishRound,
            roundScores1: roundScores1,
            roundScores2: roundScores2,
            viewerCount: viewerCount,
            totalBets: 0,
            startTime: block.timestamp,
            endTime: block.timestamp,
            isDraw: isDraw
        });

        outcomes[matchId] = outcome;
        matchStatus[matchId] = MatchStatus.Completed;
        totalCompletedMatches++;

        // Distribute prize pool
        if (setup.prizePool > 0) {
            uint256 fee = (setup.prizePool * protocolFeePercent) / 10000;
            payable(treasury).transfer(fee);
            // Remaining goes to winner (in practice, would call AthleteNFT.recordMatchResult)
        }

        emit MatchCompleted(matchId, winnerId, finishType);
        return outcome;
    }

    /// @notice Cancel a match
    function cancelMatch(uint256 matchId, string memory reason) external onlyRole(SIMULATOR_ROLE) {
        require(matchStatus[matchId] == MatchStatus.Scheduled, "Cannot cancel");
        matchStatus[matchId] = MatchStatus.Cancelled;

        // Refund prize pool
        uint256 prizePool = matches[matchId].prizePool;
        if (prizePool > 0) {
            // In production, refund to match creator
            payable(treasury).transfer(prizePool);
        }

        emit MatchCancelled(matchId, reason);
    }

    // View functions
    function getMatchOutcome(uint256 matchId) external view returns (MatchOutcome memory) {
        return outcomes[matchId];
    }

    function getAthleteMatches(uint256 athleteId) external view returns (uint256[] memory) {
        return athleteMatches[athleteId];
    }

    function getMatchEvents(uint256 matchId) external view returns (RoundEvent[] memory) {
        return matchEvents[matchId];
    }

    function getRoundScores(uint256 matchId) external view returns (uint256[] memory, uint256[] memory) {
        return (outcomes[matchId].roundScores1, outcomes[matchId].roundScores2);
    }

    // Admin
    function setAthleteContract(address newContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        athleteContract = newContract;
    }

    function setProtocolFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 1000, "Max 10%");
        protocolFeePercent = newFee;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
