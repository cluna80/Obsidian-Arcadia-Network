// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract InsuranceProtocol is Ownable, ReentrancyGuard {
    
    enum InsuranceType {EntityDeath, PerformanceGuarantee, ReputationProtection, WorldStability}
    
    struct Policy {uint256 id;InsuranceType policyType;uint256 insuredId;address holder;uint256 coverage;uint256 premium;uint256 duration;uint256 startTime;bool isActive;bool claimed;}
    
    mapping(uint256 => Policy) public policies;
    uint256 public policyCount;
    uint256 public totalPremiums;
    uint256 public totalClaims;
    
    event PolicyCreated(uint256 indexed policyId, address indexed holder, uint256 coverage, uint256 premium);
    event PremiumPaid(uint256 indexed policyId, uint256 amount);
    event ClaimFiled(uint256 indexed policyId, address indexed holder);
    event ClaimPaid(uint256 indexed policyId, uint256 amount);
    
    constructor() Ownable(msg.sender) {}
    
    function createPolicy(InsuranceType policyType,uint256 insuredId,uint256 coverage,uint256 duration) external payable returns (uint256) {uint256 premium = calculatePremium(coverage, duration);require(msg.value >= premium);policyCount++;policies[policyCount] = Policy(policyCount,policyType,insuredId,msg.sender,coverage,premium,duration,block.timestamp,true,false);totalPremiums += premium;emit PolicyCreated(policyCount, msg.sender, coverage, premium);emit PremiumPaid(policyCount, premium);return policyCount;}
    
    function fileClaim(uint256 policyId) external {Policy storage policy = policies[policyId];require(policy.holder == msg.sender && policy.isActive && !policy.claimed);require(block.timestamp < policy.startTime + policy.duration);policy.claimed = true;emit ClaimFiled(policyId, msg.sender);}
    
    function processClaim(uint256 policyId, bool approved) external onlyOwner nonReentrant {Policy storage policy = policies[policyId];require(policy.claimed && policy.isActive);if(approved){payable(policy.holder).transfer(policy.coverage);totalClaims += policy.coverage;emit ClaimPaid(policyId, policy.coverage);}policy.isActive = false;}
    
    function calculatePremium(uint256 coverage, uint256 duration) public pure returns (uint256) {return (coverage * duration) / (365 days) / 10;}
    
    function getPolicy(uint256 policyId) external view returns (Policy memory) {return policies[policyId];}
}
