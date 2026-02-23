// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AIToolMarketplace - Buy/sell AI behaviors & tools (Layer 6, Phase 6.2)
contract AIToolMarketplace is AccessControl, ReentrancyGuard {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");

    enum ToolCategory { Combat, Strategy, Social, Economic, Creative, Navigation, Analysis, Communication }
    enum LicenseType  { Perpetual, Subscription, SingleUse, OpenSource }

    struct AITool {
        uint256      toolId;
        string       name;
        string       description;
        address      creator;
        ToolCategory category;
        LicenseType  licenseType;
        uint256      price;
        uint256      subscriptionPrice;
        uint256      totalSales;
        uint256      totalRevenue;
        uint256      rating;
        uint256      ratingCount;
        bool         isActive;
        bool         isVerified;
        string       metadataURI;
        uint256      createdAt;
        string       version;
    }

    struct Purchase {
        uint256     purchaseId;
        uint256     toolId;
        address     buyer;
        uint256     price;
        LicenseType licenseType;
        uint256     timestamp;
        uint256     expiresAt;
        bool        isActive;
    }

    uint256 private _toolCounter;
    uint256 private _purchaseCounter;

    mapping(uint256 => AITool)   public tools;
    mapping(uint256 => Purchase) public purchases;
    mapping(address => uint256[]) public creatorTools;
    mapping(address => uint256[]) public buyerPurchases;
    mapping(address => mapping(uint256 => uint256)) public userLicense;   // buyer => toolId => purchaseId
    mapping(address => mapping(uint256 => bool))    public hasRated;

    address public treasury;
    uint256 public platformFeeBps = 500;   // 5 %
    uint256 public totalTools;
    uint256 public totalVolume;

    event ToolListed(uint256 indexed toolId, address indexed creator, string name, ToolCategory category, uint256 price);
    event ToolPurchased(uint256 indexed purchaseId, uint256 indexed toolId, address indexed buyer, uint256 price);
    event ToolRated(uint256 indexed toolId, address indexed rater, uint256 rating);
    event ToolVerified(uint256 indexed toolId);
    event ToolDeactivated(uint256 indexed toolId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CURATOR_ROLE,       msg.sender);
    }

    function listTool(
        string memory name,
        string memory description,
        ToolCategory category,
        LicenseType licenseType,
        uint256 price,
        uint256 subscriptionPrice,
        string memory metadataURI,
        string memory version
    ) external returns (uint256) {
        require(bytes(name).length > 0 && price > 0, "Invalid params");

        uint256 toolId = ++_toolCounter;
        tools[toolId] = AITool({
            toolId:            toolId,
            name:              name,
            description:       description,
            creator:           msg.sender,
            category:          category,
            licenseType:       licenseType,
            price:             price,
            subscriptionPrice: subscriptionPrice,
            totalSales:        0,
            totalRevenue:      0,
            rating:            0,
            ratingCount:       0,
            isActive:          true,
            isVerified:        false,
            metadataURI:       metadataURI,
            createdAt:         block.timestamp,
            version:           version
        });

        creatorTools[msg.sender].push(toolId);
        totalTools++;
        emit ToolListed(toolId, msg.sender, name, category, price);
        return toolId;
    }

    function purchaseTool(uint256 toolId, LicenseType licenseType) external payable nonReentrant returns (uint256) {
        AITool storage t = tools[toolId];
        require(t.isActive,              "Tool not active");
        require(t.creator != msg.sender, "Cannot buy own tool");

        uint256 requiredPrice = licenseType == LicenseType.Subscription ? t.subscriptionPrice : t.price;
        require(msg.value >= requiredPrice, "Insufficient payment");

        uint256 expiry = licenseType == LicenseType.Subscription ? block.timestamp + 30 days : 0;
        uint256 purchaseId = ++_purchaseCounter;
        purchases[purchaseId] = Purchase({
            purchaseId:  purchaseId,
            toolId:      toolId,
            buyer:       msg.sender,
            price:       msg.value,
            licenseType: licenseType,
            timestamp:   block.timestamp,
            expiresAt:   expiry,
            isActive:    true
        });

        buyerPurchases[msg.sender].push(purchaseId);
        userLicense[msg.sender][toolId] = purchaseId;
        t.totalSales++;
        t.totalRevenue += msg.value;

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(t.creator).transfer(msg.value - fee);
        totalVolume += msg.value;

        emit ToolPurchased(purchaseId, toolId, msg.sender, msg.value);
        return purchaseId;
    }

    function rateTool(uint256 toolId, uint256 rating) external {
        require(userLicense[msg.sender][toolId] != 0, "Must own tool to rate");
        require(!hasRated[msg.sender][toolId],         "Already rated");
        require(rating >= 1 && rating <= 5,           "Rating 1-5");

        hasRated[msg.sender][toolId] = true;
        AITool storage t = tools[toolId];
        t.ratingCount++;
        t.rating = ((t.rating * (t.ratingCount - 1)) + (rating * 100)) / t.ratingCount;
        emit ToolRated(toolId, msg.sender, rating);
    }

    function verifyTool(uint256 toolId) external onlyRole(CURATOR_ROLE) {
        tools[toolId].isVerified = true;
        emit ToolVerified(toolId);
    }

    function deactivateTool(uint256 toolId) external {
        require(tools[toolId].creator == msg.sender || hasRole(CURATOR_ROLE, msg.sender), "Not authorized");
        tools[toolId].isActive = false;
        emit ToolDeactivated(toolId);
    }

    function hasAccess(address user, uint256 toolId) external view returns (bool) {
        uint256 purchaseId = userLicense[user][toolId];
        if (purchaseId == 0) return false;
        Purchase memory p = purchases[purchaseId];
        if (p.licenseType == LicenseType.Subscription) return block.timestamp <= p.expiresAt;
        return p.isActive;
    }

    function getCreatorTools(address creator)   external view returns (uint256[] memory) { return creatorTools[creator]; }
    function getBuyerPurchases(address buyer)    external view returns (uint256[] memory) { return buyerPurchases[buyer]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
