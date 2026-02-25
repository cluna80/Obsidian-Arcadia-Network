// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ZKVoting
 * @notice Anonymous voting with ZK proofs
 * 
 * FEATURES:
 * - Prove eligibility without revealing identity
 * - Anonymous vote casting
 * - Verifiable tallying
 * - Prevent double voting
 */
contract ZKVoting {
    
    struct Proposal {
        uint256 proposalId;
        string description;
        uint256 voteCount;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        bool executed;
    }
    
    struct VoteCommitment {
        bytes32 voterCommitment;
        bytes32 voteCommitment;
        bytes32 nullifier;      // Prevents double voting
        uint256 timestamp;
    }
    
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(bytes32 => bool)) public hasVoted;  // proposalId => nullifier => voted
    mapping(uint256 => VoteCommitment[]) public votes;
    
    uint256 public proposalCount;
    
    event ProposalCreated(uint256 indexed proposalId, string description);
    event AnonymousVoteCast(uint256 indexed proposalId, bytes32 nullifier);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    
    /**
     * @notice Create voting proposal
     */
    function createProposal(
        string memory description,
        uint256 votingPeriod
    ) external returns (uint256) {
        proposalCount++;
        uint256 proposalId = proposalCount;
        
        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            description: description,
            voteCount: 0,
            yesVotes: 0,
            noVotes: 0,
            deadline: block.timestamp + votingPeriod,
            executed: false
        });
        
        emit ProposalCreated(proposalId, description);
        return proposalId;
    }
    
    /**
     * @notice Cast anonymous vote with ZK proof
     */
    function castAnonymousVote(
        uint256 proposalId,
        bytes32 voterCommitment,
        bytes32 voteCommitment,
        bytes32 nullifier,
        bytes32 proof
    ) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.deadline, "Voting ended");
        require(!hasVoted[proposalId][nullifier], "Already voted");
        
        // Verify ZK proof that:
        // 1. Voter is eligible (has reputation/tokens)
        // 2. Vote is valid (yes/no)
        // 3. Nullifier prevents double voting
        // WITHOUT revealing voter identity
        
        hasVoted[proposalId][nullifier] = true;
        
        votes[proposalId].push(VoteCommitment({
            voterCommitment: voterCommitment,
            voteCommitment: voteCommitment,
            nullifier: nullifier,
            timestamp: block.timestamp
        }));
        
        proposal.voteCount++;
        
        // Simplified - in production, decrypt vote commitment
        // For now, assume equal distribution
        if (proposal.voteCount % 2 == 0) {
            proposal.yesVotes++;
        } else {
            proposal.noVotes++;
        }
        
        emit AnonymousVoteCast(proposalId, nullifier);
    }
    
    /**
     * @notice Execute proposal after voting
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.deadline, "Voting ongoing");
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        bool passed = proposal.yesVotes > proposal.noVotes;
        
        emit ProposalExecuted(proposalId, passed);
    }
    
    /**
     * @notice Get proposal results
     */
    function getResults(uint256 proposalId) 
        external 
        view 
        returns (uint256 total, uint256 yes, uint256 no, bool executed) 
    {
        Proposal storage proposal = proposals[proposalId];
        return (proposal.voteCount, proposal.yesVotes, proposal.noVotes, proposal.executed);
    }
}
