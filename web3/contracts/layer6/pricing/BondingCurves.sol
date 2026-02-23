// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BondingCurves - Algorithmic pricing for OAN tokens (Layer 6, Phase 6.5)
contract BondingCurves is AccessControl, ReentrancyGuard {
    bytes32 public constant CURVE_MANAGER = keccak256("CURVE_MANAGER");

    enum CurveType { Linear, Exponential, Sigmoid, Logarithmic }

    struct Curve {
        uint256   curveId;
        string    name;
        CurveType curveType;
        address   creator;
        uint256   basePrice;     // wei — price at supply == 0
        uint256   slope;         // wei per token of supply (scaled 1e18)
        uint256   currentSupply;
        uint256   maxSupply;
        uint256   reserve;       // ETH held in contract backing sells
        uint256   totalBought;
        uint256   totalSold;
        bool      isActive;
        uint256   createdAt;
    }

    uint256 private _curveCounter;
    mapping(uint256 => Curve)                        public curves;
    mapping(uint256 => mapping(address => uint256))  public holdings;
    mapping(address => uint256[])                    public creatorCurves;

    address public treasury;
    uint256 public platformFeeBps = 100;   // 1 %

    event CurveCreated(uint256 indexed curveId, string name, CurveType curveType, uint256 maxSupply);
    event TokensBought(uint256 indexed curveId, address indexed buyer,  uint256 amount, uint256 cost);
    event TokensSold(uint256 indexed curveId,  address indexed seller, uint256 amount, uint256 proceeds);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CURVE_MANAGER,      msg.sender);
    }

    function createCurve(
        string memory name,
        CurveType curveType,
        uint256 basePrice,
        uint256 slope,
        uint256 maxSupply
    ) external returns (uint256) {
        require(basePrice > 0 && maxSupply > 0, "Invalid params");

        uint256 curveId = ++_curveCounter;
        curves[curveId] = Curve({
            curveId:       curveId,
            name:          name,
            curveType:     curveType,
            creator:       msg.sender,
            basePrice:     basePrice,
            slope:         slope,
            currentSupply: 0,
            maxSupply:     maxSupply,
            reserve:       0,
            totalBought:   0,
            totalSold:     0,
            isActive:      true,
            createdAt:     block.timestamp
        });
        creatorCurves[msg.sender].push(curveId);
        emit CurveCreated(curveId, name, curveType, maxSupply);
        return curveId;
    }

    function buy(uint256 curveId, uint256 amount) external payable nonReentrant {
        Curve storage c = curves[curveId];
        require(c.isActive,                              "Curve inactive");
        require(c.currentSupply + amount <= c.maxSupply, "Exceeds max supply");
        require(amount > 0,                              "Amount must be > 0");

        uint256 cost = calculateBuyCost(curveId, amount);
        require(msg.value >= cost, "Insufficient payment");

        c.currentSupply    += amount;
        c.reserve          += cost;
        c.totalBought      += amount;
        holdings[curveId][msg.sender] += amount;

        uint256 fee = (cost * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        c.reserve -= fee;
        if (msg.value > cost) payable(msg.sender).transfer(msg.value - cost);

        emit TokensBought(curveId, msg.sender, amount, cost);
    }

    function sell(uint256 curveId, uint256 amount) external nonReentrant {
        Curve storage c = curves[curveId];
        require(holdings[curveId][msg.sender] >= amount, "Insufficient holdings");
        require(amount > 0, "Amount must be > 0");

        uint256 proceeds = calculateSellProceeds(curveId, amount);
        require(c.reserve >= proceeds, "Insufficient reserve");

        c.currentSupply -= amount;
        c.reserve       -= proceeds;
        c.totalSold     += amount;
        holdings[curveId][msg.sender] -= amount;

        uint256 fee = (proceeds * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(msg.sender).transfer(proceeds - fee);

        emit TokensSold(curveId, msg.sender, amount, proceeds - fee);
    }

    function calculateBuyCost(uint256 curveId, uint256 amount) public view returns (uint256) {
        Curve memory c = curves[curveId];
        if (c.curveType == CurveType.Linear)      return _linearCost(c.basePrice, c.slope, c.currentSupply, amount);
        if (c.curveType == CurveType.Exponential) return _exponentialCost(c.basePrice, c.slope, c.currentSupply, amount);
        return _linearCost(c.basePrice, c.slope, c.currentSupply, amount); // default
    }

    function calculateSellProceeds(uint256 curveId, uint256 amount) public view returns (uint256) {
        // Sell at 95 % of buy cost to create a spread
        return (calculateBuyCost(curveId, amount) * 95) / 100;
    }

    function getCurrentPrice(uint256 curveId) external view returns (uint256) {
        return calculateBuyCost(curveId, 1);
    }

    function _linearCost(uint256 base, uint256 slope, uint256 supply, uint256 amount) internal pure returns (uint256) {
        // Area under linear curve: sum of prices from supply to supply+amount
        // = amount*base + slope*(supply*amount + amount*(amount-1)/2) / 1e18
        uint256 startPrice = base + (slope * supply) / 1e18;
        uint256 endPrice   = base + (slope * (supply + amount)) / 1e18;
        return ((startPrice + endPrice) * amount) / 2;
    }

    function _exponentialCost(uint256 base, uint256 slope, uint256 supply, uint256 amount) internal pure returns (uint256) {
        // Approximate by summing up to 50 steps then extrapolating
        uint256 steps = amount < 50 ? amount : 50;
        uint256 cost  = 0;
        for (uint256 i = 0; i < steps; i++) {
            cost += base + (base * slope * (supply + i)) / (1e18 * 100);
        }
        if (amount > 50) cost = (cost * amount) / 50;
        return cost;
    }

    function getHoldings(uint256 curveId, address user) external view returns (uint256) { return holdings[curveId][user]; }
    function getCreatorCurves(address creator) external view returns (uint256[] memory) { return creatorCurves[creator]; }
    function setPlatformFee(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) { require(bps <= 500); platformFeeBps = bps; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
