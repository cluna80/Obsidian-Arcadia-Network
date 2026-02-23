// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title RoyaltyEngine - Perpetual creator royalties across all OAN sales (Layer 6, Phase 6.3)
contract RoyaltyEngine is AccessControl, ReentrancyGuard {
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    struct RoyaltyConfig {
        address   primaryCreator;
        uint256   primaryBps;
        address[] collaborators;
        uint256[] collaboratorBps;
        uint256   totalBps;
        bool      isActive;
        uint256   totalPaid;
        uint256   createdAt;
    }

    struct RoyaltyPayment {
        uint256 paymentId;
        address nftContract;
        uint256 tokenId;
        uint256 salePrice;
        uint256 royaltyAmount;
        address payer;
        uint256 timestamp;
    }

    uint256 private _paymentCounter;
    mapping(address => mapping(uint256 => RoyaltyConfig)) public royaltyConfigs;
    mapping(uint256 => RoyaltyPayment) public payments;
    mapping(address => uint256)        public pendingRoyalties;
    mapping(address => uint256)        public totalEarned;
    mapping(address => mapping(uint256 => uint256[])) public nftPayments;

    address public treasury;
    uint256 public platformFeeBps  = 50;    // 0.5 % on royalty flow
    uint256 public maxRoyaltyBps   = 1500;  // 15 % max
    uint256 public totalRoyaltiesPaid;

    event RoyaltyConfigSet(address indexed nftContract, uint256 indexed tokenId, address creator, uint256 totalBps);
    event RoyaltyPaid(uint256 indexed paymentId, address indexed nftContract, uint256 indexed tokenId, uint256 amount);
    event RoyaltyWithdrawn(address indexed recipient, uint256 amount);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE,  msg.sender);
        _grantRole(MARKETPLACE_ROLE,    msg.sender);
    }

    function setRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 primaryBps,
        address[] memory collaborators,
        uint256[] memory collaboratorBps
    ) external {
        require(collaborators.length == collaboratorBps.length, "Length mismatch");
        uint256 total = primaryBps;
        for (uint256 i = 0; i < collaboratorBps.length; i++) total += collaboratorBps[i];
        require(total <= maxRoyaltyBps, "Exceeds max royalty");

        royaltyConfigs[nftContract][tokenId] = RoyaltyConfig({
            primaryCreator: msg.sender,
            primaryBps:     primaryBps,
            collaborators:  collaborators,
            collaboratorBps: collaboratorBps,
            totalBps:       total,
            isActive:       true,
            totalPaid:      0,
            createdAt:      block.timestamp
        });
        emit RoyaltyConfigSet(nftContract, tokenId, msg.sender, total);
    }

    function processRoyalty(address nftContract, uint256 tokenId, address payer)
        external payable onlyRole(MARKETPLACE_ROLE) nonReentrant returns (uint256)
    {
        RoyaltyConfig storage config = royaltyConfigs[nftContract][tokenId];
        require(config.isActive, "No royalty config");

        uint256 salePrice     = msg.value;
        uint256 royaltyAmount = (salePrice * config.totalBps) / 10000;
        require(royaltyAmount <= salePrice, "Invalid royalty");

        uint256 paymentId = ++_paymentCounter;
        payments[paymentId] = RoyaltyPayment({
            paymentId:     paymentId,
            nftContract:   nftContract,
            tokenId:       tokenId,
            salePrice:     salePrice,
            royaltyAmount: royaltyAmount,
            payer:         payer,
            timestamp:     block.timestamp
        });
        nftPayments[nftContract][tokenId].push(paymentId);

        uint256 primaryAmount = (salePrice * config.primaryBps) / 10000;
        pendingRoyalties[config.primaryCreator] += primaryAmount;
        totalEarned[config.primaryCreator]      += primaryAmount;

        for (uint256 i = 0; i < config.collaborators.length; i++) {
            uint256 colabAmount = (salePrice * config.collaboratorBps[i]) / 10000;
            pendingRoyalties[config.collaborators[i]] += colabAmount;
            totalEarned[config.collaborators[i]]      += colabAmount;
        }

        config.totalPaid      += royaltyAmount;
        totalRoyaltiesPaid    += royaltyAmount;
        emit RoyaltyPaid(paymentId, nftContract, tokenId, royaltyAmount);

        uint256 change = salePrice - royaltyAmount;
        if (change > 0) payable(payer).transfer(change);
        return royaltyAmount;
    }

    function withdrawRoyalties() external nonReentrant {
        uint256 amt = pendingRoyalties[msg.sender];
        require(amt > 0, "Nothing to withdraw");
        pendingRoyalties[msg.sender] = 0;
        payable(msg.sender).transfer(amt);
        emit RoyaltyWithdrawn(msg.sender, amt);
    }

    function getRoyaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice)
        external view returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyConfig memory c = royaltyConfigs[nftContract][tokenId];
        return (c.primaryCreator, (salePrice * c.totalBps) / 10000);
    }

    function getNFTPayments(address nftContract, uint256 tokenId) external view returns (uint256[] memory) { return nftPayments[nftContract][tokenId]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
