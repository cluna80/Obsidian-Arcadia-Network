// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AuctionHouse - English & Dutch auctions for OAN assets (Layer 6, Phase 6.1)
contract AuctionHouse is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum AuctionType   { English, Dutch }
    enum AuctionStatus { Active, Settled, Cancelled }
    enum TokenType     { ERC721, ERC1155 }

    struct Auction {
        uint256 auctionId;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 amount;
        TokenType    tokenType;
        AuctionType  auctionType;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 currentBid;
        address currentBidder;
        uint256 startTime;
        uint256 endTime;
        uint256 minBidIncrement;
        AuctionStatus status;
        uint256 dutchEndPrice;
        uint256 totalBids;
    }

    struct Bid { address bidder; uint256 amount; uint256 timestamp; }

    uint256 private _auctionCounter;
    mapping(uint256 => Auction)  public auctions;
    mapping(uint256 => Bid[])    public bidHistory;
    mapping(address => uint256)  public pendingReturns;
    mapping(address => uint256[]) public userAuctions;

    address public treasury;
    uint256 public platformFeeBps = 250;
    uint256 public totalAuctionVolume;
    uint256 public totalAuctions;

    event AuctionCreated(uint256 indexed auctionId, address indexed seller, AuctionType auctionType, uint256 startPrice, uint256 endTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount);
    event AuctionSettled(uint256 indexed auctionId, address indexed winner, uint256 finalPrice);
    event AuctionCancelled(uint256 indexed auctionId);
    event DutchPurchase(uint256 indexed auctionId, address indexed buyer, uint256 price);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE,      msg.sender);
    }

    function createEnglishAuction(
        address nftContract, uint256 tokenId, uint256 amount, TokenType tokenType,
        uint256 startPrice, uint256 reservePrice, uint256 duration, uint256 minBidIncrement
    ) external returns (uint256) {
        require(startPrice > 0 && duration >= 1 hours, "Invalid params");
        _escrowNFT(nftContract, tokenId, amount, tokenType);

        uint256 id = ++_auctionCounter;
        auctions[id] = Auction({
            auctionId: id, seller: msg.sender, nftContract: nftContract, tokenId: tokenId,
            amount: amount, tokenType: tokenType, auctionType: AuctionType.English,
            startPrice: startPrice, reservePrice: reservePrice, currentBid: 0,
            currentBidder: address(0), startTime: block.timestamp,
            endTime: block.timestamp + duration, minBidIncrement: minBidIncrement,
            status: AuctionStatus.Active, dutchEndPrice: 0, totalBids: 0
        });
        userAuctions[msg.sender].push(id);
        totalAuctions++;
        emit AuctionCreated(id, msg.sender, AuctionType.English, startPrice, block.timestamp + duration);
        return id;
    }

    function createDutchAuction(
        address nftContract, uint256 tokenId, uint256 amount, TokenType tokenType,
        uint256 startPrice, uint256 endPrice, uint256 duration
    ) external returns (uint256) {
        require(startPrice > endPrice && endPrice > 0 && duration >= 1 hours, "Invalid params");
        _escrowNFT(nftContract, tokenId, amount, tokenType);

        uint256 id = ++_auctionCounter;
        auctions[id] = Auction({
            auctionId: id, seller: msg.sender, nftContract: nftContract, tokenId: tokenId,
            amount: amount, tokenType: tokenType, auctionType: AuctionType.Dutch,
            startPrice: startPrice, reservePrice: endPrice, currentBid: 0,
            currentBidder: address(0), startTime: block.timestamp,
            endTime: block.timestamp + duration, minBidIncrement: 0,
            status: AuctionStatus.Active, dutchEndPrice: endPrice, totalBids: 0
        });
        userAuctions[msg.sender].push(id);
        totalAuctions++;
        emit AuctionCreated(id, msg.sender, AuctionType.Dutch, startPrice, block.timestamp + duration);
        return id;
    }

    function placeBid(uint256 auctionId) external payable nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active,       "Not active");
        require(a.auctionType == AuctionType.English,   "Use buyDutch");
        require(block.timestamp < a.endTime,            "Ended");
        uint256 minBid = a.currentBid == 0 ? a.startPrice : a.currentBid + a.minBidIncrement;
        require(msg.value >= minBid, "Bid too low");

        if (a.currentBidder != address(0)) pendingReturns[a.currentBidder] += a.currentBid;
        a.currentBid    = msg.value;
        a.currentBidder = msg.sender;
        a.totalBids++;
        bidHistory[auctionId].push(Bid(msg.sender, msg.value, block.timestamp));
        if (a.endTime - block.timestamp < 5 minutes) a.endTime += 5 minutes; // anti-snipe
        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function buyDutch(uint256 auctionId) external payable nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active && a.auctionType == AuctionType.Dutch, "Invalid");
        require(block.timestamp <= a.endTime, "Expired");
        uint256 price = getDutchPrice(auctionId);
        require(msg.value >= price, "Insufficient payment");

        a.status        = AuctionStatus.Settled;
        a.currentBidder = msg.sender;
        a.currentBid    = price;
        _transferNFT(a.nftContract, a.tokenId, a.amount, a.tokenType, address(this), msg.sender);

        uint256 fee = (price * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(a.seller).transfer(price - fee);
        if (msg.value > price) payable(msg.sender).transfer(msg.value - price);
        totalAuctionVolume += price;
        emit DutchPurchase(auctionId, msg.sender, price);
    }

    function settleAuction(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.status == AuctionStatus.Active && a.auctionType == AuctionType.English, "Cannot settle");
        require(block.timestamp >= a.endTime, "Not ended");
        a.status = AuctionStatus.Settled;

        if (a.currentBidder != address(0) && a.currentBid >= a.reservePrice) {
            uint256 fee = (a.currentBid * platformFeeBps) / 10000;
            payable(treasury).transfer(fee);
            payable(a.seller).transfer(a.currentBid - fee);
            _transferNFT(a.nftContract, a.tokenId, a.amount, a.tokenType, address(this), a.currentBidder);
            totalAuctionVolume += a.currentBid;
            emit AuctionSettled(auctionId, a.currentBidder, a.currentBid);
        } else {
            _transferNFT(a.nftContract, a.tokenId, a.amount, a.tokenType, address(this), a.seller);
            if (a.currentBidder != address(0)) pendingReturns[a.currentBidder] += a.currentBid;
            emit AuctionCancelled(auctionId);
        }
    }

    function cancelAuction(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.seller == msg.sender || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(a.status == AuctionStatus.Active && a.currentBidder == address(0), "Has bids");
        a.status = AuctionStatus.Cancelled;
        _transferNFT(a.nftContract, a.tokenId, a.amount, a.tokenType, address(this), a.seller);
        emit AuctionCancelled(auctionId);
    }

    function withdraw() external nonReentrant {
        uint256 amt = pendingReturns[msg.sender];
        require(amt > 0, "Nothing to withdraw");
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amt);
    }

    function getDutchPrice(uint256 auctionId) public view returns (uint256) {
        Auction memory a = auctions[auctionId];
        if (block.timestamp >= a.endTime) return a.dutchEndPrice;
        uint256 elapsed   = block.timestamp - a.startTime;
        uint256 duration  = a.endTime       - a.startTime;
        uint256 priceDrop = ((a.startPrice - a.dutchEndPrice) * elapsed) / duration;
        return a.startPrice - priceDrop;
    }

    function getBidHistory(uint256 auctionId) external view returns (Bid[] memory)    { return bidHistory[auctionId]; }
    function getUserAuctions(address user)    external view returns (uint256[] memory) { return userAuctions[user]; }

    function _escrowNFT(address nftContract, uint256 tokenId, uint256 amount, TokenType tokenType) internal {
        if (tokenType == TokenType.ERC721) {
            require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        } else {
            require(IERC1155(nftContract).balanceOf(msg.sender, tokenId) >= amount, "Balance");
            IERC1155(nftContract).safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        }
    }

    function _transferNFT(address nftContract, uint256 tokenId, uint256 amount, TokenType tokenType, address from, address to) internal {
        if (tokenType == TokenType.ERC721) IERC721(nftContract).safeTransferFrom(from, to, tokenId);
        else IERC1155(nftContract).safeTransferFrom(from, to, tokenId, amount, "");
    }

    function setPlatformFee(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) { require(bps <= 1000); platformFeeBps = bps; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
