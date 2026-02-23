// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title EndorsementNFT - Soulbound endorsement tokens (Layer 6, Phase 6.4)
contract EndorsementNFT is ERC721, ERC721URIStorage, AccessControl {
    bytes32 public constant ENDORSER_ROLE = keccak256("ENDORSER_ROLE");

    enum EndorsementType { SkillVerification, CharacterReference, WorkQuality, Innovation, Leadership, Reliability }

    struct Endorsement {
        uint256         endorsementId;
        address         endorser;
        address         recipient;
        EndorsementType endType;
        string          skill;
        uint256         strength;
        string          evidence;
        uint256         issuedAt;
        bool            isRevoked;
        uint256         expiresAt;
    }

    uint256 private _tokenCounter;
    mapping(uint256 => Endorsement) public endorsements;
    mapping(address => uint256[])   public receivedEndorsements;
    mapping(address => uint256[])   public givenEndorsements;
    mapping(address => mapping(address => mapping(EndorsementType => bool))) public hasEndorsed;
    mapping(address => mapping(EndorsementType => uint256)) public endorsementScore;

    event EndorsementIssued(uint256 indexed tokenId, address indexed endorser, address indexed recipient, EndorsementType endType);
    event EndorsementRevoked(uint256 indexed tokenId, string reason);

    constructor() ERC721("OAN Endorsement", "OANEND") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ENDORSER_ROLE,      msg.sender);
    }

    function issueEndorsement(
        address recipient,
        EndorsementType endType,
        string memory skill,
        uint256 strength,
        string memory evidence,
        uint256 duration,
        string memory tokenURI_
    ) external returns (uint256) {
        require(msg.sender != recipient,                          "No self-endorsement");
        require(!hasEndorsed[msg.sender][recipient][endType],    "Already endorsed");
        require(strength >= 1 && strength <= 10,                "Strength 1-10");

        hasEndorsed[msg.sender][recipient][endType] = true;

        uint256 tokenId = ++_tokenCounter;
        endorsements[tokenId] = Endorsement({
            endorsementId: tokenId,
            endorser:      msg.sender,
            recipient:     recipient,
            endType:       endType,
            skill:         skill,
            strength:      strength,
            evidence:      evidence,
            issuedAt:      block.timestamp,
            isRevoked:     false,
            expiresAt:     duration > 0 ? block.timestamp + duration : 0
        });

        receivedEndorsements[recipient].push(tokenId);
        givenEndorsements[msg.sender].push(tokenId);
        endorsementScore[recipient][endType] += strength;

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURI_);

        emit EndorsementIssued(tokenId, msg.sender, recipient, endType);
        return tokenId;
    }

    function revokeEndorsement(uint256 tokenId, string memory reason) external {
        Endorsement storage e = endorsements[tokenId];
        require(e.endorser == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        e.isRevoked = true;
        if (endorsementScore[e.recipient][e.endType] >= e.strength)
            endorsementScore[e.recipient][e.endType] -= e.strength;
        emit EndorsementRevoked(tokenId, reason);
    }

    function isValid(uint256 tokenId) external view returns (bool) {
        Endorsement memory e = endorsements[tokenId];
        return !e.isRevoked && (e.expiresAt == 0 || block.timestamp <= e.expiresAt);
    }

    // ── Soulbound: block all transfers ──────────────────────
    function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert("Soulbound: non-transferable");
    }
    function safeTransferFrom(address, address, uint256, bytes memory) public pure override(ERC721, IERC721) {
        revert("Soulbound: non-transferable");
    }

    function getReceivedEndorsements(address user) external view returns (uint256[] memory) { return receivedEndorsements[user]; }
    function getEndorsementScore(address user, EndorsementType endType) external view returns (uint256) { return endorsementScore[user][endType]; }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) { return super.tokenURI(tokenId); }
    function supportsInterface(bytes4 i) public view override(ERC721, ERC721URIStorage, AccessControl) returns (bool) { return super.supportsInterface(i); }
}
