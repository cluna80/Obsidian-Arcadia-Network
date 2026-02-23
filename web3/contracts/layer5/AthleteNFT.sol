// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @title AthleteNFT - AI-powered athletes (Layer 5, Phase 5.2)
contract AthleteNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TRAINER_ROLE = keccak256("TRAINER_ROLE");
    uint256 private _tokenIdCounter;
    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }
    enum AthleteStatus { Active, Retired, Injured, Suspended, Training }
    enum WeightClass { Strawweight, Flyweight, Bantamweight, Featherweight, Lightweight, Welterweight, Middleweight, Heavyweight }
    struct AthleteStats { uint256 strength; uint256 speed; uint256 endurance; uint256 technique; uint256 intelligence; uint256 charisma; uint256 defense; uint256 aggression; }
    struct Athlete {
        uint256 athleteId; uint256 entityId; string name; string nickname;
        SportType primarySport; WeightClass weightClass; AthleteStats stats;
        AthleteStatus status; uint256 totalFights; uint256 wins; uint256 losses;
        uint256 draws; uint256 knockouts; uint256 careerEarnings; uint256 retirementAge;
        uint256 createdAt; uint256 lastTrainedAt; bool isActive;
    }
    struct TrainingSession { uint256 timestamp; string statImproved; uint256 improvement; uint256 cost; }
    mapping(uint256 => Athlete) public athletes;
    mapping(uint256 => TrainingSession[]) public trainingHistory;
    mapping(uint256 => uint256[]) public matchHistory;
    mapping(uint256 => bool) public entityLinked;
    mapping(address => uint256[]) public ownerAthletes;
    uint256 public mintPrice = 0.05 ether; uint256 public trainingCost = 0.001 ether;
    address public treasury; uint256 public protocolFeePercent = 250; uint256 public totalAthletes;
    event AthleteMinted(uint256 indexed athleteId, address indexed owner, string name, SportType sport);
    event AthleteStatImproved(uint256 indexed athleteId, string stat, uint256 oldValue, uint256 newValue);
    event AthleteRetired(uint256 indexed athleteId, uint256 totalFights, uint256 careerEarnings);
    event MatchRecorded(uint256 indexed athleteId, uint256 indexed matchId, bool won);
    constructor(address _treasury) ERC721("OAN Athlete", "OANATH") { treasury = _treasury; _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); _grantRole(MINTER_ROLE, msg.sender); _grantRole(TRAINER_ROLE, msg.sender); }
    function mintAthlete(uint256 entityId, string memory name, string memory nickname, SportType primarySport, WeightClass weightClass, AthleteStats memory initialStats, uint256 careerLengthDays, string memory tokenURI_) external payable nonReentrant returns (uint256) {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(!entityLinked[entityId], "Entity already linked");
        require(bytes(name).length > 0, "Name required");
        uint256 tokenId = ++_tokenIdCounter;
        athletes[tokenId] = Athlete({ athleteId: tokenId, entityId: entityId, name: name, nickname: nickname, primarySport: primarySport, weightClass: weightClass, stats: initialStats, status: AthleteStatus.Active, totalFights: 0, wins: 0, losses: 0, draws: 0, knockouts: 0, careerEarnings: 0, retirementAge: block.timestamp + (careerLengthDays * 1 days), createdAt: block.timestamp, lastTrainedAt: block.timestamp, isActive: true });
        entityLinked[entityId] = true; ownerAthletes[msg.sender].push(tokenId); totalAthletes++;
        _safeMint(msg.sender, tokenId); _setTokenURI(tokenId, tokenURI_);
        payable(treasury).transfer((msg.value * protocolFeePercent) / 10000);
        emit AthleteMinted(tokenId, msg.sender, name, primarySport);
        return tokenId;
    }
    function trainAthlete(uint256 athleteId, uint8 statIndex) external payable nonReentrant {
        require(ownerOf(athleteId) == msg.sender && msg.value >= trainingCost, "Invalid");
        Athlete storage a = athletes[athleteId];
        require(a.isActive && block.timestamp >= a.lastTrainedAt + 1 hours, "Cannot train");
        AthleteStats storage s = a.stats;
        uint256 imp = (block.timestamp % 3) + 1;
        string memory statName; uint256 old; uint256 nw;
        if (statIndex == 0) { old = s.strength; s.strength = _min(s.strength + imp, 100); nw = s.strength; statName = "strength"; }
        else if (statIndex == 1) { old = s.speed; s.speed = _min(s.speed + imp, 100); nw = s.speed; statName = "speed"; }
        else if (statIndex == 2) { old = s.endurance; s.endurance = _min(s.endurance + imp, 100); nw = s.endurance; statName = "endurance"; }
        else if (statIndex == 3) { old = s.technique; s.technique = _min(s.technique + imp, 100); nw = s.technique; statName = "technique"; }
        else { old = s.charisma; s.charisma = _min(s.charisma + imp, 100); nw = s.charisma; statName = "charisma"; }
        a.lastTrainedAt = block.timestamp;
        trainingHistory[athleteId].push(TrainingSession(block.timestamp, statName, nw - old, msg.value));
        payable(treasury).transfer(msg.value);
        emit AthleteStatImproved(athleteId, statName, old, nw);
    }
    function recordMatchResult(uint256 athleteId, uint256 matchId, bool won, bool knockout, uint256 earnings) external onlyRole(TRAINER_ROLE) {
        Athlete storage a = athletes[athleteId]; a.totalFights++; matchHistory[athleteId].push(matchId);
        if (won) { a.wins++; if (knockout) a.knockouts++; } else a.losses++;
        a.careerEarnings += earnings;
        emit MatchRecorded(athleteId, matchId, won);
    }
    function retireAthlete(uint256 athleteId) external {
        require(ownerOf(athleteId) == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        athletes[athleteId].isActive = false; athletes[athleteId].status = AthleteStatus.Retired;
        emit AthleteRetired(athleteId, athletes[athleteId].totalFights, athletes[athleteId].careerEarnings);
    }
    function getAthleteStats(uint256 athleteId) external view returns (AthleteStats memory) { return athletes[athleteId].stats; }
    function getMatchHistory(uint256 athleteId) external view returns (uint256[] memory) { return matchHistory[athleteId]; }
    function getOwnerAthletes(address owner) external view returns (uint256[] memory) { return ownerAthletes[owner]; }
    function getOverallRating(uint256 athleteId) external view returns (uint256) { AthleteStats memory s = athletes[athleteId].stats; return (s.strength + s.speed + s.endurance + s.technique + s.intelligence + s.charisma + s.defense + s.aggression) / 8; }
    function _min(uint256 a, uint256 b) internal pure returns (uint256) { return a < b ? a : b; }
    function setMintPrice(uint256 p) external onlyRole(DEFAULT_ADMIN_ROLE) { mintPrice = p; }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) { return super.tokenURI(tokenId); }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) { return super.supportsInterface(interfaceId); }
}
