// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ProposalSystem
 * @dev Proposal creation and management for OAN DAO
 */
contract ProposalSystem is Ownable {
    
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    
    enum ProposalType {
        Standard,           // General governance
        Treasury,           // Treasury spending
        ProtocolUpgrade,    // Smart contract upgrades
        ParameterChange,    // Protocol parameter changes
        Emergency           // Emergency actions
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        ProposalType proposalType;
        ProposalState state;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startBlock;
        uint256 endBlock;
        uint256 eta;                // Execution time
        bytes[] calldatas;          // Function calls to execute
        address[] targets;          // Target contracts
        uint256[] values;           // ETH values for calls
        uint256 createdAt;
    }
    
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    
    // Proposal parameters
    uint256 public votingDelay = 1 days;
    uint256 public votingPeriod = 3 days;
    uint256 public proposalThreshold = 100_000 * 10**18; // 100k tokens to propose
    uint256 public quorum = 4_000_000 * 10**18;          // 4M tokens for quorum
    
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        ProposalType proposalType
    );
    event ProposalCanceled(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    
    constructor() Ownable(msg.sender) {}
    
    function createProposal(
        string memory title,
        string memory description,
        ProposalType proposalType,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) external returns (uint256) {
        require(targets.length == values.length, "Length mismatch");
        require(targets.length == calldatas.length, "Length mismatch");
        require(targets.length > 0, "Empty proposal");
        
        uint256 proposalId = proposalCount++;
        uint256 startBlock = block.number + (votingDelay / 12); // ~12s blocks
        uint256 endBlock = startBlock + (votingPeriod / 12);
        
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            proposalType: proposalType,
            state: ProposalState.Pending,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            startBlock: startBlock,
            endBlock: endBlock,
            eta: 0,
            targets: targets,
            values: values,
            calldatas: calldatas,
            createdAt: block.timestamp
        });
        
        emit ProposalCreated(proposalId, msg.sender, title, proposalType);
        return proposalId;
    }
    
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer || msg.sender == owner(),
            "Not authorized"
        );
        require(proposal.state == ProposalState.Pending || proposal.state == ProposalState.Active, "Cannot cancel");
        
        proposal.state = ProposalState.Canceled;
        
        emit ProposalCanceled(proposalId);
    }
    
    function queueProposal(uint256 proposalId, uint256 eta) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Succeeded, "Not succeeded");
        
        proposal.state = ProposalState.Queued;
        proposal.eta = eta;
        
        emit ProposalQueued(proposalId, eta);
    }
    
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Queued, "Not queued");
        require(block.timestamp >= proposal.eta, "Not ready");
        
        proposal.state = ProposalState.Executed;
        
        // Execute calls would go here in production
        // For now, just mark as executed
        
        emit ProposalExecuted(proposalId);
    }
    
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }
    
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.state == ProposalState.Canceled) return ProposalState.Canceled;
        if (proposal.state == ProposalState.Executed) return ProposalState.Executed;
        
        if (block.number < proposal.startBlock) return ProposalState.Pending;
        if (block.number <= proposal.endBlock) return ProposalState.Active;
        
        // Check if succeeded
        if (proposal.forVotes > proposal.againstVotes && proposal.forVotes >= quorum) {
            return proposal.state == ProposalState.Queued ? ProposalState.Queued : ProposalState.Succeeded;
        }
        
        return ProposalState.Defeated;
    }
    
    function updateVotingParameters(
        uint256 newVotingDelay,
        uint256 newVotingPeriod,
        uint256 newProposalThreshold,
        uint256 newQuorum
    ) external onlyOwner {
        votingDelay = newVotingDelay;
        votingPeriod = newVotingPeriod;
        proposalThreshold = newProposalThreshold;
        quorum = newQuorum;
    }
}
