// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title OfferSystem - Make/accept offers on any OAN asset (Layer 6, Phase 6.1)
contract OfferSystem is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum TokenType   { ERC721, ERC1155 }
    enum OfferStatus { Active, Accepted, Rejected, Cancelled, Expired }

    struct Offer {
        uint256     offerId;
        address     offerer;
        address     nftContract;
        uint256     tokenId;
        uint256     amount;
        uint256     offerPrice;
        TokenType   tokenType;
        OfferStatus status;
        uint256     createdAt;
        uint256     expiresAt;
        string      message;
    }

    struct CounterOffer {
        uint256 offerId;
        uint256 counterPrice;
        address counterFrom;
        uint256 timestamp;
    }

    uint256 private _offerCounter;
    mapping(uint256 => Offer)           public offers;
    mapping(address => uint256[])       public offererOffers;
    mapping(address => mapping(uint256 => uint256[])) public nftOffers;
    mapping(uint256 => CounterOffer[])  public counterOffers;

    address public treasury;
    uint256 public platformFeeBps = 250;
    uint256 public totalOffersCreated;
    uint256 public totalOffersAccepted;

    event OfferCreated(uint256 indexed offerId, address indexed offerer, address nftContract, uint256 tokenId, uint256 price);
    event OfferAccepted(uint256 indexed offerId, address indexed seller, uint256 price);
    event OfferRejected(uint256 indexed offerId);
    event OfferCancelled(uint256 indexed offerId);
    event CounterOfferMade(uint256 indexed offerId, uint256 counterPrice);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE,      msg.sender);
    }

    function makeOffer(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        TokenType tokenType,
        uint256 duration,
        string memory message
    ) external payable nonReentrant returns (uint256) {
        require(msg.value > 0, "Offer must be > 0");
        require(duration >= 1 hours && duration <= 30 days, "Invalid duration");

        uint256 offerId = ++_offerCounter;
        offers[offerId] = Offer({
            offerId:    offerId,
            offerer:    msg.sender,
            nftContract: nftContract,
            tokenId:    tokenId,
            amount:     amount,
            offerPrice: msg.value,
            tokenType:  tokenType,
            status:     OfferStatus.Active,
            createdAt:  block.timestamp,
            expiresAt:  block.timestamp + duration,
            message:    message
        });

        offererOffers[msg.sender].push(offerId);
        nftOffers[nftContract][tokenId].push(offerId);
        totalOffersCreated++;
        emit OfferCreated(offerId, msg.sender, nftContract, tokenId, msg.value);
        return offerId;
    }

    function acceptOffer(uint256 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        require(o.status == OfferStatus.Active,       "Not active");
        require(block.timestamp <= o.expiresAt,       "Expired");

        if (o.tokenType == TokenType.ERC721)
            require(IERC721(o.nftContract).ownerOf(o.tokenId) == msg.sender, "Not owner");
        else
            require(IERC1155(o.nftContract).balanceOf(msg.sender, o.tokenId) >= o.amount, "Balance");

        o.status = OfferStatus.Accepted;
        totalOffersAccepted++;

        if (o.tokenType == TokenType.ERC721)
            IERC721(o.nftContract).safeTransferFrom(msg.sender, o.offerer, o.tokenId);
        else
            IERC1155(o.nftContract).safeTransferFrom(msg.sender, o.offerer, o.tokenId, o.amount, "");

        uint256 fee = (o.offerPrice * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(msg.sender).transfer(o.offerPrice - fee);
        emit OfferAccepted(offerId, msg.sender, o.offerPrice);
    }

    function rejectOffer(uint256 offerId) external {
        Offer storage o = offers[offerId];
        require(o.status == OfferStatus.Active, "Not active");
        o.status = OfferStatus.Rejected;
        emit OfferRejected(offerId);
    }

    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        require(o.offerer == msg.sender,          "Not offerer");
        require(o.status == OfferStatus.Active,   "Not active");
        o.status = OfferStatus.Cancelled;
        payable(msg.sender).transfer(o.offerPrice);
        emit OfferCancelled(offerId);
    }

    function makeCounterOffer(uint256 offerId, uint256 counterPrice) external {
        require(offers[offerId].status == OfferStatus.Active, "Not active");
        counterOffers[offerId].push(CounterOffer({
            offerId:      offerId,
            counterPrice: counterPrice,
            counterFrom:  msg.sender,
            timestamp:    block.timestamp
        }));
        emit CounterOfferMade(offerId, counterPrice);
    }

    function claimExpiredOffer(uint256 offerId) external nonReentrant {
        Offer storage o = offers[offerId];
        require(o.offerer == msg.sender,                   "Not offerer");
        require(block.timestamp > o.expiresAt,             "Not expired");
        require(o.status == OfferStatus.Active,            "Not active");
        o.status = OfferStatus.Expired;
        payable(msg.sender).transfer(o.offerPrice);
    }

    function getOffersForNFT(address nftContract, uint256 tokenId) external view returns (uint256[] memory) { return nftOffers[nftContract][tokenId]; }
    function getOffererOffers(address offerer) external view returns (uint256[] memory)  { return offererOffers[offerer]; }
    function getCounterOffers(uint256 offerId) external view returns (CounterOffer[] memory) { return counterOffers[offerId]; }
    function setPlatformFee(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) { require(bps <= 1000); platformFeeBps = bps; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
