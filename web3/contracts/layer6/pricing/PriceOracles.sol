// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title PriceOracles - Real-time price feeds for OAN assets (Layer 6, Phase 6.5)
contract PriceOracles is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    struct PriceFeed {
        uint256 feedId;
        string  assetId;
        uint256 currentPrice;
        uint256 previousPrice;
        uint256 high24h;
        uint256 low24h;
        uint256 volume24h;
        uint256 lastUpdated;
        uint256 updateCount;
        address lastUpdater;
        bool    isActive;
        uint256 confidence;
    }

    struct PricePoint {
        uint256 price;
        uint256 timestamp;
        address reporter;
    }

    uint256 private _feedCounter;
    mapping(uint256 => PriceFeed)    public feeds;
    mapping(string  => uint256)      public assetToFeed;
    mapping(uint256 => PricePoint[]) public priceHistory;

    uint256 public maxHistoryLength    = 100;
    uint256 public stalePriceThreshold = 1 hours;
    uint256 public totalFeeds;

    event FeedCreated(uint256 indexed feedId, string assetId, uint256 initialPrice);
    event PriceUpdated(uint256 indexed feedId, string assetId, uint256 oldPrice, uint256 newPrice);
    event FeedDeactivated(uint256 indexed feedId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE,        msg.sender);
    }

    function createFeed(string memory assetId, uint256 initialPrice) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        require(assetToFeed[assetId] == 0, "Feed already exists");
        require(initialPrice > 0,          "Price must be > 0");

        uint256 feedId = ++_feedCounter;
        feeds[feedId] = PriceFeed({
            feedId:        feedId,
            assetId:       assetId,
            currentPrice:  initialPrice,
            previousPrice: initialPrice,
            high24h:       initialPrice,
            low24h:        initialPrice,
            volume24h:     0,
            lastUpdated:   block.timestamp,
            updateCount:   0,
            lastUpdater:   msg.sender,
            isActive:      true,
            confidence:    100
        });

        assetToFeed[assetId] = feedId;
        totalFeeds++;
        priceHistory[feedId].push(PricePoint(initialPrice, block.timestamp, msg.sender));
        emit FeedCreated(feedId, assetId, initialPrice);
        return feedId;
    }

    function updatePrice(uint256 feedId, uint256 newPrice, uint256 volume) external onlyRole(ORACLE_ROLE) {
        PriceFeed storage f = feeds[feedId];
        require(f.isActive,  "Feed inactive");
        require(newPrice > 0, "Price must be > 0");

        f.previousPrice = f.currentPrice;
        f.currentPrice  = newPrice;
        if (newPrice > f.high24h) f.high24h = newPrice;
        if (newPrice < f.low24h)  f.low24h  = newPrice;
        f.volume24h   += volume;
        f.lastUpdated  = block.timestamp;
        f.updateCount++;
        f.lastUpdater  = msg.sender;

        // Rolling history — drop oldest when full
        if (priceHistory[feedId].length >= maxHistoryLength) {
            for (uint256 i = 0; i < priceHistory[feedId].length - 1; i++)
                priceHistory[feedId][i] = priceHistory[feedId][i + 1];
            priceHistory[feedId].pop();
        }
        priceHistory[feedId].push(PricePoint(newPrice, block.timestamp, msg.sender));

        emit PriceUpdated(feedId, f.assetId, f.previousPrice, newPrice);
    }

    function getPrice(string memory assetId) external view returns (uint256 price, uint256 timestamp, bool isStale) {
        uint256 feedId = assetToFeed[assetId];
        require(feedId != 0, "No feed for asset");
        PriceFeed memory f = feeds[feedId];
        return (f.currentPrice, f.lastUpdated, block.timestamp - f.lastUpdated > stalePriceThreshold);
    }

    function getPriceChange(uint256 feedId) external view returns (int256 changePercent) {
        PriceFeed memory f = feeds[feedId];
        if (f.previousPrice == 0) return 0;
        int256 change = int256(f.currentPrice) - int256(f.previousPrice);
        return (change * 10000) / int256(f.previousPrice);
    }

    function getPriceHistory(uint256 feedId) external view returns (PricePoint[] memory) { return priceHistory[feedId]; }

    function deactivateFeed(uint256 feedId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeds[feedId].isActive = false;
        emit FeedDeactivated(feedId);
    }

    function setStalePriceThreshold(uint256 threshold) external onlyRole(DEFAULT_ADMIN_ROLE) { stalePriceThreshold = threshold; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
