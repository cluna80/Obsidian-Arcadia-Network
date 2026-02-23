// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BundleMarketplace - Sell multiple OAN assets as one bundle (Layer 6, Phase 6.1)
contract BundleMarketplace is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum TokenType    { ERC721, ERC1155 }
    enum BundleStatus { Active, Sold, Cancelled }

    struct BundleItem { address nftContract; uint256 tokenId; uint256 amount; TokenType tokenType; }

    struct Bundle {
        uint256      bundleId;
        address      seller;
        string       name;
        string       description;
        uint256      price;
        BundleStatus status;
        uint256      listedAt;
        uint256      expiresAt;
        uint256      discountBps;
    }

    uint256 private _bundleCounter;
    mapping(uint256 => Bundle)       public bundles;
    mapping(uint256 => BundleItem[]) public bundleItems;
    mapping(address => uint256[])    public sellerBundles;
    mapping(address => uint256[])    public buyerBundles;

    address public treasury;
    uint256 public platformFeeBps = 250;
    uint256 public totalBundles;
    uint256 public totalBundleVolume;

    event BundleCreated(uint256 indexed bundleId, address indexed seller, uint256 price, uint256 itemCount);
    event BundleSold(uint256 indexed bundleId, address indexed buyer, uint256 price);
    event BundleCancelled(uint256 indexed bundleId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE,      msg.sender);
    }

    function createBundle(
        string memory name,
        string memory description,
        BundleItem[] memory items,
        uint256 price,
        uint256 duration,
        uint256 discountBps
    ) external returns (uint256) {
        require(items.length >= 2 && items.length <= 20, "2-20 items");
        require(price > 0 && discountBps <= 5000, "Invalid params");

        uint256 bundleId = ++_bundleCounter;
        bundles[bundleId] = Bundle({
            bundleId:    bundleId,
            seller:      msg.sender,
            name:        name,
            description: description,
            price:       price,
            status:      BundleStatus.Active,
            listedAt:    block.timestamp,
            expiresAt:   block.timestamp + duration,
            discountBps: discountBps
        });

        for (uint256 i = 0; i < items.length; i++) {
            bundleItems[bundleId].push(items[i]);
            if (items[i].tokenType == TokenType.ERC721) {
                require(IERC721(items[i].nftContract).ownerOf(items[i].tokenId) == msg.sender, "Not owner");
                IERC721(items[i].nftContract).transferFrom(msg.sender, address(this), items[i].tokenId);
            } else {
                require(IERC1155(items[i].nftContract).balanceOf(msg.sender, items[i].tokenId) >= items[i].amount, "Balance");
                IERC1155(items[i].nftContract).safeTransferFrom(msg.sender, address(this), items[i].tokenId, items[i].amount, "");
            }
        }

        sellerBundles[msg.sender].push(bundleId);
        totalBundles++;
        emit BundleCreated(bundleId, msg.sender, price, items.length);
        return bundleId;
    }

    function buyBundle(uint256 bundleId) external payable nonReentrant {
        Bundle storage b = bundles[bundleId];
        require(b.status == BundleStatus.Active,  "Not active");
        require(block.timestamp <= b.expiresAt,   "Expired");
        require(msg.value >= b.price,             "Insufficient payment");

        b.status = BundleStatus.Sold;
        BundleItem[] storage items = bundleItems[bundleId];
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].tokenType == TokenType.ERC721)
                IERC721(items[i].nftContract).safeTransferFrom(address(this), msg.sender, items[i].tokenId);
            else
                IERC1155(items[i].nftContract).safeTransferFrom(address(this), msg.sender, items[i].tokenId, items[i].amount, "");
        }

        uint256 fee = (b.price * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(b.seller).transfer(b.price - fee);
        if (msg.value > b.price) payable(msg.sender).transfer(msg.value - b.price);

        buyerBundles[msg.sender].push(bundleId);
        totalBundleVolume += b.price;
        emit BundleSold(bundleId, msg.sender, b.price);
    }

    function cancelBundle(uint256 bundleId) external nonReentrant {
        Bundle storage b = bundles[bundleId];
        require(b.seller == msg.sender || hasRole(OPERATOR_ROLE, msg.sender), "Not authorized");
        require(b.status == BundleStatus.Active, "Not active");
        b.status = BundleStatus.Cancelled;

        BundleItem[] storage items = bundleItems[bundleId];
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i].tokenType == TokenType.ERC721)
                IERC721(items[i].nftContract).safeTransferFrom(address(this), b.seller, items[i].tokenId);
            else
                IERC1155(items[i].nftContract).safeTransferFrom(address(this), b.seller, items[i].tokenId, items[i].amount, "");
        }
        emit BundleCancelled(bundleId);
    }

    function getBundleItems(uint256 bundleId)      external view returns (BundleItem[] memory) { return bundleItems[bundleId]; }
    function getSellerBundles(address seller)      external view returns (uint256[] memory)    { return sellerBundles[seller]; }
    function setPlatformFee(uint256 bps)           external onlyRole(DEFAULT_ADMIN_ROLE) { require(bps <= 1000); platformFeeBps = bps; }
    function supportsInterface(bytes4 i)           public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
