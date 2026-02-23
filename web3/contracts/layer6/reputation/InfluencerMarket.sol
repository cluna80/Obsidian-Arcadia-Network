// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title InfluencerMarket - Monetise OAN influence & reach (Layer 6, Phase 6.4)
contract InfluencerMarket is AccessControl, ReentrancyGuard {
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    enum CampaignType   { Promotion, Review, Tutorial, Collaboration, Airdrop, AMA }
    enum CampaignStatus { Open, InProgress, Completed, Cancelled, Disputed }

    struct InfluencerProfile {
        address  influencer;
        uint256  followerCount;
        uint256  engagementRate;
        uint256  campaignsCompleted;
        uint256  totalEarned;
        uint256  reputationScore;
        bool     isVerified;
        uint256  minCampaignBudget;
    }

    struct Campaign {
        uint256        campaignId;
        address        brand;
        address        influencer;
        CampaignType   campType;
        string         description;
        uint256        budget;
        uint256        deadline;
        CampaignStatus status;
        string         requirements;
        uint256        createdAt;
        string         deliverableURI;
        uint256        targetReach;
    }

    uint256 private _campaignCounter;
    mapping(address => InfluencerProfile) public influencers;
    mapping(address => string[])          public influencerNiches;
    mapping(uint256 => Campaign)          public campaigns;
    mapping(address => uint256[])         public brandCampaigns;
    mapping(address => uint256[])         public influencerCampaigns;
    mapping(uint256 => address[])         public campaignApplicants;

    address public treasury;
    uint256 public platformFeeBps = 500;

    event InfluencerRegistered(address indexed influencer, uint256 followers);
    event CampaignCreated(uint256 indexed campaignId, address indexed brand, uint256 budget);
    event CampaignAccepted(uint256 indexed campaignId, address indexed influencer);
    event CampaignCompleted(uint256 indexed campaignId, uint256 payment);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE,      msg.sender);
    }

    function registerInfluencer(
        uint256 followerCount,
        uint256 engagementRate,
        string[] memory niches,
        uint256 minBudget
    ) external {
        require(influencers[msg.sender].followerCount == 0, "Already registered");
        influencers[msg.sender] = InfluencerProfile({
            influencer:           msg.sender,
            followerCount:        followerCount,
            engagementRate:       engagementRate,
            campaignsCompleted:   0,
            totalEarned:          0,
            reputationScore:      100,
            isVerified:           false,
            minCampaignBudget:    minBudget
        });
        influencerNiches[msg.sender] = niches;
        emit InfluencerRegistered(msg.sender, followerCount);
    }

    function createCampaign(
        CampaignType campType,
        string memory description,
        address preferredInfluencer,
        uint256 deadline,
        string memory requirements,
        uint256 targetReach
    ) external payable returns (uint256) {
        require(msg.value > 0 && deadline > block.timestamp, "Invalid params");

        uint256 campaignId = ++_campaignCounter;
        campaigns[campaignId] = Campaign({
            campaignId:   campaignId,
            brand:        msg.sender,
            influencer:   preferredInfluencer,
            campType:     campType,
            description:  description,
            budget:       msg.value,
            deadline:     deadline,
            status:       preferredInfluencer != address(0) ? CampaignStatus.InProgress : CampaignStatus.Open,
            requirements: requirements,
            createdAt:    block.timestamp,
            deliverableURI: "",
            targetReach:  targetReach
        });

        brandCampaigns[msg.sender].push(campaignId);
        if (preferredInfluencer != address(0)) influencerCampaigns[preferredInfluencer].push(campaignId);
        emit CampaignCreated(campaignId, msg.sender, msg.value);
        return campaignId;
    }

    function applyForCampaign(uint256 campaignId) external {
        require(campaigns[campaignId].status == CampaignStatus.Open, "Not open");
        campaignApplicants[campaignId].push(msg.sender);
    }

    function assignInfluencer(uint256 campaignId, address influencer) external {
        Campaign storage c = campaigns[campaignId];
        require(c.brand == msg.sender && c.status == CampaignStatus.Open, "Invalid");
        c.influencer = influencer;
        c.status     = CampaignStatus.InProgress;
        influencerCampaigns[influencer].push(campaignId);
        emit CampaignAccepted(campaignId, influencer);
    }

    function submitDeliverable(uint256 campaignId, string memory deliverableURI) external {
        Campaign storage c = campaigns[campaignId];
        require(c.influencer == msg.sender && c.status == CampaignStatus.InProgress, "Invalid");
        c.deliverableURI = deliverableURI;
    }

    function approveCampaign(uint256 campaignId) external nonReentrant {
        Campaign storage c = campaigns[campaignId];
        require(c.brand == msg.sender && bytes(c.deliverableURI).length > 0, "Invalid");
        c.status = CampaignStatus.Completed;

        uint256 fee = (c.budget * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(c.influencer).transfer(c.budget - fee);

        influencers[c.influencer].campaignsCompleted++;
        influencers[c.influencer].totalEarned += c.budget;
        emit CampaignCompleted(campaignId, c.budget);
    }

    function verifyInfluencer(address influencer) external onlyRole(VERIFIER_ROLE) { influencers[influencer].isVerified = true; }
    function getApplicants(uint256 campaignId)    external view returns (address[] memory) { return campaignApplicants[campaignId]; }
    function getNiches(address influencer)        external view returns (string[] memory)  { return influencerNiches[influencer]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
