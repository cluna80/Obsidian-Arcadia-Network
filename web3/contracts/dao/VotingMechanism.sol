// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VotingMechanism
 * @dev Voting system for OAN DAO proposals
 */
contract VotingMechanism is Ownable {
    
    enum VoteType {
        Against,
        For,
        Abstain
    }
    
    struct Vote {
        address voter;
        VoteType support;
        uint256 weight;
        uint256 timestamp;
        string reason;
    }
    
    struct VotingPower {
        uint256 tokenBalance;
        uint256 stakedAmount;
        uint256 reputationBonus;
        uint256 totalPower;
    }
    
    // Proposal ID => Voter => Vote
    mapping(uint256 => mapping(address => Vote)) public votes;
    
    // Proposal ID => Vote counts
    mapping(uint256 => uint256) public forVotes;
    mapping(uint256 => uint256) public againstVotes;
    mapping(uint256 => uint256) public abstainVotes;
    
    // Proposal ID => Total voters
    mapping(uint256 => uint256) public totalVoters;
    
    // Proposal ID => Voter list
    mapping(uint256 => address[]) public voters;
    
    // Track if address has voted
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        VoteType support,
        uint256 weight,
        string reason
    );
    event VotingPowerCalculated(address indexed voter, uint256 power);
    
    constructor() Ownable(msg.sender) {}
    
    function castVote(
        uint256 proposalId,
        VoteType support,
        uint256 votingPower,
        string memory reason
    ) external {
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(votingPower > 0, "No voting power");
        
        votes[proposalId][msg.sender] = Vote({
            voter: msg.sender,
            support: support,
            weight: votingPower,
            timestamp: block.timestamp,
            reason: reason
        });
        
        hasVoted[proposalId][msg.sender] = true;
        voters[proposalId].push(msg.sender);
        totalVoters[proposalId]++;
        
        if (support == VoteType.For) {
            forVotes[proposalId] += votingPower;
        } else if (support == VoteType.Against) {
            againstVotes[proposalId] += votingPower;
        } else {
            abstainVotes[proposalId] += votingPower;
        }
        
        emit VoteCast(msg.sender, proposalId, support, votingPower, reason);
    }
    
    function calculateVotingPower(
        address voter,
        uint256 tokenBalance,
        uint256 stakedAmount,
        int256 reputationScore
    ) public pure returns (uint256) {
        uint256 basePower = tokenBalance;
        uint256 stakingBonus = stakedAmount / 2; // 50% bonus from staking
        uint256 reputationBonus = reputationScore > 0 ? uint256(reputationScore) / 10 : 0;
        
        return basePower + stakingBonus + reputationBonus;
    }
    
    function getVote(uint256 proposalId, address voter) 
        external view returns (Vote memory) 
    {
        return votes[proposalId][voter];
    }
    
    function getVoteCounts(uint256 proposalId) 
        external view returns (uint256 forCount, uint256 againstCount, uint256 abstainCount) 
    {
        return (forVotes[proposalId], againstVotes[proposalId], abstainVotes[proposalId]);
    }
    
    function getVoters(uint256 proposalId) external view returns (address[] memory) {
        return voters[proposalId];
    }
    
    function getVoterCount(uint256 proposalId) external view returns (uint256) {
        return totalVoters[proposalId];
    }
    
    function hasVotedOnProposal(uint256 proposalId, address voter) 
        external view returns (bool) 
    {
        return hasVoted[proposalId][voter];
    }
    
    function getWinningOption(uint256 proposalId) external view returns (VoteType) {
        uint256 forCount = forVotes[proposalId];
        uint256 againstCount = againstVotes[proposalId];
        
        if (forCount > againstCount) {
            return VoteType.For;
        } else if (againstCount > forCount) {
            return VoteType.Against;
        } else {
            return VoteType.Abstain;
        }
    }
    
    function getParticipationRate(uint256 proposalId, uint256 totalSupply) 
        external view returns (uint256) 
    {
        uint256 totalVoted = forVotes[proposalId] + againstVotes[proposalId] + abstainVotes[proposalId];
        if (totalSupply == 0) return 0;
        return (totalVoted * 10000) / totalSupply; // Returns basis points
    }
}
