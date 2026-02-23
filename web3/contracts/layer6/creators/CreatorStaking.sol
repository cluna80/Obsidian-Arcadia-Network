// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CreatorStaking - Stake ETH to signal quality and earn rewards (Layer 6, Phase 6.3)
contract CreatorStaking is AccessControl, ReentrancyGuard {
    bytes32 public constant SLASH_ROLE = keccak256("SLASH_ROLE");

    enum StakeTier { None, Bronze, Silver, Gold, Diamond }

    struct Stake {
        uint256   amount;
        uint256   stakedAt;
        uint256   lockUntil;
        StakeTier tier;
        uint256   rewardsEarned;
        uint256   lastRewardAt;
        uint256   slashCount;
        bool      isActive;
    }

    mapping(address => Stake)     public stakes;
    mapping(StakeTier => uint256) public tierMinStake;
    mapping(StakeTier => uint256) public tierRewardMultiplier; // bps multiplier on base rate
    mapping(StakeTier => uint256) public tierLockDuration;
    address[] public stakers;
    mapping(address => bool) public isStaker;

    address public treasury;
    uint256 public totalStaked;
    uint256 public rewardRateBps = 100;   // 1 % annual base, scaled by tier

    event Staked(address indexed creator, uint256 amount, StakeTier tier);
    event Unstaked(address indexed creator, uint256 amount);
    event RewardClaimed(address indexed creator, uint256 amount);
    event Slashed(address indexed creator, uint256 amount, string reason);
    event RewardPoolFunded(uint256 amount);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SLASH_ROLE,         msg.sender);

        tierMinStake[StakeTier.Bronze]  = 0.01 ether;
        tierMinStake[StakeTier.Silver]  = 0.1 ether;
        tierMinStake[StakeTier.Gold]    = 1 ether;
        tierMinStake[StakeTier.Diamond] = 10 ether;

        tierRewardMultiplier[StakeTier.Bronze]  = 100;
        tierRewardMultiplier[StakeTier.Silver]  = 150;
        tierRewardMultiplier[StakeTier.Gold]    = 200;
        tierRewardMultiplier[StakeTier.Diamond] = 300;

        tierLockDuration[StakeTier.Bronze]  = 7 days;
        tierLockDuration[StakeTier.Silver]  = 30 days;
        tierLockDuration[StakeTier.Gold]    = 90 days;
        tierLockDuration[StakeTier.Diamond] = 180 days;
    }

    function stake(StakeTier tier) external payable nonReentrant {
        require(tier != StakeTier.None, "Invalid tier");
        require(msg.value >= tierMinStake[tier], "Insufficient stake");

        if (!isStaker[msg.sender]) { stakers.push(msg.sender); isStaker[msg.sender] = true; }

        Stake storage s = stakes[msg.sender];
        if (s.isActive) {
            uint256 pending = _calculateReward(msg.sender);
            s.rewardsEarned += pending;
        }
        s.amount       += msg.value;
        s.stakedAt      = block.timestamp;
        s.lastRewardAt  = block.timestamp;
        s.lockUntil     = block.timestamp + tierLockDuration[tier];
        s.tier          = tier;
        s.isActive      = true;
        totalStaked    += msg.value;

        emit Staked(msg.sender, msg.value, tier);
    }

    function unstake() external nonReentrant {
        Stake storage s = stakes[msg.sender];
        require(s.isActive,                    "Not staking");
        require(block.timestamp >= s.lockUntil, "Still locked");

        uint256 pending = _calculateReward(msg.sender);
        uint256 total   = s.amount + s.rewardsEarned + pending;
        totalStaked    -= s.amount;

        s.isActive      = false;
        s.amount        = 0;
        s.rewardsEarned = 0;

        payable(msg.sender).transfer(total);
        emit Unstaked(msg.sender, total);
    }

    function claimRewards() external nonReentrant {
        Stake storage s = stakes[msg.sender];
        require(s.isActive, "Not staking");

        uint256 reward = _calculateReward(msg.sender) + s.rewardsEarned;
        require(reward > 0, "No rewards");

        s.rewardsEarned = 0;
        s.lastRewardAt  = block.timestamp;

        payable(msg.sender).transfer(reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function slash(address creator, uint256 bps, string memory reason) external onlyRole(SLASH_ROLE) nonReentrant {
        Stake storage s = stakes[creator];
        require(s.isActive && bps <= 5000, "Invalid");

        uint256 slashAmount = (s.amount * bps) / 10000;
        s.amount     -= slashAmount;
        s.slashCount++;
        totalStaked  -= slashAmount;

        payable(treasury).transfer(slashAmount);
        emit Slashed(creator, slashAmount, reason);
    }

    function fundRewardPool() external payable { emit RewardPoolFunded(msg.value); }

    function getStakeTier(address creator) external view returns (StakeTier) {
        return stakes[creator].isActive ? stakes[creator].tier : StakeTier.None;
    }

    function getPendingReward(address creator) external view returns (uint256) {
        return _calculateReward(creator) + stakes[creator].rewardsEarned;
    }

    function _calculateReward(address creator) internal view returns (uint256) {
        Stake memory s = stakes[creator];
        if (!s.isActive) return 0;
        uint256 elapsed    = block.timestamp - s.lastRewardAt;
        uint256 multiplier = tierRewardMultiplier[s.tier];
        return (s.amount * rewardRateBps * multiplier * elapsed) / (10000 * 100 * 365 days);
    }

    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
