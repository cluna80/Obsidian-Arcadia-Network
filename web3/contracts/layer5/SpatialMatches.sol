// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SpatialMatches - Sports matches in 3D metaverse space
/// @notice Layer 5, Phase 5.5
contract SpatialMatches is AccessControl {
    bytes32 public constant SPATIAL_MANAGER = keccak256("SPATIAL_MANAGER");

    struct SpatialZone {
        uint256 zoneId;
        string name;
        int256 minX; int256 maxX;
        int256 minY; int256 maxY;
        int256 minZ; int256 maxZ;
        uint256 venueId;
        bool isMatchActive;
        uint256 activeMatchId;
        uint256 maxCapacity;
        uint256 currentOccupancy;
    }

    struct SpatialMatch {
        uint256 spatialMatchId;
        uint256 matchId;           // Link to MatchSimulator
        uint256 zoneId;
        uint256 startTime;
        uint256 endTime;
        uint256 spectatorCount;
        bool isLive;
        string physicsConfigURI;   // Link to physics simulation config
        string replayDataURI;      // Match replay spatial data
    }

    mapping(uint256 => SpatialZone) public zones;
    mapping(uint256 => SpatialMatch) public spatialMatches;
    mapping(uint256 => uint256[]) public venueZones;
    mapping(uint256 => uint256[]) public matchSpatialData;

    uint256 private _zoneIdCounter;
    uint256 private _spatialMatchIdCounter;

    event ZoneCreated(uint256 indexed zoneId, string name, uint256 venueId);
    event SpatialMatchStarted(uint256 indexed spatialMatchId, uint256 matchId, uint256 zoneId);
    event SpatialMatchEnded(uint256 indexed spatialMatchId, uint256 spectators);
    event SpectatorEntered(uint256 indexed zoneId, address spectator);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SPATIAL_MANAGER, msg.sender);
    }

    function createZone(
        string memory name,
        int256 minX, int256 maxX,
        int256 minY, int256 maxY,
        int256 minZ, int256 maxZ,
        uint256 venueId,
        uint256 maxCapacity
    ) external onlyRole(SPATIAL_MANAGER) returns (uint256) {
        uint256 zoneId = ++_zoneIdCounter;
        zones[zoneId] = SpatialZone(zoneId, name, minX, maxX, minY, maxY, minZ, maxZ, venueId, false, 0, maxCapacity, 0);
        venueZones[venueId].push(zoneId);
        emit ZoneCreated(zoneId, name, venueId);
        return zoneId;
    }

    function startSpatialMatch(
        uint256 matchId,
        uint256 zoneId,
        string memory physicsConfigURI
    ) external onlyRole(SPATIAL_MANAGER) returns (uint256) {
        require(!zones[zoneId].isMatchActive, "Zone already has active match");

        uint256 spatialMatchId = ++_spatialMatchIdCounter;
        spatialMatches[spatialMatchId] = SpatialMatch(
            spatialMatchId, matchId, zoneId, block.timestamp, 0, 0, true, physicsConfigURI, ""
        );

        zones[zoneId].isMatchActive = true;
        zones[zoneId].activeMatchId = spatialMatchId;

        emit SpatialMatchStarted(spatialMatchId, matchId, zoneId);
        return spatialMatchId;
    }

    function endSpatialMatch(uint256 spatialMatchId, string memory replayURI) external onlyRole(SPATIAL_MANAGER) {
        SpatialMatch storage sm = spatialMatches[spatialMatchId];
        require(sm.isLive, "Not live");
        sm.isLive = false;
        sm.endTime = block.timestamp;
        sm.replayDataURI = replayURI;
        zones[sm.zoneId].isMatchActive = false;
        emit SpatialMatchEnded(spatialMatchId, sm.spectatorCount);
    }

    function enterZone(uint256 zoneId) external {
        SpatialZone storage zone = zones[zoneId];
        require(zone.currentOccupancy < zone.maxCapacity, "Zone at capacity");
        zone.currentOccupancy++;
        if (zone.isMatchActive) {
            spatialMatches[zone.activeMatchId].spectatorCount++;
        }
        emit SpectatorEntered(zoneId, msg.sender);
    }

    function getVenueZones(uint256 venueId) external view returns (uint256[] memory) {
        return venueZones[venueId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// ============================================================
