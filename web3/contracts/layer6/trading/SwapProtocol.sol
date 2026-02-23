// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SwapProtocol - Peer-to-peer asset-for-asset trading (Layer 6, Phase 6.6)
contract SwapProtocol is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum TokenType  { ERC721, ERC1155 }
    enum SwapStatus { Pending, Accepted, Cancelled, Expired }

    struct SwapItem {
        address   nftContract;
        uint256   tokenId;
        uint256   amount;     // 1 for ERC721, quantity for ERC1155
        TokenType tokenType;
    }

    struct SwapOffer {
        uint256    offerId;
        address    offeror;
        address    counterparty;
        uint256    ethSupplement; // extra ETH from offeror to sweeten the deal
        SwapStatus status;
        uint256    createdAt;
        uint256    expiresAt;
        string     message;
    }

    uint256 private _offerCounter;
    mapping(uint256 => SwapOffer)   public swapOffers;
    mapping(uint256 => SwapItem[])  public offerItems;   // what offeror gives
    mapping(uint256 => SwapItem[])  public wantItems;    // what offeror wants back
    mapping(address => uint256[])   public userOffers;
    mapping(address => uint256[])   public receivedOffers;

    address public treasury;
    uint256 public platformFeeBps = 100;  // 1 % on ETH supplement only
    uint256 public totalSwaps;

    event SwapOffered(uint256 indexed offerId, address indexed offeror, address indexed counterparty);
    event SwapAccepted(uint256 indexed offerId);
    event SwapCancelled(uint256 indexed offerId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE,      msg.sender);
    }

    function proposeSwap(
        address counterparty,
        SwapItem[] memory _offerItems,
        SwapItem[] memory _wantItems,
        uint256 duration,
        string memory message
    ) external payable returns (uint256) {
        require(_offerItems.length > 0 && _wantItems.length > 0, "Must offer and want items");
        require(counterparty != msg.sender,                       "No self-swap");
        require(duration >= 1 hours && duration <= 30 days,       "Invalid duration");

        // Escrow offeror's items now
        for (uint256 i = 0; i < _offerItems.length; i++) {
            _escrowItem(_offerItems[i], msg.sender);
        }

        uint256 offerId = ++_offerCounter;
        SwapOffer storage s = swapOffers[offerId];
        s.offerId        = offerId;
        s.offeror        = msg.sender;
        s.counterparty   = counterparty;
        s.ethSupplement  = msg.value;
        s.status         = SwapStatus.Pending;
        s.createdAt      = block.timestamp;
        s.expiresAt      = block.timestamp + duration;
        s.message        = message;

        for (uint256 i = 0; i < _offerItems.length; i++) offerItems[offerId].push(_offerItems[i]);
        for (uint256 i = 0; i < _wantItems.length;  i++) wantItems[offerId].push(_wantItems[i]);

        userOffers[msg.sender].push(offerId);
        receivedOffers[counterparty].push(offerId);

        emit SwapOffered(offerId, msg.sender, counterparty);
        return offerId;
    }

    function acceptSwap(uint256 offerId) external nonReentrant {
        SwapOffer storage s = swapOffers[offerId];
        require(s.counterparty == msg.sender,      "Not counterparty");
        require(s.status == SwapStatus.Pending,    "Not pending");
        require(block.timestamp <= s.expiresAt,    "Offer expired");

        // Escrow counterparty's items
        SwapItem[] storage want = wantItems[offerId];
        for (uint256 i = 0; i < want.length; i++) _escrowItem(want[i], msg.sender);

        s.status = SwapStatus.Accepted;

        // Release escrowed offer items → counterparty
        SwapItem[] storage offer = offerItems[offerId];
        for (uint256 i = 0; i < offer.length; i++) _releaseItem(offer[i], msg.sender);

        // Release escrowed want items → offeror
        for (uint256 i = 0; i < want.length; i++) _releaseItem(want[i], s.offeror);

        // Forward ETH supplement with fee
        if (s.ethSupplement > 0) {
            uint256 fee = (s.ethSupplement * platformFeeBps) / 10000;
            payable(treasury).transfer(fee);
            payable(msg.sender).transfer(s.ethSupplement - fee);
        }

        totalSwaps++;
        emit SwapAccepted(offerId);
    }

    function cancelSwap(uint256 offerId) external nonReentrant {
        SwapOffer storage s = swapOffers[offerId];
        require(
            s.offeror == msg.sender ||
            (block.timestamp > s.expiresAt && s.status == SwapStatus.Pending),
            "Cannot cancel"
        );
        require(s.status == SwapStatus.Pending, "Not pending");

        s.status = SwapStatus.Cancelled;

        // Return escrowed offer items to offeror
        SwapItem[] storage offer = offerItems[offerId];
        for (uint256 i = 0; i < offer.length; i++) _releaseItem(offer[i], s.offeror);

        // Return ETH supplement
        if (s.ethSupplement > 0) payable(s.offeror).transfer(s.ethSupplement);

        emit SwapCancelled(offerId);
    }

    function _escrowItem(SwapItem memory item, address from) internal {
        if (item.tokenType == TokenType.ERC721)
            IERC721(item.nftContract).transferFrom(from, address(this), item.tokenId);
        else
            IERC1155(item.nftContract).safeTransferFrom(from, address(this), item.tokenId, item.amount, "");
    }

    function _releaseItem(SwapItem memory item, address to) internal {
        if (item.tokenType == TokenType.ERC721)
            IERC721(item.nftContract).safeTransferFrom(address(this), to, item.tokenId);
        else
            IERC1155(item.nftContract).safeTransferFrom(address(this), to, item.tokenId, item.amount, "");
    }

    function getOfferItems(uint256 offerId) external view returns (SwapItem[] memory, SwapItem[] memory) {
        return (offerItems[offerId], wantItems[offerId]);
    }
    function getUserOffers(address user)     external view returns (uint256[] memory) { return userOffers[user]; }
    function getReceivedOffers(address user) external view returns (uint256[] memory) { return receivedOffers[user]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
