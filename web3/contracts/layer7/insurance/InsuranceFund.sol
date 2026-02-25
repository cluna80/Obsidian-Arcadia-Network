// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title InsuranceFund
/// @notice Protocol-level insurance pool for covering losses across OAN
contract InsuranceFund is AccessControl, ReentrancyGuard {

    bytes32 public constant CLAIMS_ADMIN_ROLE = keccak256("CLAIMS_ADMIN_ROLE");
    bytes32 public constant CONTRIBUTOR_ROLE  = keccak256("CONTRIBUTOR_ROLE");

    enum PolicyType  { SmartContractBug, FraudLoss, OracleFault, BridgeFailure, Custom }
    enum ClaimStatus { Submitted, UnderReview, Approved, Rejected, Paid }

    struct Policy {
        uint256     id;
        address     holder;
        PolicyType  policyType;
        uint256     coverageAmount;
        uint256     premium;            // paid upfront
        uint256     startedAt;
        uint256     expiresAt;
        bool        active;
    }

    struct InsuranceClaim {
        uint256     id;
        uint256     policyId;
        address     claimant;
        uint256     requestedAmount;
        uint256     approvedAmount;
        ClaimStatus status;
        bytes32     evidenceHash;
        uint256     submittedAt;
        string      description;
    }

    struct PoolStats {
        uint256 totalPremiums;
        uint256 totalClaimed;
        uint256 totalReserve;
        uint256 activePolicies;
    }

    uint256 public policyCounter;
    uint256 public claimCounter;
    uint256 public reserveRatio   = 200;  // 200% reserve of max exposure
    uint256 public maxPayoutRatio = 80;   // max 80% of pool per single claim
    uint256 public premiumRate    = 100;  // basis points of coverage (1%)
    address public treasury;

    PoolStats public poolStats;

    mapping(uint256 => Policy)         public policies;
    mapping(uint256 => InsuranceClaim) public claims;
    mapping(address => uint256[])      public holderPolicies;
    mapping(address => uint256[])      public claimantClaims;
    mapping(PolicyType => uint256)     public maxCoverageByType;

    event PolicyIssued(uint256 indexed policyId, address indexed holder, PolicyType policyType, uint256 coverage);
    event PolicyExpired(uint256 indexed policyId, address indexed holder);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, uint256 requestedAmount);
    event ClaimApproved(uint256 indexed claimId, uint256 approvedAmount);
    event ClaimRejected(uint256 indexed claimId, string reason);
    event ClaimPaid(uint256 indexed claimId, address indexed claimant, uint256 amount);
    event FundDeposited(address indexed contributor, uint256 amount);
    event FundWithdrawn(address indexed to, uint256 amount);

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE,  msg.sender);
        _grantRole(CLAIMS_ADMIN_ROLE,   msg.sender);
        _grantRole(CONTRIBUTOR_ROLE,    msg.sender);

        // Default max coverage by type
        maxCoverageByType[PolicyType.SmartContractBug] = 100 ether;
        maxCoverageByType[PolicyType.FraudLoss]        = 50 ether;
        maxCoverageByType[PolicyType.OracleFault]      = 30 ether;
        maxCoverageByType[PolicyType.BridgeFailure]    = 80 ether;
        maxCoverageByType[PolicyType.Custom]           = 20 ether;
    }

    /// @notice Fund the insurance pool
    function fundPool() external payable onlyRole(CONTRIBUTOR_ROLE) {
        require(msg.value > 0, "No value sent");
        poolStats.totalReserve += msg.value;
        emit FundDeposited(msg.sender, msg.value);
    }

    /// @notice Purchase an insurance policy
    function purchasePolicy(
        PolicyType policyType,
        uint256 coverageAmount,
        uint256 duration
    ) external payable nonReentrant returns (uint256 policyId) {
        uint256 maxCov = maxCoverageByType[policyType];
        require(coverageAmount <= maxCov,  "Coverage exceeds max");
        require(duration > 0,              "Invalid duration");

        uint256 premium = (coverageAmount * premiumRate) / 10000;
        require(msg.value >= premium,      "Insufficient premium");

        // Check pool can cover
        require(poolStats.totalReserve >= coverageAmount, "Pool insufficient");

        policyCounter++;
        policyId = policyCounter;

        policies[policyId] = Policy({
            id:             policyId,
            holder:         msg.sender,
            policyType:     policyType,
            coverageAmount: coverageAmount,
            premium:        premium,
            startedAt:      block.timestamp,
            expiresAt:      block.timestamp + duration,
            active:         true
        });

        holderPolicies[msg.sender].push(policyId);
        poolStats.totalPremiums  += premium;
        poolStats.totalReserve   += premium;
        poolStats.activePolicies++;

        // Refund excess premium
        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }

        emit PolicyIssued(policyId, msg.sender, policyType, coverageAmount);
    }

    /// @notice Submit an insurance claim
    function submitClaim(
        uint256 policyId,
        uint256 requestedAmount,
        bytes32 evidenceHash,
        string calldata description
    ) external nonReentrant returns (uint256 claimId) {
        Policy storage policy = policies[policyId];
        require(policy.holder == msg.sender, "Not policy holder");
        require(policy.active,               "Policy not active");
        require(block.timestamp <= policy.expiresAt, "Policy expired");
        require(requestedAmount <= policy.coverageAmount, "Exceeds coverage");

        claimCounter++;
        claimId = claimCounter;

        claims[claimId] = InsuranceClaim({
            id:              claimId,
            policyId:        policyId,
            claimant:        msg.sender,
            requestedAmount: requestedAmount,
            approvedAmount:  0,
            status:          ClaimStatus.Submitted,
            evidenceHash:    evidenceHash,
            submittedAt:     block.timestamp,
            description:     description
        });

        claimantClaims[msg.sender].push(claimId);
        emit ClaimSubmitted(claimId, policyId, requestedAmount);
    }

    /// @notice Approve and pay a claim
    function approveClaim(uint256 claimId, uint256 approvedAmount)
        external onlyRole(CLAIMS_ADMIN_ROLE) nonReentrant
    {
        InsuranceClaim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Submitted || claim.status == ClaimStatus.UnderReview, "Not reviewable");

        Policy storage policy = policies[claim.policyId];
        require(approvedAmount <= policy.coverageAmount, "Exceeds coverage");

        uint256 maxPayout = (poolStats.totalReserve * maxPayoutRatio) / 100;
        uint256 payout    = approvedAmount > maxPayout ? maxPayout : approvedAmount;

        claim.approvedAmount = payout;
        claim.status         = ClaimStatus.Approved;
        emit ClaimApproved(claimId, payout);

        // Pay immediately
        claim.status            = ClaimStatus.Paid;
        poolStats.totalReserve -= payout;
        poolStats.totalClaimed += payout;

        payable(claim.claimant).transfer(payout);
        emit ClaimPaid(claimId, claim.claimant, payout);
    }

    /// @notice Reject a claim
    function rejectClaim(uint256 claimId, string calldata reason) external onlyRole(CLAIMS_ADMIN_ROLE) {
        InsuranceClaim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Submitted || claim.status == ClaimStatus.UnderReview, "Not reviewable");
        claim.status = ClaimStatus.Rejected;
        emit ClaimRejected(claimId, reason);
    }

    /// @notice Emergency withdrawal by admin (to treasury)
    function emergencyWithdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        poolStats.totalReserve -= amount;
        payable(treasury).transfer(amount);
        emit FundWithdrawn(treasury, amount);
    }

    /// @notice Get pool balance
    function getPoolBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /// @notice Get all policy IDs for a holder
    function getHolderPolicies(address holder) external view returns (uint256[] memory) {
        return holderPolicies[holder];
    }

    /// @notice Get all claim IDs for a claimant
    function getClaimantClaims(address claimant) external view returns (uint256[] memory) {
        return claimantClaims[claimant];
    }
}
