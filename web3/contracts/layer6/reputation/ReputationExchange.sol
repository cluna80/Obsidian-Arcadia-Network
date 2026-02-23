// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ReputationExchange - Trade and rent on-chain reputation (Layer 6, Phase 6.4)
contract ReputationExchange is AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    enum ReputationType { Creator, Trader, Athlete, Validator, Community }

    struct ReputationListing {
        uint256        listingId;
        address        owner;
        ReputationType repType;
        uint256        reputationScore;
        uint256        rentalPricePerDay;
        uint256        salePrice;
        bool           isForRent;
        bool           isForSale;
        bool           isActive;
        uint256        listedAt;
        uint256        totalRentals;
    }

    struct ReputationRental {
        uint256 rentalId;
        uint256 listingId;
        address renter;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPaid;
        bool    isActive;
    }

    mapping(address => uint256)        public reputationScores;
    mapping(address => ReputationType) public reputationTypes;
    mapping(uint256 => ReputationListing) public listings;
    mapping(uint256 => ReputationRental)  public rentals;
    mapping(address => uint256[]) public ownerListings;
    mapping(address => uint256[]) public renterHistory;

    uint256 private _listingCounter;
    uint256 private _rentalCounter;

    address public treasury;
    uint256 public platformFeeBps = 300;

    event ReputationListed(uint256 indexed listingId, address indexed owner, uint256 score);
    event ReputationRented(uint256 indexed rentalId, address indexed renter, uint256 days_);
    event ReputationSold(uint256 indexed listingId, address indexed buyer, uint256 price);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE,        msg.sender);
    }

    function setReputation(address user, uint256 score, ReputationType repType) external onlyRole(ORACLE_ROLE) {
        reputationScores[user] = score;
        reputationTypes[user]  = repType;
    }

    function listReputation(uint256 rentalPricePerDay, uint256 salePrice, bool isForRent, bool isForSale)
        external returns (uint256)
    {
        require(reputationScores[msg.sender] > 0, "No reputation");
        require(isForRent || isForSale,           "Must list for rent or sale");

        uint256 listingId = ++_listingCounter;
        listings[listingId] = ReputationListing({
            listingId:         listingId,
            owner:             msg.sender,
            repType:           reputationTypes[msg.sender],
            reputationScore:   reputationScores[msg.sender],
            rentalPricePerDay: rentalPricePerDay,
            salePrice:         salePrice,
            isForRent:         isForRent,
            isForSale:         isForSale,
            isActive:          true,
            listedAt:          block.timestamp,
            totalRentals:      0
        });
        ownerListings[msg.sender].push(listingId);
        emit ReputationListed(listingId, msg.sender, reputationScores[msg.sender]);
        return listingId;
    }

    function rentReputation(uint256 listingId, uint256 days_) external payable nonReentrant {
        ReputationListing storage l = listings[listingId];
        require(l.isActive && l.isForRent, "Not for rent");

        uint256 totalCost = l.rentalPricePerDay * days_;
        require(msg.value >= totalCost, "Insufficient payment");

        uint256 rentalId = ++_rentalCounter;
        rentals[rentalId] = ReputationRental({
            rentalId:  rentalId,
            listingId: listingId,
            renter:    msg.sender,
            startTime: block.timestamp,
            endTime:   block.timestamp + (days_ * 1 days),
            totalPaid: msg.value,
            isActive:  true
        });

        renterHistory[msg.sender].push(rentalId);
        l.totalRentals++;

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(l.owner).transfer(msg.value - fee);
        emit ReputationRented(rentalId, msg.sender, days_);
    }

    function buyReputation(uint256 listingId) external payable nonReentrant {
        ReputationListing storage l = listings[listingId];
        require(l.isActive && l.isForSale, "Not for sale");
        require(msg.value >= l.salePrice,  "Insufficient payment");

        l.isActive = false;
        reputationScores[msg.sender] = l.reputationScore;
        reputationTypes[msg.sender]  = l.repType;

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(l.owner).transfer(msg.value - fee);
        emit ReputationSold(listingId, msg.sender, l.salePrice);
    }

    function getOwnerListings(address owner) external view returns (uint256[] memory) { return ownerListings[owner]; }
    function getRenterHistory(address renter) external view returns (uint256[] memory) { return renterHistory[renter]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
