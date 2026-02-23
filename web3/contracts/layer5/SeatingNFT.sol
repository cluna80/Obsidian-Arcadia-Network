// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @title SeatingNFT - Virtual seats for events (Layer 5, Phase 5.1)
contract SeatingNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _tokenIdCounter;
    enum SeatTier { Standard, Premium, VIP, Skybox, Ringside }
    enum SeatType { Permanent, Seasonal, SingleEvent }
    struct Seat {
        uint256 seatId; uint256 stadiumId; uint256 row; uint256 seatNumber;
        SeatTier tier; SeatType seatType; uint256 pricePerEvent; bool isPermanent;
        uint256 eventsAttended; uint256 totalSpent; uint256 seasonExpiry; bool isListed; uint256 rentalPrice;
    }
    struct SeatPerks { bool exclusiveRewards; bool earlyTicketAccess; bool merchandiseDiscount; bool meetAndGreetAccess; uint256 votingWeight; }
    mapping(uint256 => Seat) public seats;
    mapping(uint256 => SeatPerks) public seatPerks;
    mapping(uint256 => mapping(uint256 => bool)) public seatAttended;
    mapping(uint256 => uint256[]) public stadiumSeats;
    mapping(address => uint256[]) public ownerSeats;
    mapping(uint256 => address) public seatRenter;
    mapping(SeatTier => uint256) public tierMintPrice;
    address public treasury; uint256 public protocolFeePercent = 250;
    event SeatMinted(uint256 indexed seatId, uint256 indexed stadiumId, address indexed owner, SeatTier tier);
    event SeatRented(uint256 indexed seatId, address indexed renter, uint256 eventId);
    event SeatUpgraded(uint256 indexed seatId, SeatTier oldTier, SeatTier newTier);
    constructor(address _treasury) ERC721("OAN Seat", "OANSEAT") {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        tierMintPrice[SeatTier.Standard] = 0.01 ether;
        tierMintPrice[SeatTier.Premium] = 0.05 ether;
        tierMintPrice[SeatTier.VIP] = 0.2 ether;
        tierMintPrice[SeatTier.Skybox] = 1 ether;
        tierMintPrice[SeatTier.Ringside] = 5 ether;
    }
    function mintSeat(uint256 stadiumId, uint256 row, uint256 seatNumber, SeatTier tier, SeatType seatType, uint256 pricePerEvent, uint256 seasonDuration, string memory tokenURI_) external payable nonReentrant returns (uint256) {
        require(msg.value >= tierMintPrice[tier], "Insufficient payment");
        bool isPermanent = (seatType == SeatType.Permanent);
        uint256 tokenId = ++_tokenIdCounter;
        seats[tokenId] = Seat({ seatId: tokenId, stadiumId: stadiumId, row: row, seatNumber: seatNumber, tier: tier, seatType: seatType, pricePerEvent: pricePerEvent, isPermanent: isPermanent, eventsAttended: 0, totalSpent: 0, seasonExpiry: isPermanent ? 0 : block.timestamp + seasonDuration, isListed: false, rentalPrice: 0 });
        seatPerks[tokenId] = _getTierPerks(tier);
        stadiumSeats[stadiumId].push(tokenId);
        ownerSeats[msg.sender].push(tokenId);
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        payable(treasury).transfer((msg.value * protocolFeePercent) / 10000);
        emit SeatMinted(tokenId, stadiumId, msg.sender, tier);
        return tokenId;
    }
    function listSeatForRental(uint256 seatId, uint256 rentalPrice) external { require(ownerOf(seatId) == msg.sender, "Not owner"); seats[seatId].isListed = true; seats[seatId].rentalPrice = rentalPrice; }
    function rentSeat(uint256 seatId, uint256 eventId) external payable nonReentrant {
        Seat storage seat = seats[seatId];
        require(seat.isListed, "Not for rent"); require(msg.value >= seat.rentalPrice, "Insufficient payment");
        require(seatRenter[seatId] == address(0), "Already rented"); require(!seatAttended[seatId][eventId], "Already used");
        seatRenter[seatId] = msg.sender; seatAttended[seatId][eventId] = true; seat.eventsAttended++;
        uint256 fee = (msg.value * protocolFeePercent) / 10000;
        payable(treasury).transfer(fee); payable(ownerOf(seatId)).transfer(msg.value - fee);
        emit SeatRented(seatId, msg.sender, eventId);
    }
    function _getTierPerks(SeatTier tier) internal pure returns (SeatPerks memory) {
        if (tier == SeatTier.Standard) return SeatPerks(false, false, false, false, 1);
        if (tier == SeatTier.Premium) return SeatPerks(true, false, true, false, 2);
        if (tier == SeatTier.VIP) return SeatPerks(true, true, true, false, 5);
        if (tier == SeatTier.Skybox) return SeatPerks(true, true, true, true, 10);
        return SeatPerks(true, true, true, true, 25);
    }
    function getStadiumSeats(uint256 stadiumId) external view returns (uint256[] memory) { return stadiumSeats[stadiumId]; }
    function getOwnerSeats(address owner) external view returns (uint256[] memory) { return ownerSeats[owner]; }
    function setTierPrice(SeatTier tier, uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) { tierMintPrice[tier] = price; }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) { return super.tokenURI(tokenId); }
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) { return super.supportsInterface(interfaceId); }
}
