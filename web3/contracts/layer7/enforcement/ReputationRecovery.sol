// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ReputationRecovery
 * @notice Path to redemption for penalized entities
 * 
 * RECOVERY PATHS:
 * - Good behavior over time
 * - Community service
 * - Arbitration appeals
 * - Probation periods
 */
contract ReputationRecovery is AccessControl {
    
    bytes32 public constant RECOVERY_MANAGER_ROLE = keccak256("RECOVERY_MANAGER_ROLE");
    
    struct RecoveryPlan {
        uint256 planId;
        uint256 entityId;
        RecoveryType recoveryType;
        int256 targetReputation;
        uint256 duration;
        uint256 startTime;
        uint256 completionTime;
        RecoveryStatus status;
        uint256 milestonesCompleted;
        uint256 totalMilestones;
    }
    
    struct Milestone {
        uint256 milestoneId;
        string description;
        int256 reputationReward;
        uint256 deadline;
        bool completed;
    }
    
    enum RecoveryType {
        GoodBehavior,
        CommunityService,
        Arbitration,
        Probation
    }
    
    enum RecoveryStatus {
        Active,
        Completed,
        Failed,
        Abandoned
    }
    
    mapping(uint256 => RecoveryPlan) public recoveryPlans;
    mapping(uint256 => Milestone[]) public planMilestones;
    mapping(uint256 => uint256) public entityActivePlan;  // entityId => planId
    
    uint256 public planCount;
    
    event RecoveryPlanCreated(uint256 indexed planId, uint256 indexed entityId, RecoveryType recoveryType);
    event MilestoneCompleted(uint256 indexed planId, uint256 milestoneId, int256 reward);
    event RecoveryCompleted(uint256 indexed planId, uint256 indexed entityId);
    event RecoveryFailed(uint256 indexed planId, string reason);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RECOVERY_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @notice Create recovery plan
     */
    function createRecoveryPlan(
        uint256 entityId,
        RecoveryType recoveryType,
        int256 targetReputation,
        uint256 duration
    ) external onlyRole(RECOVERY_MANAGER_ROLE) returns (uint256) {
        require(entityActivePlan[entityId] == 0, "Already has active plan");
        
        planCount++;
        uint256 planId = planCount;
        
        recoveryPlans[planId] = RecoveryPlan({
            planId: planId,
            entityId: entityId,
            recoveryType: recoveryType,
            targetReputation: targetReputation,
            duration: duration,
            startTime: block.timestamp,
            completionTime: 0,
            status: RecoveryStatus.Active,
            milestonesCompleted: 0,
            totalMilestones: 0
        });
        
        entityActivePlan[entityId] = planId;
        
        emit RecoveryPlanCreated(planId, entityId, recoveryType);
        return planId;
    }
    
    /**
     * @notice Add milestone to recovery plan
     */
    function addMilestone(
        uint256 planId,
        string memory description,
        int256 reputationReward,
        uint256 deadline
    ) external onlyRole(RECOVERY_MANAGER_ROLE) {
        RecoveryPlan storage plan = recoveryPlans[planId];
        require(plan.status == RecoveryStatus.Active, "Plan not active");
        
        uint256 milestoneId = planMilestones[planId].length;
        
        planMilestones[planId].push(Milestone({
            milestoneId: milestoneId,
            description: description,
            reputationReward: reputationReward,
            deadline: deadline,
            completed: false
        }));
        
        plan.totalMilestones++;
    }
    
    /**
     * @notice Complete milestone
     */
    function completeMilestone(
        uint256 planId,
        uint256 milestoneId
    ) external onlyRole(RECOVERY_MANAGER_ROLE) returns (int256) {
        RecoveryPlan storage plan = recoveryPlans[planId];
        require(plan.status == RecoveryStatus.Active, "Plan not active");
        
        Milestone storage milestone = planMilestones[planId][milestoneId];
        require(!milestone.completed, "Already completed");
        require(block.timestamp <= milestone.deadline, "Deadline passed");
        
        milestone.completed = true;
        plan.milestonesCompleted++;
        
        emit MilestoneCompleted(planId, milestoneId, milestone.reputationReward);
        
        // Check if all milestones completed
        if (plan.milestonesCompleted == plan.totalMilestones) {
            _completeRecovery(planId);
        }
        
        return milestone.reputationReward;
    }
    
    /**
     * @notice Complete recovery plan
     */
    function _completeRecovery(uint256 planId) internal {
        RecoveryPlan storage plan = recoveryPlans[planId];
        plan.status = RecoveryStatus.Completed;
        plan.completionTime = block.timestamp;
        
        entityActivePlan[plan.entityId] = 0;
        
        emit RecoveryCompleted(planId, plan.entityId);
    }
    
    /**
     * @notice Fail recovery plan
     */
    function failRecovery(uint256 planId, string memory reason) 
        external 
        onlyRole(RECOVERY_MANAGER_ROLE) 
    {
        RecoveryPlan storage plan = recoveryPlans[planId];
        require(plan.status == RecoveryStatus.Active, "Plan not active");
        
        plan.status = RecoveryStatus.Failed;
        entityActivePlan[plan.entityId] = 0;
        
        emit RecoveryFailed(planId, reason);
    }
    
    /**
     * @notice Get recovery progress
     */
    function getRecoveryProgress(uint256 planId) 
        external 
        view 
        returns (
            uint256 milestonesCompleted,
            uint256 totalMilestones,
            uint256 timeRemaining,
            RecoveryStatus status
        ) 
    {
        RecoveryPlan storage plan = recoveryPlans[planId];
        
        uint256 timeLeft = 0;
        if (plan.startTime + plan.duration > block.timestamp) {
            timeLeft = (plan.startTime + plan.duration) - block.timestamp;
        }
        
        return (
            plan.milestonesCompleted,
            plan.totalMilestones,
            timeLeft,
            plan.status
        );
    }
    
    /**
     * @notice Get plan milestones
     */
    function getPlanMilestones(uint256 planId) 
        external 
        view 
        returns (Milestone[] memory) 
    {
        return planMilestones[planId];
    }
}
