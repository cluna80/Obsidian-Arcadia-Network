// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title DisputeResolution
/// @notice Decentralized dispute resolution for OAN protocol conflicts
contract DisputeResolution is AccessControl, ReentrancyGuard {

    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");
    bytes32 public constant JUROR_ROLE      = keccak256("JUROR_ROLE");

    enum DisputeStatus  { Filed, Responding, UnderReview, Voting, Resolved, Appealed, Closed }
    enum DisputeType    { Marketplace, Service, Identity, Behavior, Payment, Contract, Custom }
    enum Resolution     { Pending, FavorPlaintiff, FavorDefendant, Split, Dismissed }

    struct Dispute {
        uint256       id;
        DisputeType   disputeType;
        address       plaintiff;
        address       defendant;
        uint256       stakeAmount;      // ETH staked by both parties
        bytes32       evidenceHash;
        string        description;
        DisputeStatus status;
        Resolution    resolution;
        uint256       filedAt;
        uint256       responseDeadline;
        uint256       resolutionDeadline;
        uint256       plaintiffVotes;
        uint256       defendantVotes;
        bool          appealed;
    }

    struct Evidence {
        uint256 disputeId;
        address submitter;
        bytes32 contentHash;
        uint256 submittedAt;
        bool    isPlaintiff;
    }

    uint256 public disputeCounter;
    uint256 public evidenceCounter;
    uint256 public filingFee        = 0.01 ether;
    uint256 public responseWindow   = 3 days;
    uint256 public resolutionWindow = 7 days;
    uint256 public appealWindow     = 2 days;
    uint256 public minJurors        = 3;
    address public treasury;

    mapping(uint256 => Dispute)                         public disputes;
    mapping(uint256 => Evidence[])                      public disputeEvidence;
    mapping(uint256 => mapping(address => bool))        public jurorVoted;
    mapping(uint256 => mapping(address => Resolution))  public jurorVotes;
    mapping(address => uint256[])                       public plaintiffDisputes;
    mapping(address => uint256[])                       public defendantDisputes;
    mapping(uint256 => bool)                            public defendantResponded;

    event DisputeFiled(uint256 indexed disputeId, address indexed plaintiff, address indexed defendant, DisputeType disputeType);
    event DisputeResponded(uint256 indexed disputeId, address indexed defendant);
    event EvidenceSubmitted(uint256 indexed disputeId, address indexed submitter, bytes32 contentHash);
    event DisputeResolved(uint256 indexed disputeId, Resolution resolution);
    event DisputeAppealed(uint256 indexed disputeId, address indexed appellant);
    event DisputeClosed(uint256 indexed disputeId);
    event JurorVoted(uint256 indexed disputeId, address indexed juror, Resolution vote);

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITRATOR_ROLE,    msg.sender);
        _grantRole(JUROR_ROLE,         msg.sender);
    }

    /// @notice File a new dispute
    function fileDispute(
        address defendant,
        DisputeType disputeType,
        bytes32 evidenceHash,
        string calldata description
    ) external payable nonReentrant returns (uint256 disputeId) {
        require(msg.value >= filingFee,       "Insufficient filing fee");
        require(defendant != msg.sender,       "Cannot dispute yourself");
        require(defendant != address(0),       "Invalid defendant");

        disputeCounter++;
        disputeId = disputeCounter;

        disputes[disputeId] = Dispute({
            id:                  disputeId,
            disputeType:         disputeType,
            plaintiff:           msg.sender,
            defendant:           defendant,
            stakeAmount:         msg.value,
            evidenceHash:        evidenceHash,
            description:         description,
            status:              DisputeStatus.Filed,
            resolution:          Resolution.Pending,
            filedAt:             block.timestamp,
            responseDeadline:    block.timestamp + responseWindow,
            resolutionDeadline:  block.timestamp + responseWindow + resolutionWindow,
            plaintiffVotes:      0,
            defendantVotes:      0,
            appealed:            false
        });

        plaintiffDisputes[msg.sender].push(disputeId);
        defendantDisputes[defendant].push(disputeId);

        emit DisputeFiled(disputeId, msg.sender, defendant, disputeType);
    }

    /// @notice Defendant responds to dispute
    function respondToDispute(uint256 disputeId, bytes32 responseHash) external payable nonReentrant {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.defendant == msg.sender,    "Not defendant");
        require(dispute.status == DisputeStatus.Filed, "Not in filed state");
        require(block.timestamp <= dispute.responseDeadline, "Response deadline passed");

        // Defendant must match plaintiff stake
        require(msg.value >= dispute.stakeAmount, "Must match plaintiff stake");
        dispute.stakeAmount += msg.value;
        dispute.status       = DisputeStatus.Responding;
        defendantResponded[disputeId] = true;

        _submitEvidence(disputeId, responseHash, false);
        emit DisputeResponded(disputeId, msg.sender);
    }

    /// @notice Submit evidence for a dispute
    function submitEvidence(uint256 disputeId, bytes32 contentHash) external {
        Dispute storage dispute = disputes[disputeId];
        require(
            msg.sender == dispute.plaintiff || msg.sender == dispute.defendant,
            "Not party to dispute"
        );
        require(
            dispute.status == DisputeStatus.Filed ||
            dispute.status == DisputeStatus.Responding ||
            dispute.status == DisputeStatus.UnderReview,
            "Cannot submit evidence now"
        );
        _submitEvidence(disputeId, contentHash, msg.sender == dispute.plaintiff);
    }

    function _submitEvidence(uint256 disputeId, bytes32 contentHash, bool isPlaintiff) internal {
        evidenceCounter++;
        disputeEvidence[disputeId].push(Evidence({
            disputeId:   disputeId,
            submitter:   msg.sender,
            contentHash: contentHash,
            submittedAt: block.timestamp,
            isPlaintiff: isPlaintiff
        }));
        emit EvidenceSubmitted(disputeId, msg.sender, contentHash);
    }

    /// @notice Juror casts a vote
    function castJurorVote(uint256 disputeId, Resolution vote) external onlyRole(JUROR_ROLE) {
        Dispute storage dispute = disputes[disputeId];
        require(
            dispute.status == DisputeStatus.UnderReview ||
            dispute.status == DisputeStatus.Voting,
            "Not in voting phase"
        );
        require(!jurorVoted[disputeId][msg.sender], "Already voted");
        require(vote != Resolution.Pending,          "Invalid vote");

        jurorVoted[disputeId][msg.sender] = true;
        jurorVotes[disputeId][msg.sender] = vote;

        if (vote == Resolution.FavorPlaintiff) {
            dispute.plaintiffVotes++;
        } else if (vote == Resolution.FavorDefendant) {
            dispute.defendantVotes++;
        }

        dispute.status = DisputeStatus.Voting;
        emit JurorVoted(disputeId, msg.sender, vote);
    }

    /// @notice Arbitrator resolves a dispute
    function resolveDispute(uint256 disputeId, Resolution resolution)
        external onlyRole(ARBITRATOR_ROLE) nonReentrant
    {
        Dispute storage dispute = disputes[disputeId];
        require(dispute.status != DisputeStatus.Closed, "Already closed");
        require(dispute.status != DisputeStatus.Resolved, "Already resolved");
        require(resolution != Resolution.Pending, "Invalid resolution");

        dispute.resolution = resolution;
        dispute.status     = DisputeStatus.Resolved;

        _distributeStake(disputeId, resolution);
        emit DisputeResolved(disputeId, resolution);
    }

    function _distributeStake(uint256 disputeId, Resolution resolution) internal {
        Dispute storage dispute = disputes[disputeId];
        uint256 total    = dispute.stakeAmount;
        uint256 feeShare = total / 10;  // 10% to treasury
        uint256 payout   = total - feeShare;

        payable(treasury).transfer(feeShare);

        if (resolution == Resolution.FavorPlaintiff) {
            payable(dispute.plaintiff).transfer(payout);
        } else if (resolution == Resolution.FavorDefendant) {
            payable(dispute.defendant).transfer(payout);
        } else if (resolution == Resolution.Split) {
            payable(dispute.plaintiff).transfer(payout / 2);
            payable(dispute.defendant).transfer(payout / 2);
        } else {
            // Dismissed — return stakes minus fee
            uint256 halfFee = feeShare / 2;
            payable(dispute.plaintiff).transfer((payout + feeShare - halfFee * 2) / 2 + halfFee);
            payable(dispute.defendant).transfer((payout + feeShare - halfFee * 2) / 2 + halfFee);
        }

        dispute.stakeAmount = 0;
        dispute.status      = DisputeStatus.Closed;
        emit DisputeClosed(disputeId);
    }

    /// @notice Appeal a resolved dispute
    function appealDispute(uint256 disputeId) external payable nonReentrant {
        Dispute storage dispute = disputes[disputeId];
        require(
            msg.sender == dispute.plaintiff || msg.sender == dispute.defendant,
            "Not party to dispute"
        );
        require(dispute.status == DisputeStatus.Resolved, "Not resolved");
        require(!dispute.appealed, "Already appealed");
        require(
            block.timestamp <= dispute.filedAt + responseWindow + resolutionWindow + appealWindow,
            "Appeal window closed"
        );
        require(msg.value >= filingFee * 2, "Insufficient appeal fee");

        dispute.appealed = true;
        dispute.status   = DisputeStatus.Appealed;
        dispute.stakeAmount += msg.value;

        emit DisputeAppealed(disputeId, msg.sender);
    }

    /// @notice Get all evidence for a dispute
    function getDisputeEvidence(uint256 disputeId) external view returns (Evidence[] memory) {
        return disputeEvidence[disputeId];
    }

    /// @notice Get disputes filed by a plaintiff
    function getPlaintiffDisputes(address plaintiff) external view returns (uint256[] memory) {
        return plaintiffDisputes[plaintiff];
    }

    /// @notice Get disputes against a defendant
    function getDefendantDisputes(address defendant) external view returns (uint256[] memory) {
        return defendantDisputes[defendant];
    }

    /// @notice Update filing fee
    function setFilingFee(uint256 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        filingFee = newFee;
    }
}
