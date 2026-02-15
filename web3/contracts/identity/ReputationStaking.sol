// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ReputationStaking
 * @dev Stake tokens to boost reputation and unlock features
 */
contract ReputationStaking is Ownable, ReentrancyGuard {
    
    struct Stake {
        uint256 amount;
        uint256 stakedAt;
        uint256 lockedUntil;
        int256 reputationBonus;
        bool active;
    }
    
    struct StakingTier {
        uint256 minStake;
        uint256 lockDuration;
        int256 reputationMultiplier;  // Basis points (100 = 1%)
        bool enabled;
    }
    
    mapping(address => Stake) public stakes;
    mapping(uint256 => StakingTier) public tiers;
    
    uint256 public totalStaked;
    uint256 public totalStakers;
    
    uint256 public constant BASIS_POINTS = 10000;
    
    event Staked(address indexed staker, uint256 amount, uint256 tier);
    event Unstaked(address indexed staker, uint256 amount);
    event ReputationBonusApplied(address indexed staker, int256 bonus);
    event TierConfigured(uint256 indexed tier, uint256 minStake, int256 multiplier);
    
    constructor() Ownable(msg.sender) {
        // Configure default tiers
        tiers[1] = StakingTier(1 ether, 30 days, 500, true);      // Bronze: 5% bonus
        tiers[2] = StakingTier(5 ether, 60 days, 1000, true);     // Silver: 10% bonus
        tiers[3] = StakingTier(10 ether, 90 days, 2000, true);    // Gold: 20% bonus
        tiers[4] = StakingTier(50 ether, 180 days, 5000, true);   // Platinum: 50% bonus
    }
    
    function configureTier(
        uint256 tier,
        uint256 minStake,
        uint256 lockDuration,
        int256 reputationMultiplier
    ) external onlyOwner {
        tiers[tier] = StakingTier({
            minStake: minStake,
            lockDuration: lockDuration,
            reputationMultiplier: reputationMultiplier,
            enabled: true
        });
        
        emit TierConfigured(tier, minStake, reputationMultiplier);
    }
    
    function stake(uint256 tier) external payable nonReentrant {
        require(tiers[tier].enabled, "Tier not enabled");
        require(msg.value >= tiers[tier].minStake, "Insufficient stake");
        require(!stakes[msg.sender].active, "Already staking");
        
        StakingTier memory tierConfig = tiers[tier];
        
        stakes[msg.sender] = Stake({
            amount: msg.value,
            stakedAt: block.timestamp,
            lockedUntil: block.timestamp + tierConfig.lockDuration,
            reputationBonus: int256(msg.value * uint256(tierConfig.reputationMultiplier) / BASIS_POINTS),
            active: true
        });
        
        totalStaked += msg.value;
        totalStakers++;
        
        emit Staked(msg.sender, msg.value, tier);
        emit ReputationBonusApplied(msg.sender, stakes[msg.sender].reputationBonus);
    }
    
    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.active, "No active stake");
        require(block.timestamp >= userStake.lockedUntil, "Stake still locked");
        
        uint256 amount = userStake.amount;
        
        userStake.active = false;
        userStake.reputationBonus = 0;
        
        totalStaked -= amount;
        totalStakers--;
        
        payable(msg.sender).transfer(amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    function getStake(address staker) external view returns (Stake memory) {
        return stakes[staker];
    }
    
    function getReputationBonus(address staker) external view returns (int256) {
        if (!stakes[staker].active) return 0;
        return stakes[staker].reputationBonus;
    }
    
    function isStakeLocked(address staker) external view returns (bool) {
        if (!stakes[staker].active) return false;
        return block.timestamp < stakes[staker].lockedUntil;
    }
    
    function getTierForAmount(uint256 amount) external view returns (uint256) {
        for (uint256 i = 4; i >= 1; i--) {
            if (tiers[i].enabled && amount >= tiers[i].minStake) {
                return i;
            }
        }
        return 0;
    }
}
