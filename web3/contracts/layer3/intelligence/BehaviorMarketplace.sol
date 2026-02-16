// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BehaviorMarketplace
 * @dev Trade AI behaviors, strategies, and decision models as NFTs
 * 
 * Revolutionary Feature: Intelligence becomes a tradeable asset class
 */
contract BehaviorMarketplace is ERC721, Ownable, ReentrancyGuard {
    
    uint256 private _behaviorIds;
    
    enum BehaviorType {
        Strategy,           // Trading/gameplay strategy
        DecisionModel,      // Decision-making logic
        Personality,        // Behavioral personality
        LearningAlgorithm   // Learning/adaptation model
    }
    
    struct Behavior {
        uint256 id;
        string name;
        BehaviorType behaviorType;
        address creator;
        bytes32 codeHash;           // Hash of the behavior code/logic
        uint256 price;
        uint256 usageCount;         // How many times used
        uint256 successRate;        // Success rate (0-10000 = 0-100%)
        uint256 createdAt;
        uint256 version;
        bool isListed;
        uint256 royaltyPercentage;  // Creator royalty on resales (basis points)
    }
    
    struct BehaviorStats {
        uint256 totalExecutions;
        uint256 successfulExecutions;
        uint256 totalRevenue;
        uint256 averagePerformance;
        uint256 lastUsed;
    }
    
    struct Listing {
        uint256 behaviorId;
        address seller;
        uint256 price;
        bool isActive;
        uint256 listedAt;
    }
    
    mapping(uint256 => Behavior) public behaviors;
    mapping(uint256 => BehaviorStats) public behaviorStats;
    mapping(uint256 => Listing) public listings;
    mapping(address => uint256[]) public creatorBehaviors;
    mapping(uint256 => address[]) public behaviorLicensees;
    
    uint256 public platformFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_ROYALTY = 1000; // Max 10%
    
    event BehaviorMinted(
        uint256 indexed behaviorId,
        address indexed creator,
        string name,
        BehaviorType behaviorType
    );
    event BehaviorListed(uint256 indexed behaviorId, uint256 price);
    event BehaviorSold(
        uint256 indexed behaviorId,
        address indexed buyer,
        uint256 price
    );
    event BehaviorExecuted(uint256 indexed behaviorId, bool success);
    event BehaviorUpdated(uint256 indexed behaviorId, uint256 newVersion);
    event RoyaltyPaid(
        uint256 indexed behaviorId,
        address indexed creator,
        uint256 amount
    );
    
    constructor() ERC721("OAN Behavior", "OANB") Ownable(msg.sender) {}
    
    /**
     * @dev Mint a new behavior NFT
     */
    function mintBehavior(
        string memory name,
        BehaviorType behaviorType,
        bytes32 codeHash,
        uint256 price,
        uint256 royaltyPercentage
    ) external returns (uint256) {
        require(royaltyPercentage <= MAX_ROYALTY, "Royalty too high");
        
        _behaviorIds++;
        uint256 newBehaviorId = _behaviorIds;
        
        _safeMint(msg.sender, newBehaviorId);
        
        behaviors[newBehaviorId] = Behavior({
            id: newBehaviorId,
            name: name,
            behaviorType: behaviorType,
            creator: msg.sender,
            codeHash: codeHash,
            price: price,
            usageCount: 0,
            successRate: 5000, // Start at 50%
            createdAt: block.timestamp,
            version: 1,
            isListed: false,
            royaltyPercentage: royaltyPercentage
        });
        
        behaviorStats[newBehaviorId] = BehaviorStats({
            totalExecutions: 0,
            successfulExecutions: 0,
            totalRevenue: 0,
            averagePerformance: 5000,
            lastUsed: 0
        });
        
        creatorBehaviors[msg.sender].push(newBehaviorId);
        
        emit BehaviorMinted(newBehaviorId, msg.sender, name, behaviorType);
        return newBehaviorId;
    }
    
    /**
     * @dev List behavior for sale
     */
    function listBehavior(uint256 behaviorId, uint256 price) external {
        require(_ownerOf(behaviorId) == msg.sender, "Not owner");
        require(price > 0, "Invalid price");
        
        behaviors[behaviorId].isListed = true;
        behaviors[behaviorId].price = price;
        
        listings[behaviorId] = Listing({
            behaviorId: behaviorId,
            seller: msg.sender,
            price: price,
            isActive: true,
            listedAt: block.timestamp
        });
        
        emit BehaviorListed(behaviorId, price);
    }
    
    /**
     * @dev Buy a behavior
     */
    function buyBehavior(uint256 behaviorId) external payable nonReentrant {
        Listing storage listing = listings[behaviorId];
        require(listing.isActive, "Not listed");
        require(msg.value >= listing.price, "Insufficient payment");
        
        Behavior storage behavior = behaviors[behaviorId];
        
        // Calculate fees
        uint256 platformFeeAmount = (listing.price * platformFee) / FEE_DENOMINATOR;
        uint256 royaltyAmount = (listing.price * behavior.royaltyPercentage) / FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price - platformFeeAmount - royaltyAmount;
        
        // Transfer NFT
        _transfer(listing.seller, msg.sender, behaviorId);
        
        // Pay seller
        payable(listing.seller).transfer(sellerAmount);
        
        // Pay royalty to original creator
        if (royaltyAmount > 0 && behavior.creator != listing.seller) {
            payable(behavior.creator).transfer(royaltyAmount);
            emit RoyaltyPaid(behaviorId, behavior.creator, royaltyAmount);
        }
        
        // Update stats
        behaviorStats[behaviorId].totalRevenue += listing.price;
        
        // Deactivate listing
        listing.isActive = false;
        behavior.isListed = false;
        
        // Refund excess
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
        
        emit BehaviorSold(behaviorId, msg.sender, listing.price);
    }
    
    /**
     * @dev Record behavior execution
     */
    function recordExecution(uint256 behaviorId, bool success) external {
        require(_ownerOf(behaviorId) == msg.sender, "Not owner");
        
        BehaviorStats storage stats = behaviorStats[behaviorId];
        Behavior storage behavior = behaviors[behaviorId];
        
        stats.totalExecutions++;
        if (success) {
            stats.successfulExecutions++;
        }
        
        // Update success rate
        behavior.successRate = (stats.successfulExecutions * 10000) / stats.totalExecutions;
        behavior.usageCount++;
        stats.lastUsed = block.timestamp;
        
        // Update average performance
        stats.averagePerformance = behavior.successRate;
        
        emit BehaviorExecuted(behaviorId, success);
    }
    
    /**
     * @dev Update behavior to new version
     */
    function updateBehavior(uint256 behaviorId, bytes32 newCodeHash) external {
        require(_ownerOf(behaviorId) == msg.sender, "Not owner");
        
        Behavior storage behavior = behaviors[behaviorId];
        behavior.codeHash = newCodeHash;
        behavior.version++;
        
        emit BehaviorUpdated(behaviorId, behavior.version);
    }
    
    /**
     * @dev Get behavior details
     */
    function getBehavior(uint256 behaviorId) 
        external 
        view 
        returns (Behavior memory) 
    {
        return behaviors[behaviorId];
    }
    
    /**
     * @dev Get behavior statistics
     */
    function getBehaviorStats(uint256 behaviorId) 
        external 
        view 
        returns (BehaviorStats memory) 
    {
        return behaviorStats[behaviorId];
    }
    
    /**
     * @dev Get all behaviors created by an address
     */
    function getCreatorBehaviors(address creator) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return creatorBehaviors[creator];
    }
    
    /**
     * @dev License a behavior (pay to use without buying)
     */
    function licenseBehavior(uint256 behaviorId) external payable {
        Behavior storage behavior = behaviors[behaviorId];
        require(msg.value >= behavior.price / 10, "Insufficient license fee");
        
        // Pay creator
        payable(behavior.creator).transfer(msg.value);
        
        // Track licensee
        behaviorLicensees[behaviorId].push(msg.sender);
        
        // Update revenue
        behaviorStats[behaviorId].totalRevenue += msg.value;
    }
    
    /**
     * @dev Check if address has licensed a behavior
     */
    function hasLicense(uint256 behaviorId, address user) 
        external 
        view 
        returns (bool) 
    {
        address[] memory licensees = behaviorLicensees[behaviorId];
        for (uint256 i = 0; i < licensees.length; i++) {
            if (licensees[i] == user) {
                return true;
            }
        }
        return _ownerOf(behaviorId) == user;
    }
    
    /**
     * @dev Withdraw platform fees
     */
    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
