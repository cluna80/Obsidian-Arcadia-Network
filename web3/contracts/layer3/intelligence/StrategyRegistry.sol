// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract StrategyRegistry is Ownable {
    struct Strategy {uint256 id;uint256 behaviorId;string name;uint256 totalUses;uint256 successCount;uint256 avgPerformance;bool isActive;}
    mapping(uint256 => Strategy) public strategies;
    mapping(uint256 => uint256[]) public behaviorStrategies;
    uint256 public strategyCount;
    event StrategyRegistered(uint256 indexed strategyId, uint256 indexed behaviorId);
    event StrategyExecuted(uint256 indexed strategyId, bool success, uint256 performance);
    constructor() Ownable(msg.sender) {}
    function registerStrategy(uint256 behaviorId, string memory name) external returns (uint256) {strategyCount++;strategies[strategyCount] = Strategy(strategyCount,behaviorId,name,0,0,0,true);behaviorStrategies[behaviorId].push(strategyCount);emit StrategyRegistered(strategyCount, behaviorId);return strategyCount;}
    function recordExecution(uint256 strategyId, bool success, uint256 performance) external {Strategy storage s = strategies[strategyId];s.totalUses++;if(success) s.successCount++;s.avgPerformance = ((s.avgPerformance * (s.totalUses - 1)) + performance) / s.totalUses;emit StrategyExecuted(strategyId, success, performance);}
}
