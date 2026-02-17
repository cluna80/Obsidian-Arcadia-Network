// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract LegacySystem is Ownable {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error LegacyAlreadyExists();
    error InvalidLineage();
    error LegacyDoesNotExist();
    error LegacyInactive();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Legacy {
        uint256 parentId;
        uint256 heirId;
        uint256 inheritedReputation;
        uint256 inheritedWealth;
        uint256[] transferredMemories;
        uint256 transferTime;
        bool isActive;
    }

    struct Dynasty {
        uint256 founderId;
        uint256[] generations;
        uint256 totalHeirs;
        uint256 establishedAt;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => Legacy) public legacies;
    mapping(uint256 => uint256) public entityToLegacy;

    mapping(uint256 => Dynasty) public dynasties;
    mapping(uint256 => uint256) public entityToDynasty;

    uint256 public legacyCount;
    uint256 public dynastyCount;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event HeirCreated(uint256 indexed parentId, uint256 indexed heirId);
    event LegacyTransferred(uint256 indexed legacyId, uint256 reputation, uint256 wealth);
    event DynastyEstablished(uint256 indexed dynastyId, uint256 indexed founderId);
    event LegacyDeactivated(uint256 indexed legacyId);

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createHeir(
        uint256 parentId,
        uint256 heirId,
        uint256 inheritedReputation,
        uint256 inheritedWealth
    ) external returns (uint256) {

        // ✅ Prevent duplicate inheritance
        if (entityToLegacy[heirId] != 0)
            revert LegacyAlreadyExists();

        // ✅ Prevent invalid lineage
        if (parentId == heirId)
            revert InvalidLineage();

        legacyCount++;

        legacies[legacyCount] = Legacy({
    parentId: parentId,
    heirId: heirId,
    inheritedReputation: inheritedReputation,
    inheritedWealth: inheritedWealth,
    transferredMemories: new uint256[](0),  
    transferTime: block.timestamp,
    isActive: true
});

        entityToLegacy[heirId] = legacyCount;

        /*//////////////////////////////////////////////////////////////
                            DYNASTY LOGIC
        //////////////////////////////////////////////////////////////*/

        if (entityToDynasty[parentId] == 0) {

            dynastyCount++;

            Dynasty storage newDynasty = dynasties[dynastyCount];
            newDynasty.founderId = parentId;
            newDynasty.establishedAt = block.timestamp;

            newDynasty.generations.push(parentId);

            entityToDynasty[parentId] = dynastyCount;

            emit DynastyEstablished(dynastyCount, parentId);
        }

        uint256 dynastyId = entityToDynasty[parentId];

        dynasties[dynastyId].generations.push(heirId);
        dynasties[dynastyId].totalHeirs++;

        entityToDynasty[heirId] = dynastyId;

        emit HeirCreated(parentId, heirId);
        emit LegacyTransferred(legacyCount, inheritedReputation, inheritedWealth);

        return legacyCount;
    }

    /*//////////////////////////////////////////////////////////////
                            MEMORY TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function transferMemory(uint256 legacyId, uint256 memoryId) external {

        if (legacyId == 0 || legacyId > legacyCount)
            revert LegacyDoesNotExist();

        Legacy storage legacy = legacies[legacyId];

        if (!legacy.isActive)
            revert LegacyInactive();

        legacy.transferredMemories.push(memoryId);
    }

    /*//////////////////////////////////////////////////////////////
                            LEGACY LIFECYCLE
    //////////////////////////////////////////////////////////////*/

    function deactivateLegacy(uint256 legacyId) external onlyOwner {

        if (legacyId == 0 || legacyId > legacyCount)
            revert LegacyDoesNotExist();

        Legacy storage legacy = legacies[legacyId];

        if (!legacy.isActive)
            revert LegacyInactive();

        legacy.isActive = false;

        emit LegacyDeactivated(legacyId);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function getDynastyTree(uint256 founderId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 dynastyId = entityToDynasty[founderId];
        return dynasties[dynastyId].generations;
    }

    function getLegacy(uint256 legacyId)
        external
        view
        returns (Legacy memory)
    {
        if (legacyId == 0 || legacyId > legacyCount)
            revert LegacyDoesNotExist();

        return legacies[legacyId];
    }
}
