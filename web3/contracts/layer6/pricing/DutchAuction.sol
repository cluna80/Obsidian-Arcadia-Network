// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DutchAuction - Standalone descending-price auctions (Layer 6, Phase 6.5)
contract DutchAuction is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct Auction {
        uint256 auctionId;
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 priceDropInterval;  // seconds between each drop
        uint256 priceDropAmount;    // wei dropped per interval
        bool    settled;
        address winner;
        uint256 finalPrice;
    }

    uint256 private _auctionCounter;
    mapping(uint256 => Auction)   public auctions;
    mapping(address => uint256[]) public sellerAuctions;

    address public treasury;
    uint256 public platformFeeBps = 250;
    uint256 public totalAuctions;
    uint256 public totalVolume;

    event AuctionStarted(uint256 indexed auctionId, address indexed seller, uint256 startPrice, uint256 endPrice, uint256 endTime);
    event AuctionWon(uint256 indexed auctionId, address indexed winner, uint256 price);
    event AuctionExpired(uint256 indexed auctionId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE,      msg.sender);
    }

    function startAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endPrice,
        uint256 duration,
        uint256 dropInterval,
        uint256 dropAmount
    ) external returns (uint256) {
        require(startPrice > endPrice && endPrice > 0, "Invalid prices");
        require(duration >= 1 hours,                  "Min 1 hour duration");
        require(dropInterval > 0,                     "Drop interval > 0");

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        uint256 auctionId = ++_auctionCounter;
        auctions[auctionId] = Auction({
            auctionId:         auctionId,
            seller:            msg.sender,
            nftContract:       nftContract,
            tokenId:           tokenId,
            startPrice:        startPrice,
            endPrice:          endPrice,
            startTime:         block.timestamp,
            endTime:           block.timestamp + duration,
            priceDropInterval: dropInterval,
            priceDropAmount:   dropAmount,
            settled:           false,
            winner:            address(0),
            finalPrice:        0
        });

        sellerAuctions[msg.sender].push(auctionId);
        totalAuctions++;
        emit AuctionStarted(auctionId, msg.sender, startPrice, endPrice, block.timestamp + duration);
        return auctionId;
    }

    function buy(uint256 auctionId) external payable nonReentrant {
        Auction storage a = auctions[auctionId];
        require(!a.settled,                   "Already settled");
        require(block.timestamp <= a.endTime, "Auction expired");

        uint256 price = getCurrentPrice(auctionId);
        require(msg.value >= price, "Insufficient payment");

        a.settled    = true;
        a.winner     = msg.sender;
        a.finalPrice = price;

        IERC721(a.nftContract).safeTransferFrom(address(this), msg.sender, a.tokenId);

        uint256 fee = (price * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(a.seller).transfer(price - fee);
        if (msg.value > price) payable(msg.sender).transfer(msg.value - price);

        totalVolume += price;
        emit AuctionWon(auctionId, msg.sender, price);
    }

    function reclaim(uint256 auctionId) external nonReentrant {
        Auction storage a = auctions[auctionId];
        require(a.seller == msg.sender, "Not seller");
        require(!a.settled,             "Already settled");
        require(block.timestamp > a.endTime, "Not expired yet");

        a.settled = true;
        IERC721(a.nftContract).safeTransferFrom(address(this), a.seller, a.tokenId);
        emit AuctionExpired(auctionId);
    }

    function getCurrentPrice(uint256 auctionId) public view returns (uint256) {
        Auction memory a = auctions[auctionId];
        if (block.timestamp >= a.endTime) return a.endPrice;

        uint256 elapsed   = block.timestamp - a.startTime;
        uint256 intervals = elapsed / a.priceDropInterval;
        uint256 totalDrop = intervals * a.priceDropAmount;

        if (totalDrop + a.endPrice >= a.startPrice) return a.endPrice;
        return a.startPrice - totalDrop;
    }

    function getSellerAuctions(address seller) external view returns (uint256[] memory) { return sellerAuctions[seller]; }
    function setPlatformFee(uint256 bps) external onlyRole(DEFAULT_ADMIN_ROLE) { require(bps <= 1000); platformFeeBps = bps; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
