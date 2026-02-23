// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title SpectatorMode - Watch matches with multiple camera angles
/// @notice Layer 5, Phase 5.5
contract SpectatorMode is AccessControl {
    bytes32 public constant BROADCAST_ROLE = keccak256("BROADCAST_ROLE");

    enum ViewAngle { Ringside, Corner, Overhead, FirstPerson, BroadcastCam, SlowMotion }

    struct SpectatorSession {
        address viewer;
        uint256 matchId;
        uint256 seatId;
        ViewAngle currentAngle;
        bool isVR;
        bool hasAudioFeed;
        uint256 joinedAt;
        uint256 rating;            // Post-match rating 1-5
        bool hasRated;
    }

    struct CameraFeed {
        uint256 feedId;
        uint256 matchId;
        ViewAngle angle;
        string feedURI;            // Stream URI for this angle
        bool isActive;
        uint256 viewerCount;
    }

    mapping(uint256 => mapping(address => SpectatorSession)) public sessions; // matchId => viewer => session
    mapping(uint256 => CameraFeed[]) public matchFeeds;       // matchId => feeds
    mapping(uint256 => address[]) public matchSpectators;
    mapping(uint256 => uint256) public matchAverageRating;
    mapping(uint256 => uint256) public matchTotalRatings;

    event SpectatorJoined(uint256 indexed matchId, address indexed viewer, ViewAngle angle);
    event AngleSwitched(uint256 indexed matchId, address indexed viewer, ViewAngle newAngle);
    event MatchRated(uint256 indexed matchId, address indexed viewer, uint256 rating);
    event FeedAdded(uint256 indexed matchId, uint256 feedId, ViewAngle angle);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BROADCAST_ROLE, msg.sender);
    }

    function addCameraFeed(uint256 matchId, ViewAngle angle, string memory feedURI) external onlyRole(BROADCAST_ROLE) {
        uint256 feedId = matchFeeds[matchId].length;
        matchFeeds[matchId].push(CameraFeed(feedId, matchId, angle, feedURI, true, 0));
        emit FeedAdded(matchId, feedId, angle);
    }

    function joinAsSpectator(uint256 matchId, uint256 seatId, ViewAngle preferredAngle, bool isVR) external {
        require(sessions[matchId][msg.sender].viewer == address(0), "Already watching");

        sessions[matchId][msg.sender] = SpectatorSession({
            viewer: msg.sender,
            matchId: matchId,
            seatId: seatId,
            currentAngle: preferredAngle,
            isVR: isVR,
            hasAudioFeed: true,
            joinedAt: block.timestamp,
            rating: 0,
            hasRated: false
        });

        matchSpectators[matchId].push(msg.sender);

        // Increment viewer count on chosen feed
        for (uint256 i = 0; i < matchFeeds[matchId].length; i++) {
            if (matchFeeds[matchId][i].angle == preferredAngle) {
                matchFeeds[matchId][i].viewerCount++;
                break;
            }
        }

        emit SpectatorJoined(matchId, msg.sender, preferredAngle);
    }

    function switchAngle(uint256 matchId, ViewAngle newAngle) external {
        require(sessions[matchId][msg.sender].viewer != address(0), "Not watching");
        sessions[matchId][msg.sender].currentAngle = newAngle;
        emit AngleSwitched(matchId, msg.sender, newAngle);
    }

    function rateMatch(uint256 matchId, uint256 rating) external {
        require(rating >= 1 && rating <= 5, "Rating 1-5");
        SpectatorSession storage session = sessions[matchId][msg.sender];
        require(session.viewer != address(0), "Did not watch");
        require(!session.hasRated, "Already rated");

        session.rating = rating;
        session.hasRated = true;

        uint256 total = matchTotalRatings[matchId];
        matchAverageRating[matchId] = ((matchAverageRating[matchId] * total) + (rating * 100)) / (total + 1);
        matchTotalRatings[matchId]++;

        emit MatchRated(matchId, msg.sender, rating);
    }

    function getMatchFeeds(uint256 matchId) external view returns (CameraFeed[] memory) {
        return matchFeeds[matchId];
    }

    function getMatchSpectators(uint256 matchId) external view returns (address[] memory) {
        return matchSpectators[matchId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// ============================================================
