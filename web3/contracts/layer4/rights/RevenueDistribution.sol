// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RevenueDistribution
 * @notice Automatic royalty payments to all contributors
 */
contract RevenueDistribution is ReentrancyGuard, Ownable {
    
    struct RevenueStream {
        uint256 streamId;
        uint256 mediaAssetId;
        address[] recipients;
        uint256[] shares;                // Basis points (must sum to 10000)
        uint256 totalCollected;
        uint256 totalDistributed;
        bool active;
    }
    
    struct Payment {
        uint256 paymentId;
        uint256 streamId;
        address payer;
        uint256 amount;
        uint256 timestamp;
        bool distributed;
    }
    
    mapping(uint256 => RevenueStream) public streams;
    mapping(uint256 => Payment[]) public streamPayments;
    mapping(address => uint256) public pendingWithdrawals;
    
    uint256 public streamCount;
    uint256 public platformFee = 250; // 2.5%
    
    event StreamCreated(uint256 indexed streamId, uint256 indexed assetId);
    event RevenueReceived(uint256 indexed streamId, uint256 amount, address indexed payer);
    event RevenueDistributed(uint256 indexed streamId, uint256 paymentId, uint256 amount);
    event WithdrawalMade(address indexed recipient, uint256 amount);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Create revenue stream for asset
     * @dev Defines who gets paid what percentage
     */
    function createRevenueStream(
        uint256 mediaAssetId,
        address[] memory recipients,
        uint256[] memory shares
    ) external returns (uint256) {
        require(recipients.length == shares.length, "Length mismatch");
        
        uint256 totalShares = 0;
        for(uint i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 10000, "Shares must sum to 100%");
        
        streamCount++;
        uint256 streamId = streamCount;
        
        streams[streamId] = RevenueStream({
            streamId: streamId,
            mediaAssetId: mediaAssetId,
            recipients: recipients,
            shares: shares,
            totalCollected: 0,
            totalDistributed: 0,
            active: true
        });
        
        emit StreamCreated(streamId, mediaAssetId);
        return streamId;
    }
    
    /**
     * @notice Receive payment and distribute automatically
     * @dev Called when movie/scene earns money
     */
    function receivePayment(uint256 streamId) external payable nonReentrant {
        RevenueStream storage stream = streams[streamId];
        require(stream.active, "Stream not active");
        require(msg.value > 0, "No payment");
        
        stream.totalCollected += msg.value;
        
        // Create payment record
        streamPayments[streamId].push(Payment({
            paymentId: streamPayments[streamId].length,
            streamId: streamId,
            payer: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            distributed: false
        }));
        
        emit RevenueReceived(streamId, msg.value, msg.sender);
        
        // Distribute immediately
        _distributeRevenue(streamId, streamPayments[streamId].length - 1);
    }
    
    /**
     * @notice Internal distribution logic
     */
    function _distributeRevenue(uint256 streamId, uint256 paymentIndex) internal {
        RevenueStream storage stream = streams[streamId];
        Payment storage payment = streamPayments[streamId][paymentIndex];
        
        require(!payment.distributed, "Already distributed");
        
        uint256 amount = payment.amount;
        
        // Platform fee
        uint256 fee = (amount * platformFee) / 10000;
        pendingWithdrawals[owner()] += fee;
        
        uint256 distributionAmount = amount - fee;
        
        // Distribute to all recipients
        for(uint i = 0; i < stream.recipients.length; i++) {
            uint256 share = (distributionAmount * stream.shares[i]) / 10000;
            pendingWithdrawals[stream.recipients[i]] += share;
        }
        
        payment.distributed = true;
        stream.totalDistributed += distributionAmount;
        
        emit RevenueDistributed(streamId, paymentIndex, distributionAmount);
    }
    
    /**
     * @notice Withdraw accumulated payments
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawals");
        
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit WithdrawalMade(msg.sender, amount);
    }
    
    /**
     * @notice Update stream recipients/shares
     * @dev Can only be done by original creator
     */
    function updateStream(
        uint256 streamId,
        address[] memory recipients,
        uint256[] memory shares
    ) external {
        RevenueStream storage stream = streams[streamId];
        require(stream.recipients[0] == msg.sender, "Not authorized");
        
        uint256 totalShares = 0;
        for(uint i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 10000, "Shares must sum to 100%");
        
        stream.recipients = recipients;
        stream.shares = shares;
    }
    
    /**
     * @notice Get stream details
     */
    function getStream(uint256 streamId) external view returns (
        uint256 mediaAssetId,
        address[] memory recipients,
        uint256[] memory shares,
        uint256 totalCollected,
        uint256 totalDistributed
    ) {
        RevenueStream storage stream = streams[streamId];
        return (
            stream.mediaAssetId,
            stream.recipients,
            stream.shares,
            stream.totalCollected,
            stream.totalDistributed
        );
    }
    
    /**
     * @notice Get payment history
     */
    function getPayments(uint256 streamId) external view returns (Payment[] memory) {
        return streamPayments[streamId];
    }
}
