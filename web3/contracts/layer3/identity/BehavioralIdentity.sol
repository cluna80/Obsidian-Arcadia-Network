// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BehavioralIdentity
 * @dev Identity based on decision patterns, not wallet address
 * 
 * Revolutionary: You are HOW you behave
 */
contract BehavioralIdentity is Ownable {
    
    enum RiskStyle {Conservative, Moderate, Aggressive, Reckless}
    enum SocialStyle {Cooperative, Competitive, Neutral, Manipulative}
    enum DecisionPattern {Impulsive, Analytical, Emotional, Strategic}
    
    struct Identity {
        uint256 identityId;
        address owner;
        RiskStyle riskStyle;
        SocialStyle socialStyle;
        DecisionPattern decisionPattern;
        uint256 totalDecisions;
        uint256 successfulDecisions;
        uint256 riskTaken;
        uint256 cooperativeActions;
        uint256 competitiveActions;
        uint256 createdAt;
        uint256 lastUpdate;
    }
    
    struct BehavioralDNA {
        uint256 riskTolerance;          // 0-100
        uint256 cooperativeness;        // 0-100
        uint256 analyticalThinking;     // 0-100
        uint256 emotionalResponse;      // 0-100
        uint256 impulsiveness;          // 0-100
        uint256 strategicPlanning;      // 0-100
        uint256 adaptability;           // 0-100
        uint256 consistency;            // 0-100
    }
    
    struct Decision {
        uint256 decisionId;
        uint256 riskLevel;
        bool wasSuccessful;
        uint256 timestamp;
        bytes32 contextHash;
    }
    
    mapping(address => uint256) public addressToIdentity;
    mapping(uint256 => Identity) public identities;
    mapping(uint256 => BehavioralDNA) public behavioralDNA;
    mapping(uint256 => Decision[]) public decisionHistory;
    
    uint256 private _identityIds;
    
    event IdentityCreated(uint256 indexed identityId, address indexed owner);
    event DecisionRecorded(uint256 indexed identityId, uint256 riskLevel, bool success);
    event BehavioralDNAUpdated(uint256 indexed identityId);
    event StyleClassified(uint256 indexed identityId, RiskStyle riskStyle, SocialStyle socialStyle);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Create behavioral identity
     */
    function createIdentity() external returns (uint256) {
        require(addressToIdentity[msg.sender] == 0, "Identity exists");
        
        _identityIds++;
        uint256 identityId = _identityIds;
        
        identities[identityId] = Identity({
            identityId: identityId,
            owner: msg.sender,
            riskStyle: RiskStyle.Moderate,
            socialStyle: SocialStyle.Neutral,
            decisionPattern: DecisionPattern.Analytical,
            totalDecisions: 0,
            successfulDecisions: 0,
            riskTaken: 0,
            cooperativeActions: 0,
            competitiveActions: 0,
            createdAt: block.timestamp,
            lastUpdate: block.timestamp
        });
        
        behavioralDNA[identityId] = BehavioralDNA({
            riskTolerance: 50,
            cooperativeness: 50,
            analyticalThinking: 50,
            emotionalResponse: 50,
            impulsiveness: 50,
            strategicPlanning: 50,
            adaptability: 50,
            consistency: 50
        });
        
        addressToIdentity[msg.sender] = identityId;
        
        emit IdentityCreated(identityId, msg.sender);
        return identityId;
    }
    
    /**
     * @dev Record a decision
     */
    function recordDecision(
        uint256 identityId,
        uint256 riskLevel,
        bool wasSuccessful,
        bool wasCooperative
    ) external {
        Identity storage identity = identities[identityId];
        require(identity.owner == msg.sender, "Not owner");
        
        identity.totalDecisions++;
        if (wasSuccessful) {
            identity.successfulDecisions++;
        }
        
        identity.riskTaken += riskLevel;
        
        if (wasCooperative) {
            identity.cooperativeActions++;
        } else {
            identity.competitiveActions++;
        }
        
        identity.lastUpdate = block.timestamp;
        
        // Record in history
        decisionHistory[identityId].push(Decision({
            decisionId: decisionHistory[identityId].length,
            riskLevel: riskLevel,
            wasSuccessful: wasSuccessful,
            timestamp: block.timestamp,
            contextHash: bytes32(0)
        }));
        
        emit DecisionRecorded(identityId, riskLevel, wasSuccessful);
        
        // Update behavioral DNA
        _updateBehavioralDNA(identityId);
        
        // Reclassify styles
        _classifyStyles(identityId);
    }
    
    /**
     * @dev Update behavioral DNA based on decisions
     */
    function _updateBehavioralDNA(uint256 identityId) internal {
        Identity storage identity = identities[identityId];
        BehavioralDNA storage dna = behavioralDNA[identityId];
        
        if (identity.totalDecisions > 0) {
            // Calculate risk tolerance
            dna.riskTolerance = (identity.riskTaken * 100) / (identity.totalDecisions * 100);
            if (dna.riskTolerance > 100) dna.riskTolerance = 100;
            
            // Calculate cooperativeness
            dna.cooperativeness = (identity.cooperativeActions * 100) / identity.totalDecisions;
            
            // Calculate consistency (success rate)
            dna.consistency = (identity.successfulDecisions * 100) / identity.totalDecisions;
            
            // Adjust other traits based on patterns
            if (identity.totalDecisions > 10) {
                Decision[] storage history = decisionHistory[identityId];
                uint256 recentRisk = 0;
                uint256 count = 0;
                
                // Look at last 10 decisions
                uint256 start = history.length > 10 ? history.length - 10 : 0;
                for (uint256 i = start; i < history.length; i++) {
                    recentRisk += history[i].riskLevel;
                    count++;
                }
                
                if (count > 0) {
                    uint256 avgRecentRisk = recentRisk / count;
                    // High recent risk = more impulsive
                    if (avgRecentRisk > 70) {
                        dna.impulsiveness = (dna.impulsiveness + 10) > 100 ? 100 : dna.impulsiveness + 10;
                        dna.strategicPlanning = dna.strategicPlanning > 10 ? dna.strategicPlanning - 10 : 0;
                    } else {
                        dna.analyticalThinking = (dna.analyticalThinking + 5) > 100 ? 100 : dna.analyticalThinking + 5;
                    }
                }
            }
        }
        
        emit BehavioralDNAUpdated(identityId);
    }
    
    /**
     * @dev Classify behavioral styles
     */
    function _classifyStyles(uint256 identityId) internal {
        Identity storage identity = identities[identityId];
        BehavioralDNA storage dna = behavioralDNA[identityId];
        
        // Classify risk style
        if (dna.riskTolerance < 30) {
            identity.riskStyle = RiskStyle.Conservative;
        } else if (dna.riskTolerance < 60) {
            identity.riskStyle = RiskStyle.Moderate;
        } else if (dna.riskTolerance < 85) {
            identity.riskStyle = RiskStyle.Aggressive;
        } else {
            identity.riskStyle = RiskStyle.Reckless;
        }
        
        // Classify social style
        if (dna.cooperativeness > 70) {
            identity.socialStyle = SocialStyle.Cooperative;
        } else if (dna.cooperativeness < 30) {
            identity.socialStyle = SocialStyle.Competitive;
        } else {
            identity.socialStyle = SocialStyle.Neutral;
        }
        
        // Classify decision pattern
        if (dna.impulsiveness > 70) {
            identity.decisionPattern = DecisionPattern.Impulsive;
        } else if (dna.analyticalThinking > 70) {
            identity.decisionPattern = DecisionPattern.Analytical;
        } else if (dna.emotionalResponse > 70) {
            identity.decisionPattern = DecisionPattern.Emotional;
        } else {
            identity.decisionPattern = DecisionPattern.Strategic;
        }
        
        emit StyleClassified(identityId, identity.riskStyle, identity.socialStyle);
    }
    
    /**
     * @dev Get identity
     */
    function getIdentity(uint256 identityId) external view returns (Identity memory) {
        return identities[identityId];
    }
    
    /**
     * @dev Get behavioral DNA
     */
    function getBehavioralDNA(uint256 identityId) external view returns (BehavioralDNA memory) {
        return behavioralDNA[identityId];
    }
    
    /**
     * @dev Get decision history
     */
    function getDecisionHistory(uint256 identityId) external view returns (Decision[] memory) {
        return decisionHistory[identityId];
    }
    
    /**
     * @dev Get identity by address
     */
    function getIdentityByAddress(address user) external view returns (uint256) {
        return addressToIdentity[user];
    }
}
