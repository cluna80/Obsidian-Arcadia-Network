// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FantasyLeagues - Fantasy sports system powered by OAN athletes
/// @notice Layer 5, Phase 5.4 - OAN Metaverse Sports Arena
contract FantasyLeagues is AccessControl, ReentrancyGuard {
    bytes32 public constant COMMISSIONER_ROLE = keccak256("COMMISSIONER_ROLE");

    enum LeagueStatus { Draft, Active, Completed, Cancelled }
    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports }

    struct League {
        uint256 leagueId;
        string name;
        SportType sport;
        uint256 entryFee;
        uint256 prizePool;
        uint256 maxTeams;
        uint256 rosterSize;         // Athletes per team
        uint256 seasonStart;
        uint256 seasonEnd;
        LeagueStatus status;
        address commissioner;
        uint256 weekNumber;
        bool isPublic;
    }

    struct FantasyTeam {
        uint256 teamId;
        uint256 leagueId;
        address owner;
        string teamName;
        uint256[] rosterAthleteIds;
        uint256 totalPoints;
        uint256 weeklyPoints;
        uint256 wins;
        uint256 losses;
        uint256 rank;
        bool isActive;
    }

    struct WeeklyResult {
        uint256 week;
        uint256 teamId;
        uint256 opponentId;
        uint256 teamPoints;
        uint256 opponentPoints;
        bool won;
    }

    uint256 private _leagueIdCounter;
    uint256 private _teamIdCounter;

    mapping(uint256 => League) public leagues;
    mapping(uint256 => FantasyTeam) public teams;
    mapping(uint256 => uint256[]) public leagueTeams;         // leagueId => teamIds
    mapping(address => uint256[]) public userTeams;           // user => teamIds
    mapping(uint256 => WeeklyResult[]) public teamHistory;    // teamId => weekly results
    mapping(uint256 => mapping(uint256 => uint256)) public athletePoints; // leagueId => athleteId => weekly points

    uint256 public totalLeagues;
    address public treasury;
    uint256 public platformFeePercent = 1000; // 10% of prize pool

    event LeagueCreated(uint256 indexed leagueId, string name, SportType sport, uint256 entryFee);
    event TeamJoined(uint256 indexed leagueId, uint256 indexed teamId, address indexed owner);
    event AthleteAdded(uint256 indexed teamId, uint256 indexed athleteId);
    event AthleteDropped(uint256 indexed teamId, uint256 indexed athleteId);
    event WeekCompleted(uint256 indexed leagueId, uint256 week);
    event LeagueCompleted(uint256 indexed leagueId, uint256 winnerId, uint256 prize);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMMISSIONER_ROLE, msg.sender);
    }

    /// @notice Create a new fantasy league
    function createLeague(
        string memory name,
        SportType sport,
        uint256 entryFee,
        uint256 maxTeams,
        uint256 rosterSize,
        uint256 seasonStart,
        uint256 seasonEnd,
        bool isPublic
    ) external payable returns (uint256) {
        require(seasonStart > block.timestamp, "Start must be future");
        require(seasonEnd > seasonStart, "End must be after start");
        require(maxTeams >= 2 && maxTeams <= 32, "Invalid team count");
        require(rosterSize >= 1 && rosterSize <= 10, "Invalid roster size");

        uint256 leagueId = ++_leagueIdCounter;

        leagues[leagueId] = League({
            leagueId: leagueId,
            name: name,
            sport: sport,
            entryFee: entryFee,
            prizePool: msg.value,
            maxTeams: maxTeams,
            rosterSize: rosterSize,
            seasonStart: seasonStart,
            seasonEnd: seasonEnd,
            status: LeagueStatus.Draft,
            commissioner: msg.sender,
            weekNumber: 0,
            isPublic: isPublic
        });

        totalLeagues++;
        emit LeagueCreated(leagueId, name, sport, entryFee);
        return leagueId;
    }

    /// @notice Join a league and create a team
    function joinLeague(uint256 leagueId, string memory teamName) external payable nonReentrant returns (uint256) {
        League storage league = leagues[leagueId];
        require(league.status == LeagueStatus.Draft, "League not in draft");
        require(league.isPublic || hasRole(COMMISSIONER_ROLE, msg.sender), "Private league");
        require(leagueTeams[leagueId].length < league.maxTeams, "League full");
        require(msg.value >= league.entryFee, "Insufficient entry fee");

        league.prizePool += msg.value;

        uint256 teamId = ++_teamIdCounter;
        teams[teamId] = FantasyTeam({
            teamId: teamId,
            leagueId: leagueId,
            owner: msg.sender,
            teamName: teamName,
            rosterAthleteIds: new uint256[](0),
            totalPoints: 0,
            weeklyPoints: 0,
            wins: 0,
            losses: 0,
            rank: 0,
            isActive: true
        });

        leagueTeams[leagueId].push(teamId);
        userTeams[msg.sender].push(teamId);

        emit TeamJoined(leagueId, teamId, msg.sender);
        return teamId;
    }

    /// @notice Draft an athlete onto your fantasy team
    function draftAthlete(uint256 teamId, uint256 athleteId) external {
        FantasyTeam storage team = teams[teamId];
        require(team.owner == msg.sender, "Not team owner");
        require(team.rosterAthleteIds.length < leagues[team.leagueId].rosterSize, "Roster full");

        // Check athlete not already on another team in this league
        require(!_isAthleteInLeague(team.leagueId, athleteId), "Athlete already drafted");

        team.rosterAthleteIds.push(athleteId);
        emit AthleteAdded(teamId, athleteId);
    }

    /// @notice Drop an athlete from your roster
    function dropAthlete(uint256 teamId, uint256 athleteId) external {
        FantasyTeam storage team = teams[teamId];
        require(team.owner == msg.sender, "Not team owner");

        uint256[] storage roster = team.rosterAthleteIds;
        for (uint256 i = 0; i < roster.length; i++) {
            if (roster[i] == athleteId) {
                roster[i] = roster[roster.length - 1];
                roster.pop();
                emit AthleteDropped(teamId, athleteId);
                return;
            }
        }
        revert("Athlete not on roster");
    }

    /// @notice Record weekly athlete points (called by commissioner/oracle)
    function recordAthletePoints(
        uint256 leagueId,
        uint256 athleteId,
        uint256 points
    ) external onlyRole(COMMISSIONER_ROLE) {
        athletePoints[leagueId][athleteId] = points;
    }

    /// @notice Process weekly results
    function processWeek(uint256 leagueId) external onlyRole(COMMISSIONER_ROLE) {
        League storage league = leagues[leagueId];
        require(league.status == LeagueStatus.Active, "League not active");

        league.weekNumber++;
        uint256[] memory teamIds = leagueTeams[leagueId];

        // Calculate weekly points for each team
        for (uint256 i = 0; i < teamIds.length; i++) {
            FantasyTeam storage team = teams[teamIds[i]];
            uint256 weekPoints = 0;

            for (uint256 j = 0; j < team.rosterAthleteIds.length; j++) {
                weekPoints += athletePoints[leagueId][team.rosterAthleteIds[j]];
            }

            team.weeklyPoints = weekPoints;
            team.totalPoints += weekPoints;
        }

        // Head-to-head matchups (simplified: pair teams)
        for (uint256 i = 0; i + 1 < teamIds.length; i += 2) {
            FantasyTeam storage t1 = teams[teamIds[i]];
            FantasyTeam storage t2 = teams[teamIds[i + 1]];

            bool t1Won = t1.weeklyPoints >= t2.weeklyPoints;
            if (t1Won) { t1.wins++; t2.losses++; } else { t2.wins++; t1.losses++; }

            teamHistory[teamIds[i]].push(WeeklyResult(league.weekNumber, teamIds[i], teamIds[i+1], t1.weeklyPoints, t2.weeklyPoints, t1Won));
            teamHistory[teamIds[i+1]].push(WeeklyResult(league.weekNumber, teamIds[i+1], teamIds[i], t2.weeklyPoints, t1.weeklyPoints, !t1Won));
        }

        emit WeekCompleted(leagueId, league.weekNumber);
    }

    /// @notice Start the league season
    function startLeague(uint256 leagueId) external onlyRole(COMMISSIONER_ROLE) {
        require(leagues[leagueId].status == LeagueStatus.Draft, "Not in draft");
        require(leagueTeams[leagueId].length >= 2, "Not enough teams");
        leagues[leagueId].status = LeagueStatus.Active;
    }

    /// @notice Complete league and award prize
    function completeLeague(uint256 leagueId, uint256 winningTeamId) external onlyRole(COMMISSIONER_ROLE) nonReentrant {
        League storage league = leagues[leagueId];
        require(league.status == LeagueStatus.Active, "Not active");

        league.status = LeagueStatus.Completed;

        uint256 fee = (league.prizePool * platformFeePercent) / 10000;
        uint256 prize = league.prizePool - fee;

        payable(treasury).transfer(fee);
        payable(teams[winningTeamId].owner).transfer(prize);

        emit LeagueCompleted(leagueId, winningTeamId, prize);
    }

    function _isAthleteInLeague(uint256 leagueId, uint256 athleteId) internal view returns (bool) {
        uint256[] memory teamIds = leagueTeams[leagueId];
        for (uint256 i = 0; i < teamIds.length; i++) {
            uint256[] memory roster = teams[teamIds[i]].rosterAthleteIds;
            for (uint256 j = 0; j < roster.length; j++) {
                if (roster[j] == athleteId) return true;
            }
        }
        return false;
    }

    // View
    function getLeagueTeams(uint256 leagueId) external view returns (uint256[] memory) {
        return leagueTeams[leagueId];
    }

    function getTeamRoster(uint256 teamId) external view returns (uint256[] memory) {
        return teams[teamId].rosterAthleteIds;
    }

    function getTeamHistory(uint256 teamId) external view returns (WeeklyResult[] memory) {
        return teamHistory[teamId];
    }

    function getUserTeams(address user) external view returns (uint256[] memory) {
        return userTeams[user];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
