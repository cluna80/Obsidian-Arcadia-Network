// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FanTokens - Team/athlete fan tokens with dynamic pricing
/// @notice Layer 5, Phase 5.4 - OAN Metaverse Sports Arena
contract FanTokens is AccessControl, ReentrancyGuard {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct FanToken {
        uint256 tokenId;           // Unique fan token series ID
        uint256 athleteId;         // Or teamId
        string name;
        string symbol;
        address tokenContract;     // ERC20 deployed per athlete
        uint256 totalSupply;
        uint256 circulatingSupply;
        uint256 basePrice;         // Base price in wei
        uint256 currentPrice;      // Dynamic price
        uint256 holderCount;
        uint256 totalRevenue;
        bool isActive;
        address creator;
    }

    struct HolderBenefits {
        bool votingRights;
        bool revenueShare;
        bool exclusiveMerchandise;
        bool meetAndGreetAccess;
        bool earlyTicketAccess;
        uint256 minHoldingRequired;   // Minimum tokens to get benefits
    }

    uint256 private _tokenSeriesCounter;

    mapping(uint256 => FanToken) public fanTokenSeries;
    mapping(uint256 => HolderBenefits) public tokenBenefits;
    mapping(uint256 => mapping(address => uint256)) public holdings;  // seriesId => holder => amount
    mapping(uint256 => address[]) public tokenHolders;
    mapping(uint256 => bool) public isHolder;
    mapping(uint256 => uint256) public athleteFanToken;  // athleteId => seriesId
    mapping(address => uint256[]) public creatorTokens;

    uint256 public totalFanTokenSeries;
    address public treasury;
    uint256 public platformFeePercent = 500; // 5%

    event FanTokenSeriesCreated(uint256 indexed seriesId, uint256 indexed athleteId, string name);
    event FanTokenPurchased(uint256 indexed seriesId, address indexed buyer, uint256 amount, uint256 price);
    event FanTokenSold(uint256 indexed seriesId, address indexed seller, uint256 amount, uint256 proceeds);
    event RevenueDistributed(uint256 indexed seriesId, uint256 totalAmount);
    event PriceUpdated(uint256 indexed seriesId, uint256 newPrice);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    /// @notice Create a fan token series for an athlete or team
    function createFanTokenSeries(
        uint256 athleteId,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 basePrice,
        HolderBenefits memory benefits
    ) external returns (uint256) {
        require(athleteFanToken[athleteId] == 0, "Already has fan token");
        require(totalSupply > 0, "Supply must be > 0");
        require(basePrice > 0, "Base price must be > 0");

        uint256 seriesId = ++_tokenSeriesCounter;

        fanTokenSeries[seriesId] = FanToken({
            tokenId: seriesId,
            athleteId: athleteId,
            name: name,
            symbol: symbol,
            tokenContract: address(0), // Simplified - no separate ERC20 deployment here
            totalSupply: totalSupply,
            circulatingSupply: 0,
            basePrice: basePrice,
            currentPrice: basePrice,
            holderCount: 0,
            totalRevenue: 0,
            isActive: true,
            creator: msg.sender
        });

        tokenBenefits[seriesId] = benefits;
        athleteFanToken[athleteId] = seriesId;
        creatorTokens[msg.sender].push(seriesId);
        totalFanTokenSeries++;

        emit FanTokenSeriesCreated(seriesId, athleteId, name);
        return seriesId;
    }

    /// @notice Buy fan tokens (bonding curve pricing)
    function buyFanTokens(uint256 seriesId, uint256 amount) external payable nonReentrant {
        FanToken storage series = fanTokenSeries[seriesId];
        require(series.isActive, "Series not active");
        require(series.circulatingSupply + amount <= series.totalSupply, "Exceeds supply");

        uint256 cost = _calculateBuyCost(seriesId, amount);
        require(msg.value >= cost, "Insufficient payment");

        series.circulatingSupply += amount;
        series.totalRevenue += cost;

        if (holdings[seriesId][msg.sender] == 0) {
            series.holderCount++;
            tokenHolders[seriesId].push(msg.sender);
        }

        holdings[seriesId][msg.sender] += amount;
        series.currentPrice = _calculateCurrentPrice(seriesId);

        uint256 fee = (cost * platformFeePercent) / 10000;
        payable(treasury).transfer(fee);
        payable(series.creator).transfer(cost - fee);

        emit FanTokenPurchased(seriesId, msg.sender, amount, cost);
        emit PriceUpdated(seriesId, series.currentPrice);
    }

    /// @notice Sell fan tokens back (bonding curve)
    function sellFanTokens(uint256 seriesId, uint256 amount) external nonReentrant {
        require(holdings[seriesId][msg.sender] >= amount, "Insufficient tokens");

        FanToken storage series = fanTokenSeries[seriesId];
        uint256 proceeds = _calculateSellProceeds(seriesId, amount);

        series.circulatingSupply -= amount;
        holdings[seriesId][msg.sender] -= amount;

        if (holdings[seriesId][msg.sender] == 0) {
            series.holderCount--;
        }

        series.currentPrice = _calculateCurrentPrice(seriesId);

        uint256 fee = (proceeds * platformFeePercent) / 10000;
        payable(treasury).transfer(fee);
        payable(msg.sender).transfer(proceeds - fee);

        emit FanTokenSold(seriesId, msg.sender, amount, proceeds - fee);
        emit PriceUpdated(seriesId, series.currentPrice);
    }

    /// @notice Distribute revenue to token holders
    function distributeRevenue(uint256 seriesId) external payable onlyRole(MANAGER_ROLE) nonReentrant {
        FanToken storage series = fanTokenSeries[seriesId];
        require(series.circulatingSupply > 0, "No holders");
        require(msg.value > 0, "No revenue");

        uint256 totalRevenue = msg.value;
        uint256 perTokenAmount = totalRevenue / series.circulatingSupply;

        address[] memory holders = tokenHolders[seriesId];
        for (uint256 i = 0; i < holders.length; i++) {
            uint256 holderBalance = holdings[seriesId][holders[i]];
            if (holderBalance > 0) {
                uint256 share = holderBalance * perTokenAmount;
                payable(holders[i]).transfer(share);
            }
        }

        emit RevenueDistributed(seriesId, totalRevenue);
    }

    function _calculateBuyCost(uint256 seriesId, uint256 amount) internal view returns (uint256) {
        FanToken memory series = fanTokenSeries[seriesId];
        // Simple linear bonding curve: price increases with supply
        uint256 avgPrice = series.currentPrice + (amount * series.basePrice * series.circulatingSupply) / (series.totalSupply * 10);
        return avgPrice * amount;
    }

    function _calculateSellProceeds(uint256 seriesId, uint256 amount) internal view returns (uint256) {
        FanToken memory series = fanTokenSeries[seriesId];
        uint256 discount = amount * series.basePrice / 20;
        uint256 avgPrice = series.currentPrice > discount ? series.currentPrice - discount : series.basePrice;
        return _max(avgPrice, series.basePrice) * amount;
    }

    function _calculateCurrentPrice(uint256 seriesId) internal view returns (uint256) {
        FanToken memory series = fanTokenSeries[seriesId];
        if (series.totalSupply == 0) return series.basePrice;
        return series.basePrice + (series.circulatingSupply * series.basePrice) / series.totalSupply;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) { return a > b ? a : b; }

    // View
    function getHoldings(uint256 seriesId, address holder) external view returns (uint256) {
        return holdings[seriesId][holder];
    }

    function getHolders(uint256 seriesId) external view returns (address[] memory) {
        return tokenHolders[seriesId];
    }

    function hasBenefits(uint256 seriesId, address holder) external view returns (bool) {
        return holdings[seriesId][holder] >= tokenBenefits[seriesId].minHoldingRequired;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
