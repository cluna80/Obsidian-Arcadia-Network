// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FractionalOwnership - Split expensive NFTs into tradeable fractions (Layer 6, Phase 6.6)
contract FractionalOwnership is AccessControl, ReentrancyGuard {
    bytes32 public constant CURATOR_ROLE = keccak256("CURATOR_ROLE");

    struct Vault {
        uint256 vaultId;
        address nftContract;
        uint256 tokenId;
        address curator;
        uint256 totalShares;
        uint256 sharePrice;       // initial price per share in wei
        uint256 reservePrice;     // minimum buyout price
        bool    isActive;
        bool    buyoutActive;
        address buyoutInitiator;
        uint256 buyoutPrice;
        uint256 buyoutDeadline;
        uint256 createdAt;
        string  name;
        string  symbol;
    }

    uint256 private _vaultCounter;
    mapping(uint256 => Vault)   public vaults;
    mapping(uint256 => address) public vaultTokens;   // vaultId => ERC20 token address
    mapping(address => uint256) public tokenToVault;  // ERC20 address => vaultId
    mapping(address => uint256[]) public curatorVaults;

    address public treasury;
    uint256 public platformFeeBps = 200;  // 2 %

    event VaultCreated(uint256 indexed vaultId, address indexed nftContract, uint256 tokenId, uint256 totalShares, address tokenAddress);
    event BuyoutInitiated(uint256 indexed vaultId, address indexed initiator, uint256 price);
    event BuyoutCompleted(uint256 indexed vaultId, address indexed buyer, uint256 price);
    event SharesRedeemed(uint256 indexed vaultId, address indexed redeemer, uint256 shares, uint256 payout);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CURATOR_ROLE,       msg.sender);
    }

    function fractionalize(
        address nftContract,
        uint256 tokenId,
        uint256 totalShares,
        uint256 initialSharePrice,
        uint256 reservePrice,
        string memory name,
        string memory symbol
    ) external returns (uint256) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(totalShares >= 100 && totalShares <= 1_000_000,      "100-1M shares");
        require(reservePrice > 0,                                     "Reserve price required");

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        uint256 vaultId = ++_vaultCounter;
        FractionalToken ft = new FractionalToken(name, symbol, totalShares, msg.sender, vaultId);

        vaults[vaultId] = Vault({
            vaultId:         vaultId,
            nftContract:     nftContract,
            tokenId:         tokenId,
            curator:         msg.sender,
            totalShares:     totalShares,
            sharePrice:      initialSharePrice,
            reservePrice:    reservePrice,
            isActive:        true,
            buyoutActive:    false,
            buyoutInitiator: address(0),
            buyoutPrice:     0,
            buyoutDeadline:  0,
            createdAt:       block.timestamp,
            name:            name,
            symbol:          symbol
        });

        vaultTokens[vaultId]       = address(ft);
        tokenToVault[address(ft)]  = vaultId;
        curatorVaults[msg.sender].push(vaultId);

        emit VaultCreated(vaultId, nftContract, tokenId, totalShares, address(ft));
        return vaultId;
    }

    function initiateBuyout(uint256 vaultId) external payable nonReentrant {
        Vault storage v = vaults[vaultId];
        require(v.isActive && !v.buyoutActive,  "Invalid vault state");
        require(msg.value >= v.reservePrice,    "Below reserve price");

        v.buyoutActive    = true;
        v.buyoutInitiator = msg.sender;
        v.buyoutPrice     = msg.value;
        v.buyoutDeadline  = block.timestamp + 3 days;

        emit BuyoutInitiated(vaultId, msg.sender, msg.value);
    }

    function completeBuyout(uint256 vaultId) external nonReentrant {
        Vault storage v = vaults[vaultId];
        require(v.buyoutActive,                    "No active buyout");
        require(block.timestamp >= v.buyoutDeadline, "Buyout period not over");

        v.isActive     = false;
        v.buyoutActive = false;

        IERC721(v.nftContract).safeTransferFrom(address(this), v.buyoutInitiator, v.tokenId);

        uint256 fee = (v.buyoutPrice * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        // Remaining ETH stays in contract for share redemptions

        emit BuyoutCompleted(vaultId, v.buyoutInitiator, v.buyoutPrice);
    }

    function redeemShares(uint256 vaultId, uint256 shareAmount) external nonReentrant {
        Vault storage v = vaults[vaultId];
        require(!v.isActive && v.buyoutPrice > 0, "Buyout not complete");

        FractionalToken ft = FractionalToken(vaultTokens[vaultId]);
        require(ft.balanceOf(msg.sender) >= shareAmount, "Insufficient shares");

        ft.burnFrom(msg.sender, shareAmount);

        uint256 fee     = (v.buyoutPrice * platformFeeBps) / 10000;
        uint256 netPool = v.buyoutPrice - fee;
        uint256 payout  = (netPool * shareAmount) / v.totalShares;

        payable(msg.sender).transfer(payout);
        emit SharesRedeemed(vaultId, msg.sender, shareAmount, payout);
    }

    function getCuratorVaults(address curator) external view returns (uint256[] memory) { return curatorVaults[curator]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}

/// @dev Minimal ERC20 issued per vault — only the vault contract can burn
contract FractionalToken is ERC20 {
    address public immutable vault;
    uint256 public immutable vaultId;

    constructor(string memory name, string memory symbol, uint256 supply, address owner, uint256 _vaultId)
        ERC20(name, symbol)
    {
        vault   = msg.sender;
        vaultId = _vaultId;
        _mint(owner, supply);
    }

    function burnFrom(address account, uint256 amount) external {
        require(msg.sender == vault, "Only vault can burn");
        _burn(account, amount);
    }
}
