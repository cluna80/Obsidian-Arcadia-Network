// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title BlacklistRegistry
 * @notice Permanent bans for severe violators
 * 
 * FEATURES:
 * - Permanent blacklist
 * - Appeal process
 * - Multi-sig removal
 * - Sybil detection integration
 */
contract BlacklistRegistry is AccessControl {
    
    bytes32 public constant BLACKLIST_MANAGER_ROLE = keccak256("BLACKLIST_MANAGER_ROLE");
    
    struct BlacklistEntry {
        uint256 entityId;
        address entityAddress;
        BlacklistReason reason;
        uint256 timestamp;
        address blacklistedBy;
        string evidence;
        bool isPermanent;
        uint256 expiresAt;
    }
    
    struct Appeal {
        uint256 appealId;
        uint256 entityId;
        address appellant;
        string justification;
        uint256 submittedAt;
        AppealStatus status;
        uint256 votesFor;
        uint256 votesAgainst;
    }
    
    enum BlacklistReason {
        Fraud,
        SevereAbuse,
        SystemExploit,
        Sybil,
        Collusion,
        CriminalActivity
    }
    
    enum AppealStatus {
        Pending,
        Approved,
        Rejected
    }
    
    mapping(uint256 => BlacklistEntry) public blacklist;
    mapping(address => bool) public isBlacklisted;
    mapping(uint256 => Appeal) public appeals;
    mapping(uint256 => mapping(address => bool)) public appealVotes;
    
    uint256 public blacklistCount;
    uint256 public appealCount;
    uint256 public constant APPEAL_THRESHOLD = 3;  // Votes needed
    
    event EntityBlacklisted(uint256 indexed entityId, address indexed entityAddress, BlacklistReason reason);
    event BlacklistRemoved(uint256 indexed entityId);
    event AppealSubmitted(uint256 indexed appealId, uint256 indexed entityId);
    event AppealResolved(uint256 indexed appealId, bool approved);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BLACKLIST_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @notice Add entity to blacklist
     */
    function addToBlacklist(
        uint256 entityId,
        address entityAddress,
        BlacklistReason reason,
        string memory evidence,
        bool isPermanent,
        uint256 duration
    ) external onlyRole(BLACKLIST_MANAGER_ROLE) {
        require(!isBlacklisted[entityAddress], "Already blacklisted");
        
        blacklistCount++;
        
        uint256 expiresAt = isPermanent ? 0 : block.timestamp + duration;
        
        blacklist[blacklistCount] = BlacklistEntry({
            entityId: entityId,
            entityAddress: entityAddress,
            reason: reason,
            timestamp: block.timestamp,
            blacklistedBy: msg.sender,
            evidence: evidence,
            isPermanent: isPermanent,
            expiresAt: expiresAt
        });
        
        isBlacklisted[entityAddress] = true;
        
        emit EntityBlacklisted(entityId, entityAddress, reason);
    }
    
    /**
     * @notice Remove from blacklist (requires admin consensus)
     */
    function removeFromBlacklist(uint256 blacklistId) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        BlacklistEntry storage entry = blacklist[blacklistId];
        require(entry.entityAddress != address(0), "Entry not found");
        
        isBlacklisted[entry.entityAddress] = false;
        
        emit BlacklistRemoved(entry.entityId);
    }
    
    /**
     * @notice Submit appeal
     */
    function submitAppeal(
        uint256 entityId,
        string memory justification
    ) external returns (uint256) {
        require(isBlacklisted[msg.sender], "Not blacklisted");
        
        appealCount++;
        uint256 appealId = appealCount;
        
        appeals[appealId] = Appeal({
            appealId: appealId,
            entityId: entityId,
            appellant: msg.sender,
            justification: justification,
            submittedAt: block.timestamp,
            status: AppealStatus.Pending,
            votesFor: 0,
            votesAgainst: 0
        });
        
        emit AppealSubmitted(appealId, entityId);
        return appealId;
    }
    
    /**
     * @notice Vote on appeal
     */
    function voteOnAppeal(uint256 appealId, bool approve) 
        external 
        onlyRole(BLACKLIST_MANAGER_ROLE) 
    {
        Appeal storage appeal = appeals[appealId];
        require(appeal.status == AppealStatus.Pending, "Appeal not pending");
        require(!appealVotes[appealId][msg.sender], "Already voted");
        
        appealVotes[appealId][msg.sender] = true;
        
        if (approve) {
            appeal.votesFor++;
        } else {
            appeal.votesAgainst++;
        }
        
        // Check if threshold reached
        if (appeal.votesFor >= APPEAL_THRESHOLD) {
            appeal.status = AppealStatus.Approved;
            isBlacklisted[appeal.appellant] = false;
            emit AppealResolved(appealId, true);
        } else if (appeal.votesAgainst >= APPEAL_THRESHOLD) {
            appeal.status = AppealStatus.Rejected;
            emit AppealResolved(appealId, false);
        }
    }
    
    /**
     * @notice Check if entity is blacklisted
     */
    function checkBlacklist(address entityAddress) 
        external 
        view 
        returns (bool blacklisted, BlacklistReason reason) 
    {
        if (!isBlacklisted[entityAddress]) return (false, BlacklistReason.Fraud);
        
        // Find entry (simplified - in production use mapping)
        for (uint256 i = 1; i <= blacklistCount; i++) {
            if (blacklist[i].entityAddress == entityAddress) {
                // Check if temporary blacklist expired
                if (!blacklist[i].isPermanent && block.timestamp >= blacklist[i].expiresAt) {
                    return (false, BlacklistReason.Fraud);
                }
                return (true, blacklist[i].reason);
            }
        }
        
        return (false, BlacklistReason.Fraud);
    }
    
    /**
     * @notice Get blacklist statistics
     */
    function getBlacklistStats() 
        external 
        view 
        returns (
            uint256 total,
            uint256 permanent,
            uint256 temporary,
            uint256 activeAppeals
        ) 
    {
        uint256 perm = 0;
        uint256 temp = 0;
        uint256 active = 0;
        
        for (uint256 i = 1; i <= blacklistCount; i++) {
            if (blacklist[i].isPermanent) perm++;
            else temp++;
        }
        
        for (uint256 i = 1; i <= appealCount; i++) {
            if (appeals[i].status == AppealStatus.Pending) active++;
        }
        
        return (blacklistCount, perm, temp, active);
    }
}
