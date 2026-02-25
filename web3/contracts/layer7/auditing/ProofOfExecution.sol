// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ProofOfExecution
 * @notice Cryptographic proof that actions occurred
 * 
 * PROVIDES:
 * - Merkle proofs of action execution
 * - Time-stamped commitments
 * - Verifiable execution logs
 * - Fraud proofs
 */
contract ProofOfExecution {
    
    struct ExecutionProof {
        uint256 proofId;
        uint256 entityId;
        bytes32 actionRoot;          // Merkle root of actions
        uint256 blockNumber;
        uint256 timestamp;
        address prover;
        bytes32 stateRoot;           // State before execution
        bytes32 resultRoot;          // State after execution
        bool verified;
    }
    
    struct Challenge {
        uint256 proofId;
        address challenger;
        uint256 stake;
        string reason;
        uint256 challengedAt;
        bool resolved;
        bool upheld;
    }
    
    mapping(uint256 => ExecutionProof) public proofs;
    mapping(uint256 => Challenge[]) public challenges;
    mapping(uint256 => bytes32[]) public executionHistory;  // entityId => proof hashes
    
    uint256 public proofCount;
    uint256 public challengeStake = 1 ether;
    
    event ProofSubmitted(uint256 indexed proofId, uint256 indexed entityId, bytes32 actionRoot);
    event ProofVerified(uint256 indexed proofId);
    event ProofChallenged(uint256 indexed proofId, address indexed challenger);
    event ChallengeResolved(uint256 indexed proofId, bool upheld);
    
    /**
     * @notice Submit proof of execution
     */
    function submitProof(
        uint256 entityId,
        bytes32 actionRoot,
        bytes32 stateRoot,
        bytes32 resultRoot
    ) external returns (uint256) {
        proofCount++;
        uint256 proofId = proofCount;
        
        proofs[proofId] = ExecutionProof({
            proofId: proofId,
            entityId: entityId,
            actionRoot: actionRoot,
            blockNumber: block.number,
            timestamp: block.timestamp,
            prover: msg.sender,
            stateRoot: stateRoot,
            resultRoot: resultRoot,
            verified: false
        });
        
        bytes32 proofHash = keccak256(abi.encodePacked(
            proofId,
            actionRoot,
            stateRoot,
            resultRoot
        ));
        
        executionHistory[entityId].push(proofHash);
        
        emit ProofSubmitted(proofId, entityId, actionRoot);
        return proofId;
    }
    
    /**
     * @notice Verify proof (after challenge period)
     */
    function verifyProof(uint256 proofId) external {
        ExecutionProof storage proof = proofs[proofId];
        require(!proof.verified, "Already verified");
        require(
            block.timestamp >= proof.timestamp + 1 days,
            "Challenge period not over"
        );
        
        // Check if any challenges were upheld
        Challenge[] storage proofChallenges = challenges[proofId];
        bool hasUpheldChallenge = false;
        
        for (uint256 i = 0; i < proofChallenges.length; i++) {
            if (proofChallenges[i].resolved && proofChallenges[i].upheld) {
                hasUpheldChallenge = true;
                break;
            }
        }
        
        require(!hasUpheldChallenge, "Proof has upheld challenges");
        
        proof.verified = true;
        emit ProofVerified(proofId);
    }
    
    /**
     * @notice Challenge a proof (requires stake)
     */
    function challengeProof(
        uint256 proofId,
        string memory reason
    ) external payable {
        require(msg.value >= challengeStake, "Insufficient stake");
        
        ExecutionProof storage proof = proofs[proofId];
        require(!proof.verified, "Already verified");
        require(
            block.timestamp < proof.timestamp + 1 days,
            "Challenge period over"
        );
        
        challenges[proofId].push(Challenge({
            proofId: proofId,
            challenger: msg.sender,
            stake: msg.value,
            reason: reason,
            challengedAt: block.timestamp,
            resolved: false,
            upheld: false
        }));
        
        emit ProofChallenged(proofId, msg.sender);
    }
    
    /**
     * @notice Resolve challenge (admin/oracle)
     */
    function resolveChallenge(
        uint256 proofId,
        uint256 challengeIndex,
        bool uphold
    ) external {
        Challenge storage challenge = challenges[proofId][challengeIndex];
        require(!challenge.resolved, "Already resolved");
        
        challenge.resolved = true;
        challenge.upheld = uphold;
        
        if (uphold) {
            // Challenger wins, gets stake back + reward
            payable(challenge.challenger).transfer(challenge.stake * 2);
        } else {
            // Prover wins, gets challenger's stake
            ExecutionProof storage proof = proofs[proofId];
            payable(proof.prover).transfer(challenge.stake);
        }
        
        emit ChallengeResolved(proofId, uphold);
    }
    
    /**
     * @notice Verify Merkle proof
     */
    function verifyMerkleProof(
        bytes32 leaf,
        bytes32[] memory proof,
        bytes32 root
    ) public pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash == root;
    }
    
    /**
     * @notice Get entity's execution history
     */
    function getExecutionHistory(uint256 entityId) 
        external 
        view 
        returns (bytes32[] memory) 
    {
        return executionHistory[entityId];
    }
}
