// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OANEntity is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    uint256 private _tokenIds;
    struct EntityData {string name;string entityType;uint256 energy;int256 reputation;uint256 parentTokenId;uint256 generation;uint256 spawnedAt;bytes32 dslHash;bool active;}
    mapping(uint256 => EntityData) public entities;
    mapping(uint256 => uint256[]) public children;
    uint256 public constant SPAWN_COST = 20;
    event EntityMinted(uint256 indexed tokenId, string name, address owner);
    event EntitySpawned(uint256 indexed parentId, uint256 indexed childId);
    constructor() ERC721("OAN Entity", "OANE") Ownable(msg.sender) {}
    function mintEntity(address to, string memory name, string memory entityType, bytes32 dslHash, string memory metadataURI) public returns (uint256) {_tokenIds++;uint256 newTokenId = _tokenIds;_safeMint(to, newTokenId);_setTokenURI(newTokenId, metadataURI);entities[newTokenId] = EntityData(name, entityType, 100, 0, 0, 1, block.number, dslHash, true);emit EntityMinted(newTokenId, name, to);return newTokenId;}
    function spawnChild(uint256 parentTokenId, string memory childName, string memory childType, bytes32 childDslHash, string memory metadataURI) public returns (uint256) {require(_ownerOf(parentTokenId) != address(0), "Parent does not exist");require(ownerOf(parentTokenId) == msg.sender, "Not parent owner");require(entities[parentTokenId].energy >= SPAWN_COST, "Insufficient energy");_tokenIds++;uint256 childTokenId = _tokenIds;_safeMint(msg.sender, childTokenId);_setTokenURI(childTokenId, metadataURI);entities[childTokenId] = EntityData(childName, childType, 50, 0, parentTokenId, entities[parentTokenId].generation + 1, block.number, childDslHash, true);entities[parentTokenId].energy -= SPAWN_COST;children[parentTokenId].push(childTokenId);emit EntitySpawned(parentTokenId, childTokenId);return childTokenId;}
    function getEntity(uint256 tokenId) public view returns (EntityData memory) {require(_ownerOf(tokenId) != address(0), "Entity does not exist");return entities[tokenId];}
    function getChildren(uint256 parentTokenId) public view returns (uint256[] memory) {return children[parentTokenId];}
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721, ERC721Enumerable) returns (address) {return super._update(to, tokenId, auth);}
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {super._increaseBalance(account, value);}
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {return super.tokenURI(tokenId);}
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721URIStorage) returns (bool) {return super.supportsInterface(interfaceId);}
}
