// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CompensationEngine
/// @notice Automated and manual compensation payouts for OAN protocol victims
contract CompensationEngine is AccessControl, ReentrancyGuard {

    bytes32 public constant COMPENSATOR_ROLE = keccak256("COMPENSATOR_ROLE");
    bytes32 public constant FUNDER_ROLE      = keccak256("FUNDER_ROLE");

    enum CompensationType { DisputeAward, InsurancePayout, BugBounty, SlashRedistribution, ProtocolGrant, Custom }
    enum PayoutStatus     { Pending, Approved, Processing, Paid, Failed, Cancelled }

    struct CompensationRequest {
        uint256           id;
        address           recipient;
        uint256           amount;
        CompensationType  compensationType;
        PayoutStatus      status;
        bytes32           evidenceHash;
        uint256           requestedAt;
        uint256           processedAt;
        address           approvedBy;
        string            reason;
        uint256           sourceId;   // linked disputeId / claimId / etc.
    }

    struct BatchPayout {
        uint256   id;
        uint256[] requestIds;
        uint256   totalAmount;
        bool      executed;
        uint256   createdAt;
    }

    uint256 public requestCounter;
    uint256 public batchCounter;
    uint256 public totalCompensated;
    uint256 public pendingAmount;
    uint256 public maxSinglePayout  = 100 ether;
    uint256 public autoApproveLimit = 0.1 ether;  // auto-approve below this amount

    mapping(uint256 => CompensationRequest) public requests;
    mapping(uint256 => BatchPayout)         public batches;
    mapping(address => uint256[])           public recipientHistory;
    mapping(address => uint256)             public totalReceived;
    mapping(CompensationType => uint256)    public typePayoutCap;  // max per-type total

    event CompensationRequested(uint256 indexed requestId, address indexed recipient, uint256 amount, CompensationType compensationType);
    event CompensationApproved(uint256 indexed requestId, address indexed approvedBy);
    event CompensationPaid(uint256 indexed requestId, address indexed recipient, uint256 amount);
    event CompensationFailed(uint256 indexed requestId, string reason);
    event CompensationCancelled(uint256 indexed requestId);
    event BatchCreated(uint256 indexed batchId, uint256 requestCount, uint256 totalAmount);
    event BatchExecuted(uint256 indexed batchId, uint256 paidCount);
    event FundsDeposited(address indexed funder, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPENSATOR_ROLE,   msg.sender);
        _grantRole(FUNDER_ROLE,        msg.sender);
    }

    /// @notice Fund the compensation pool
    function depositFunds() external payable onlyRole(FUNDER_ROLE) {
        require(msg.value > 0, "No value sent");
        emit FundsDeposited(msg.sender, msg.value);
    }

    /// @notice Request compensation for a recipient
    function requestCompensation(
        address recipient,
        uint256 amount,
        CompensationType compensationType,
        bytes32 evidenceHash,
        string calldata reason,
        uint256 sourceId
    ) external onlyRole(COMPENSATOR_ROLE) returns (uint256 requestId) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0,              "Amount must be > 0");
        require(amount <= maxSinglePayout, "Exceeds max single payout");
        require(address(this).balance >= pendingAmount + amount, "Insufficient pool balance");

        requestCounter++;
        requestId = requestCounter;

        PayoutStatus status = amount <= autoApproveLimit
            ? PayoutStatus.Approved
            : PayoutStatus.Pending;

        requests[requestId] = CompensationRequest({
            id:               requestId,
            recipient:        recipient,
            amount:           amount,
            compensationType: compensationType,
            status:           status,
            evidenceHash:     evidenceHash,
            requestedAt:      block.timestamp,
            processedAt:      0,
            approvedBy:       status == PayoutStatus.Approved ? msg.sender : address(0),
            reason:           reason,
            sourceId:         sourceId
        });

        recipientHistory[recipient].push(requestId);
        pendingAmount += amount;

        emit CompensationRequested(requestId, recipient, amount, compensationType);

        // Auto-pay if below threshold
        if (status == PayoutStatus.Approved) {
            _processPayout(requestId);
        }
    }

    /// @notice Approve a pending compensation request
    function approveCompensation(uint256 requestId) external onlyRole(COMPENSATOR_ROLE) {
        CompensationRequest storage req = requests[requestId];
        require(req.status == PayoutStatus.Pending, "Not pending");
        req.status     = PayoutStatus.Approved;
        req.approvedBy = msg.sender;
        emit CompensationApproved(requestId, msg.sender);
    }

    /// @notice Process an approved payout
    function processPayout(uint256 requestId) external onlyRole(COMPENSATOR_ROLE) nonReentrant {
        _processPayout(requestId);
    }

    function _processPayout(uint256 requestId) internal {
        CompensationRequest storage req = requests[requestId];
        require(req.status == PayoutStatus.Approved, "Not approved");
        require(address(this).balance >= req.amount,  "Insufficient balance");

        req.status      = PayoutStatus.Processing;
        req.processedAt = block.timestamp;

        (bool success, ) = payable(req.recipient).call{value: req.amount}("");

        if (success) {
            req.status         = PayoutStatus.Paid;
            totalCompensated  += req.amount;
            totalReceived[req.recipient] += req.amount;
            pendingAmount     -= req.amount;
            emit CompensationPaid(requestId, req.recipient, req.amount);
        } else {
            req.status = PayoutStatus.Failed;
            emit CompensationFailed(requestId, "Transfer failed");
        }
    }

    /// @notice Cancel a pending request
    function cancelCompensation(uint256 requestId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CompensationRequest storage req = requests[requestId];
        require(req.status == PayoutStatus.Pending, "Can only cancel pending");
        req.status     = PayoutStatus.Cancelled;
        pendingAmount -= req.amount;
        emit CompensationCancelled(requestId);
    }

    /// @notice Create a batch payout for multiple requests
    function createBatch(uint256[] calldata requestIds)
        external onlyRole(COMPENSATOR_ROLE) returns (uint256 batchId)
    {
        require(requestIds.length > 0, "Empty batch");
        uint256 total;

        for (uint256 i = 0; i < requestIds.length; i++) {
            CompensationRequest storage req = requests[requestIds[i]];
            require(req.status == PayoutStatus.Approved, "Request not approved");
            total += req.amount;
        }

        require(address(this).balance >= total, "Insufficient balance for batch");

        batchCounter++;
        batchId = batchCounter;

        batches[batchId] = BatchPayout({
            id:           batchId,
            requestIds:   requestIds,
            totalAmount:  total,
            executed:     false,
            createdAt:    block.timestamp
        });

        emit BatchCreated(batchId, requestIds.length, total);
    }

    /// @notice Execute a batch payout
    function executeBatch(uint256 batchId) external onlyRole(COMPENSATOR_ROLE) nonReentrant {
        BatchPayout storage batch = batches[batchId];
        require(!batch.executed, "Already executed");
        batch.executed = true;

        uint256 paidCount;
        for (uint256 i = 0; i < batch.requestIds.length; i++) {
            uint256 rid = batch.requestIds[i];
            if (requests[rid].status == PayoutStatus.Approved) {
                _processPayout(rid);
                if (requests[rid].status == PayoutStatus.Paid) {
                    paidCount++;
                }
            }
        }

        emit BatchExecuted(batchId, paidCount);
    }

    /// @notice Update auto-approve limit
    function setAutoApproveLimit(uint256 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        autoApproveLimit = newLimit;
    }

    /// @notice Update max single payout
    function setMaxSinglePayout(uint256 newMax) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxSinglePayout = newMax;
    }

    /// @notice Get pool balance
    function getPoolBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get all request IDs for a recipient
    function getRecipientHistory(address recipient) external view returns (uint256[] memory) {
        return recipientHistory[recipient];
    }

    /// @notice Get total paid to a recipient
    function getTotalReceived(address recipient) external view returns (uint256) {
        return totalReceived[recipient];
    }
}
