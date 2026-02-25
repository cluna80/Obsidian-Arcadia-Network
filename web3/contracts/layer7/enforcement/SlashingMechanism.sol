// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SlashingMechanism
 * @notice Punish bad actors with stake/reputation slashing
 * 
 * PENALTIES:
 * - Slash staked funds
 * - Reduce reputation
 * - Temporary bans
 * - Permanent bans for severe violations
 */
contract SlashingMechanism is AccessControl, ReentrancyGuard {
    
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    
    struct Stake {
        uint256 amount;
        uint256 lockedUntil;
        bool slashed;
        uint256 slashedAmount;
    }
    
    struct SlashingEvent {
        uint256 eventId;
        uint256 entityId;
        address slashedAddress;
        uint256 amountSlashed;
        SlashReason reason;
        uint256 timestamp;
        address slasher;
    }
    
    enum SlashReason {
        Manipulation,
        Fraud,
        Abuse,
        Collusion,
        Violation,
        Negligence
    }
    
    mapping(uint256 => Stake) public stakes;                    // entityId => stake
    mapping(uint256 => SlashingEvent[]) public slashHistory;    // entityId => events
    mapping(SlashReason => uint256) public slashPercentages;    // reason => percentage
    
    uint256 public totalSlashed;
    uint256 public slashEventCount;
    address public slashingPool;
    
    event Slashed(
        uint256 indexed entityId,
        uint256 amount,
        SlashReason indexed reason,
        address indexed slasher
    );
    event StakeDeposited(uint256 indexed entityId, uint256 amount);
    event StakeWithdrawn(uint256 indexed entityId, uint256 amount);
    
    constructor(address _slashingPool) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SLASHER_ROLE, msg.sender);
        
        slashingPool = _slashingPool;
        
        // Set default slash percentages
        slashPercentages[SlashReason.Fraud] = 100;        // 100% slash
        slashPercentages[SlashReason.Manipulation] = 75;  // 75% slash
        slashPercentages[SlashReason.Collusion] = 50;     // 50% slash
        slashPercentages[SlashReason.Abuse] = 25;         // 25% slash
        slashPercentages[SlashReason.Violation] = 10;     // 10% slash
        slashPercentages[SlashReason.Negligence] = 5;     // 5% slash
    }
    
    /**
     * @notice Deposit stake
     */
    function depositStake(uint256 entityId, uint256 lockDuration) 
        external 
        payable 
        nonReentrant 
    {
        require(msg.value > 0, "No stake provided");
        
        Stake storage stake = stakes[entityId];
        stake.amount += msg.value;
        stake.lockedUntil = block.timestamp + lockDuration;
        
        emit StakeDeposited(entityId, msg.value);
    }
    
    /**
     * @notice Slash entity stake
     */
    function slash(
        uint256 entityId,
        SlashReason reason,
        string memory evidence
    ) external onlyRole(SLASHER_ROLE) nonReentrant returns (uint256) {
        Stake storage stake = stakes[entityId];
        require(stake.amount > 0, "No stake to slash");
        require(!stake.slashed, "Already slashed");
        
        // Calculate slash amount
        uint256 slashPercentage = slashPercentages[reason];
        uint256 slashAmount = (stake.amount * slashPercentage) / 100;
        
        // Execute slash
        stake.slashed = true;
        stake.slashedAmount = slashAmount;
        stake.amount -= slashAmount;
        
        totalSlashed += slashAmount;
        
        // Record event
        slashEventCount++;
        slashHistory[entityId].push(SlashingEvent({
            eventId: slashEventCount,
            entityId: entityId,
            slashedAddress: msg.sender,
            amountSlashed: slashAmount,
            reason: reason,
            timestamp: block.timestamp,
            slasher: msg.sender
        }));
        
        // Transfer slashed funds to pool
        payable(slashingPool).transfer(slashAmount);
        
        emit Slashed(entityId, slashAmount, reason, msg.sender);
        
        return slashAmount;
    }
    
    /**
     * @notice Withdraw stake (after lock period)
     */
    function withdrawStake(uint256 entityId) external nonReentrant {
        Stake storage stake = stakes[entityId];
        require(stake.amount > 0, "No stake");
        require(block.timestamp >= stake.lockedUntil, "Still locked");
        require(!stake.slashed, "Cannot withdraw slashed stake");
        
        uint256 amount = stake.amount;
        stake.amount = 0;
        
        payable(msg.sender).transfer(amount);
        
        emit StakeWithdrawn(entityId, amount);
    }
    
    /**
     * @notice Update slash percentage
     */
    function updateSlashPercentage(SlashReason reason, uint256 percentage) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(percentage <= 100, "Invalid percentage");
        slashPercentages[reason] = percentage;
    }
    
    /**
     * @notice Get slash history
     */
    function getSlashHistory(uint256 entityId) 
        external 
        view 
        returns (SlashingEvent[] memory) 
    {
        return slashHistory[entityId];
    }
    
    /**
     * @notice Check if entity has been slashed
     */
    function hasBeenSlashed(uint256 entityId) external view returns (bool) {
        return stakes[entityId].slashed;
    }
}
