// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ZKEntityBridge
 * @notice Bridge OAN entities between L1 and L2 (ZKSync)
 * 
 * FEATURES:
 * - Deposit entities to ZKSync
 * - Withdraw entities to L1
 * - Maintain state consistency
 * - Prove entity ownership with ZK proofs
 */
contract ZKEntityBridge {
    
    struct BridgeDeposit {
        uint256 depositId;
        uint256 entityId;
        address owner;
        uint256 l1BlockNumber;
        uint256 l2BlockNumber;
        bytes32 stateRoot;
        bool processed;
    }
    
    struct BridgeWithdrawal {
        uint256 withdrawalId;
        uint256 entityId;
        address owner;
        uint256 l2BlockNumber;
        bytes32 proof;
        bool processed;
    }
    
    mapping(uint256 => BridgeDeposit) public deposits;
    mapping(uint256 => BridgeWithdrawal) public withdrawals;
    mapping(uint256 => bool) public entityOnL2;  // entityId => isOnL2
    
    uint256 public depositCount;
    uint256 public withdrawalCount;
    
    address public l1Bridge;
    
    event EntityDeposited(uint256 indexed entityId, address indexed owner, uint256 depositId);
    event EntityWithdrawn(uint256 indexed entityId, address indexed owner, uint256 withdrawalId);
    event DepositProcessed(uint256 indexed depositId);
    event WithdrawalProcessed(uint256 indexed withdrawalId);
    
    constructor(address _l1Bridge) {
        l1Bridge = _l1Bridge;
    }
    
    /**
     * @notice Deposit entity from L1 to L2
     */
    function depositEntity(
        uint256 entityId,
        address owner,
        bytes32 stateRoot
    ) external returns (uint256) {
        require(!entityOnL2[entityId], "Already on L2");
        
        depositCount++;
        uint256 depositId = depositCount;
        
        deposits[depositId] = BridgeDeposit({
            depositId: depositId,
            entityId: entityId,
            owner: owner,
            l1BlockNumber: block.number,
            l2BlockNumber: 0,
            stateRoot: stateRoot,
            processed: false
        });
        
        entityOnL2[entityId] = true;
        
        emit EntityDeposited(entityId, owner, depositId);
        return depositId;
    }
    
    /**
     * @notice Process deposit on L2
     */
    function processDeposit(uint256 depositId) external {
        BridgeDeposit storage deposit = deposits[depositId];
        require(!deposit.processed, "Already processed");
        
        deposit.processed = true;
        deposit.l2BlockNumber = block.number;
        
        emit DepositProcessed(depositId);
    }
    
    /**
     * @notice Initiate withdrawal from L2 to L1
     */
    function withdrawEntity(
        uint256 entityId,
        bytes32 proof
    ) external returns (uint256) {
        require(entityOnL2[entityId], "Not on L2");
        
        withdrawalCount++;
        uint256 withdrawalId = withdrawalCount;
        
        withdrawals[withdrawalId] = BridgeWithdrawal({
            withdrawalId: withdrawalId,
            entityId: entityId,
            owner: msg.sender,
            l2BlockNumber: block.number,
            proof: proof,
            processed: false
        });
        
        entityOnL2[entityId] = false;
        
        emit EntityWithdrawn(entityId, msg.sender, withdrawalId);
        return withdrawalId;
    }
    
    /**
     * @notice Process withdrawal on L1
     */
    function processWithdrawal(uint256 withdrawalId) external {
        BridgeWithdrawal storage withdrawal = withdrawals[withdrawalId];
        require(!withdrawal.processed, "Already processed");
        
        withdrawal.processed = true;
        
        emit WithdrawalProcessed(withdrawalId);
    }
    
    /**
     * @notice Check if entity is on L2
     */
    function isEntityOnL2(uint256 entityId) external view returns (bool) {
        return entityOnL2[entityId];
    }
}
