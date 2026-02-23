// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TeamNFT - Sports teams and guilds in OAN metaverse
/// @notice Layer 5, Phase 5.2 - OAN Metaverse Sports Arena
contract TeamNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _tokenIdCounter;

    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }
    enum TeamStatus { Active, Disbanded, Suspended }

    struct Team {
        uint256 teamId;
        string name;
        string symbol;             // Short team code (e.g., "NYC")
        SportType primarySport;
        address owner;
        address manager;           // Can be different from owner
        uint256[] rosterAthleteIds;
        uint256 maxRosterSize;
        uint256 wins;
        uint256 losses;
        uint256 totalEarnings;
        TeamStatus status;
        uint256 foundedAt;
        uint256 fanTokenId;        // Link to FanTokens contract
        string homeStadiumLocation;
        bool isPublic;             // Can others request to join?
    }

    struct TeamApplication {
        uint256 athleteId;
        address applicant;
        uint256 timestamp;
        bool accepted;
        bool rejected;
    }

    mapping(uint256 => Team) public teams;
    mapping(uint256 => TeamApplication[]) public teamApplications;
    mapping(uint256 => mapping(uint256 => bool)) public isTeamMember; // teamId => athleteId => bool
    mapping(uint256 => uint256) public athleteTeam;   // athleteId => teamId (current team)
    mapping(address => uint256[]) public ownerTeams;
    mapping(string => bool) public teamNameTaken;
    mapping(string => bool) public teamSymbolTaken;

    uint256 public mintPrice = 0.1 ether;
    uint256 public maxRosterDefault = 10;
    address public treasury;
    uint256 public protocolFeePercent = 250;
    uint256 public totalTeams;

    event TeamCreated(uint256 indexed teamId, address indexed owner, string name, SportType sport);
    event AthleteJoined(uint256 indexed teamId, uint256 indexed athleteId);
    event AthleteLeft(uint256 indexed teamId, uint256 indexed athleteId);
    event TeamWin(uint256 indexed teamId, uint256 indexed matchId);
    event ManagerUpdated(uint256 indexed teamId, address newManager);
    event ApplicationSubmitted(uint256 indexed teamId, uint256 indexed athleteId);

    constructor(address _treasury) ERC721("OAN Team", "OANTEAM") {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /// @notice Create a new team
    function createTeam(
        string memory name,
        string memory symbol,
        SportType primarySport,
        uint256 maxRosterSize,
        bool isPublic,
        string memory homeStadium,
        string memory tokenURI_
    ) external payable nonReentrant returns (uint256) {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(!teamNameTaken[name], "Team name taken");
        require(!teamSymbolTaken[symbol], "Team symbol taken");
        require(maxRosterSize >= 1 && maxRosterSize <= 50, "Invalid roster size");

        uint256 tokenId = ++_tokenIdCounter;

        teams[tokenId] = Team({
            teamId: tokenId,
            name: name,
            symbol: symbol,
            primarySport: primarySport,
            owner: msg.sender,
            manager: msg.sender,
            rosterAthleteIds: new uint256[](0),
            maxRosterSize: maxRosterSize,
            wins: 0,
            losses: 0,
            totalEarnings: 0,
            status: TeamStatus.Active,
            foundedAt: block.timestamp,
            fanTokenId: 0,
            homeStadiumLocation: homeStadium,
            isPublic: isPublic
        });

        teamNameTaken[name] = true;
        teamSymbolTaken[symbol] = true;
        ownerTeams[msg.sender].push(tokenId);
        totalTeams++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        uint256 fee = (msg.value * protocolFeePercent) / 10000;
        payable(treasury).transfer(fee);

        emit TeamCreated(tokenId, msg.sender, name, primarySport);
        return tokenId;
    }

    /// @notice Add athlete to team (owner/manager only)
    function addAthlete(uint256 teamId, uint256 athleteId) external {
        Team storage team = teams[teamId];
        require(msg.sender == team.owner || msg.sender == team.manager, "Not authorized");
        require(team.rosterAthleteIds.length < team.maxRosterSize, "Roster full");
        require(!isTeamMember[teamId][athleteId], "Already on team");
        require(team.status == TeamStatus.Active, "Team not active");

        team.rosterAthleteIds.push(athleteId);
        isTeamMember[teamId][athleteId] = true;
        athleteTeam[athleteId] = teamId;

        emit AthleteJoined(teamId, athleteId);
    }

    /// @notice Remove athlete from team
    function removeAthlete(uint256 teamId, uint256 athleteId) external {
        Team storage team = teams[teamId];
        require(msg.sender == team.owner || msg.sender == team.manager, "Not authorized");
        require(isTeamMember[teamId][athleteId], "Not on team");

        isTeamMember[teamId][athleteId] = false;
        athleteTeam[athleteId] = 0;

        // Remove from roster array
        uint256[] storage roster = team.rosterAthleteIds;
        for (uint256 i = 0; i < roster.length; i++) {
            if (roster[i] == athleteId) {
                roster[i] = roster[roster.length - 1];
                roster.pop();
                break;
            }
        }

        emit AthleteLeft(teamId, athleteId);
    }

    /// @notice Apply to join a public team
    function applyToTeam(uint256 teamId, uint256 athleteId) external {
        Team storage team = teams[teamId];
        require(team.isPublic, "Team is private");
        require(team.status == TeamStatus.Active, "Team not active");
        require(!isTeamMember[teamId][athleteId], "Already on team");

        teamApplications[teamId].push(TeamApplication({
            athleteId: athleteId,
            applicant: msg.sender,
            timestamp: block.timestamp,
            accepted: false,
            rejected: false
        }));

        emit ApplicationSubmitted(teamId, athleteId);
    }

    /// @notice Accept or reject a team application
    function processApplication(uint256 teamId, uint256 appIndex, bool accept) external {
        Team storage team = teams[teamId];
        require(msg.sender == team.owner || msg.sender == team.manager, "Not authorized");

        TeamApplication storage app = teamApplications[teamId][appIndex];
        require(!app.accepted && !app.rejected, "Already processed");

        if (accept) {
            app.accepted = true;
            require(team.rosterAthleteIds.length < team.maxRosterSize, "Roster full");
            team.rosterAthleteIds.push(app.athleteId);
            isTeamMember[teamId][app.athleteId] = true;
            athleteTeam[app.athleteId] = teamId;
            emit AthleteJoined(teamId, app.athleteId);
        } else {
            app.rejected = true;
        }
    }

    /// @notice Record a team match win (called by match contracts)
    function recordWin(uint256 teamId, uint256 matchId, uint256 earnings) external onlyRole(MINTER_ROLE) {
        teams[teamId].wins++;
        teams[teamId].totalEarnings += earnings;
        emit TeamWin(teamId, matchId);
    }

    /// @notice Record a team match loss
    function recordLoss(uint256 teamId) external onlyRole(MINTER_ROLE) {
        teams[teamId].losses++;
    }

    /// @notice Update team manager
    function setManager(uint256 teamId, address newManager) external {
        require(ownerOf(teamId) == msg.sender, "Not team owner");
        teams[teamId].manager = newManager;
        emit ManagerUpdated(teamId, newManager);
    }

    // View functions
    function getTeamRoster(uint256 teamId) external view returns (uint256[] memory) {
        return teams[teamId].rosterAthleteIds;
    }

    function getTeamApplications(uint256 teamId) external view returns (TeamApplication[] memory) {
        return teamApplications[teamId];
    }

    function getOwnerTeams(address owner) external view returns (uint256[] memory) {
        return ownerTeams[owner];
    }

    function getAthleteCurrentTeam(uint256 athleteId) external view returns (uint256) {
        return athleteTeam[athleteId];
    }

    // Admin
    function setMintPrice(uint256 newPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintPrice = newPrice;
    }

    // Required overrides
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
