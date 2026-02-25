// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TransparencyRegistry
 * @notice Public audit trail for all protocol actions
 * 
 * FEATURES:
 * - Public read access
 * - Searchable records
 * - Historical snapshots
 * - Compliance reporting
 */
contract TransparencyRegistry {
    
    struct AuditRecord {
        uint256 recordId;
        uint256 entityId;
        RecordType recordType;
        bytes32 dataHash;
        uint256 timestamp;
        address reporter;
        string description;
        bool isPublic;
    }
    
    enum RecordType {
        Action,
        Transaction,
        StateChange,
        Governance,
        Security,
        Compliance
    }
    
    mapping(uint256 => AuditRecord) public records;
    mapping(RecordType => uint256[]) public recordsByType;
    mapping(uint256 => uint256[]) public entityRecords;
    
    uint256 public recordCount;
    
    event RecordCreated(uint256 indexed recordId, RecordType recordType, uint256 indexed entityId);
    event RecordMadePublic(uint256 indexed recordId);
    
    /**
     * @notice Create audit record
     */
    function createRecord(
        uint256 entityId,
        RecordType recordType,
        bytes32 dataHash,
        string memory description,
        bool isPublic
    ) external returns (uint256) {
        recordCount++;
        uint256 recordId = recordCount;
        
        records[recordId] = AuditRecord({
            recordId: recordId,
            entityId: entityId,
            recordType: recordType,
            dataHash: dataHash,
            timestamp: block.timestamp,
            reporter: msg.sender,
            description: description,
            isPublic: isPublic
        });
        
        recordsByType[recordType].push(recordId);
        entityRecords[entityId].push(recordId);
        
        emit RecordCreated(recordId, recordType, entityId);
        
        return recordId;
    }
    
    /**
     * @notice Make record public
     */
    function makePublic(uint256 recordId) external {
        AuditRecord storage record = records[recordId];
        require(record.reporter == msg.sender, "Not reporter");
        
        record.isPublic = true;
        emit RecordMadePublic(recordId);
    }
    
    /**
     * @notice Get records by type
     */
    function getRecordsByType(RecordType recordType) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return recordsByType[recordType];
    }
    
    /**
     * @notice Get entity's audit trail
     */
    function getEntityRecords(uint256 entityId) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return entityRecords[entityId];
    }
    
    /**
     * @notice Generate compliance report
     */
    function generateComplianceReport(
        uint256 entityId,
        uint256 fromTimestamp,
        uint256 toTimestamp
    ) external view returns (
        uint256 totalRecords,
        uint256 securityRecords,
        uint256 complianceRecords
    ) {
        uint256[] storage entityRecs = entityRecords[entityId];
        
        uint256 security = 0;
        uint256 compliance = 0;
        uint256 total = 0;
        
        for (uint256 i = 0; i < entityRecs.length; i++) {
            AuditRecord storage record = records[entityRecs[i]];
            
            if (record.timestamp >= fromTimestamp && record.timestamp <= toTimestamp) {
                total++;
                if (record.recordType == RecordType.Security) security++;
                if (record.recordType == RecordType.Compliance) compliance++;
            }
        }
        
        return (total, security, compliance);
    }
}
