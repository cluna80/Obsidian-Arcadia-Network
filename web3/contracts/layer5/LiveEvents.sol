// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LiveEvents - Real-time match streaming and ticketing
/// @notice Layer 5, Phase 5.3 - OAN Metaverse Sports Arena
contract LiveEvents is AccessControl, ReentrancyGuard {
    bytes32 public constant EVENT_OPERATOR_ROLE = keccak256("EVENT_OPERATOR_ROLE");

    enum EventStatus { Upcoming, Live, Paused, Ended, Cancelled }
    enum AccessTier { Free, Standard, Premium, VIP }

    struct LiveEvent {
        uint256 eventId;
        uint256 matchId;           // Link to MatchSimulator
        uint256 stadiumId;
        string title;
        string description;
        EventStatus status;
        uint256 startTime;
        uint256 endTime;
        uint256 maxViewers;
        uint256 currentViewers;
        uint256 peakViewers;
        uint256 totalRevenue;
        address organizer;
        bool hasReplay;
        string streamURI;          // IPFS or decentralized stream link
        string replayURI;
    }

    struct TicketTier {
        AccessTier tier;
        uint256 price;
        uint256 maxSupply;
        uint256 sold;
        bool isActive;
    }

    struct ViewerSession {
        address viewer;
        uint256 joinTime;
        uint256 leaveTime;
        AccessTier accessTier;
        bool isActive;
    }

    uint256 private _eventIdCounter;

    mapping(uint256 => LiveEvent) public events;
    mapping(uint256 => mapping(AccessTier => TicketTier)) public ticketTiers;
    mapping(uint256 => mapping(address => AccessTier)) public viewerAccess;  // eventId => viewer => tier
    mapping(uint256 => ViewerSession[]) public viewerSessions;
    mapping(address => uint256[]) public viewerEventHistory;
    mapping(uint256 => bool) public hasTicket;

    uint256 public totalEvents;
    address public treasury;
    uint256 public platformFeePercent = 500; // 5%

    event EventCreated(uint256 indexed eventId, uint256 indexed matchId, string title, uint256 startTime);
    event EventStarted(uint256 indexed eventId);
    event EventEnded(uint256 indexed eventId, uint256 peakViewers, uint256 revenue);
    event ViewerJoined(uint256 indexed eventId, address indexed viewer, AccessTier tier);
    event ViewerLeft(uint256 indexed eventId, address indexed viewer);
    event TicketPurchased(uint256 indexed eventId, address indexed buyer, AccessTier tier);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EVENT_OPERATOR_ROLE, msg.sender);
    }

    /// @notice Create a live event
    function createEvent(
        uint256 matchId,
        uint256 stadiumId,
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 maxViewers,
        string memory streamURI
    ) external returns (uint256) {
        require(startTime > block.timestamp, "Start must be future");

        uint256 eventId = ++_eventIdCounter;

        events[eventId] = LiveEvent({
            eventId: eventId,
            matchId: matchId,
            stadiumId: stadiumId,
            title: title,
            description: description,
            status: EventStatus.Upcoming,
            startTime: startTime,
            endTime: 0,
            maxViewers: maxViewers,
            currentViewers: 0,
            peakViewers: 0,
            totalRevenue: 0,
            organizer: msg.sender,
            hasReplay: false,
            streamURI: streamURI,
            replayURI: ""
        });

        // Default ticket tiers
        ticketTiers[eventId][AccessTier.Free] = TicketTier(AccessTier.Free, 0, 1000, 0, true);
        ticketTiers[eventId][AccessTier.Standard] = TicketTier(AccessTier.Standard, 0.001 ether, 5000, 0, true);
        ticketTiers[eventId][AccessTier.Premium] = TicketTier(AccessTier.Premium, 0.005 ether, 1000, 0, true);
        ticketTiers[eventId][AccessTier.VIP] = TicketTier(AccessTier.VIP, 0.02 ether, 100, 0, true);

        totalEvents++;
        emit EventCreated(eventId, matchId, title, startTime);
        return eventId;
    }

    /// @notice Set custom ticket pricing
    function setTicketTier(
        uint256 eventId,
        AccessTier tier,
        uint256 price,
        uint256 maxSupply
    ) external {
        require(events[eventId].organizer == msg.sender, "Not organizer");
        require(events[eventId].status == EventStatus.Upcoming, "Event already started");

        ticketTiers[eventId][tier] = TicketTier(tier, price, maxSupply, 0, true);
    }

    /// @notice Purchase a ticket to an event
    function purchaseTicket(uint256 eventId, AccessTier tier) external payable nonReentrant {
        LiveEvent storage evt = events[eventId];
        require(evt.status == EventStatus.Upcoming || evt.status == EventStatus.Live, "Event not available");
        require(viewerAccess[eventId][msg.sender] == AccessTier.Free, "Already has ticket");

        TicketTier storage ticket = ticketTiers[eventId][tier];
        require(ticket.isActive, "Tier not available");
        require(ticket.sold < ticket.maxSupply, "Sold out");
        require(msg.value >= ticket.price, "Insufficient payment");

        ticket.sold++;
        viewerAccess[eventId][msg.sender] = tier;
        evt.totalRevenue += ticket.price;
        viewerEventHistory[msg.sender].push(eventId);

        uint256 fee = (ticket.price * platformFeePercent) / 10000;
        if (fee > 0) payable(treasury).transfer(fee);
        uint256 organizer = ticket.price - fee;
        if (organizer > 0) payable(evt.organizer).transfer(organizer);

        emit TicketPurchased(eventId, msg.sender, tier);
    }

    /// @notice Start the live event
    function startEvent(uint256 eventId) external onlyRole(EVENT_OPERATOR_ROLE) {
        LiveEvent storage evt = events[eventId];
        require(evt.status == EventStatus.Upcoming, "Not upcoming");
        evt.status = EventStatus.Live;
        emit EventStarted(eventId);
    }

    /// @notice Record viewer joining
    function viewerJoin(uint256 eventId) external {
        LiveEvent storage evt = events[eventId];
        require(evt.status == EventStatus.Live, "Not live");
        require(evt.currentViewers < evt.maxViewers, "At capacity");

        evt.currentViewers++;
        if (evt.currentViewers > evt.peakViewers) {
            evt.peakViewers = evt.currentViewers;
        }

        AccessTier tier = viewerAccess[eventId][msg.sender];
        viewerSessions[eventId].push(ViewerSession({
            viewer: msg.sender,
            joinTime: block.timestamp,
            leaveTime: 0,
            accessTier: tier,
            isActive: true
        }));

        emit ViewerJoined(eventId, msg.sender, tier);
    }

    /// @notice Record viewer leaving
    function viewerLeave(uint256 eventId, uint256 sessionIndex) external {
        LiveEvent storage evt = events[eventId];
        ViewerSession storage session = viewerSessions[eventId][sessionIndex];
        require(session.viewer == msg.sender, "Not your session");
        require(session.isActive, "Session already ended");

        session.leaveTime = block.timestamp;
        session.isActive = false;
        if (evt.currentViewers > 0) evt.currentViewers--;

        emit ViewerLeft(eventId, msg.sender);
    }

    /// @notice End the event
    function endEvent(uint256 eventId, string memory replayURI) external onlyRole(EVENT_OPERATOR_ROLE) {
        LiveEvent storage evt = events[eventId];
        require(evt.status == EventStatus.Live || evt.status == EventStatus.Paused, "Not live");

        evt.status = EventStatus.Ended;
        evt.endTime = block.timestamp;
        evt.currentViewers = 0;

        if (bytes(replayURI).length > 0) {
            evt.hasReplay = true;
            evt.replayURI = replayURI;
        }

        emit EventEnded(eventId, evt.peakViewers, evt.totalRevenue);
    }

    // View
    function getViewerSessions(uint256 eventId) external view returns (ViewerSession[] memory) {
        return viewerSessions[eventId];
    }

    function canAccess(uint256 eventId, address viewer) external view returns (bool, AccessTier) {
        AccessTier tier = viewerAccess[eventId][viewer];
        return (true, tier); // Free tier always accessible
    }

    function getViewerHistory(address viewer) external view returns (uint256[] memory) {
        return viewerEventHistory[viewer];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
