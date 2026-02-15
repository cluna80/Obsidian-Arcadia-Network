// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenEconomics
 * @dev Manages OAN token economics and incentives
 */
contract TokenEconomics is Ownable {
    
    struct EconomicMetrics {
        uint256 circulatingSupply;
        uint256 burnedAmount;
        uint256 stakedAmount;
        uint256 treasuryAmount;
        uint256 lastUpdate;
    }
    
    struct Incentive {
        string name;
        uint256 rewardRate;        // Tokens per action
        uint256 maxRewards;         // Max tokens available
        uint256 distributed;        // Tokens already distributed
        bool active;
    }
    
    EconomicMetrics public metrics;
    
    mapping(uint256 => Incentive) public incentives;
    uint256 public incentiveCount;
    
    // Token emission schedule
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18;
    uint256 public constant MAX_SUPPLY = 10_000_000_000 * 10**18;
    uint256 public emissionRate = 5; // 5% per year
    uint256 public lastEmission;
    
    // Fee structure (basis points)
    uint256 public tradingFee = 250;          // 2.5%
    uint256 public marketplaceFee = 250;      // 2.5%
    uint256 public spawningFee = 100;         // 1%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    event MetricsUpdated(uint256 circulating, uint256 burned, uint256 staked);
    event IncentiveCreated(uint256 indexed incentiveId, string name, uint256 rewardRate);
    event RewardDistributed(uint256 indexed incentiveId, address indexed recipient, uint256 amount);
    event EmissionRateUpdated(uint256 oldRate, uint256 newRate);
    event FeesUpdated(uint256 trading, uint256 marketplace, uint256 spawning);
    
    constructor() Ownable(msg.sender) {
        metrics = EconomicMetrics({
            circulatingSupply: INITIAL_SUPPLY,
            burnedAmount: 0,
            stakedAmount: 0,
            treasuryAmount: 0,
            lastUpdate: block.timestamp
        });
        
        lastEmission = block.timestamp;
        
        // Create default incentives
        _createIncentive("Entity Creation", 100 * 10**18, 1_000_000 * 10**18);
        _createIncentive("Tool Creation", 50 * 10**18, 500_000 * 10**18);
        _createIncentive("High Reputation", 200 * 10**18, 2_000_000 * 10**18);
        _createIncentive("Liquidity Provider", 500 * 10**18, 5_000_000 * 10**18);
    }
    
    function _createIncentive(string memory name, uint256 rewardRate, uint256 maxRewards) 
        internal returns (uint256) 
    {
        uint256 incentiveId = incentiveCount++;
        
        incentives[incentiveId] = Incentive({
            name: name,
            rewardRate: rewardRate,
            maxRewards: maxRewards,
            distributed: 0,
            active: true
        });
        
        emit IncentiveCreated(incentiveId, name, rewardRate);
        return incentiveId;
    }
    
    function updateMetrics(
        uint256 circulating,
        uint256 burned,
        uint256 staked,
        uint256 treasury
    ) external onlyOwner {
        metrics.circulatingSupply = circulating;
        metrics.burnedAmount = burned;
        metrics.stakedAmount = staked;
        metrics.treasuryAmount = treasury;
        metrics.lastUpdate = block.timestamp;
        
        emit MetricsUpdated(circulating, burned, staked);
    }
    
    function distributeReward(uint256 incentiveId, address recipient) 
        external onlyOwner returns (uint256) 
    {
        Incentive storage incentive = incentives[incentiveId];
        require(incentive.active, "Incentive inactive");
        require(
            incentive.distributed + incentive.rewardRate <= incentive.maxRewards,
            "Max rewards reached"
        );
        
        incentive.distributed += incentive.rewardRate;
        
        emit RewardDistributed(incentiveId, recipient, incentive.rewardRate);
        return incentive.rewardRate;
    }
    
    function updateEmissionRate(uint256 newRate) external onlyOwner {
        require(newRate <= 10, "Rate too high"); // Max 10%
        
        uint256 oldRate = emissionRate;
        emissionRate = newRate;
        
        emit EmissionRateUpdated(oldRate, newRate);
    }
    
    function updateFees(
        uint256 _tradingFee,
        uint256 _marketplaceFee,
        uint256 _spawningFee
    ) external onlyOwner {
        require(_tradingFee <= 1000, "Fee too high"); // Max 10%
        require(_marketplaceFee <= 1000, "Fee too high");
        require(_spawningFee <= 500, "Fee too high"); // Max 5%
        
        tradingFee = _tradingFee;
        marketplaceFee = _marketplaceFee;
        spawningFee = _spawningFee;
        
        emit FeesUpdated(_tradingFee, _marketplaceFee, _spawningFee);
    }
    
    function calculateEmission() public view returns (uint256) {
        if (metrics.circulatingSupply >= MAX_SUPPLY) return 0;
        
        uint256 timeElapsed = block.timestamp - lastEmission;
        uint256 yearsPassed = timeElapsed / 365 days;
        
        if (yearsPassed == 0) return 0;
        
        uint256 emission = (metrics.circulatingSupply * emissionRate * yearsPassed) / 100;
        uint256 maxEmission = MAX_SUPPLY - metrics.circulatingSupply;
        
        return emission > maxEmission ? maxEmission : emission;
    }
    
    function getMetrics() external view returns (EconomicMetrics memory) {
        return metrics;
    }
    
    function getIncentive(uint256 incentiveId) external view returns (Incentive memory) {
        return incentives[incentiveId];
    }
    
    function getTotalValueLocked() external view returns (uint256) {
        return metrics.stakedAmount + metrics.treasuryAmount;
    }
}
