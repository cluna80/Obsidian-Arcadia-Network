// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DerivativesMarket - Options on OAN NFT floor prices (Layer 6, Phase 6.6)
contract DerivativesMarket is AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    enum OptionType   { Call, Put }
    enum OptionStatus { Active, Exercised, Expired, Cancelled }

    struct Option {
        uint256      optionId;
        address      writer;
        address      holder;
        address      nftContract;    // reference collection
        OptionType   optionType;
        uint256      strikePrice;    // wei — price at which option is exercisable
        uint256      premium;        // wei — cost to buy this option
        uint256      expiry;         // timestamp
        OptionStatus status;
        uint256      createdAt;
        bool         isAmerican;     // true = exercise any time; false = only near expiry
        uint256      collateral;     // ETH locked by writer
    }

    uint256 private _optionCounter;
    mapping(uint256 => Option)    public options;
    mapping(address => uint256)   public nftFloorPrices;   // set by oracle
    mapping(address => uint256[]) public writerOptions;
    mapping(address => uint256[]) public holderOptions;

    address public treasury;
    uint256 public platformFeeBps = 300;
    uint256 public totalOptions;
    uint256 public totalPremiumsCollected;

    event OptionWritten(uint256 indexed optionId, address indexed writer, OptionType optionType, uint256 strikePrice, uint256 expiry);
    event OptionPurchased(uint256 indexed optionId, address indexed holder, uint256 premium);
    event OptionExercised(uint256 indexed optionId, address indexed holder, uint256 payout);
    event OptionExpired(uint256 indexed optionId);
    event FloorPriceUpdated(address indexed nftContract, uint256 newPrice);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE,        msg.sender);
    }

    function writeOption(
        address nftContract,
        OptionType optionType,
        uint256 strikePrice,
        uint256 premium,
        uint256 expiry,
        bool isAmerican
    ) external payable returns (uint256) {
        require(expiry > block.timestamp,    "Expiry must be in the future");
        require(strikePrice > 0 && premium > 0, "Invalid params");

        // Writers must collateralize:
        // Call writer: must post ≥ 10% of strike (they owe payout if exercised)
        // Put writer:  must post 100% of strike  (they absorb full downside)
        if (optionType == OptionType.Call)
            require(msg.value >= strikePrice / 10, "Insufficient call collateral (min 10% of strike)");
        else
            require(msg.value >= strikePrice,      "Insufficient put collateral (100% of strike)");

        uint256 optionId = ++_optionCounter;
        options[optionId] = Option({
            optionId:    optionId,
            writer:      msg.sender,
            holder:      address(0),
            nftContract: nftContract,
            optionType:  optionType,
            strikePrice: strikePrice,
            premium:     premium,
            expiry:      expiry,
            status:      OptionStatus.Active,
            createdAt:   block.timestamp,
            isAmerican:  isAmerican,
            collateral:  msg.value
        });

        writerOptions[msg.sender].push(optionId);
        totalOptions++;
        emit OptionWritten(optionId, msg.sender, optionType, strikePrice, expiry);
        return optionId;
    }

    function buyOption(uint256 optionId) external payable nonReentrant {
        Option storage o = options[optionId];
        require(o.status == OptionStatus.Active, "Not available");
        require(o.holder == address(0),          "Already purchased");
        require(block.timestamp < o.expiry,      "Option expired");
        require(msg.value >= o.premium,          "Insufficient premium");

        o.holder = msg.sender;
        holderOptions[msg.sender].push(optionId);

        uint256 fee = (o.premium * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(o.writer).transfer(o.premium - fee);
        totalPremiumsCollected += o.premium;

        if (msg.value > o.premium) payable(msg.sender).transfer(msg.value - o.premium);
        emit OptionPurchased(optionId, msg.sender, o.premium);
    }

    function exerciseOption(uint256 optionId) external nonReentrant {
        Option storage o = options[optionId];
        require(o.holder == msg.sender,          "Not holder");
        require(o.status == OptionStatus.Active, "Not active");
        require(block.timestamp <= o.expiry,     "Expired");

        // European options: only exercisable in final hour
        if (!o.isAmerican)
            require(block.timestamp >= o.expiry - 1 hours, "European: exercise only near expiry");

        uint256 currentPrice = nftFloorPrices[o.nftContract];
        require(currentPrice > 0, "No floor price set");

        uint256 payout = 0;
        if (o.optionType == OptionType.Call && currentPrice > o.strikePrice) {
            payout = currentPrice - o.strikePrice;
        } else if (o.optionType == OptionType.Put && o.strikePrice > currentPrice) {
            payout = o.strikePrice - currentPrice;
        }
        require(payout > 0,               "Option not in the money");
        require(payout <= o.collateral,   "Payout exceeds collateral");

        o.status = OptionStatus.Exercised;
        payable(msg.sender).transfer(payout);
        if (o.collateral > payout) payable(o.writer).transfer(o.collateral - payout);

        emit OptionExercised(optionId, msg.sender, payout);
    }

    function expireOption(uint256 optionId) external nonReentrant {
        Option storage o = options[optionId];
        require(block.timestamp > o.expiry,      "Not expired yet");
        require(o.status == OptionStatus.Active, "Not active");

        o.status = OptionStatus.Expired;
        // Return collateral to writer
        payable(o.writer).transfer(o.collateral);
        emit OptionExpired(optionId);
    }

    function updateFloorPrice(address nftContract, uint256 price) external onlyRole(ORACLE_ROLE) {
        require(price > 0, "Price must be > 0");
        nftFloorPrices[nftContract] = price;
        emit FloorPriceUpdated(nftContract, price);
    }

    function getWriterOptions(address writer) external view returns (uint256[] memory) { return writerOptions[writer]; }
    function getHolderOptions(address holder) external view returns (uint256[] memory) { return holderOptions[holder]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
