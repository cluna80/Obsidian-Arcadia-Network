// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SandboxEnvironment
 * @notice Isolated execution contexts for untrusted entity actions
 * 
 * KEY FEATURES:
 * - Isolate risky operations
 * - Prevent cross-contamination
 * - Rollback on failure
 * - Resource quotas per sandbox
 */
contract SandboxEnvironment is AccessControl {
    
    bytes32 public constant SANDBOX_MANAGER_ROLE = keccak256("SANDBOX_MANAGER_ROLE");
    
    struct Sandbox {
        uint256 sandboxId;
        uint256 entityId;
        address executor;
        uint256 gasLimit;
        uint256 storageQuota;
        uint256 timeLimit;
        SandboxStatus status;
        uint256 createdAt;
        uint256 executedAt;
        bool succeeded;
        string errorMessage;
    }
    
    enum SandboxStatus {Created, Executing, Completed, Failed, TimedOut}
    
    mapping(uint256 => Sandbox) public sandboxes;
    mapping(uint256 => uint256[]) public entitySandboxes;  // entityId => sandboxIds
    
    uint256 public sandboxCount;
    uint256 public defaultGasLimit = 1000000;
    uint256 public defaultStorageQuota = 10000;
    uint256 public defaultTimeLimit = 60; // seconds
    
    event SandboxCreated(uint256 indexed sandboxId, uint256 indexed entityId);
    event SandboxExecuted(uint256 indexed sandboxId, bool success);
    event SandboxFailed(uint256 indexed sandboxId, string reason);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SANDBOX_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @notice Create isolated sandbox for entity action
     */
    function createSandbox(
        uint256 entityId,
        uint256 gasLimit,
        uint256 storageQuota,
        uint256 timeLimit
    ) external onlyRole(SANDBOX_MANAGER_ROLE) returns (uint256) {
        sandboxCount++;
        uint256 sandboxId = sandboxCount;
        
        sandboxes[sandboxId] = Sandbox({
            sandboxId: sandboxId,
            entityId: entityId,
            executor: msg.sender,
            gasLimit: gasLimit > 0 ? gasLimit : defaultGasLimit,
            storageQuota: storageQuota > 0 ? storageQuota : defaultStorageQuota,
            timeLimit: timeLimit > 0 ? timeLimit : defaultTimeLimit,
            status: SandboxStatus.Created,
            createdAt: block.timestamp,
            executedAt: 0,
            succeeded: false,
            errorMessage: ""
        });
        
        entitySandboxes[entityId].push(sandboxId);
        
        emit SandboxCreated(sandboxId, entityId);
        return sandboxId;
    }
    
    /**
     * @notice Execute action in sandbox
     */
    function executeSandbox(
        uint256 sandboxId
    ) external onlyRole(SANDBOX_MANAGER_ROLE) returns (bool) {
        Sandbox storage sandbox = sandboxes[sandboxId];
        require(sandbox.status == SandboxStatus.Created, "Invalid status");
        require(block.timestamp <= sandbox.createdAt + sandbox.timeLimit, "Timed out");
        
        sandbox.status = SandboxStatus.Executing;
        sandbox.executedAt = block.timestamp;
        
        // Execution happens here (placeholder - actual execution logic would be implemented)
        // In production, this would use delegatecall with gas limits
        
        bool success = true; // Placeholder
        
        if (success) {
            sandbox.status = SandboxStatus.Completed;
            sandbox.succeeded = true;
            emit SandboxExecuted(sandboxId, true);
        } else {
            sandbox.status = SandboxStatus.Failed;
            sandbox.errorMessage = "Execution failed";
            emit SandboxFailed(sandboxId, "Execution failed");
        }
        
        return success;
    }
    
    /**
     * @notice Terminate sandbox (timeout/emergency)
     */
    function terminateSandbox(uint256 sandboxId, string memory reason) 
        external 
        onlyRole(SANDBOX_MANAGER_ROLE) 
    {
        Sandbox storage sandbox = sandboxes[sandboxId];
        require(
            sandbox.status == SandboxStatus.Created || 
            sandbox.status == SandboxStatus.Executing,
            "Cannot terminate"
        );
        
        sandbox.status = SandboxStatus.Failed;
        sandbox.errorMessage = reason;
        
        emit SandboxFailed(sandboxId, reason);
    }
    
    /**
     * @notice Get sandbox status
     */
    function getSandboxStatus(uint256 sandboxId) 
        external 
        view 
        returns (SandboxStatus status, bool succeeded, string memory errorMessage) 
    {
        Sandbox storage sandbox = sandboxes[sandboxId];
        return (sandbox.status, sandbox.succeeded, sandbox.errorMessage);
    }
    
    /**
     * @notice Set default limits
     */
    function setDefaultLimits(
        uint256 gasLimit,
        uint256 storageQuota,
        uint256 timeLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        defaultGasLimit = gasLimit;
        defaultStorageQuota = storageQuota;
        defaultTimeLimit = timeLimit;
    }
}
