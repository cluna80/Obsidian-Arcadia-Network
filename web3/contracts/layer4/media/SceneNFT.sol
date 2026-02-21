// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SceneNFT is ERC721, Ownable {
    
    uint256 private _sceneIds;
    
    struct Scene {
        uint256 sceneId;
        string description;
        string ipfsHash;
        uint256 duration;
        uint256[] actorIds;
        uint256[] propIds;
        SceneType sceneType;
        uint256 productionCost;
        uint256 timesUsed;
        address creator;
    }
    
    enum SceneType {Opening, Action, Dialogue, Transition, Climax, Resolution, Credits}
    
    mapping(uint256 => Scene) public scenes;
    mapping(uint256 => uint256) public sceneRoyalties;
    
    event SceneMinted(uint256 indexed sceneId, address indexed creator);
    event SceneLicensed(uint256 indexed sceneId, address indexed licensee, uint256 fee);
    
    constructor() ERC721("OAN Scene", "SCENE") Ownable(msg.sender) {}
    
    function mintScene(
        string memory description,
        string memory ipfsHash,
        uint256 duration,
        SceneType sceneType,
        uint256 royaltyPerUse
    ) external returns (uint256) {
        _sceneIds++;
        uint256 sceneId = _sceneIds;
        _safeMint(msg.sender, sceneId);
        scenes[sceneId] = Scene(sceneId,description,ipfsHash,duration,new uint256[](0),new uint256[](0),sceneType,0,0,msg.sender);
        sceneRoyalties[sceneId] = royaltyPerUse;
        emit SceneMinted(sceneId, msg.sender);
        return sceneId;
    }
    
    function licenseScene(uint256 sceneId) external payable {
        Scene storage scene = scenes[sceneId];
        uint256 royalty = sceneRoyalties[sceneId];
        require(msg.value >= royalty, "Insufficient payment");
        scene.timesUsed++;
        payable(scene.creator).transfer(royalty);
        if (msg.value > royalty) {payable(msg.sender).transfer(msg.value - royalty);}
        emit SceneLicensed(sceneId, msg.sender, royalty);
    }
    
    function addActor(uint256 sceneId, uint256 actorId) external {
        require(ownerOf(sceneId) == msg.sender, "Not owner");
        scenes[sceneId].actorIds.push(actorId);
    }
    
    function addProp(uint256 sceneId, uint256 propId) external {
        require(ownerOf(sceneId) == msg.sender, "Not owner");
        scenes[sceneId].propIds.push(propId);
    }
    
    function getScene(uint256 sceneId) external view returns (Scene memory) {
        return scenes[sceneId];
    }
}
