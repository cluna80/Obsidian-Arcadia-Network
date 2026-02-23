// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FanRewards - Loyalty and rewards program for OAN sports fans
/// @notice Layer 5, Phase 5.4 - OAN Metaverse Sports Arena
contract FanRewards is AccessControl, ReentrancyGuard {
    bytes32 public constant REWARDS_MANAGER = keccak256("REWARDS_MANAGER");

    enum RewardType { Points, Badge, NFTDrop, TokenAirdrop, ExclusiveAccess }

    struct FanProfile {
        address fan;
        uint256 totalPoints;
        uint256 spentPoints;
        uint256 eventsAttended;
        uint256 betsPlaced;
        uint256 cardsOwned;
        uint256 consecutiveDays;   // Streak
        uint256 lastActivity;
        uint256 loyaltyTier;       // 0=Bronze, 1=Silver, 2=Gold, 3=Platinum, 4=Diamond
        bool isRegistered;
    }

    struct Reward {
        uint256 rewardId;
        string name;
        string description;
        RewardType rewardType;
        uint256 pointCost;
        uint256 maxRedemptions;
        uint256 totalRedeemed;
        bool isActive;
        uint256 expiresAt;
    }

    struct Redemption {
        uint256 rewardId;
        uint256 timestamp;
        uint256 pointsSpent;
    }

    // Loyalty tier thresholds (in points)
    uint256[5] public tierThresholds = [0, 1000, 5000, 20000, 100000];
    string[5] public tierNames = ["Bronze", "Silver", "Gold", "Platinum", "Diamond"];

    uint256 private _rewardIdCounter;

    mapping(address => FanProfile) public fanProfiles;
    mapping(uint256 => Reward) public rewards;
    mapping(address => Redemption[]) public redemptions;
    mapping(address => mapping(uint256 => bool)) public hasBadge;  // fan => badgeId => earned
    mapping(uint256 => uint256) public athleteFanCount;            // athleteId => fan count

    address[] public registeredFans;
    uint256 public totalFans;
    uint256 public totalPointsIssued;
    address public treasury;

    // Point multipliers per activity
    uint256 public eventAttendancePoints = 100;
    uint256 public betPlacedPoints = 10;
    uint256 public cardPurchasePoints = 50;
    uint256 public dailyLoginPoints = 5;
    uint256 public referralPoints = 200;

    event FanRegistered(address indexed fan);
    event PointsEarned(address indexed fan, uint256 amount, string activity);
    event PointsSpent(address indexed fan, uint256 amount, uint256 rewardId);
    event TierUpgraded(address indexed fan, uint256 oldTier, uint256 newTier);
    event RewardCreated(uint256 indexed rewardId, string name, uint256 pointCost);
    event RewardRedeemed(uint256 indexed rewardId, address indexed fan);
    event BadgeEarned(address indexed fan, uint256 badgeId, string name);
    event StreakUpdated(address indexed fan, uint256 streak);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARDS_MANAGER, msg.sender);
    }

    /// @notice Register as a fan
    function registerFan() external {
        require(!fanProfiles[msg.sender].isRegistered, "Already registered");

        fanProfiles[msg.sender] = FanProfile({
            fan: msg.sender,
            totalPoints: 100,          // Welcome bonus
            spentPoints: 0,
            eventsAttended: 0,
            betsPlaced: 0,
            cardsOwned: 0,
            consecutiveDays: 1,
            lastActivity: block.timestamp,
            loyaltyTier: 0,
            isRegistered: true
        });

        registeredFans.push(msg.sender);
        totalFans++;
        totalPointsIssued += 100;

        emit FanRegistered(msg.sender);
        emit PointsEarned(msg.sender, 100, "welcome_bonus");
    }

    /// @notice Record event attendance and award points
    function recordEventAttendance(address fan, uint256 eventId) external onlyRole(REWARDS_MANAGER) {
        _requireRegistered(fan);
        FanProfile storage profile = fanProfiles[fan];

        profile.eventsAttended++;
        _awardPoints(fan, eventAttendancePoints, "event_attendance");
        _updateStreak(fan);

        // Milestone badges
        if (profile.eventsAttended == 10) _awardBadge(fan, 1, "Event Regular");
        if (profile.eventsAttended == 100) _awardBadge(fan, 2, "Stadium Legend");
    }

    /// @notice Record a bet placed
    function recordBetPlaced(address fan, uint256 betAmount) external onlyRole(REWARDS_MANAGER) {
        _requireRegistered(fan);
        fanProfiles[fan].betsPlaced++;

        uint256 bonusPoints = betPlacedPoints + (betAmount / 0.01 ether); // +1 per 0.01 ETH bet
        _awardPoints(fan, bonusPoints, "bet_placed");

        if (fanProfiles[fan].betsPlaced == 50) _awardBadge(fan, 3, "Prediction Master");
    }

    /// @notice Record card purchase
    function recordCardPurchase(address fan, uint256 cardRarity) external onlyRole(REWARDS_MANAGER) {
        _requireRegistered(fan);
        fanProfiles[fan].cardsOwned++;

        uint256 multiplier = 1 + cardRarity; // Higher rarity = more points
        _awardPoints(fan, cardPurchasePoints * multiplier, "card_purchase");

        if (fanProfiles[fan].cardsOwned == 50) _awardBadge(fan, 4, "Card Collector");
    }

    /// @notice Record daily login
    function recordDailyLogin(address fan) external onlyRole(REWARDS_MANAGER) {
        _requireRegistered(fan);
        _updateStreak(fan);
        _awardPoints(fan, dailyLoginPoints, "daily_login");
    }

    /// @notice Create a reward
    function createReward(
        string memory name,
        string memory description,
        RewardType rewardType,
        uint256 pointCost,
        uint256 maxRedemptions,
        uint256 duration
    ) external onlyRole(REWARDS_MANAGER) returns (uint256) {
        uint256 rewardId = ++_rewardIdCounter;

        rewards[rewardId] = Reward({
            rewardId: rewardId,
            name: name,
            description: description,
            rewardType: rewardType,
            pointCost: pointCost,
            maxRedemptions: maxRedemptions,
            totalRedeemed: 0,
            isActive: true,
            expiresAt: block.timestamp + duration
        });

        emit RewardCreated(rewardId, name, pointCost);
        return rewardId;
    }

    /// @notice Redeem a reward using points
    function redeemReward(uint256 rewardId) external nonReentrant {
        _requireRegistered(msg.sender);

        Reward storage reward = rewards[rewardId];
        require(reward.isActive, "Reward not active");
        require(block.timestamp <= reward.expiresAt, "Reward expired");
        require(reward.totalRedeemed < reward.maxRedemptions, "Reward sold out");

        FanProfile storage profile = fanProfiles[msg.sender];
        uint256 availablePoints = profile.totalPoints - profile.spentPoints;
        require(availablePoints >= reward.pointCost, "Insufficient points");

        profile.spentPoints += reward.pointCost;
        reward.totalRedeemed++;

        redemptions[msg.sender].push(Redemption({
            rewardId: rewardId,
            timestamp: block.timestamp,
            pointsSpent: reward.pointCost
        }));

        emit PointsSpent(msg.sender, reward.pointCost, rewardId);
        emit RewardRedeemed(rewardId, msg.sender);
    }

    function _awardPoints(address fan, uint256 amount, string memory activity) internal {
        FanProfile storage profile = fanProfiles[fan];
        uint256 multiplier = _getTierMultiplier(profile.loyaltyTier);
        uint256 bonusAmount = (amount * multiplier) / 100;

        profile.totalPoints += bonusAmount;
        totalPointsIssued += bonusAmount;

        _checkTierUpgrade(fan);
        emit PointsEarned(fan, bonusAmount, activity);
    }

    function _awardBadge(address fan, uint256 badgeId, string memory name) internal {
        if (!hasBadge[fan][badgeId]) {
            hasBadge[fan][badgeId] = true;
            _awardPoints(fan, 500, "badge_earned");
            emit BadgeEarned(fan, badgeId, name);
        }
    }

    function _updateStreak(address fan) internal {
        FanProfile storage profile = fanProfiles[fan];
        uint256 daysSinceActivity = (block.timestamp - profile.lastActivity) / 1 days;

        if (daysSinceActivity <= 1) {
            profile.consecutiveDays++;
        } else {
            profile.consecutiveDays = 1;
        }

        profile.lastActivity = block.timestamp;

        // Streak bonuses
        if (profile.consecutiveDays == 7) _awardPoints(fan, 500, "week_streak");
        if (profile.consecutiveDays == 30) _awardPoints(fan, 3000, "month_streak");

        emit StreakUpdated(fan, profile.consecutiveDays);
    }

    function _checkTierUpgrade(address fan) internal {
        FanProfile storage profile = fanProfiles[fan];
        uint256 currentTier = profile.loyaltyTier;

        for (uint256 i = 4; i > currentTier; i--) {
            if (profile.totalPoints >= tierThresholds[i]) {
                profile.loyaltyTier = i;
                emit TierUpgraded(fan, currentTier, i);
                break;
            }
        }
    }

    function _getTierMultiplier(uint256 tier) internal pure returns (uint256) {
        // Bronze=100%, Silver=110%, Gold=125%, Platinum=150%, Diamond=200%
        uint256[5] memory multipliers = [uint256(100), 110, 125, 150, 200];
        return multipliers[tier];
    }

    function _requireRegistered(address fan) internal view {
        require(fanProfiles[fan].isRegistered, "Fan not registered");
    }

    // View
    function getAvailablePoints(address fan) external view returns (uint256) {
        FanProfile memory p = fanProfiles[fan];
        return p.totalPoints - p.spentPoints;
    }

    function getTierName(address fan) external view returns (string memory) {
        return tierNames[fanProfiles[fan].loyaltyTier];
    }

    function getRedemptions(address fan) external view returns (Redemption[] memory) {
        return redemptions[fan];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
