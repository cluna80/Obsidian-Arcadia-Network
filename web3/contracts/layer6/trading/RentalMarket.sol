// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title RentalMarket - Rent OAN NFTs temporarily (Layer 6, Phase 6.6)
contract RentalMarket is AccessControl, ReentrancyGuard {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    enum RentalStatus { Available, Rented, Returned, Cancelled }

    struct RentalListing {
        uint256       listingId;
        address       owner;
        address       nftContract;
        uint256       tokenId;
        uint256       pricePerDay;
        uint256       collateralRequired;
        uint256       minDuration;   // days
        uint256       maxDuration;   // days
        RentalStatus  status;
        address       currentRenter;
        uint256       rentalStart;
        uint256       rentalEnd;
        uint256       totalRentals;
        uint256       totalEarned;
    }

    struct RentalRecord {
        uint256 recordId;
        uint256 listingId;
        address renter;
        uint256 startTime;
        uint256 endTime;
        uint256 totalPaid;
        uint256 collateral;
        bool    returned;
        bool    collateralRefunded;
    }

    uint256 private _listingCounter;
    uint256 private _recordCounter;
    mapping(uint256 => RentalListing) public listings;
    mapping(uint256 => RentalRecord)  public rentalRecords;
    mapping(address => uint256[])     public ownerListings;
    mapping(address => uint256[])     public renterHistory;
    mapping(uint256 => uint256)       public activeRental;  // listingId => recordId

    address public treasury;
    uint256 public platformFeeBps = 300;
    uint256 public totalListings;
    uint256 public totalVolume;

    event Listed(uint256 indexed listingId, address indexed owner, address nftContract, uint256 tokenId, uint256 pricePerDay);
    event Rented(uint256 indexed recordId, uint256 indexed listingId, address indexed renter, uint256 days_);
    event Returned(uint256 indexed recordId, bool collateralRefunded);
    event ListingWithdrawn(uint256 indexed listingId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE,      msg.sender);
    }

    function listForRental(
        address nftContract,
        uint256 tokenId,
        uint256 pricePerDay,
        uint256 collateralRequired,
        uint256 minDuration,
        uint256 maxDuration
    ) external returns (uint256) {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(pricePerDay > 0,                  "Price must be > 0");
        require(minDuration >= 1,                 "Min 1 day");
        require(maxDuration >= minDuration,       "Max >= min");

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        uint256 listingId = ++_listingCounter;
        listings[listingId] = RentalListing({
            listingId:         listingId,
            owner:             msg.sender,
            nftContract:       nftContract,
            tokenId:           tokenId,
            pricePerDay:       pricePerDay,
            collateralRequired: collateralRequired,
            minDuration:       minDuration,
            maxDuration:       maxDuration,
            status:            RentalStatus.Available,
            currentRenter:     address(0),
            rentalStart:       0,
            rentalEnd:         0,
            totalRentals:      0,
            totalEarned:       0
        });

        ownerListings[msg.sender].push(listingId);
        totalListings++;
        emit Listed(listingId, msg.sender, nftContract, tokenId, pricePerDay);
        return listingId;
    }

    function rent(uint256 listingId, uint256 days_) external payable nonReentrant {
        RentalListing storage l = listings[listingId];
        require(l.status == RentalStatus.Available,          "Not available");
        require(days_ >= l.minDuration && days_ <= l.maxDuration, "Duration out of range");

        uint256 rentalCost    = l.pricePerDay * days_;
        uint256 totalRequired = rentalCost + l.collateralRequired;
        require(msg.value >= totalRequired, "Insufficient payment");

        l.status        = RentalStatus.Rented;
        l.currentRenter = msg.sender;
        l.rentalStart   = block.timestamp;
        l.rentalEnd     = block.timestamp + (days_ * 1 days);

        uint256 recordId = ++_recordCounter;
        rentalRecords[recordId] = RentalRecord({
            recordId:          recordId,
            listingId:         listingId,
            renter:            msg.sender,
            startTime:         block.timestamp,
            endTime:           l.rentalEnd,
            totalPaid:         rentalCost,
            collateral:        l.collateralRequired,
            returned:          false,
            collateralRefunded: false
        });

        activeRental[listingId] = recordId;
        renterHistory[msg.sender].push(recordId);

        uint256 fee = (rentalCost * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(l.owner).transfer(rentalCost - fee);

        l.totalRentals++;
        l.totalEarned += rentalCost;
        totalVolume   += rentalCost;

        if (msg.value > totalRequired) payable(msg.sender).transfer(msg.value - totalRequired);
        emit Rented(recordId, listingId, msg.sender, days_);
    }

    function returnNFT(uint256 listingId) external nonReentrant {
        RentalListing storage l = listings[listingId];
        uint256 recordId        = activeRental[listingId];
        RentalRecord storage r  = rentalRecords[recordId];

        require(
            r.renter == msg.sender || block.timestamp > l.rentalEnd,
            "Not renter or not overdue"
        );
        require(!r.returned, "Already returned");

        r.returned = true;
        l.status   = RentalStatus.Available;
        l.currentRenter = address(0);

        bool onTime = block.timestamp <= l.rentalEnd;
        if (onTime) {
            r.collateralRefunded = true;
            payable(r.renter).transfer(r.collateral);
        } else {
            // Late — split collateral between owner and treasury
            uint256 half = r.collateral / 2;
            payable(l.owner).transfer(half);
            payable(treasury).transfer(r.collateral - half);
        }

        emit Returned(recordId, onTime);
    }

    function withdrawListing(uint256 listingId) external nonReentrant {
        RentalListing storage l = listings[listingId];
        require(l.owner == msg.sender,              "Not owner");
        require(l.status == RentalStatus.Available, "Cannot withdraw while rented");

        l.status = RentalStatus.Cancelled;
        IERC721(l.nftContract).safeTransferFrom(address(this), msg.sender, l.tokenId);
        emit ListingWithdrawn(listingId);
    }

    function getOwnerListings(address owner)   external view returns (uint256[] memory) { return ownerListings[owner]; }
    function getRenterHistory(address renter)  external view returns (uint256[] memory) { return renterHistory[renter]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
