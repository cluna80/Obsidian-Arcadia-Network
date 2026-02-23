// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SportsCardNFT - Trading cards for OAN athletes (ERC1155 multi-edition)
/// @notice Layer 5, Phase 5.2 - OAN Metaverse Sports Arena
contract SportsCardNFT is ERC1155, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _cardIdCounter;

    enum CardRarity { Common, Uncommon, Rare, Epic, Legendary, Mythic }
    enum CardType { Base, Rookie, Champion, AllStar, Historic, Special }

    struct CardStats {
        uint256 strength;
        uint256 speed;
        uint256 endurance;
        uint256 technique;
        uint256 wins;
        uint256 losses;
        uint256 knockouts;
    }

    struct Card {
        uint256 cardId;
        uint256 athleteId;         // Link to AthleteNFT
        string athleteName;
        CardRarity rarity;
        CardType cardType;
        uint256 season;            // Season number
        uint256 totalMinted;       // Max supply for this card
        uint256 currentMinted;     // How many have been minted
        CardStats snapshotStats;   // Athlete stats at time of card creation
        uint256 createdAt;
        bool isActive;             // Can still be minted?
        string metadataURI;
    }

    mapping(uint256 => Card) public cards;
    mapping(uint256 => uint256[]) public athleteCards;   // athleteId => cardIds
    mapping(uint256 => mapping(address => uint256)) public cardMintNumber; // cardId => address => their mint#
    mapping(uint256 => mapping(uint256 => address)) public mintNumberOwner; // cardId => mintNumber => owner
    mapping(uint256 => uint256) public cardMintPrice;

    // Rarity determines supply caps
    mapping(CardRarity => uint256) public maxSupplyByRarity;

    address public treasury;
    uint256 public protocolFeePercent = 250;
    uint256 public currentSeason = 1;
    uint256 public totalCardsCreated;

    event CardCreated(uint256 indexed cardId, uint256 indexed athleteId, CardRarity rarity, uint256 maxSupply);
    event CardMinted(uint256 indexed cardId, address indexed to, uint256 mintNumber);
    event SeasonAdvanced(uint256 newSeason);
    event CardRetired(uint256 indexed cardId);

    constructor(address _treasury) ERC1155("") {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        // Set supply caps by rarity
        maxSupplyByRarity[CardRarity.Common] = 10000;
        maxSupplyByRarity[CardRarity.Uncommon] = 5000;
        maxSupplyByRarity[CardRarity.Rare] = 1000;
        maxSupplyByRarity[CardRarity.Epic] = 500;
        maxSupplyByRarity[CardRarity.Legendary] = 100;
        maxSupplyByRarity[CardRarity.Mythic] = 10;
    }

    /// @notice Create a new card template for an athlete
    function createCard(
        uint256 athleteId,
        string memory athleteName,
        CardRarity rarity,
        CardType cardType,
        CardStats memory snapshotStats,
        uint256 mintPrice_,
        string memory metadataURI_
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 cardId = ++_cardIdCounter;
        uint256 maxSupply = maxSupplyByRarity[rarity];

        cards[cardId] = Card({
            cardId: cardId,
            athleteId: athleteId,
            athleteName: athleteName,
            rarity: rarity,
            cardType: cardType,
            season: currentSeason,
            totalMinted: maxSupply,
            currentMinted: 0,
            snapshotStats: snapshotStats,
            createdAt: block.timestamp,
            isActive: true,
            metadataURI: metadataURI_
        });

        cardMintPrice[cardId] = mintPrice_;
        athleteCards[athleteId].push(cardId);
        totalCardsCreated++;

        emit CardCreated(cardId, athleteId, rarity, maxSupply);
        return cardId;
    }

    /// @notice Mint a card (purchase)
    function mintCard(uint256 cardId, uint256 quantity) external payable nonReentrant {
        Card storage card = cards[cardId];
        require(card.isActive, "Card not active");
        require(card.currentMinted + quantity <= card.totalMinted, "Exceeds max supply");
        require(msg.value >= cardMintPrice[cardId] * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            card.currentMinted++;
            uint256 mintNumber = card.currentMinted;
            cardMintNumber[cardId][msg.sender] = mintNumber;
            mintNumberOwner[cardId][mintNumber] = msg.sender;
            emit CardMinted(cardId, msg.sender, mintNumber);
        }

        _mint(msg.sender, cardId, quantity, "");

        uint256 fee = (msg.value * protocolFeePercent) / 10000;
        payable(treasury).transfer(fee);
    }

    /// @notice Retire a card (no more minting)
    function retireCard(uint256 cardId) external onlyRole(MINTER_ROLE) {
        cards[cardId].isActive = false;
        emit CardRetired(cardId);
    }

    /// @notice Advance the season
    function advanceSeason() external onlyRole(DEFAULT_ADMIN_ROLE) {
        currentSeason++;
        emit SeasonAdvanced(currentSeason);
    }

    /// @notice Get all cards for an athlete
    function getAthleteCards(uint256 athleteId) external view returns (uint256[] memory) {
        return athleteCards[athleteId];
    }

    /// @notice Get mint number for an address
    function getMintNumber(uint256 cardId, address owner) external view returns (uint256) {
        return cardMintNumber[cardId][owner];
    }

    /// @notice Calculate card value multiplier (lower mint number = higher value)
    function getValueMultiplier(uint256 cardId, uint256 mintNumber) external view returns (uint256) {
        uint256 maxSupply = cards[cardId].totalMinted;
        if (maxSupply == 0) return 100;
        // #1 gets 1000% multiplier, last gets 100%
        return 100 + ((maxSupply - mintNumber) * 900) / maxSupply;
    }

    // URI
    function uri(uint256 cardId) public view override returns (string memory) {
        return cards[cardId].metadataURI;
    }

    // Admin
    function setMaxSupplyForRarity(CardRarity rarity, uint256 maxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxSupplyByRarity[rarity] = maxSupply;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
