// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title TrustScoring - On-chain trustworthiness tracker (Layer 6, Phase 6.4)
contract TrustScoring is AccessControl {
    bytes32 public constant SCORER_ROLE = keccak256("SCORER_ROLE");

    struct TrustProfile {
        uint256 overallScore;
        uint256 tradeScore;
        uint256 creatorScore;
        uint256 communityScore;
        uint256 athleteScore;
        uint256 totalTransactions;
        uint256 successfulTransactions;
        uint256 disputes;
        uint256 disputesLost;
        uint256 endorsementsReceived;
        uint256 lastUpdated;
        uint256 accountAge;
        bool    isBlacklisted;
        string  trustLevel;
    }

    struct TrustEvent {
        uint256  eventId;
        address  subject;
        int256   scoreDelta;
        string   category;
        string   reason;
        uint256  timestamp;
        address  reporter;
    }

    uint256 private _eventCounter;
    mapping(address => TrustProfile) public profiles;
    mapping(uint256 => TrustEvent)   public events;
    mapping(address => uint256[])    public userEvents;
    mapping(address => bool)         public hasProfile;

    uint256 public totalProfiles;

    event ProfileCreated(address indexed user, uint256 initialScore);
    event ScoreUpdated(address indexed user, int256 delta, string category);
    event UserBlacklisted(address indexed user, string reason);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SCORER_ROLE,        msg.sender);
    }

    function createProfile(address user) external onlyRole(SCORER_ROLE) {
        require(!hasProfile[user], "Already exists");
        profiles[user] = TrustProfile({
            overallScore:           500,
            tradeScore:             500,
            creatorScore:           500,
            communityScore:         500,
            athleteScore:           500,
            totalTransactions:      0,
            successfulTransactions: 0,
            disputes:               0,
            disputesLost:           0,
            endorsementsReceived:   0,
            lastUpdated:            block.timestamp,
            accountAge:             block.timestamp,
            isBlacklisted:          false,
            trustLevel:             "Neutral"
        });
        hasProfile[user] = true;
        totalProfiles++;
        emit ProfileCreated(user, 500);
    }

    function updateScore(address user, int256 delta, string memory category, string memory reason) external onlyRole(SCORER_ROLE) {
        require(hasProfile[user], "No profile");
        TrustProfile storage p = profiles[user];

        uint256 eventId = ++_eventCounter;
        events[eventId] = TrustEvent({
            eventId:   eventId,
            subject:   user,
            scoreDelta: delta,
            category:  category,
            reason:    reason,
            timestamp: block.timestamp,
            reporter:  msg.sender
        });
        userEvents[user].push(eventId);

        if (delta > 0) {
            uint256 increase = uint256(delta);
            p.overallScore = p.overallScore + increase > 1000 ? 1000 : p.overallScore + increase;
        } else {
            uint256 decrease = uint256(-delta);
            p.overallScore = p.overallScore > decrease ? p.overallScore - decrease : 0;
        }

        p.lastUpdated = block.timestamp;
        _updateCategoryScore(p, category, delta);
        _updateTrustLevel(p);
        emit ScoreUpdated(user, delta, category);
    }

    function recordTransaction(address user, bool success, bool hadDispute, bool disputeLost) external onlyRole(SCORER_ROLE) {
        TrustProfile storage p = profiles[user];
        p.totalTransactions++;
        if (success) {
            p.successfulTransactions++;
            p.overallScore = p.overallScore < 1000 ? p.overallScore + 2 : 1000;
        } else {
            p.overallScore = p.overallScore > 5 ? p.overallScore - 5 : 0;
        }
        if (hadDispute) {
            p.disputes++;
            if (disputeLost) {
                p.disputesLost++;
                p.overallScore = p.overallScore > 20 ? p.overallScore - 20 : 0;
            }
        }
        _updateTrustLevel(p);
    }

    function blacklist(address user, string memory reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        profiles[user].isBlacklisted = true;
        profiles[user].overallScore  = 0;
        emit UserBlacklisted(user, reason);
    }

    function _updateCategoryScore(TrustProfile storage p, string memory category, int256 delta) internal {
        bytes32 cat = keccak256(bytes(category));
        if (cat == keccak256("trade")) {
            p.tradeScore = _applyDelta(p.tradeScore, delta);
        } else if (cat == keccak256("creator")) {
            p.creatorScore = _applyDelta(p.creatorScore, delta);
        } else if (cat == keccak256("community")) {
            p.communityScore = _applyDelta(p.communityScore, delta);
        } else if (cat == keccak256("athlete")) {
            p.athleteScore = _applyDelta(p.athleteScore, delta);
        }
    }

    function _applyDelta(uint256 current, int256 delta) internal pure returns (uint256) {
        if (delta > 0) {
            uint256 result = current + uint256(delta);
            return result > 1000 ? 1000 : result;
        } else {
            uint256 decrease = uint256(-delta);
            return current > decrease ? current - decrease : 0;
        }
    }

    function _updateTrustLevel(TrustProfile storage p) internal {
        if      (p.overallScore >= 900) p.trustLevel = "Legendary";
        else if (p.overallScore >= 750) p.trustLevel = "Trusted";
        else if (p.overallScore >= 600) p.trustLevel = "Reliable";
        else if (p.overallScore >= 400) p.trustLevel = "Neutral";
        else if (p.overallScore >= 200) p.trustLevel = "Cautious";
        else                            p.trustLevel = "Risky";
    }

    function getTrustScore(address user)  external view returns (uint256)        { return profiles[user].overallScore; }
    function getTrustLevel(address user)  external view returns (string memory)  { return profiles[user].trustLevel; }
    function getUserEvents(address user)  external view returns (uint256[] memory) { return userEvents[user]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
