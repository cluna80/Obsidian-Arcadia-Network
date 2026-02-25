// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BehaviorValidator
/// @notice Validate and flag entity behavior patterns across OAN layers
contract BehaviorValidator is AccessControl, ReentrancyGuard {

    bytes32 public constant REPORTER_ROLE  = keccak256("REPORTER_ROLE");
    bytes32 public constant ANALYST_ROLE   = keccak256("ANALYST_ROLE");

    enum BehaviorStatus { Clean, Flagged, Suspended, Banned }
    enum ViolationType  { Spam, Fraud, Manipulation, Sybil, Harassment, Exploit, RateAbuse, Custom }
    enum Severity       { Low, Medium, High, Critical }

    struct BehaviorReport {
        uint256       id;
        address       subject;
        ViolationType violationType;
        Severity      severity;
        bytes32       evidenceHash;
        uint256       reportedAt;
        address       reporter;
        bool          confirmed;
        string        description;
    }

    struct BehaviorProfile {
        BehaviorStatus status;
        uint256        totalReports;
        uint256        confirmedViolations;
        uint256        riskScore;          // 0-1000, higher = riskier
        uint256        lastViolationAt;
        uint256        suspendedUntil;
        bool           active;
    }

    struct RateLimit {
        uint256 actionCount;
        uint256 windowStart;
        uint256 maxPerWindow;
        uint256 windowDuration;
    }

    uint256 public reportCounter;
    uint256 public constant MAX_RISK_SCORE   = 1000;
    uint256 public constant AUTO_FLAG_SCORE  = 500;
    uint256 public constant AUTO_BAN_SCORE   = 900;

    mapping(uint256 => BehaviorReport)          public reports;
    mapping(address => BehaviorProfile)         public profiles;
    mapping(address => uint256[])               public subjectReports;
    mapping(address => RateLimit)               public rateLimits;
    mapping(ViolationType => uint256)           public violationWeights;  // score impact per type

    event BehaviorReported(uint256 indexed reportId, address indexed subject, ViolationType violationType, Severity severity);
    event ViolationConfirmed(uint256 indexed reportId, address indexed subject, uint256 newRiskScore);
    event SubjectFlagged(address indexed subject, uint256 riskScore);
    event SubjectSuspended(address indexed subject, uint256 until);
    event SubjectBanned(address indexed subject);
    event SubjectCleared(address indexed subject);
    event RateLimitBreached(address indexed subject, uint256 actionCount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REPORTER_ROLE,      msg.sender);
        _grantRole(ANALYST_ROLE,       msg.sender);

        // Set default violation weights
        violationWeights[ViolationType.Spam]         = 50;
        violationWeights[ViolationType.Fraud]        = 300;
        violationWeights[ViolationType.Manipulation] = 200;
        violationWeights[ViolationType.Sybil]        = 250;
        violationWeights[ViolationType.Harassment]   = 150;
        violationWeights[ViolationType.Exploit]      = 400;
        violationWeights[ViolationType.RateAbuse]    = 100;
        violationWeights[ViolationType.Custom]       = 100;
    }

    /// @notice Report a behavior violation
    function reportBehavior(
        address subject,
        ViolationType violationType,
        Severity severity,
        bytes32 evidenceHash,
        string calldata description
    ) external onlyRole(REPORTER_ROLE) returns (uint256 reportId) {
        reportCounter++;
        reportId = reportCounter;

        reports[reportId] = BehaviorReport({
            id:            reportId,
            subject:       subject,
            violationType: violationType,
            severity:      severity,
            evidenceHash:  evidenceHash,
            reportedAt:    block.timestamp,
            reporter:      msg.sender,
            confirmed:     false,
            description:   description
        });

        subjectReports[subject].push(reportId);

        BehaviorProfile storage profile = profiles[subject];
        if (!profile.active) profile.active = true;
        profile.totalReports++;

        emit BehaviorReported(reportId, subject, violationType, severity);
    }

    /// @notice Analyst confirms a report and applies risk score
    function confirmViolation(uint256 reportId) external onlyRole(ANALYST_ROLE) {
        BehaviorReport storage report = reports[reportId];
        require(!report.confirmed, "Already confirmed");

        report.confirmed = true;
        BehaviorProfile storage profile = profiles[report.subject];
        profile.confirmedViolations++;
        profile.lastViolationAt = block.timestamp;

        // Apply severity multiplier
        uint256 baseWeight = violationWeights[report.violationType];
        uint256 multiplier = uint256(report.severity) + 1; // Low=1x, Medium=2x, High=3x, Critical=4x
        uint256 impact     = baseWeight * multiplier;

        profile.riskScore = profile.riskScore + impact > MAX_RISK_SCORE
            ? MAX_RISK_SCORE
            : profile.riskScore + impact;

        emit ViolationConfirmed(reportId, report.subject, profile.riskScore);
        _applyStatusFromScore(report.subject);
    }

    function _applyStatusFromScore(address subject) internal {
        BehaviorProfile storage profile = profiles[subject];

        if (profile.riskScore >= AUTO_BAN_SCORE) {
            profile.status = BehaviorStatus.Banned;
            emit SubjectBanned(subject);
        } else if (profile.riskScore >= AUTO_FLAG_SCORE) {
            if (profile.status == BehaviorStatus.Clean) {
                profile.status = BehaviorStatus.Flagged;
                emit SubjectFlagged(subject, profile.riskScore);
            }
        }
    }

    /// @notice Manually suspend a subject for a duration
    function suspendSubject(address subject, uint256 duration) external onlyRole(ANALYST_ROLE) {
        BehaviorProfile storage profile = profiles[subject];
        profile.status         = BehaviorStatus.Suspended;
        profile.suspendedUntil = block.timestamp + duration;
        emit SubjectSuspended(subject, profile.suspendedUntil);
    }

    /// @notice Clear a subject's status after review
    function clearSubject(address subject, uint256 scoreReduction) external onlyRole(DEFAULT_ADMIN_ROLE) {
        BehaviorProfile storage profile = profiles[subject];
        profile.riskScore = profile.riskScore > scoreReduction
            ? profile.riskScore - scoreReduction
            : 0;
        profile.status    = BehaviorStatus.Clean;
        emit SubjectCleared(subject);
    }

    /// @notice Check and record rate-limited actions
    function checkRateLimit(address subject) external onlyRole(REPORTER_ROLE) returns (bool allowed) {
        RateLimit storage rl = rateLimits[subject];

        if (rl.windowDuration == 0) {
            // No rate limit configured
            return true;
        }

        if (block.timestamp > rl.windowStart + rl.windowDuration) {
            rl.actionCount  = 0;
            rl.windowStart  = block.timestamp;
        }

        rl.actionCount++;

        if (rl.actionCount > rl.maxPerWindow) {
            emit RateLimitBreached(subject, rl.actionCount);
            return false;
        }
        return true;
    }

    /// @notice Configure rate limit for a subject
    function setRateLimit(address subject, uint256 maxPerWindow, uint256 windowDuration)
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        rateLimits[subject] = RateLimit({
            actionCount:    0,
            windowStart:    block.timestamp,
            maxPerWindow:   maxPerWindow,
            windowDuration: windowDuration
        });
    }

    /// @notice Update violation weight for a type
    function setViolationWeight(ViolationType vType, uint256 weight)
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(weight <= MAX_RISK_SCORE, "Weight too high");
        violationWeights[vType] = weight;
    }

    /// @notice Check if a subject is currently allowed to act
    function isAllowed(address subject) external view returns (bool) {
        BehaviorProfile storage profile = profiles[subject];
        if (profile.status == BehaviorStatus.Banned) return false;
        if (profile.status == BehaviorStatus.Suspended) {
            return block.timestamp > profile.suspendedUntil;
        }
        return true;
    }

    /// @notice Get all report IDs for a subject
    function getSubjectReports(address subject) external view returns (uint256[] memory) {
        return subjectReports[subject];
    }
}
