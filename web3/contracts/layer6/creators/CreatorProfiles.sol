// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CreatorProfiles - Creator reputation & portfolios (Layer 6, Phase 6.3)
contract CreatorProfiles is AccessControl, ReentrancyGuard {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    enum CreatorTier { Newcomer, Rising, Established, Elite, Legendary }

    struct Profile {
        uint256     profileId;
        address     creator;
        string      username;
        string      bio;
        string      avatarURI;
        CreatorTier tier;
        uint256     totalSales;
        uint256     totalRevenue;
        uint256     totalCreations;
        uint256     followersCount;
        uint256     reputation;
        bool        isVerified;
        uint256     createdAt;
        uint256     lastActiveAt;
        string      portfolioURI;
    }

    struct PortfolioItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        string  title;
        string  description;
        uint256 addedAt;
        bool    featured;
    }

    uint256 private _profileCounter;
    uint256 private _itemCounter;

    mapping(uint256 => Profile)        public profiles;
    mapping(address => uint256)        public addressToProfile;
    mapping(string  => uint256)        public usernameToProfile;
    mapping(uint256 => PortfolioItem[]) public portfolioItems;
    mapping(uint256 => string[])       public profileSpecialties;
    mapping(address => mapping(uint256 => bool)) public isFollowing;
    mapping(uint256 => address[])      public followers;

    uint256 public totalProfiles;
    uint256 public verifiedProfiles;

    event ProfileCreated(uint256 indexed profileId, address indexed creator, string username);
    event ProfileVerified(uint256 indexed profileId);
    event TierUpgraded(uint256 indexed profileId, CreatorTier oldTier, CreatorTier newTier);
    event PortfolioItemAdded(uint256 indexed profileId, uint256 indexed itemId);
    event Followed(uint256 indexed profileId, address indexed follower);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE,      msg.sender);
    }

    function createProfile(
        string memory username,
        string memory bio,
        string memory avatarURI,
        string[] memory specialties,
        string memory portfolioURI
    ) external returns (uint256) {
        require(addressToProfile[msg.sender] == 0, "Already has profile");
        require(usernameToProfile[username]  == 0, "Username taken");
        require(bytes(username).length >= 3,        "Username too short");

        uint256 profileId = ++_profileCounter;
        profiles[profileId] = Profile({
            profileId:      profileId,
            creator:        msg.sender,
            username:       username,
            bio:            bio,
            avatarURI:      avatarURI,
            tier:           CreatorTier.Newcomer,
            totalSales:     0,
            totalRevenue:   0,
            totalCreations: 0,
            followersCount: 0,
            reputation:     100,
            isVerified:     false,
            createdAt:      block.timestamp,
            lastActiveAt:   block.timestamp,
            portfolioURI:   portfolioURI
        });

        profileSpecialties[profileId] = specialties;
        addressToProfile[msg.sender] = profileId;
        usernameToProfile[username]  = profileId;
        totalProfiles++;

        emit ProfileCreated(profileId, msg.sender, username);
        return profileId;
    }

    function addPortfolioItem(
        address nftContract,
        uint256 tokenId,
        string memory title,
        string memory description,
        bool featured
    ) external {
        uint256 profileId = addressToProfile[msg.sender];
        require(profileId != 0, "No profile");

        uint256 itemId = ++_itemCounter;
        portfolioItems[profileId].push(PortfolioItem({
            itemId:      itemId,
            nftContract: nftContract,
            tokenId:     tokenId,
            title:       title,
            description: description,
            addedAt:     block.timestamp,
            featured:    featured
        }));

        profiles[profileId].totalCreations++;
        profiles[profileId].lastActiveAt = block.timestamp;
        emit PortfolioItemAdded(profileId, itemId);
    }

    function follow(uint256 profileId) external {
        require(!isFollowing[msg.sender][profileId],   "Already following");
        require(profiles[profileId].creator != msg.sender, "Cannot follow self");
        isFollowing[msg.sender][profileId] = true;
        followers[profileId].push(msg.sender);
        profiles[profileId].followersCount++;
        emit Followed(profileId, msg.sender);
    }

    function recordSale(uint256 profileId, uint256 saleAmount) external onlyRole(VERIFIER_ROLE) {
        Profile storage p = profiles[profileId];
        p.totalSales++;
        p.totalRevenue += saleAmount;
        p.reputation   += 10;
        _checkTierUpgrade(profileId);
    }

    function verifyProfile(uint256 profileId) external onlyRole(VERIFIER_ROLE) {
        require(!profiles[profileId].isVerified, "Already verified");
        profiles[profileId].isVerified = true;
        verifiedProfiles++;
        emit ProfileVerified(profileId);
    }

    function _checkTierUpgrade(uint256 profileId) internal {
        Profile storage p = profiles[profileId];
        CreatorTier old     = p.tier;
        CreatorTier newTier = old;

        if      (p.totalRevenue >= 100 ether) newTier = CreatorTier.Legendary;
        else if (p.totalRevenue >= 10 ether)  newTier = CreatorTier.Elite;
        else if (p.totalRevenue >= 1 ether)   newTier = CreatorTier.Established;
        else if (p.totalRevenue >= 0.1 ether) newTier = CreatorTier.Rising;

        if (newTier != old) {
            p.tier = newTier;
            emit TierUpgraded(profileId, old, newTier);
        }
    }

    function getPortfolio(uint256 profileId)   external view returns (PortfolioItem[] memory) { return portfolioItems[profileId]; }
    function getFollowers(uint256 profileId)   external view returns (address[] memory)        { return followers[profileId]; }
    function getSpecialties(uint256 profileId) external view returns (string[] memory)         { return profileSpecialties[profileId]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
