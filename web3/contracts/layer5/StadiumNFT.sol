// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @title StadiumNFT - Sports venues as NFTs (Layer 5, Phase 5.1)
contract StadiumNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 private _tokenIdCounter;
    enum SportType { Boxing, MMA, Racing, Soccer, Basketball, Esports, Tennis, Wrestling }
    enum StadiumTier { Community, Regional, National, Global, Legendary }
    struct Stadium {
        uint256 stadiumId; string name; string location; uint256 capacity;
        SportType[] supportedSports; StadiumTier tier; uint256 totalEvents;
        uint256 totalRevenue; uint256 hostingFeePercent; address owner; bool isActive; uint256 createdAt;
    }
    struct EventRecord {
        uint256 eventId; uint256 stadiumId; string eventName;
        uint256 timestamp; uint256 revenue; uint256 attendees;
    }
    mapping(uint256 => Stadium) public stadiums;
    mapping(uint256 => EventRecord[]) public stadiumEvents;
    mapping(uint256 => mapping(address => bool)) public authorizedHosts;
    uint256 public mintPrice = 0.1 ether;
    uint256 public maxCapacity = 100000;
    uint256 public totalStadiums;
    address public treasury;
    uint256 public protocolFeePercent = 250;
    event StadiumMinted(uint256 indexed stadiumId, address indexed owner, string name, StadiumTier tier);
    event EventHosted(uint256 indexed stadiumId, uint256 indexed eventId, string eventName, uint256 revenue);
    event StadiumUpgraded(uint256 indexed stadiumId, StadiumTier oldTier, StadiumTier newTier);
    event HostAuthorized(uint256 indexed stadiumId, address indexed host);
    event RevenueWithdrawn(uint256 indexed stadiumId, address indexed owner, uint256 amount);
    constructor(address _treasury) ERC721("OAN Stadium", "OANSTD") {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }
    function mintStadium(string memory name, string memory location, uint256 capacity, SportType[] memory supportedSports, StadiumTier tier, uint256 hostingFeePercent, string memory tokenURI_) external payable nonReentrant returns (uint256) {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(capacity > 0 && capacity <= maxCapacity, "Invalid capacity");
        require(hostingFeePercent <= 3000, "Fee too high");
        require(supportedSports.length > 0, "Need at least one sport");
        uint256 tokenId = ++_tokenIdCounter;
        stadiums[tokenId] = Stadium({ stadiumId: tokenId, name: name, location: location, capacity: capacity, supportedSports: supportedSports, tier: tier, totalEvents: 0, totalRevenue: 0, hostingFeePercent: hostingFeePercent, owner: msg.sender, isActive: true, createdAt: block.timestamp });
        totalStadiums++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        payable(treasury).transfer((msg.value * protocolFeePercent) / 10000);
        emit StadiumMinted(tokenId, msg.sender, name, tier);
        return tokenId;
    }
    function recordEvent(uint256 stadiumId, string memory eventName, uint256 attendees) external payable nonReentrant returns (uint256) {
        Stadium storage s = stadiums[stadiumId];
        require(s.isActive, "Not active");
        require(msg.sender == ownerOf(stadiumId) || authorizedHosts[stadiumId][msg.sender], "Not authorized");
        require(attendees <= s.capacity, "Over capacity");
        uint256 stadiumFee = (msg.value * s.hostingFeePercent) / 10000;
        s.totalEvents++; s.totalRevenue += stadiumFee;
        uint256 eventId = stadiumEvents[stadiumId].length;
        stadiumEvents[stadiumId].push(EventRecord({ eventId: eventId, stadiumId: stadiumId, eventName: eventName, timestamp: block.timestamp, revenue: msg.value, attendees: attendees }));
        payable(treasury).transfer((msg.value * protocolFeePercent) / 10000);
        emit EventHosted(stadiumId, eventId, eventName, msg.value);
        return eventId;
    }
    function authorizeHost(uint256 stadiumId, address host) external { require(ownerOf(stadiumId) == msg.sender, "Not owner"); authorizedHosts[stadiumId][host] = true; emit HostAuthorized(stadiumId, host); }
    function upgradeStadium(uint256 stadiumId) external payable {
        require(ownerOf(stadiumId) == msg.sender, "Not owner");
        Stadium storage s = stadiums[stadiumId];
        require(uint8(s.tier) < uint8(StadiumTier.Legendary), "Max tier");
        require(msg.value >= mintPrice * (uint256(s.tier) + 2), "Insufficient payment");
        StadiumTier old = s.tier;
        s.tier = StadiumTier(uint8(s.tier) + 1);
        s.capacity = (s.capacity * 150) / 100;
        payable(treasury).transfer(msg.value);
        emit StadiumUpgraded(stadiumId, old, s.tier);
    }
    function withdrawRevenue(uint256 stadiumId) external nonReentrant {
        require(ownerOf(stadiumId) == msg.sender, "Not owner");
        uint256 amount = stadiums[stadiumId].totalRevenue;
        require(amount > 0, "No revenue");
        stadiums[stadiumId].totalRevenue = 0;
        payable(msg.sender).transfer(amount);
        emit RevenueWithdrawn(stadiumId, msg.sender, amount);
    }
    function getSupportedSports(uint256 stadiumId) external view returns (SportType[] memory) { return stadiums[stadiumId].supportedSports; }
    function getEventHistory(uint256 stadiumId) external view returns (EventRecord[] memory) { return stadiumEvents[stadiumId]; }
    function setMintPrice(uint256 p) external onlyRole(DEFAULT_ADMIN_ROLE) { mintPrice = p; }
    function setTreasury(address t) external onlyRole(DEFAULT_ADMIN_ROLE) { treasury = t; }
    function setProtocolFee(uint256 f) external onlyRole(DEFAULT_ADMIN_ROLE) { require(f <= 1000, "Max 10%"); protocolFeePercent = f; }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) { return super.tokenURI(tokenId); }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) { return super.supportsInterface(interfaceId); }
}
