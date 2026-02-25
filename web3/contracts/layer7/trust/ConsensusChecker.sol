// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ConsensusChecker
/// @notice Multi-signature consensus verification for critical OAN protocol actions
contract ConsensusChecker is AccessControl, ReentrancyGuard {

    bytes32 public constant SIGNER_ROLE   = keccak256("SIGNER_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    enum ProposalStatus { Active, Approved, Rejected, Expired, Executed }
    enum ProposalType   { TrustUpdate, Suspension, ContractUpgrade, ParameterChange, EmergencyAction, Custom }

    struct Proposal {
        uint256        id;
        ProposalType   proposalType;
        address        target;
        bytes          callData;        // encoded function call to execute if approved
        bytes32        descriptionHash;
        uint256        createdAt;
        uint256        expiresAt;
        uint256        requiredSignatures;
        uint256        approvals;
        uint256        rejections;
        ProposalStatus status;
        address        proposer;
        bool           executed;
    }

    struct ConsensusConfig {
        uint256 requiredSignatures;   // number of signatures required
        uint256 timeoutDuration;      // proposal lifetime
        uint256 executionDelay;       // delay after approval before execution
    }

    uint256 public proposalCounter;
    uint256 public defaultRequiredSigs = 3;
    uint256 public defaultTimeout      = 7 days;
    uint256 public executionDelay      = 24 hours;

    mapping(uint256 => Proposal)                       public proposals;
    mapping(uint256 => mapping(address => bool))       public hasVoted;
    mapping(uint256 => mapping(address => bool))       public voteChoice;   // true=approve
    mapping(uint256 => uint256)                        public approvedAt;
    mapping(ProposalType => ConsensusConfig)           public typeConfigs;
    mapping(address => uint256[])                      public signerHistory;

    event ProposalCreated(uint256 indexed proposalId, ProposalType proposalType, address target);
    event VoteCast(uint256 indexed proposalId, address indexed signer, bool approved);
    event ProposalApproved(uint256 indexed proposalId, uint256 approvals);
    event ProposalRejected(uint256 indexed proposalId, uint256 rejections);
    event ProposalExecuted(uint256 indexed proposalId, address target, bool success);
    event ProposalExpired(uint256 indexed proposalId);

    constructor(uint256 _requiredSigs) {
        require(_requiredSigs >= 1, "Min 1 signature");
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SIGNER_ROLE,        msg.sender);
        _grantRole(PROPOSER_ROLE,      msg.sender);
        defaultRequiredSigs = _requiredSigs;
    }

    /// @notice Create a new consensus proposal
    function createProposal(
        ProposalType proposalType,
        address target,
        bytes calldata callData,
        bytes32 descriptionHash
    ) external onlyRole(PROPOSER_ROLE) returns (uint256 proposalId) {
        proposalCounter++;
        proposalId = proposalCounter;

        ConsensusConfig memory config = typeConfigs[proposalType];
        uint256 required = config.requiredSignatures > 0 ? config.requiredSignatures : defaultRequiredSigs;
        uint256 timeout  = config.timeoutDuration  > 0 ? config.timeoutDuration  : defaultTimeout;

        proposals[proposalId] = Proposal({
            id:                 proposalId,
            proposalType:       proposalType,
            target:             target,
            callData:           callData,
            descriptionHash:    descriptionHash,
            createdAt:          block.timestamp,
            expiresAt:          block.timestamp + timeout,
            requiredSignatures: required,
            approvals:          0,
            rejections:         0,
            status:             ProposalStatus.Active,
            proposer:           msg.sender,
            executed:           false
        });

        emit ProposalCreated(proposalId, proposalType, target);
    }

    /// @notice Cast a vote on a proposal
    function castVote(uint256 proposalId, bool approve) external onlyRole(SIGNER_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "Proposal not active");
        require(block.timestamp <= proposal.expiresAt,    "Proposal expired");
        require(!hasVoted[proposalId][msg.sender],         "Already voted");

        hasVoted[proposalId][msg.sender]    = true;
        voteChoice[proposalId][msg.sender]  = approve;
        signerHistory[msg.sender].push(proposalId);

        if (approve) {
            proposal.approvals++;
        } else {
            proposal.rejections++;
        }

        emit VoteCast(proposalId, msg.sender, approve);

        if (proposal.approvals >= proposal.requiredSignatures) {
            proposal.status  = ProposalStatus.Approved;
            approvedAt[proposalId] = block.timestamp;
            emit ProposalApproved(proposalId, proposal.approvals);
        } else if (proposal.rejections >= proposal.requiredSignatures) {
            proposal.status = ProposalStatus.Rejected;
            emit ProposalRejected(proposalId, proposal.rejections);
        }
    }

    /// @notice Execute an approved proposal after delay
    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Approved, "Proposal not approved");
        require(!proposal.executed,                          "Already executed");
        require(
            block.timestamp >= approvedAt[proposalId] + executionDelay,
            "Execution delay not met"
        );

        proposal.executed = true;
        proposal.status   = ProposalStatus.Executed;

        (bool success, ) = proposal.target.call(proposal.callData);
        emit ProposalExecuted(proposalId, proposal.target, success);
        require(success, "Execution failed");
    }

    /// @notice Mark an expired proposal
    function markExpired(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.Active, "Not active");
        require(block.timestamp > proposal.expiresAt,     "Not expired yet");
        proposal.status = ProposalStatus.Expired;
        emit ProposalExpired(proposalId);
    }

    /// @notice Configure consensus requirements per proposal type
    function setTypeConfig(
        ProposalType proposalType,
        uint256 requiredSignatures,
        uint256 timeoutDuration
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        typeConfigs[proposalType] = ConsensusConfig({
            requiredSignatures: requiredSignatures,
            timeoutDuration:    timeoutDuration,
            executionDelay:     executionDelay
        });
    }

    /// @notice Update the execution delay
    function setExecutionDelay(uint256 newDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        executionDelay = newDelay;
    }

    /// @notice Check if a proposal has enough signatures
    function hasConsensus(uint256 proposalId) external view returns (bool) {
        Proposal storage p = proposals[proposalId];
        return p.approvals >= p.requiredSignatures;
    }

    /// @notice Get vote history for a signer
    function getSignerHistory(address signer) external view returns (uint256[] memory) {
        return signerHistory[signer];
    }
}
