// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RevenueDistribution
 * @dev Distribute protocol revenue to stakeholders
 */
contract RevenueDistribution is AccessControl, ReentrancyGuard {
    
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    
    struct RevenueShare {
        address recipient;
        uint256 percentage; // Basis points (100 = 1%)
        uint256 totalReceived;
        uint256 lastClaim;
    }
    
    mapping(address => RevenueShare) public shares;
    address[] public recipients;
    
    uint256 public totalDistributed;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Revenue allocation percentages (basis points)
    uint256 public stakersShare = 4000;      // 40%
    uint256 public treasuryShare = 3000;     // 30%
    uint256 public creatorShare = 2000;      // 20%
    uint256 public burnShare = 1000;         // 10%
    
    event RevenueReceived(address indexed from, uint256 amount);
    event RevenueDistributed(uint256 amount, uint256 timestamp);
    event ShareClaimed(address indexed recipient, uint256 amount);
    event AllocationUpdated(uint256 stakers, uint256 treasury, uint256 creators, uint256 burn);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);
    }
    
    receive() external payable {
        emit RevenueReceived(msg.sender, msg.value);
    }
    
    function distributeRevenue() external onlyRole(DISTRIBUTOR_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No revenue to distribute");
        
        // Calculate shares
        uint256 toStakers = (balance * stakersShare) / BASIS_POINTS;
        uint256 toTreasury = (balance * treasuryShare) / BASIS_POINTS;
        uint256 toCreators = (balance * creatorShare) / BASIS_POINTS;
        uint256 toBurn = (balance * burnShare) / BASIS_POINTS;
        
        // Distribute to recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            RevenueShare storage share = shares[recipient];
            
            if (share.percentage > 0) {
                uint256 amount = (balance * share.percentage) / BASIS_POINTS;
                share.totalReceived += amount;
                payable(recipient).transfer(amount);
            }
        }
        
        totalDistributed += balance;
        
        emit RevenueDistributed(balance, block.timestamp);
    }
    
    function addRecipient(address recipient, uint256 percentage) 
        external onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(recipient != address(0), "Invalid address");
        require(shares[recipient].percentage == 0, "Already exists");
        
        shares[recipient] = RevenueShare({
            recipient: recipient,
            percentage: percentage,
            totalReceived: 0,
            lastClaim: block.timestamp
        });
        
        recipients.push(recipient);
    }
    
    function updateAllocation(
        uint256 _stakersShare,
        uint256 _treasuryShare,
        uint256 _creatorShare,
        uint256 _burnShare
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _stakersShare + _treasuryShare + _creatorShare + _burnShare == BASIS_POINTS,
            "Must total 100%"
        );
        
        stakersShare = _stakersShare;
        treasuryShare = _treasuryShare;
        creatorShare = _creatorShare;
        burnShare = _burnShare;
        
        emit AllocationUpdated(_stakersShare, _treasuryShare, _creatorShare, _burnShare);
    }
    
    function getRecipientShare(address recipient) 
        external view returns (RevenueShare memory) 
    {
        return shares[recipient];
    }
    
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
