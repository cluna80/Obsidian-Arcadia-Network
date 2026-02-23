// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title ToolRating - Community reviews for OAN AI tools (Layer 6, Phase 6.2)
contract ToolRating is AccessControl {
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    struct Review {
        uint256 reviewId;
        uint256 toolId;
        address reviewer;
        uint256 rating;
        string  title;
        string  content;
        uint256 timestamp;
        uint256 helpfulVotes;
        uint256 notHelpfulVotes;
        bool    isVerifiedPurchase;
        bool    isFlagged;
        bool    isHidden;
    }

    struct ToolStats {
        uint256 toolId;
        uint256 totalReviews;
        uint256 averageRating;
        uint256 fiveStars;
        uint256 fourStars;
        uint256 threeStars;
        uint256 twoStars;
        uint256 oneStar;
        uint256 totalHelpfulVotes;
    }

    uint256 private _reviewCounter;
    mapping(uint256 => Review)    public reviews;
    mapping(uint256 => ToolStats) public toolStats;
    mapping(uint256 => uint256[]) public toolReviews;
    mapping(address => uint256[]) public reviewerHistory;
    mapping(address => mapping(uint256 => bool)) public hasReviewed;
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(address => mapping(uint256 => bool)) public verifiedPurchaser;

    uint256 public totalReviews;

    event ReviewSubmitted(uint256 indexed reviewId, uint256 indexed toolId, address indexed reviewer, uint256 rating);
    event ReviewVoted(uint256 indexed reviewId, address indexed voter, bool helpful);
    event ReviewFlagged(uint256 indexed reviewId, address indexed reporter);
    event ReviewHidden(uint256 indexed reviewId, string reason);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE,     msg.sender);
    }

    function submitReview(
        uint256 toolId,
        uint256 rating,
        string memory title,
        string memory content
    ) external returns (uint256) {
        require(!hasReviewed[msg.sender][toolId],       "Already reviewed");
        require(rating >= 1 && rating <= 5,            "Rating 1-5");
        require(bytes(title).length > 0,               "Title required");
        require(bytes(content).length >= 10,           "Content too short");

        hasReviewed[msg.sender][toolId] = true;

        uint256 reviewId = ++_reviewCounter;
        reviews[reviewId] = Review({
            reviewId:           reviewId,
            toolId:             toolId,
            reviewer:           msg.sender,
            rating:             rating,
            title:              title,
            content:            content,
            timestamp:          block.timestamp,
            helpfulVotes:       0,
            notHelpfulVotes:    0,
            isVerifiedPurchase: verifiedPurchaser[msg.sender][toolId],
            isFlagged:          false,
            isHidden:           false
        });

        toolReviews[toolId].push(reviewId);
        reviewerHistory[msg.sender].push(reviewId);
        totalReviews++;

        ToolStats storage s = toolStats[toolId];
        s.toolId = toolId;
        s.totalReviews++;
        s.averageRating = ((s.averageRating * (s.totalReviews - 1)) + (rating * 100)) / s.totalReviews;
        if      (rating == 5) s.fiveStars++;
        else if (rating == 4) s.fourStars++;
        else if (rating == 3) s.threeStars++;
        else if (rating == 2) s.twoStars++;
        else                  s.oneStar++;

        emit ReviewSubmitted(reviewId, toolId, msg.sender, rating);
        return reviewId;
    }

    function voteHelpful(uint256 reviewId, bool helpful) external {
        require(!hasVoted[msg.sender][reviewId],             "Already voted");
        require(reviews[reviewId].reviewer != msg.sender,   "No self-vote");

        hasVoted[msg.sender][reviewId] = true;
        if (helpful) {
            reviews[reviewId].helpfulVotes++;
            toolStats[reviews[reviewId].toolId].totalHelpfulVotes++;
        } else {
            reviews[reviewId].notHelpfulVotes++;
        }
        emit ReviewVoted(reviewId, msg.sender, helpful);
    }

    function flagReview(uint256 reviewId) external {
        require(!reviews[reviewId].isFlagged, "Already flagged");
        reviews[reviewId].isFlagged = true;
        emit ReviewFlagged(reviewId, msg.sender);
    }

    function hideReview(uint256 reviewId, string memory reason) external onlyRole(MODERATOR_ROLE) {
        reviews[reviewId].isHidden = true;
        emit ReviewHidden(reviewId, reason);
    }

    function markVerifiedPurchase(address user, uint256 toolId) external onlyRole(MODERATOR_ROLE) {
        verifiedPurchaser[user][toolId] = true;
    }

    function getToolReviews(uint256 toolId)       external view returns (uint256[] memory) { return toolReviews[toolId]; }
    function getReviewerHistory(address reviewer) external view returns (uint256[] memory) { return reviewerHistory[reviewer]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
