// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MemoryVault is ERC721, Ownable {
    uint256 private _vaultIds;
    enum MemoryRarity {Common, Rare, Epic, Legendary}
    struct Memory {uint256 id;uint256 vaultId;string description;MemoryRarity rarity;uint256 timestamp;bytes32 dataHash;bool isTransferable;}
    struct Vault {uint256 id;address owner;uint256 entityId;uint256 memoryCount;uint256 createdAt;}
    mapping(uint256 => Vault) public vaults;
    mapping(uint256 => Memory[]) public vaultMemories;
    mapping(uint256 => uint256) public entityToVault;
    event VaultCreated(uint256 indexed vaultId, address indexed owner, uint256 entityId);
    event MemoryStored(uint256 indexed vaultId, uint256 memoryId, MemoryRarity rarity);
    constructor() ERC721("OAN Memory Vault", "OANM") Ownable(msg.sender) {}
    function createVault(uint256 entityId) external returns (uint256) {_vaultIds++;uint256 id = _vaultIds;_safeMint(msg.sender, id);vaults[id] = Vault(id,msg.sender,entityId,0,block.timestamp);entityToVault[entityId] = id;emit VaultCreated(id, msg.sender, entityId);return id;}
    function storeMemory(uint256 vaultId,string memory description,MemoryRarity rarity,bytes32 dataHash) external {require(_ownerOf(vaultId) == msg.sender);Memory memory newMemory = Memory(vaultMemories[vaultId].length,vaultId,description,rarity,block.timestamp,dataHash,true);vaultMemories[vaultId].push(newMemory);vaults[vaultId].memoryCount++;emit MemoryStored(vaultId, newMemory.id, rarity);}
    function getMemories(uint256 vaultId) external view returns (Memory[] memory) {return vaultMemories[vaultId];}
}
