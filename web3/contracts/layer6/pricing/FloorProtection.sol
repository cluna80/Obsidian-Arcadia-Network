// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title FloorProtection - Prevent collection floor-price collapse (Layer 6, Phase 6.5)
contract FloorProtection is AccessControl, ReentrancyGuard {
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    struct FloorConfig {
        address nftContract;
        uint256 floorPrice;        // current floor in wei
        uint256 buybackReserve;    // ETH held for buybacks
        uint256 triggerThreshold;  // bps below floor that triggers buyback (e.g. 8000 = 80%)
        bool    isActive;
        uint256 totalBuybacks;
        uint256 totalSpent;
        uint256 lastBuybackAt;
        address guardian;
    }

    struct BuybackEvent {
        uint256 eventId;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        uint256 timestamp;
    }

    uint256 private _eventCounter;
    mapping(address => FloorConfig) public floorConfigs;
    mapping(uint256 => BuybackEvent) public buybackEvents;
    mapping(address => uint256[])   public collectionEvents;
    address[] public protectedCollections;
    mapping(address => bool) public isProtected;

    event FloorConfigSet(address indexed nftContract, uint256 floorPrice, uint256 triggerThreshold);
    event BuybackTriggered(address indexed nftContract, uint256 tokenId, uint256 price);
    event ReserveFunded(address indexed nftContract, uint256 amount);
    event FloorUpdated(address indexed nftContract, uint256 oldFloor, uint256 newFloor);
    event ReserveWithdrawn(address indexed nftContract, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE,      msg.sender);
    }

    function setFloorConfig(
        address nftContract,
        uint256 floorPrice,
        uint256 triggerThreshold
    ) external onlyRole(GUARDIAN_ROLE) {
        require(floorPrice > 0,          "Floor must be > 0");
        require(triggerThreshold <= 9500, "Threshold max 95%");

        if (!isProtected[nftContract]) {
            protectedCollections.push(nftContract);
            isProtected[nftContract] = true;
        }

        FloorConfig storage c = floorConfigs[nftContract];
        c.nftContract      = nftContract;
        c.floorPrice       = floorPrice;
        c.triggerThreshold = triggerThreshold;
        c.isActive         = true;
        c.guardian         = msg.sender;

        emit FloorConfigSet(nftContract, floorPrice, triggerThreshold);
    }

    function fundReserve(address nftContract) external payable {
        require(isProtected[nftContract], "Not a protected collection");
        floorConfigs[nftContract].buybackReserve += msg.value;
        emit ReserveFunded(nftContract, msg.value);
    }

    function triggerBuyback(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) external onlyRole(GUARDIAN_ROLE) nonReentrant {
        FloorConfig storage c = floorConfigs[nftContract];
        require(c.isActive, "Config not active");

        uint256 triggerPrice = (c.floorPrice * c.triggerThreshold) / 10000;
        require(salePrice <= triggerPrice,     "Price above trigger threshold");
        require(c.buybackReserve >= salePrice, "Insufficient reserve");

        c.buybackReserve -= salePrice;
        c.totalBuybacks++;
        c.totalSpent     += salePrice;
        c.lastBuybackAt   = block.timestamp;

        uint256 eventId = ++_eventCounter;
        buybackEvents[eventId] = BuybackEvent({
            eventId:     eventId,
            nftContract: nftContract,
            tokenId:     tokenId,
            price:       salePrice,
            timestamp:   block.timestamp
        });
        collectionEvents[nftContract].push(eventId);

        emit BuybackTriggered(nftContract, tokenId, salePrice);
    }

    function updateFloor(address nftContract, uint256 newFloor) external onlyRole(GUARDIAN_ROLE) {
        require(newFloor > 0, "Floor must be > 0");
        uint256 old = floorConfigs[nftContract].floorPrice;
        floorConfigs[nftContract].floorPrice = newFloor;
        emit FloorUpdated(nftContract, old, newFloor);
    }

    function withdrawReserve(address nftContract, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        FloorConfig storage c = floorConfigs[nftContract];
        require(c.buybackReserve >= amount, "Insufficient reserve");
        c.buybackReserve -= amount;
        payable(msg.sender).transfer(amount);
        emit ReserveWithdrawn(nftContract, amount);
    }

    function shouldTriggerBuyback(address nftContract, uint256 currentPrice) external view returns (bool) {
        FloorConfig memory c = floorConfigs[nftContract];
        if (!c.isActive || c.buybackReserve == 0) return false;
        return currentPrice <= (c.floorPrice * c.triggerThreshold) / 10000;
    }

    function getCollectionEvents(address nftContract)  external view returns (uint256[] memory) { return collectionEvents[nftContract]; }
    function getProtectedCollections()                 external view returns (address[] memory)  { return protectedCollections; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
