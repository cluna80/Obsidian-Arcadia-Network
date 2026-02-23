// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
/// @title VenueMarketplace - Buy/sell/auction venues and seats (Layer 5, Phase 5.1)
contract VenueMarketplace is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    enum ListingType { Sale, Rental, Auction }
    enum ListingStatus { Active, Sold, Cancelled, Expired }
    struct Listing {
        uint256 listingId; address nftContract; uint256 tokenId; address seller;
        ListingType listingType; ListingStatus status; uint256 price;
        uint256 rentalDuration; uint256 auctionEndTime; uint256 highestBid;
        address highestBidder; uint256 createdAt; uint256 expiresAt;
    }
    struct Offer { address offerer; uint256 amount; uint256 timestamp; bool accepted; }
    uint256 private _listingIdCounter;
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer[]) public listingOffers;
    mapping(address => uint256[]) public sellerListings;
    mapping(address => uint256[]) public buyerPurchases;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => mapping(uint256 => address)) public originalCreator;
    uint256 public platformFeePercent = 250; uint256 public royaltyPercent = 200;
    address public treasury; uint256 public totalListings; uint256 public totalVolume;
    event Listed(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, ListingType t, uint256 price);
    event Sold(uint256 indexed listingId, address indexed buyer, uint256 price);
    event AuctionBid(uint256 indexed listingId, address indexed bidder, uint256 amount);
    event AuctionSettled(uint256 indexed listingId, address indexed winner, uint256 amount);
    event ListingCancelled(uint256 indexed listingId);
    constructor(address _treasury) { treasury = _treasury; _grantRole(DEFAULT_ADMIN_ROLE, msg.sender); _grantRole(OPERATOR_ROLE, msg.sender); }
    function listForSale(address nftContract, uint256 tokenId, uint256 price, uint256 duration) external returns (uint256) {
        require(price > 0, "Price > 0");
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        uint256 listingId = ++_listingIdCounter;
        listings[listingId] = Listing(listingId, nftContract, tokenId, msg.sender, ListingType.Sale, ListingStatus.Active, price, 0, 0, 0, address(0), block.timestamp, block.timestamp + duration);
        sellerListings[msg.sender].push(listingId); totalListings++;
        if (originalCreator[nftContract][tokenId] == address(0)) originalCreator[nftContract][tokenId] = msg.sender;
        emit Listed(listingId, msg.sender, nftContract, tokenId, ListingType.Sale, price);
        return listingId;
    }
    function listForAuction(address nftContract, uint256 tokenId, uint256 startingBid, uint256 duration) external returns (uint256) {
        require(startingBid > 0 && duration >= 1 hours, "Invalid params");
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        uint256 listingId = ++_listingIdCounter;
        listings[listingId] = Listing(listingId, nftContract, tokenId, msg.sender, ListingType.Auction, ListingStatus.Active, startingBid, 0, block.timestamp + duration, 0, address(0), block.timestamp, block.timestamp + duration);
        sellerListings[msg.sender].push(listingId); totalListings++;
        emit Listed(listingId, msg.sender, nftContract, tokenId, ListingType.Auction, startingBid);
        return listingId;
    }
    function buyNow(uint256 listingId) external payable nonReentrant {
        Listing storage l = listings[listingId];
        require(l.status == ListingStatus.Active && l.listingType == ListingType.Sale, "Not for sale");
        require(msg.value >= l.price && block.timestamp <= l.expiresAt, "Invalid");
        l.status = ListingStatus.Sold; totalVolume += l.price;
        _distributeFunds(l, msg.sender);
        IERC721(l.nftContract).transferFrom(address(this), msg.sender, l.tokenId);
        buyerPurchases[msg.sender].push(listingId);
        emit Sold(listingId, msg.sender, l.price);
    }
    function bidAuction(uint256 listingId) external payable nonReentrant {
        Listing storage l = listings[listingId];
        require(l.status == ListingStatus.Active && l.listingType == ListingType.Auction, "Not auction");
        require(block.timestamp < l.auctionEndTime && msg.value > l.highestBid && msg.value >= l.price, "Bid too low");
        if (l.highestBidder != address(0)) pendingWithdrawals[l.highestBidder] += l.highestBid;
        l.highestBid = msg.value; l.highestBidder = msg.sender;
        emit AuctionBid(listingId, msg.sender, msg.value);
    }
    function settleAuction(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        require(l.listingType == ListingType.Auction && block.timestamp >= l.auctionEndTime && l.status == ListingStatus.Active, "Cannot settle");
        l.status = ListingStatus.Sold;
        if (l.highestBidder != address(0)) {
            totalVolume += l.highestBid; l.price = l.highestBid;
            _distributeFunds(l, l.highestBidder);
            IERC721(l.nftContract).transferFrom(address(this), l.highestBidder, l.tokenId);
            emit AuctionSettled(listingId, l.highestBidder, l.highestBid);
        } else { l.status = ListingStatus.Cancelled; IERC721(l.nftContract).transferFrom(address(this), l.seller, l.tokenId); }
    }
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage l = listings[listingId];
        require(l.seller == msg.sender || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(l.status == ListingStatus.Active && l.highestBidder == address(0), "Cannot cancel");
        l.status = ListingStatus.Cancelled;
        IERC721(l.nftContract).transferFrom(address(this), l.seller, l.tokenId);
        emit ListingCancelled(listingId);
    }
    function withdrawPending() external nonReentrant { uint256 a = pendingWithdrawals[msg.sender]; require(a > 0, "Nothing"); pendingWithdrawals[msg.sender] = 0; payable(msg.sender).transfer(a); }
    function _distributeFunds(Listing memory l, address buyer) internal {
        uint256 fee = (l.price * platformFeePercent) / 10000;
        address creator = originalCreator[l.nftContract][l.tokenId];
        uint256 royalty = (creator != address(0) && creator != l.seller) ? (l.price * royaltyPercent) / 10000 : 0;
        payable(treasury).transfer(fee);
        if (royalty > 0) payable(creator).transfer(royalty);
        payable(l.seller).transfer(l.price - fee - royalty);
    }
    function getSellerListings(address s) external view returns (uint256[] memory) { return sellerListings[s]; }
    function getListingOffers(uint256 id) external view returns (Offer[] memory) { return listingOffers[id]; }
    function setPlatformFee(uint256 f) external onlyRole(DEFAULT_ADMIN_ROLE) { require(f <= 1000, "Max 10%"); platformFeePercent = f; }
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) { return super.supportsInterface(interfaceId); }
}
