// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TrainingGrounds - Practice spaces for athletes in the metaverse
/// @notice Layer 5, Phase 5.5
contract TrainingGrounds is AccessControl, ReentrancyGuard {
    bytes32 public constant TRAINER_ROLE = keccak256("TRAINER_ROLE");

    enum TrainingType { Sparring, Strength, Cardio, Technique, Mental, Recovery }

    struct TrainingGround {
        uint256 groundId;
        string name;
        uint256 venueId;
        TrainingType trainingType;
        uint256 maxConcurrentAthletes;
        uint256 currentAthletes;
        uint256 hourlyFee;         // In wei
        bool isPublic;
        address owner;
        uint256 totalSessions;
    }

    struct TrainingSession {
        uint256 sessionId;
        uint256 groundId;
        uint256 athleteId;
        uint256 startTime;
        uint256 endTime;
        TrainingType trainingType;
        uint256 statGained;        // Encoded stat improvement
        bool completed;
    }

    struct SparringRequest {
        uint256 challenger;
        uint256 opponent;
        uint256 groundId;
        uint256 requestTime;
        bool accepted;
        bool completed;
    }

    uint256 private _groundIdCounter;
    uint256 private _sessionIdCounter;

    mapping(uint256 => TrainingGround) public grounds;
    mapping(uint256 => TrainingSession[]) public athleteSessions;
    mapping(uint256 => uint256[]) public venueGrounds;
    mapping(uint256 => SparringRequest[]) public sparringRequests;
    mapping(uint256 => bool) public athleteInTraining;

    address public treasury;
    uint256 public platformFeePercent = 250;

    event GroundCreated(uint256 indexed groundId, string name, TrainingType trainingType);
    event TrainingStarted(uint256 indexed sessionId, uint256 indexed athleteId, uint256 groundId);
    event TrainingCompleted(uint256 indexed sessionId, uint256 indexed athleteId);
    event SparringRequested(uint256 indexed groundId, uint256 challenger, uint256 opponent);
    event SparringAccepted(uint256 indexed groundId, uint256 challenger, uint256 opponent);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TRAINER_ROLE, msg.sender);
    }

    function createTrainingGround(
        string memory name,
        uint256 venueId,
        TrainingType trainingType,
        uint256 maxConcurrent,
        uint256 hourlyFee,
        bool isPublic
    ) external returns (uint256) {
        uint256 groundId = ++_groundIdCounter;
        grounds[groundId] = TrainingGround(groundId, name, venueId, trainingType, maxConcurrent, 0, hourlyFee, isPublic, msg.sender, 0);
        venueGrounds[venueId].push(groundId);
        emit GroundCreated(groundId, name, trainingType);
        return groundId;
    }

    function startTraining(uint256 groundId, uint256 athleteId, uint256 durationHours) external payable nonReentrant {
        TrainingGround storage ground = grounds[groundId];
        require(ground.currentAthletes < ground.maxConcurrentAthletes, "Ground full");
        require(!athleteInTraining[athleteId], "Already training");
        require(msg.value >= ground.hourlyFee * durationHours, "Insufficient fee");

        ground.currentAthletes++;
        ground.totalSessions++;
        athleteInTraining[athleteId] = true;

        uint256 sessionId = ++_sessionIdCounter;
        athleteSessions[athleteId].push(TrainingSession({
            sessionId: sessionId,
            groundId: groundId,
            athleteId: athleteId,
            startTime: block.timestamp,
            endTime: block.timestamp + (durationHours * 1 hours),
            trainingType: ground.trainingType,
            statGained: 0,
            completed: false
        }));

        uint256 fee = (msg.value * platformFeePercent) / 10000;
        payable(treasury).transfer(fee);
        payable(ground.owner).transfer(msg.value - fee);

        emit TrainingStarted(sessionId, athleteId, groundId);
    }

    function completeTraining(uint256 athleteId, uint256 sessionIndex) external onlyRole(TRAINER_ROLE) {
        TrainingSession storage session = athleteSessions[athleteId][sessionIndex];
        require(!session.completed, "Already completed");
        require(block.timestamp >= session.endTime, "Training not done yet");

        session.completed = true;
        athleteInTraining[athleteId] = false;
        grounds[session.groundId].currentAthletes--;

        emit TrainingCompleted(session.sessionId, athleteId);
    }

    function requestSparring(uint256 groundId, uint256 challengerAthleteId, uint256 opponentAthleteId) external {
        sparringRequests[groundId].push(SparringRequest(challengerAthleteId, opponentAthleteId, groundId, block.timestamp, false, false));
        emit SparringRequested(groundId, challengerAthleteId, opponentAthleteId);
    }

    function acceptSparring(uint256 groundId, uint256 requestIndex) external {
        SparringRequest storage req = sparringRequests[groundId][requestIndex];
        req.accepted = true;
        emit SparringAccepted(groundId, req.challenger, req.opponent);
    }

    function getVenueGrounds(uint256 venueId) external view returns (uint256[] memory) {
        return venueGrounds[venueId];
    }

    function getAthleteSessions(uint256 athleteId) external view returns (TrainingSession[] memory) {
        return athleteSessions[athleteId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
