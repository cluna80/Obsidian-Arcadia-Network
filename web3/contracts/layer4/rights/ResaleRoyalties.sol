// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ResaleRoyalties is ReentrancyGuard, Ownable {
    constructor() Ownable(msg.sender) {}

    struct RoyaltyConfig {
        uint256 assetId;
        address creator;
        uint256 royaltyBps;
        uint256 totalRoyaltiesCollected;
        uint256 totalSales;
    }

    struct Sale {
        uint256 saleId;
        uint256 assetId;
        address seller;
        address buyer;
        uint256 price;
        uint256 royaltyPaid;
        uint256 timestamp;
    }

    mapping(uint256 => RoyaltyConfig) public royaltyConfigs;
    mapping(uint256 => Sale[]) public salesHistory;
    mapping(address => uint256) public creatorEarnings;
    mapping(address => bool) public approvedMarketplaces;

    uint256 public saleCount;
    uint256 public constant MAX_ROYALTY_BPS = 1000;

    modifier onlyMarketplace() {
        require(approvedMarketplaces[msg.sender], "Unauthorized marketplace");
        _;
    }

    function approveMarketplace(address marketplace, bool approved) external onlyOwner {
        approvedMarketplaces[marketplace] = approved;
    }

    function configureRoyalty(uint256 assetId, uint256 royaltyBps) external {
        require(royaltyConfigs[assetId].creator == address(0), "Already configured");
        require(royaltyBps <= MAX_ROYALTY_BPS, "Royalty too high");
        royaltyConfigs[assetId] = RoyaltyConfig({
            assetId: assetId,
            creator: msg.sender,
            royaltyBps: royaltyBps,
            totalRoyaltiesCollected: 0,
            totalSales: 0
        });
    }

    function recordSale(
        uint256 assetId,
        address seller,
        address buyer,
        uint256 price
    ) external payable nonReentrant onlyMarketplace returns (uint256) {
        require(msg.value == price, "Incorrect payment");

        RoyaltyConfig storage config = royaltyConfigs[assetId];
        require(config.creator != address(0), "Not configured");

        uint256 royalty = (price * config.royaltyBps) / 10000;
        uint256 sellerProceeds = price - royalty;

        saleCount++;
        uint256 saleId = saleCount;

        salesHistory[assetId].push(Sale({
            saleId: saleId,
            assetId: assetId,
            seller: seller,
            buyer: buyer,
            price: price,
            royaltyPaid: royalty,
            timestamp: block.timestamp
        }));

        config.totalRoyaltiesCollected += royalty;
        config.totalSales++;
        creatorEarnings[config.creator] += royalty;

        (bool successCreator, ) = payable(config.creator).call{value: royalty}("");
        require(successCreator, "Royalty payment failed");

        (bool successSeller, ) = payable(seller).call{value: sellerProceeds}("");
        require(successSeller, "Seller payment failed");

        return saleId;
    }

    /**
     * @notice Returns the royalty configuration for a given asset
     * @param assetId The ID of the asset (e.g. tokenId from MovieNFT/SceneNFT)
     * @return creator The original creator address
     * @return royaltyBps Royalty in basis points (e.g. 1000 = 10%)
     * @return totalRoyaltiesCollected Cumulative royalties paid out for this asset
     * @return totalSales Number of secondary sales recorded for this asset
     */
    function getRoyaltyConfig(uint256 assetId)
        external
        view
        returns (
            address creator,
            uint256 royaltyBps,
            uint256 totalRoyaltiesCollected,
            uint256 totalSales
        )
    {
        RoyaltyConfig memory config = royaltyConfigs[assetId];
        return (
            config.creator,
            config.royaltyBps,
            config.totalRoyaltiesCollected,
            config.totalSales
        );
    }

    /**
     * @notice Returns the total royalties earned (and paid out) to a creator across all assets
     * @param creator The creator's address
     * @return Total earnings in wei
     */
    function getCreatorEarnings(address creator) external view returns (uint256) {
        return creatorEarnings[creator];
    }
}