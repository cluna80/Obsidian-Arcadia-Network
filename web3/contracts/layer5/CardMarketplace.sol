// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @title CardMarketplace - Trade sports cards and athletes
/// @notice Layer 5, Phase 5.2 - OAN Metaverse Sports Arena
contract CardMarketplace is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum TokenStandard { ERC721, ERC1155 }
    enum ListingStatus { Active, Sold, Cancelled }

    struct Listing {
        uint256 listingId;
        address nftContract;
        uint256 tokenId;
        uint256 quantity;           // 1 for ERC721, N for ERC1155
        TokenStandard standard;
        address seller;
        uint256 pricePerUnit;
        ListingStatus status;
        uint256 createdAt;
        uint256 expiresAt;
        string category;            // "card", "athlete", "team"
    }

    struct Offer {
        address offerer;
        uint256 amount;
        uint256 quantity;
        uint256 timestamp;
        bool active;
    }

    uint256 private _listingIdCounter;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer[]) public offers;
    mapping(address => uint256[]) public sellerListings;
    mapping(address => uint256[]) public buyerHistory;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public totalVolumeBySeller;

    // Stats
    uint256 public totalVolume;
    uint256 public totalListings;
    uint256 public totalSales;

    address public treasury;
    uint256 public platformFeePercent = 250;    // 2.5%
    uint256 public creatorRoyaltyPercent = 200; // 2.0%

    mapping(address => mapping(uint256 => address)) public creatorOf; // contract => tokenId => creator

    event Listed(uint256 indexed listingId, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event Sold(uint256 indexed listingId, address indexed buyer, uint256 quantity, uint256 totalPrice);
    event OfferMade(uint256 indexed listingId, address indexed offerer, uint256 amount);
    event OfferAccepted(uint256 indexed listingId, uint256 offerIndex);
    event ListingCancelled(uint256 indexed listingId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /// @notice List an ERC721 (athlete, team) for sale
    function listERC721(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 duration,
        string memory category
    ) external returns (uint256) {
        require(price > 0, "Price must be > 0");
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        uint256 listingId = ++_listingIdCounter;
        listings[listingId] = Listing({
            listingId: listingId,
            nftContract: nftContract,
            tokenId: tokenId,
            quantity: 1,
            standard: TokenStandard.ERC721,
            seller: msg.sender,
            pricePerUnit: price,
            status: ListingStatus.Active,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + duration,
            category: category
        });

        sellerListings[msg.sender].push(listingId);
        totalListings++;

        if (creatorOf[nftContract][tokenId] == address(0)) {
            creatorOf[nftContract][tokenId] = msg.sender;
        }

        emit Listed(listingId, msg.sender, nftContract, tokenId, price);
        return listingId;
    }

    /// @notice List ERC1155 cards for sale
    function listERC1155(
        address nftContract,
        uint256 tokenId,
        uint256 quantity,
        uint256 pricePerUnit,
        uint256 duration,
        string memory category
    ) external returns (uint256) {
        require(pricePerUnit > 0 && quantity > 0, "Invalid params");
        IERC1155(nftContract).safeTransferFrom(msg.sender, address(this), tokenId, quantity, "");

        uint256 listingId = ++_listingIdCounter;
        listings[listingId] = Listing({
            listingId: listingId,
            nftContract: nftContract,
            tokenId: tokenId,
            quantity: quantity,
            standard: TokenStandard.ERC1155,
            seller: msg.sender,
            pricePerUnit: pricePerUnit,
            status: ListingStatus.Active,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + duration,
            category: category
        });

        sellerListings[msg.sender].push(listingId);
        totalListings++;

        emit Listed(listingId, msg.sender, nftContract, tokenId, pricePerUnit);
        return listingId;
    }

    /// @notice Buy a listed item
    function buy(uint256 listingId, uint256 quantity) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.status == ListingStatus.Active, "Not active");
        require(block.timestamp <= listing.expiresAt, "Listing expired");

        uint256 buyQuantity = (listing.standard == TokenStandard.ERC721) ? 1 : quantity;
        require(buyQuantity <= listing.quantity, "Not enough quantity");

        uint256 totalPrice = listing.pricePerUnit * buyQuantity;
        require(msg.value >= totalPrice, "Insufficient payment");

        listing.quantity -= buyQuantity;
        if (listing.quantity == 0) {
            listing.status = ListingStatus.Sold;
        }

        _distributeFunds(listing, totalPrice);

        if (listing.standard == TokenStandard.ERC721) {
            IERC721(listing.nftContract).transferFrom(address(this), msg.sender, listing.tokenId);
        } else {
            IERC1155(listing.nftContract).safeTransferFrom(address(this), msg.sender, listing.tokenId, buyQuantity, "");
        }

        totalVolume += totalPrice;
        totalSales++;
        totalVolumeBySeller[listing.seller] += totalPrice;
        buyerHistory[msg.sender].push(listingId);

        emit Sold(listingId, msg.sender, buyQuantity, totalPrice);
    }

    /// @notice Make an offer on a listing
    function makeOffer(uint256 listingId, uint256 quantity) external payable {
        require(listings[listingId].status == ListingStatus.Active, "Not active");
        require(msg.value > 0, "Offer must be > 0");

        offers[listingId].push(Offer({
            offerer: msg.sender,
            amount: msg.value,
            quantity: quantity,
            timestamp: block.timestamp,
            active: true
        }));

        emit OfferMade(listingId, msg.sender, msg.value);
    }

    /// @notice Accept an offer
    function acceptOffer(uint256 listingId, uint256 offerIndex) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not seller");
        require(listing.status == ListingStatus.Active, "Not active");

        Offer storage offer = offers[listingId][offerIndex];
        require(offer.active, "Offer not active");
        offer.active = false;

        uint256 buyQty = (listing.standard == TokenStandard.ERC721) ? 1 : offer.quantity;
        listing.quantity -= buyQty;
        if (listing.quantity == 0) listing.status = ListingStatus.Sold;

        _distributeFunds(listing, offer.amount);

        if (listing.standard == TokenStandard.ERC721) {
            IERC721(listing.nftContract).transferFrom(address(this), offer.offerer, listing.tokenId);
        } else {
            IERC1155(listing.nftContract).safeTransferFrom(address(this), offer.offerer, listing.tokenId, buyQty, "");
        }

        totalVolume += offer.amount;
        emit OfferAccepted(listingId, offerIndex);
    }

    /// @notice Cancel a listing
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(listing.status == ListingStatus.Active, "Not active");

        listing.status = ListingStatus.Cancelled;

        if (listing.standard == TokenStandard.ERC721) {
            IERC721(listing.nftContract).transferFrom(address(this), listing.seller, listing.tokenId);
        } else {
            IERC1155(listing.nftContract).safeTransferFrom(address(this), listing.seller, listing.tokenId, listing.quantity, "");
        }

        emit ListingCancelled(listingId);
    }

    /// @notice Withdraw pending refunds
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function _distributeFunds(Listing memory listing, uint256 salePrice) internal {
        uint256 platformFee = (salePrice * platformFeePercent) / 10000;
        address creator = creatorOf[listing.nftContract][listing.tokenId];
        uint256 royalty = (creator != address(0) && creator != listing.seller)
            ? (salePrice * creatorRoyaltyPercent) / 10000
            : 0;
        uint256 sellerAmount = salePrice - platformFee - royalty;

        payable(treasury).transfer(platformFee);
        if (royalty > 0) payable(creator).transfer(royalty);
        payable(listing.seller).transfer(sellerAmount);
    }

    // ERC1155 receiver
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // View
    function getSellerListings(address seller) external view returns (uint256[] memory) {
        return sellerListings[seller];
    }

    function getBuyerHistory(address buyer) external view returns (uint256[] memory) {
        return buyerHistory[buyer];
    }

    function getListingOffers(uint256 listingId) external view returns (Offer[] memory) {
        return offers[listingId];
    }

    // Admin
    function setPlatformFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 1000, "Max 10%");
        platformFeePercent = newFee;
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
