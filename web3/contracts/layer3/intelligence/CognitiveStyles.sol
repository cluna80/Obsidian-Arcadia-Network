// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CognitiveStyles is ERC721, Ownable {
    uint256 private _styleIds;
    struct CognitiveStyle {uint256 id;string name;address creator;uint256 riskTolerance;uint256 adaptability;uint256 creativity;uint256 analyticalScore;uint256 emotionalIntelligence;bool isAttached;uint256 attachedTo;uint256 createdAt;}
    mapping(uint256 => CognitiveStyle) public styles;
    mapping(uint256 => uint256) public entityStyle;
    event StyleMinted(uint256 indexed styleId, string name, address indexed creator);
    event StyleAttached(uint256 indexed styleId, uint256 indexed entityId);
    constructor() ERC721("OAN Cognitive Style", "OANC") Ownable(msg.sender) {}
    function mintStyle(string memory name,uint256 risk,uint256 adapt,uint256 creative,uint256 analytical,uint256 emotional) external returns (uint256) {_styleIds++;uint256 id = _styleIds;_safeMint(msg.sender, id);styles[id] = CognitiveStyle(id,name,msg.sender,risk,adapt,creative,analytical,emotional,false,0,block.timestamp);emit StyleMinted(id, name, msg.sender);return id;}
    function attachToEntity(uint256 styleId, uint256 entityId) external {require(_ownerOf(styleId) == msg.sender);styles[styleId].isAttached = true;styles[styleId].attachedTo = entityId;entityStyle[entityId] = styleId;emit StyleAttached(styleId, entityId);}
    function getStyle(uint256 styleId) external view returns (CognitiveStyle memory) {return styles[styleId];}
}
