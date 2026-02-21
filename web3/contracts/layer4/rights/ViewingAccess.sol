// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ViewingAccess
 * @notice Pay-per-view and subscription management
 */
contract ViewingAccess is ReentrancyGuard {
    
    struct AccessPass {
        uint256 passId;
        uint256 mediaAssetId;
        address viewer;
        AccessType accessType;
        uint256 purchaseDate;
        uint256 expiryDate;              // For rentals/subscriptions
        uint256 viewCount;
        uint256 pricePaid;
        bool active;
    }
    
    struct PricingModel {
        uint256 assetId;
        uint256 purchasePrice;           // Own forever
        uint256 rentalPrice24h;          // 24 hour rental
        uint256 rentalPrice7d;           // 7 day rental
        uint256 subscriptionMonthly;     // Monthly subscription
        bool isPremium;
        address creator;
    }
    
    enum AccessType {
        Purchase, Rental24h, Rental7d, Subscription, Free
    }
    
    mapping(uint256 => AccessPass) public accessPasses;
    mapping(uint256 => PricingModel) public pricingModels;
    mapping(address => uint256[]) public viewerPasses;
    mapping(uint256 => uint256) public assetViewCount;
    
    uint256 public passCount;
    
    event AccessGranted(uint256 indexed passId, uint256 indexed assetId, address indexed viewer, AccessType accessType);
    event ContentViewed(uint256 indexed passId, uint256 indexed assetId);
    event PricingUpdated(uint256 indexed assetId, uint256 purchasePrice, uint256 rental24h);
    
    /**
     * @notice Set pricing for media asset
     */
    function setPricing(
        uint256 assetId,
        uint256 purchasePrice,
        uint256 rental24h,
        uint256 rental7d,
        uint256 subscriptionMonthly,
        bool isPremium
    ) external {
        pricingModels[assetId] = PricingModel({
            assetId: assetId,
            purchasePrice: purchasePrice,
            rentalPrice24h: rental24h,
            rentalPrice7d: rental7d,
            subscriptionMonthly: subscriptionMonthly,
            isPremium: isPremium,
            creator: msg.sender
        });
        
        emit PricingUpdated(assetId, purchasePrice, rental24h);
    }
    
    /**
     * @notice Purchase permanent access
     */
    function purchaseAccess(uint256 assetId) external payable nonReentrant returns (uint256) {
        PricingModel storage pricing = pricingModels[assetId];
        require(msg.value >= pricing.purchasePrice, "Insufficient payment");
        
        passCount++;
        uint256 passId = passCount;
        
        accessPasses[passId] = AccessPass({
            passId: passId,
            mediaAssetId: assetId,
            viewer: msg.sender,
            accessType: AccessType.Purchase,
            purchaseDate: block.timestamp,
            expiryDate: 0, // Never expires
            viewCount: 0,
            pricePaid: msg.value,
            active: true
        });
        
        viewerPasses[msg.sender].push(passId);
        
        // Pay creator (via revenue distribution)
        payable(pricing.creator).transfer(msg.value);
        
        emit AccessGranted(passId, assetId, msg.sender, AccessType.Purchase);
        return passId;
    }
    
    /**
     * @notice Rent for 24 hours
     */
    function rent24h(uint256 assetId) external payable nonReentrant returns (uint256) {
        PricingModel storage pricing = pricingModels[assetId];
        require(msg.value >= pricing.rentalPrice24h, "Insufficient payment");
        
        passCount++;
        uint256 passId = passCount;
        
        accessPasses[passId] = AccessPass({
            passId: passId,
            mediaAssetId: assetId,
            viewer: msg.sender,
            accessType: AccessType.Rental24h,
            purchaseDate: block.timestamp,
            expiryDate: block.timestamp + 24 hours,
            viewCount: 0,
            pricePaid: msg.value,
            active: true
        });
        
        viewerPasses[msg.sender].push(passId);
        payable(pricing.creator).transfer(msg.value);
        
        emit AccessGranted(passId, assetId, msg.sender, AccessType.Rental24h);
        return passId;
    }
    
    /**
     * @notice Rent for 7 days
     */
    function rent7d(uint256 assetId) external payable nonReentrant returns (uint256) {
        PricingModel storage pricing = pricingModels[assetId];
        require(msg.value >= pricing.rentalPrice7d, "Insufficient payment");
        
        passCount++;
        uint256 passId = passCount;
        
        accessPasses[passId] = AccessPass({
            passId: passId,
            mediaAssetId: assetId,
            viewer: msg.sender,
            accessType: AccessType.Rental7d,
            purchaseDate: block.timestamp,
            expiryDate: block.timestamp + 7 days,
            viewCount: 0,
            pricePaid: msg.value,
            active: true
        });
        
        viewerPasses[msg.sender].push(passId);
        payable(pricing.creator).transfer(msg.value);
        
        emit AccessGranted(passId, assetId, msg.sender, AccessType.Rental7d);
        return passId;
    }
    
    /**
     * @notice Subscribe for monthly access
     */
    function subscribe(uint256 assetId) external payable nonReentrant returns (uint256) {
        PricingModel storage pricing = pricingModels[assetId];
        require(msg.value >= pricing.subscriptionMonthly, "Insufficient payment");
        
        passCount++;
        uint256 passId = passCount;
        
        accessPasses[passId] = AccessPass({
            passId: passId,
            mediaAssetId: assetId,
            viewer: msg.sender,
            accessType: AccessType.Subscription,
            purchaseDate: block.timestamp,
            expiryDate: block.timestamp + 30 days,
            viewCount: 0,
            pricePaid: msg.value,
            active: true
        });
        
        viewerPasses[msg.sender].push(passId);
        payable(pricing.creator).transfer(msg.value);
        
        emit AccessGranted(passId, assetId, msg.sender, AccessType.Subscription);
        return passId;
    }
    
    /**
     * @notice Record viewing
     */
    function recordView(uint256 passId, uint256 assetId) external {
        AccessPass storage pass = accessPasses[passId];
        require(pass.viewer == msg.sender, "Not pass owner");
        require(pass.active, "Pass not active");
        
        if (pass.expiryDate > 0) {
            require(block.timestamp <= pass.expiryDate, "Pass expired");
        }
        
        pass.viewCount++;
        assetViewCount[assetId]++;
        
        emit ContentViewed(passId, assetId);
    }
    
    /**
     * @notice Check if user has access
     */
    function hasAccess(address viewer, uint256 assetId) external view returns (bool) {
        uint256[] storage passes = viewerPasses[viewer];
        for(uint i = 0; i < passes.length; i++) {
            AccessPass storage pass = accessPasses[passes[i]];
            if (pass.mediaAssetId == assetId && pass.active) {
                if (pass.expiryDate == 0 || block.timestamp <= pass.expiryDate) {
                    return true;
                }
            }
        }
        return false;
    }
    
    function getAccessPass(uint256 passId) external view returns (AccessPass memory) {
        return accessPasses[passId];
    }
    
    function getPricing(uint256 assetId) external view returns (PricingModel memory) {
        return pricingModels[assetId];
    }
}
