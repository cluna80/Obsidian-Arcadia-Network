// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EntityRegistry
 * @dev Central registry for all OAN entities
 */
contract EntityRegistry is Ownable {
    
    struct RegistryEntry {
        address nftContract;
        uint256 tokenId;
        address owner;
        string entityType;
        bool active;
        uint256 registeredAt;
        bytes32 dslHash;
    }
    
    // Global entity ID => Registry entry
    mapping(uint256 => RegistryEntry) public registry;
    
    // NFT contract + token ID => Global entity ID
    mapping(address => mapping(uint256 => uint256)) public nftToEntityId;
    
    // Owner => list of entity IDs
    mapping(address => uint256[]) public ownerEntities;
    
    uint256 private _nextEntityId = 1;
    uint256 public totalEntities;
    
    event EntityRegistered(uint256 indexed entityId, address indexed nftContract, uint256 indexed tokenId, address owner);
    event EntityDeactivated(uint256 indexed entityId);
    event EntityTransferred(uint256 indexed entityId, address indexed from, address indexed to);
    
    constructor() Ownable(msg.sender) {}
    
    function registerEntity(
        address nftContract,
        uint256 tokenId,
        address owner,
        string memory entityType,
        bytes32 dslHash
    ) external returns (uint256) {
        require(nftToEntityId[nftContract][tokenId] == 0, "Entity already registered");
        
        uint256 entityId = _nextEntityId++;
        
        registry[entityId] = RegistryEntry({
            nftContract: nftContract,
            tokenId: tokenId,
            owner: owner,
            entityType: entityType,
            active: true,
            registeredAt: block.timestamp,
            dslHash: dslHash
        });
        
        nftToEntityId[nftContract][tokenId] = entityId;
        ownerEntities[owner].push(entityId);
        totalEntities++;
        
        emit EntityRegistered(entityId, nftContract, tokenId, owner);
        return entityId;
    }
    
    function deactivateEntity(uint256 entityId) external {
        require(registry[entityId].owner == msg.sender || msg.sender == owner(), "Not authorized");
        require(registry[entityId].active, "Already inactive");
        
        registry[entityId].active = false;
        emit EntityDeactivated(entityId);
    }
    
    function transferEntity(uint256 entityId, address newOwner) external {
        require(registry[entityId].owner == msg.sender, "Not owner");
        require(newOwner != address(0), "Invalid address");
        
        address oldOwner = registry[entityId].owner;
        registry[entityId].owner = newOwner;
        
        // Update owner list
        ownerEntities[newOwner].push(entityId);
        
        emit EntityTransferred(entityId, oldOwner, newOwner);
    }
    
    function getEntity(uint256 entityId) external view returns (RegistryEntry memory) {
        return registry[entityId];
    }
    
    function getOwnerEntities(address owner) external view returns (uint256[] memory) {
        return ownerEntities[owner];
    }
    
    function getEntityByNFT(address nftContract, uint256 tokenId) external view returns (uint256) {
        return nftToEntityId[nftContract][tokenId];
    }
    
    function isEntityActive(uint256 entityId) external view returns (bool) {
        return registry[entityId].active;
    }
}
