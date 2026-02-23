// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @title VenueRegistry - Catalog of all arenas/venues (Layer 5, Phase 5.1)
contract VenueRegistry is AccessControl, ReentrancyGuard {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    enum VenueType { Stadium, Arena, GrassField, RaceTrack, GymRing, VirtualDome, Colosseum }
    enum VenueStatus { Active, Maintenance, Closed, Banned }
    struct Venue {
        uint256 venueId; uint256 stadiumNFTId; string name; string description;
        VenueType venueType; VenueStatus status; address owner; uint256 registeredAt;
        uint256 totalEventsHosted; uint256 averageRating; uint256 totalRatings;
        bool isVerified; string metadataURI; string[] tags;
    }
    struct VenueRating { address rater; uint256 rating; string comment; uint256 timestamp; }
    uint256 private _venueIdCounter;
    mapping(uint256 => Venue) public venues;
    mapping(uint256 => VenueRating[]) public venueRatings;
    mapping(uint256 => bool) public stadiumRegistered;
    mapping(address => uint256[]) public ownerVenues;
    mapping(string => uint256[]) public venuesByTag;
    mapping(VenueType => uint256[]) public venuesByType;
    mapping(address => mapping(uint256 => bool)) public hasRated;
    uint256 public totalVenues; uint256 public verifiedVenues;
    event VenueRegistered(uint256 indexed venueId, uint256 indexed stadiumNFTId, address indexed owner, string name);
    event VenueStatusChanged(uint256 indexed venueId, VenueStatus oldStatus, VenueStatus newStatus);
    event VenueVerified(uint256 indexed venueId);
    event VenueRated(uint256 indexed venueId, address indexed rater, uint256 rating);
    constructor() { _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); _grantRole(REGISTRAR_ROLE, msg.sender); }
    function registerVenue(uint256 stadiumNFTId, string memory name, string memory description, VenueType venueType, string memory metadataURI, string[] memory tags) external returns (uint256) {
        require(!stadiumRegistered[stadiumNFTId], "Already registered");
        uint256 venueId = ++_venueIdCounter;
        venues[venueId] = Venue(venueId, stadiumNFTId, name, description, venueType, VenueStatus.Active, msg.sender, block.timestamp, 0, 0, 0, false, metadataURI, tags);
        stadiumRegistered[stadiumNFTId] = true;
        ownerVenues[msg.sender].push(venueId);
        venuesByType[venueType].push(venueId);
        for (uint256 i = 0; i < tags.length; i++) venuesByTag[tags[i]].push(venueId);
        totalVenues++;
        emit VenueRegistered(venueId, stadiumNFTId, msg.sender, name);
        return venueId;
    }
    function rateVenue(uint256 venueId, uint256 rating, string memory comment) external {
        require(venues[venueId].venueId != 0, "Not found"); require(rating >= 1 && rating <= 5, "Rating 1-5");
        require(!hasRated[msg.sender][venueId], "Already rated"); require(venues[venueId].owner != msg.sender, "No self-rating");
        hasRated[msg.sender][venueId] = true;
        venueRatings[venueId].push(VenueRating(msg.sender, rating, comment, block.timestamp));
        Venue storage v = venues[venueId]; v.totalRatings++;
        v.averageRating = ((v.averageRating * (v.totalRatings - 1)) + (rating * 100)) / v.totalRatings;
        emit VenueRated(venueId, msg.sender, rating);
    }
    function setVenueStatus(uint256 venueId, VenueStatus status) external {
        require(venues[venueId].owner == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        VenueStatus old = venues[venueId].status; venues[venueId].status = status;
        emit VenueStatusChanged(venueId, old, status);
    }
    function verifyVenue(uint256 venueId) external onlyRole(DEFAULT_ADMIN_ROLE) { require(!venues[venueId].isVerified, "Already verified"); venues[venueId].isVerified = true; verifiedVenues++; emit VenueVerified(venueId); }
    function recordEvent(uint256 venueId) external onlyRole(REGISTRAR_ROLE) { venues[venueId].totalEventsHosted++; }
    function getVenuesByOwner(address owner) external view returns (uint256[] memory) { return ownerVenues[owner]; }
    function getVenuesByType(VenueType t) external view returns (uint256[] memory) { return venuesByType[t]; }
    function getVenueRatings(uint256 venueId) external view returns (VenueRating[] memory) { return venueRatings[venueId]; }
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) { return super.supportsInterface(interfaceId); }
}
