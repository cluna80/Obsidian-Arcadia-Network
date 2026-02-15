// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EntityMarketplace
 * @dev Buy, sell, and trade OAN entities as NFTs
 */
contract EntityMarketplace is Ownable, ReentrancyGuard {
    
    struct Listing {
        uint256 tokenId;
        address nftContract;
        address seller;
        uint256 price;
        uint256 listedAt;
        bool active;
        bool isAuction;
        uint256 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
    }
    
    struct Offer {
        address offerer;
        uint256 amount;
        uint256 expiresAt;
        bool active;
    }
    
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer[]) public offers;
    
    uint256 public listingCount;
    uint256 public platformFee = 250; // 2.5%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    uint256 public totalVolume;
    uint256 public totalSales;
    
    event EntityListed(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );
    event EntitySold(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 price
    );
    event ListingCanceled(uint256 indexed listingId);
    event OfferMade(uint256 indexed listingId, address indexed offerer, uint256 amount);
    event OfferAccepted(uint256 indexed listingId, address indexed offerer, uint256 amount);
    
    constructor() Ownable(msg.sender) {}
    
    function listEntity(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        bool isAuction,
        uint256 auctionDuration
    ) external returns (uint256) {
        require(price > 0, "Invalid price");
        
        uint256 listingId = listingCount++;
        
        listings[listingId] = Listing({
            tokenId: tokenId,
            nftContract: nftContract,
            seller: msg.sender,
            price: price,
            listedAt: block.timestamp,
            active: true,
            isAuction: isAuction,
            auctionEndTime: isAuction ? block.timestamp + auctionDuration : 0,
            highestBidder: address(0),
            highestBid: 0
        });
        
        emit EntityListed(listingId, msg.sender, tokenId, price);
        return listingId;
    }
    
    function buyEntity(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing inactive");
        require(!listing.isAuction, "Cannot buy auction");
        require(msg.value >= listing.price, "Insufficient payment");
        
        uint256 fee = (listing.price * platformFee) / FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price - fee;
        
        listing.active = false;
        totalVolume += listing.price;
        totalSales++;
        
        payable(listing.seller).transfer(sellerAmount);
        
        if (msg.value > listing.price) {
            payable(msg.sender).transfer(msg.value - listing.price);
        }
        
        emit EntitySold(listingId, msg.sender, listing.price);
    }
    
    function placeBid(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing inactive");
        require(listing.isAuction, "Not an auction");
        require(block.timestamp < listing.auctionEndTime, "Auction ended");
        require(msg.value > listing.highestBid, "Bid too low");
        
        // Refund previous bidder
        if (listing.highestBidder != address(0)) {
            payable(listing.highestBidder).transfer(listing.highestBid);
        }
        
        listing.highestBidder = msg.sender;
        listing.highestBid = msg.value;
    }
    
    function finalizeAuction(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing inactive");
        require(listing.isAuction, "Not an auction");
        require(block.timestamp >= listing.auctionEndTime, "Auction not ended");
        
        listing.active = false;
        
        if (listing.highestBidder != address(0)) {
            uint256 fee = (listing.highestBid * platformFee) / FEE_DENOMINATOR;
            uint256 sellerAmount = listing.highestBid - fee;
            
            totalVolume += listing.highestBid;
            totalSales++;
            
            payable(listing.seller).transfer(sellerAmount);
            
            emit EntitySold(listingId, listing.highestBidder, listing.highestBid);
        }
    }
    
    function makeOffer(uint256 listingId, uint256 duration) external payable {
        require(msg.value > 0, "Invalid offer");
        
        offers[listingId].push(Offer({
            offerer: msg.sender,
            amount: msg.value,
            expiresAt: block.timestamp + duration,
            active: true
        }));
        
        emit OfferMade(listingId, msg.sender, msg.value);
    }
    
    function acceptOffer(uint256 listingId, uint256 offerIndex) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Listing inactive");
        
        Offer storage offer = offers[listingId][offerIndex];
        require(offer.active, "Offer inactive");
        require(block.timestamp < offer.expiresAt, "Offer expired");
        
        uint256 fee = (offer.amount * platformFee) / FEE_DENOMINATOR;
        uint256 sellerAmount = offer.amount - fee;
        
        listing.active = false;
        offer.active = false;
        totalVolume += offer.amount;
        totalSales++;
        
        payable(listing.seller).transfer(sellerAmount);
        
        emit OfferAccepted(listingId, offer.offerer, offer.amount);
    }
    
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.active, "Already inactive");
        
        listing.active = false;
        
        emit ListingCanceled(listingId);
    }
    
    function getMarketplaceStats() external view returns (
        uint256 totalListings,
        uint256 volume,
        uint256 sales,
        uint256 fee
    ) {
        return (listingCount, totalVolume, totalSales, platformFee);
    }
    
    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
