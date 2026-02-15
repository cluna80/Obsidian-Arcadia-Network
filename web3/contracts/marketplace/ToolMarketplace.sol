// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ToolMarketplace
 * @dev Marketplace for buying/selling entity tools
 */
contract ToolMarketplace is Ownable, ReentrancyGuard {
    
    struct Tool {
        string name;
        string description;
        address creator;
        uint256 price;
        bool active;
        uint256 totalSales;
        uint256 createdAt;
    }
    
    struct Listing {
        uint256 toolId;
        address seller;
        uint256 price;
        bool active;
    }
    
    mapping(uint256 => Tool) public tools;
    mapping(uint256 => Listing) public listings;
    mapping(address => mapping(uint256 => bool)) public ownership;
    
    uint256 private _nextToolId = 1;
    uint256 private _nextListingId = 1;
    
    uint256 public platformFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    event ToolCreated(uint256 indexed toolId, string name, address indexed creator, uint256 price);
    event ToolListed(uint256 indexed listingId, uint256 indexed toolId, address indexed seller, uint256 price);
    event ToolSold(uint256 indexed listingId, uint256 indexed toolId, address indexed buyer, uint256 price);
    event ToolDeactivated(uint256 indexed toolId);
    
    constructor() Ownable(msg.sender) {}
    
    function createTool(
        string memory name,
        string memory description,
        uint256 price
    ) external returns (uint256) {
        uint256 toolId = _nextToolId++;
        
        tools[toolId] = Tool({
            name: name,
            description: description,
            creator: msg.sender,
            price: price,
            active: true,
            totalSales: 0,
            createdAt: block.timestamp
        });
        
        ownership[msg.sender][toolId] = true;
        
        emit ToolCreated(toolId, name, msg.sender, price);
        return toolId;
    }
    
    function listTool(uint256 toolId, uint256 price) external returns (uint256) {
        require(ownership[msg.sender][toolId], "Not tool owner");
        require(tools[toolId].active, "Tool inactive");
        
        uint256 listingId = _nextListingId++;
        
        listings[listingId] = Listing({
            toolId: toolId,
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit ToolListed(listingId, toolId, msg.sender, price);
        return listingId;
    }
    
    function buyTool(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing inactive");
        require(msg.value >= listing.price, "Insufficient payment");
        
        Tool storage tool = tools[listing.toolId];
        require(tool.active, "Tool inactive");
        
        // Calculate fees
        uint256 fee = (listing.price * platformFee) / FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price - fee;
        
        // Transfer payment
        payable(listing.seller).transfer(sellerAmount);
        
        // Grant ownership
        ownership[msg.sender][listing.toolId] = true;
        
        // Update stats
        tool.totalSales++;
        listing.active = false;
        
        // Refund excess
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
        
        emit ToolSold(listingId, listing.toolId, msg.sender, listing.price);
    }
    
    function getTool(uint256 toolId) external view returns (Tool memory) {
        return tools[toolId];
    }
    
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }
    
    function hasTool(address owner, uint256 toolId) external view returns (bool) {
        return ownership[owner][toolId];
    }
    
    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
