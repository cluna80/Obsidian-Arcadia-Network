// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BehaviorMarketplace is ERC721, Ownable, ReentrancyGuard {
    uint256 private _behaviorIds;

    enum BehaviorType {
        Strategy,
        DecisionModel,
        Personality,
        LearningAlgorithm
    }

    struct Behavior {
        uint256 id;
        string name;
        BehaviorType behaviorType;
        address creator;
        bytes32 codeHash;
        uint256 price;
        uint256 usageCount;
        uint256 successRate; // 0–10000 (basis points)
        uint256 createdAt;
        uint256 version;
        bool isListed;
        uint256 royaltyBps; // basis points (0–1000 = 0–10%)
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
    mapping(uint256 => address[]) public licensees;

    uint256 public platformFeeBps = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_ROYALTY_BPS = 1000;

    event BehaviorMinted(
        uint256 indexed behaviorId,
        address indexed creator,
        string name,
        BehaviorType behaviorType,
        bytes32 codeHash,
        uint256 initialPrice,
        uint256 royaltyBps
    );
    event BehaviorListed(uint256 indexed behaviorId, address seller, uint256 price);
    event ListingCancelled(uint256 indexed behaviorId, address seller);
    event BehaviorSold(
        uint256 indexed behaviorId,
        address indexed seller,
        address indexed buyer,
        uint256 price,
        uint256 royaltyPaid
    );
    event BehaviorExecuted(uint256 indexed behaviorId, address executor, bool success);
    event BehaviorUpdated(uint256 indexed behaviorId, bytes32 newCodeHash, uint256 newVersion);
    event RoyaltyPaid(uint256 indexed behaviorId, address creator, uint256 amount);
    event PlatformFeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    constructor() ERC721("OAN Behavior", "OANB") Ownable(msg.sender) {}

    // ───────────────────────────────────────────────────────────────
    // Mint new behavior NFT
    // ───────────────────────────────────────────────────────────────
    function mintBehavior(
        string calldata name,
        BehaviorType behaviorType,
        bytes32 codeHash,
        uint256 price,
        uint256 royaltyBps
    ) external returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(royaltyBps <= MAX_ROYALTY_BPS, "Royalty too high");

        _behaviorIds++;
        uint256 newId = _behaviorIds;

        _safeMint(msg.sender, newId);

        behaviors[newId] = Behavior({
            id: newId,
            name: name,
            behaviorType: behaviorType,
            creator: msg.sender,
            codeHash: codeHash,
            price: price,
            usageCount: 0,
            successRate: 5000, // 50%
            createdAt: block.timestamp,
            version: 1,
            isListed: false,
            royaltyBps: royaltyBps
        });

        behaviorStats[newId] = BehaviorStats({
            totalExecutions: 0,
            successfulExecutions: 0,
            totalRevenue: 0,
            averagePerformance: 5000,
            lastUsed: 0
        });

        creatorBehaviors[msg.sender].push(newId);

        emit BehaviorMinted(newId, msg.sender, name, behaviorType, codeHash, price, royaltyBps);
        return newId;
    }

    // ───────────────────────────────────────────────────────────────
    // List behavior for sale
    // ───────────────────────────────────────────────────────────────
    function listBehavior(uint256 behaviorId, uint256 price) external {
    require(_ownerOf(behaviorId) == msg.sender, "Not owner");
    require(price > 0, "Price must be positive");
    require(!behaviors[behaviorId].isListed, "Already listed");

    behaviors[behaviorId].isListed = true;
    behaviors[behaviorId].price = price;

    listings[behaviorId] = Listing({
        behaviorId: behaviorId,
        seller: msg.sender,
        price: price,
        isActive: true,
        listedAt: block.timestamp
    });

    emit BehaviorListed(behaviorId, msg.sender, price);  // ← FIXED: added msg.sender
}

    // ───────────────────────────────────────────────────────────────
    // Cancel active listing
    // ───────────────────────────────────────────────────────────────
    function cancelListing(uint256 behaviorId) external {
        Listing storage listing = listings[behaviorId];
        require(listing.isActive, "Not listed");
        require(listing.seller == msg.sender || owner() == msg.sender, "Not authorized");

        listing.isActive = false;
        behaviors[behaviorId].isListed = false;

        emit ListingCancelled(behaviorId, msg.sender);
    }

    // ───────────────────────────────────────────────────────────────
    // Buy listed behavior NFT
    // ───────────────────────────────────────────────────────────────
    function buyBehavior(uint256 behaviorId) external payable nonReentrant {
        Listing storage listing = listings[behaviorId];
        require(listing.isActive, "Not listed or sale ended");
        require(msg.value >= listing.price, "Insufficient payment");

        Behavior storage behavior = behaviors[behaviorId];

        uint256 platformFeeAmount = (listing.price * platformFeeBps) / FEE_DENOMINATOR;
        uint256 royaltyAmount = (listing.price * behavior.royaltyBps) / FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price - platformFeeAmount - royaltyAmount;

        // Transfer NFT
        _transfer(listing.seller, msg.sender, behaviorId);

        // Pay seller
        (bool sentSeller, ) = payable(listing.seller).call{value: sellerAmount}("");
        require(sentSeller, "Failed to send to seller");

        // Pay royalty (only if creator is not current seller)
        if (royaltyAmount > 0 && behavior.creator != listing.seller) {
            (bool sentRoyalty, ) = payable(behavior.creator).call{value: royaltyAmount}("");
            require(sentRoyalty, "Royalty transfer failed");
            emit RoyaltyPaid(behaviorId, behavior.creator, royaltyAmount);
        }

        // Pay platform fee
        if (platformFeeAmount > 0) {
            (bool sentFee, ) = payable(owner()).call{value: platformFeeAmount}("");
            require(sentFee, "Platform fee transfer failed");
        }

        // Update stats
        behaviorStats[behaviorId].totalRevenue += listing.price;

        // Clean up listing
        listing.isActive = false;
        behavior.isListed = false;

        // Refund excess payment
        if (msg.value > listing.price) {
            (bool refunded, ) = payable(msg.sender).call{value: msg.value - listing.price}("");
            require(refunded, "Refund failed");
        }

        emit BehaviorSold(behaviorId, listing.seller, msg.sender, listing.price, royaltyAmount);
    }

    // ───────────────────────────────────────────────────────────────
    // Record successful/failed execution (only current owner)
    // ───────────────────────────────────────────────────────────────
    function recordExecution(uint256 behaviorId, bool success) external {
        require(_ownerOf(behaviorId) == msg.sender, "Not owner");

        BehaviorStats storage stats = behaviorStats[behaviorId];
        Behavior storage behavior = behaviors[behaviorId];

        stats.totalExecutions++;
        if (success) stats.successfulExecutions++;

        if (stats.totalExecutions > 0) {
            behavior.successRate = (stats.successfulExecutions * 10000) / stats.totalExecutions;
            stats.averagePerformance = behavior.successRate;
        }

        behavior.usageCount++;
        stats.lastUsed = block.timestamp;

        emit BehaviorExecuted(behaviorId, msg.sender, success);
    }

    // ───────────────────────────────────────────────────────────────
    // Update behavior code (new version)
    // ───────────────────────────────────────────────────────────────
    function updateBehavior(uint256 behaviorId, bytes32 newCodeHash) external {
        require(_ownerOf(behaviorId) == msg.sender, "Not owner");

        Behavior storage behavior = behaviors[behaviorId];
        behavior.codeHash = newCodeHash;
        behavior.version++;

        emit BehaviorUpdated(behaviorId, newCodeHash, behavior.version);
    }

    // ───────────────────────────────────────────────────────────────
    // License / rent behavior (cheaper than buying)
    // ───────────────────────────────────────────────────────────────
    function licenseBehavior(uint256 behaviorId) external payable nonReentrant {
        Behavior storage behavior = behaviors[behaviorId];
        require(msg.value >= behavior.price / 10, "License fee too low");

        (bool sent, ) = payable(behavior.creator).call{value: msg.value}("");
        require(sent, "Payment to creator failed");

        licensees[behaviorId].push(msg.sender);
        behaviorStats[behaviorId].totalRevenue += msg.value;
    }

    // ───────────────────────────────────────────────────────────────
    // View helpers
    // ───────────────────────────────────────────────────────────────
    function getBehavior(uint256 behaviorId) external view returns (Behavior memory) {
        return behaviors[behaviorId];
    }

    function getBehaviorStats(uint256 behaviorId) external view returns (BehaviorStats memory) {
        return behaviorStats[behaviorId];
    }

    function getListedBehaviors() external view returns (uint256[] memory) {
        uint256[] memory activeIds = new uint256[](_behaviorIds);
        uint256 count = 0;

        for (uint256 i = 1; i <= _behaviorIds; i++) {
            if (listings[i].isActive) {
                activeIds[count] = i;
                count++;
            }
        }

        // Resize array to actual count (assembly trick)
        assembly {
            mstore(activeIds, count)
        }
        return activeIds;
    }

    function getCreatorBehaviors(address creator) external view returns (uint256[] memory) {
        return creatorBehaviors[creator];
    }

    function hasLicense(uint256 behaviorId, address user) external view returns (bool) {
        if (_ownerOf(behaviorId) == user) return true;

        address[] memory lic = licensees[behaviorId];
        for (uint256 i = 0; i < lic.length; i++) {
            if (lic[i] == user) return true;
        }
        return false;
    }

    // ───────────────────────────────────────────────────────────────
    // Admin / platform controls
    // ───────────────────────────────────────────────────────────────
    function setPlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "Fee too high"); // max 10%
        emit PlatformFeeUpdated(platformFeeBps, newFeeBps);
        platformFeeBps = newFeeBps;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool sent, ) = payable(owner()).call{value: balance}("");
        require(sent, "Withdrawal failed");
    }
}