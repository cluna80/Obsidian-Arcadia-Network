// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SportsBridge - Bridge to real-world sports data
/// @notice Layer 5, Phase 5.6
contract SportsBridge is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    enum DataSource { ManualOracle, ChainlinkFeed, APIConsumer, CommunityVote }

    struct RealWorldEvent {
        uint256 eventId;
        string eventName;
        string sport;
        uint256 timestamp;
        string result;             // JSON-encoded result
        DataSource source;
        address reporter;
        uint256 confirmations;
        bool isVerified;
        uint256 linkedOANMatchId; // Corresponding OAN match if any
    }

    struct OracleReport {
        address oracle;
        uint256 eventId;
        string data;
        uint256 timestamp;
        bool disputed;
    }

    struct AthleteRealWorldLink {
        uint256 oanAthleteId;
        string realWorldName;
        string realWorldSport;
        string externalId;        // ID in external sports database
        bool isVerified;
        uint256 linkedAt;
    }

    uint256 private _eventIdCounter;

    mapping(uint256 => RealWorldEvent) public realWorldEvents;
    mapping(uint256 => OracleReport[]) public oracleReports;
    mapping(uint256 => AthleteRealWorldLink) public athleteLinks;
    mapping(string => uint256) public externalIdToOAN;  // external ID => OAN athlete ID
    mapping(uint256 => uint256[]) public matchRealWorldEvents; // oanMatchId => eventIds

    uint256 public minConfirmations = 3;
    uint256 public totalEvents;
    uint256 public totalLinkedAthletes;

    event RealWorldEventRecorded(uint256 indexed eventId, string eventName, string sport);
    event EventVerified(uint256 indexed eventId);
    event AthleteLinked(uint256 indexed oanAthleteId, string realWorldName);
    event OracleReportSubmitted(uint256 indexed eventId, address oracle);
    event DataDisputed(uint256 indexed eventId, address disputer);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
    }

    function recordRealWorldEvent(
        string memory eventName,
        string memory sport,
        string memory result,
        DataSource source,
        uint256 linkedOANMatchId
    ) external onlyRole(ORACLE_ROLE) returns (uint256) {
        uint256 eventId = ++_eventIdCounter;

        realWorldEvents[eventId] = RealWorldEvent({
            eventId: eventId,
            eventName: eventName,
            sport: sport,
            timestamp: block.timestamp,
            result: result,
            source: source,
            reporter: msg.sender,
            confirmations: 1,
            isVerified: false,
            linkedOANMatchId: linkedOANMatchId
        });

        if (linkedOANMatchId != 0) {
            matchRealWorldEvents[linkedOANMatchId].push(eventId);
        }

        totalEvents++;
        emit RealWorldEventRecorded(eventId, eventName, sport);
        return eventId;
    }

    function confirmEvent(uint256 eventId, string memory data) external onlyRole(ORACLE_ROLE) {
        RealWorldEvent storage evt = realWorldEvents[eventId];
        require(!evt.isVerified, "Already verified");

        oracleReports[eventId].push(OracleReport({
            oracle: msg.sender,
            eventId: eventId,
            data: data,
            timestamp: block.timestamp,
            disputed: false
        }));

        evt.confirmations++;

        if (evt.confirmations >= minConfirmations) {
            evt.isVerified = true;
            emit EventVerified(eventId);
        }

        emit OracleReportSubmitted(eventId, msg.sender);
    }

    function disputeEvent(uint256 eventId) external onlyRole(ORACLE_ROLE) {
        OracleReport[] storage reports = oracleReports[eventId];
        if (reports.length > 0) {
            reports[reports.length - 1].disputed = true;
        }
        emit DataDisputed(eventId, msg.sender);
    }

    function linkRealWorldAthlete(
        uint256 oanAthleteId,
        string memory realWorldName,
        string memory realWorldSport,
        string memory externalId
    ) external onlyRole(ORACLE_ROLE) {
        athleteLinks[oanAthleteId] = AthleteRealWorldLink({
            oanAthleteId: oanAthleteId,
            realWorldName: realWorldName,
            realWorldSport: realWorldSport,
            externalId: externalId,
            isVerified: false,
            linkedAt: block.timestamp
        });

        externalIdToOAN[externalId] = oanAthleteId;
        totalLinkedAthletes++;

        emit AthleteLinked(oanAthleteId, realWorldName);
    }

    function verifyAthleteLink(uint256 oanAthleteId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        athleteLinks[oanAthleteId].isVerified = true;
    }

    function getOracleReports(uint256 eventId) external view returns (OracleReport[] memory) {
        return oracleReports[eventId];
    }

    function getMatchEvents(uint256 oanMatchId) external view returns (uint256[] memory) {
        return matchRealWorldEvents[oanMatchId];
    }

    function getAthleteByExternalId(string memory externalId) external view returns (uint256) {
        return externalIdToOAN[externalId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
