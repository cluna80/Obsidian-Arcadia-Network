// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TournamentBrackets - Organize competitive tournaments
/// @notice Layer 5, Phase 5.3 - OAN Metaverse Sports Arena
contract TournamentBrackets is AccessControl, ReentrancyGuard {
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");

    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }
    enum TournamentFormat { SingleElimination, DoubleElimination, RoundRobin, Swiss }
    enum TournamentStatus { Registration, InProgress, Completed, Cancelled }

    struct Tournament {
        uint256 tournamentId;
        string name;
        SportType sport;
        TournamentFormat format;
        uint256 prizePool;
        uint256 entryFee;
        uint256 maxParticipants;
        uint256[] participantAthleteIds;
        uint256 startDate;
        uint256 endDate;
        TournamentStatus status;
        address organizer;
        uint256 winnerId;
        bool prizeDistributed;
    }

    struct BracketMatch {
        uint256 bracketMatchId;
        uint256 tournamentId;
        uint256 round;
        uint256 athlete1Id;
        uint256 athlete2Id;
        uint256 winnerId;
        uint256 matchId;        // Link to MatchSimulator
        bool completed;
    }

    uint256 private _tournamentIdCounter;
    uint256 private _bracketMatchIdCounter;

    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => BracketMatch[]) public tournamentBracket;
    mapping(uint256 => mapping(uint256 => bool)) public isRegistered; // tournamentId => athleteId => registered
    mapping(address => uint256[]) public organizerTournaments;
    mapping(uint256 => uint256[]) public athleteTournaments;

    uint256 public totalTournaments;
    address public treasury;
    uint256 public platformFeePercent = 1000; // 10% of prize pool

    // Prize distribution (percentages in basis points)
    uint256 public firstPlacePct = 5000;  // 50%
    uint256 public secondPlacePct = 3000; // 30%
    uint256 public thirdPlacePct = 2000;  // 20%

    event TournamentCreated(uint256 indexed tournamentId, string name, SportType sport, uint256 prizePool);
    event AthleteRegistered(uint256 indexed tournamentId, uint256 indexed athleteId);
    event TournamentStarted(uint256 indexed tournamentId, uint256 participantCount);
    event BracketMatchCreated(uint256 indexed tournamentId, uint256 round, uint256 athlete1Id, uint256 athlete2Id);
    event BracketMatchCompleted(uint256 indexed bracketMatchId, uint256 winnerId);
    event TournamentCompleted(uint256 indexed tournamentId, uint256 winnerId, uint256 prize);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORGANIZER_ROLE, msg.sender);
    }

    /// @notice Create a new tournament
    function createTournament(
        string memory name,
        SportType sport,
        TournamentFormat format,
        uint256 entryFee,
        uint256 maxParticipants,
        uint256 startDate,
        uint256 endDate
    ) external payable returns (uint256) {
        require(startDate > block.timestamp, "Start must be future");
        require(endDate > startDate, "End must be after start");
        require(maxParticipants >= 2, "Need at least 2 participants");

        uint256 tournamentId = ++_tournamentIdCounter;

        tournaments[tournamentId] = Tournament({
            tournamentId: tournamentId,
            name: name,
            sport: sport,
            format: format,
            prizePool: msg.value,
            entryFee: entryFee,
            maxParticipants: maxParticipants,
            participantAthleteIds: new uint256[](0),
            startDate: startDate,
            endDate: endDate,
            status: TournamentStatus.Registration,
            organizer: msg.sender,
            winnerId: 0,
            prizeDistributed: false
        });

        organizerTournaments[msg.sender].push(tournamentId);
        totalTournaments++;

        emit TournamentCreated(tournamentId, name, sport, msg.value);
        return tournamentId;
    }

    /// @notice Register an athlete for a tournament
    function registerAthlete(uint256 tournamentId, uint256 athleteId) external payable nonReentrant {
        Tournament storage t = tournaments[tournamentId];
        require(t.status == TournamentStatus.Registration, "Registration closed");
        require(t.participantAthleteIds.length < t.maxParticipants, "Tournament full");
        require(!isRegistered[tournamentId][athleteId], "Already registered");
        require(msg.value >= t.entryFee, "Insufficient entry fee");

        isRegistered[tournamentId][athleteId] = true;
        t.participantAthleteIds.push(athleteId);
        t.prizePool += msg.value;
        athleteTournaments[athleteId].push(tournamentId);

        emit AthleteRegistered(tournamentId, athleteId);
    }

    /// @notice Start a tournament and generate bracket
    function startTournament(uint256 tournamentId) external onlyRole(ORGANIZER_ROLE) {
        Tournament storage t = tournaments[tournamentId];
        require(t.status == TournamentStatus.Registration, "Not in registration");
        require(t.participantAthleteIds.length >= 2, "Not enough participants");

        t.status = TournamentStatus.InProgress;

        // Generate Round 1 matchups
        uint256[] memory participants = t.participantAthleteIds;
        for (uint256 i = 0; i < participants.length - 1; i += 2) {
            uint256 bMatchId = ++_bracketMatchIdCounter;
            tournamentBracket[tournamentId].push(BracketMatch({
                bracketMatchId: bMatchId,
                tournamentId: tournamentId,
                round: 1,
                athlete1Id: participants[i],
                athlete2Id: participants[i + 1],
                winnerId: 0,
                matchId: 0,
                completed: false
            }));
            emit BracketMatchCreated(tournamentId, 1, participants[i], participants[i + 1]);
        }

        emit TournamentStarted(tournamentId, participants.length);
    }

    /// @notice Record a bracket match result
    function recordBracketResult(
        uint256 tournamentId,
        uint256 bracketMatchIndex,
        uint256 winnerId
    ) external onlyRole(ORGANIZER_ROLE) {
        BracketMatch storage bm = tournamentBracket[tournamentId][bracketMatchIndex];
        require(!bm.completed, "Already completed");
        require(winnerId == bm.athlete1Id || winnerId == bm.athlete2Id, "Invalid winner");

        bm.winnerId = winnerId;
        bm.completed = true;

        emit BracketMatchCompleted(bm.bracketMatchId, winnerId);
    }

    /// @notice Complete tournament and award prize
    function completeTournament(uint256 tournamentId, uint256 winnerId) external onlyRole(ORGANIZER_ROLE) nonReentrant {
        Tournament storage t = tournaments[tournamentId];
        require(t.status == TournamentStatus.InProgress, "Not in progress");
        require(!t.prizeDistributed, "Prize already distributed");

        t.status = TournamentStatus.Completed;
        t.winnerId = winnerId;
        t.prizeDistributed = true;

        // Distribute prizes
        uint256 fee = (t.prizePool * platformFeePercent) / 10000;
        uint256 remainder = t.prizePool - fee;
        payable(treasury).transfer(fee);

        // Winner gets majority (in production would split to 2nd/3rd place too)
        // This is simplified — full implementation would track placements
        payable(msg.sender).transfer(remainder); // placeholder: send to organizer to distribute

        emit TournamentCompleted(tournamentId, winnerId, remainder);
    }

    // View
    function getTournamentBracket(uint256 tournamentId) external view returns (BracketMatch[] memory) {
        return tournamentBracket[tournamentId];
    }

    function getTournamentParticipants(uint256 tournamentId) external view returns (uint256[] memory) {
        return tournaments[tournamentId].participantAthleteIds;
    }

    function getAthleteTournaments(uint256 athleteId) external view returns (uint256[] memory) {
        return athleteTournaments[athleteId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
