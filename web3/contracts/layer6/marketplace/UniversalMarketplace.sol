// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniversalMarketplace is ReentrancyGuard, Ownable {
    
    struct Listing {
        uint256 listingId;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        TokenType tokenType;
        string category;
        uint8 status;                 // 0=Active, 1=Sold, 2=Cancelled
        uint256 listedAt;
        uint256 expiresAt;
    }
    
    struct Sale {
        uint256 saleId;
        uint256 listingId;
        address buyer;
        address seller;
        uint256 price;
        uint256 timestamp;
        uint256 platformFee;
        uint256 creatorRoyalty;
    }
    
    enum TokenType {ERC721, ERC1155}
    
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Sale) public sales;
    mapping(address => uint256[]) public userListings;
    mapping(address => uint256) public sellerVolume;
    mapping(address => mapping(uint256 => uint256)) public creatorRoyaltyBps;
    
    uint256 public listingCount;
    uint256 public saleCount;
    uint256 public totalVolume;       // NEW: Track total marketplace volume
    uint256 public basePlatformFee = 250;
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    address public reputationOracle;
    
    event Listed(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event Sold(uint256 indexed saleId, uint256 indexed listingId, address indexed buyer, uint256 price);
    event Delisted(uint256 indexed listingId);
    event PriceUpdated(uint256 indexed listingId, uint256 oldPrice, uint256 newPrice);
    
    constructor(address _reputationOracle) Ownable(msg.sender) {
        reputationOracle = _reputationOracle;
    }
    
    function listItem(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        uint256 price,
        TokenType tokenType,
        uint256 duration,
        string memory category
    ) external returns (uint256) {
        require(price > 0, "Price must be > 0");
        
        if (tokenType == TokenType.ERC721) {
            require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
            require(
                IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContract).getApproved(tokenId) == address(this),
                "Not approved"
            );
        } else {
            require(
                IERC1155(nftContract).balanceOf(msg.sender, tokenId) >= amount,
                "Insufficient balance"
            );
            require(
                IERC1155(nftContract).isApprovedForAll(msg.sender, address(this)),
                "Not approved"
            );
        }
        
        listingCount++;
        uint256 listingId = listingCount;
        
        listings[listingId] = Listing({
            listingId: listingId,
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            price: price,
            tokenType: tokenType,
            category: category,
            status: 0,
            listedAt: block.timestamp,
            expiresAt: block.timestamp + duration
        });
        
        userListings[msg.sender].push(listingId);
        
        emit Listed(listingId, msg.sender, nftContract, tokenId, price);
        return listingId;
    }
    
    function buyItem(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.status == 0, "Not active");
        require(block.timestamp <= listing.expiresAt, "Expired");
        require(msg.value >= listing.price, "Insufficient payment");
        
        listing.status = 1; // Sold
        
        uint256 platformFee = _calculatePlatformFee(listing.seller, listing.price);
        uint256 royalty = _calculateRoyalty(listing.nftContract, listing.tokenId, listing.price);
        uint256 sellerProceeds = listing.price - platformFee - royalty;
        
        saleCount++;
        sales[saleCount] = Sale({
            saleId: saleCount,
            listingId: listingId,
            buyer: msg.sender,
            seller: listing.seller,
            price: listing.price,
            timestamp: block.timestamp,
            platformFee: platformFee,
            creatorRoyalty: royalty
        });
        
        if (listing.tokenType == TokenType.ERC721) {
            IERC721(listing.nftContract).safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId
            );
        } else {
            IERC1155(listing.nftContract).safeTransferFrom(
                listing.seller,
                msg.sender,
                listing.tokenId,
                listing.amount,
                ""
            );
        }
        
        payable(listing.seller).transfer(sellerProceeds);
        payable(owner()).transfer(platformFee);
        
        if (royalty > 0) {
            payable(listing.seller).transfer(royalty);
        }
        
        sellerVolume[listing.seller] += listing.price;
        totalVolume += listing.price;  // Track total volume
        
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
        
        emit Sold(saleCount, listingId, msg.sender, listing.price);
    }
    
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.status == 0, "Not active");
        
        listing.status = 2; // Cancelled
        
        emit Delisted(listingId);
    }
    
    function updatePrice(uint256 listingId, uint256 newPrice) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.status == 0, "Not active");
        require(newPrice > 0, "Price must be > 0");
        
        uint256 oldPrice = listing.price;
        listing.price = newPrice;
        
        emit PriceUpdated(listingId, oldPrice, newPrice);
    }
    
    function setCreatorRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 royaltyBps
    ) external {
        require(royaltyBps <= 1000, "Max 10%");
        creatorRoyaltyBps[nftContract][tokenId] = royaltyBps;
    }
    
    function _calculatePlatformFee(address, uint256 price) internal view returns (uint256) {
        return (price * basePlatformFee) / FEE_DENOMINATOR;
    }
    
    function _calculateRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) internal view returns (uint256) {
        uint256 royaltyBps = creatorRoyaltyBps[nftContract][tokenId];
        if (royaltyBps == 0) return 0;
        return (price * royaltyBps) / FEE_DENOMINATOR;
    }
    
    function getActiveListings(uint256 offset, uint256 limit) 
        external 
        view 
        returns (Listing[] memory) 
    {
        uint256 activeCount = 0;
        for (uint256 i = 1; i <= listingCount; i++) {
            if (listings[i].status == 0 && block.timestamp <= listings[i].expiresAt) {
                activeCount++;
            }
        }
        
        uint256 size = activeCount < limit ? activeCount : limit;
        Listing[] memory result = new Listing[](size);
        
        uint256 index = 0;
        uint256 skipped = 0;
        
        for (uint256 i = 1; i <= listingCount && index < size; i++) {
            if (listings[i].status == 0 && block.timestamp <= listings[i].expiresAt) {
                if (skipped < offset) {
                    skipped++;
                    continue;
                }
                result[index] = listings[i];
                index++;
            }
        }
        
        return result;
    }
    
    function getUserListings(address user) external view returns (uint256[] memory) {
        return userListings[user];
    }
}
