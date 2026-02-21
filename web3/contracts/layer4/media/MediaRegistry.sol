// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MediaRegistry {
    
    struct MediaAsset {
        uint256 assetId;
        AssetType assetType;
        address contractAddress;
        uint256 tokenId;
        string metadata;
        uint256 createdAt;
        address creator;
        uint256 viewCount;
        uint256 revenue;
    }
    
    enum AssetType {Movie, Scene, Prop, Actor, Director}
    
    mapping(uint256 => MediaAsset) public assets;
    mapping(AssetType => uint256[]) public assetsByType;
    mapping(address => uint256[]) public assetsByCreator;
    
    uint256 public totalAssets;
    
    event AssetRegistered(uint256 indexed assetId, AssetType assetType, address indexed creator);
    
    function registerAsset(
        AssetType assetType,
        address contractAddress,
        uint256 tokenId,
        string memory metadata
    ) external returns (uint256) {
        totalAssets++;
        uint256 assetId = totalAssets;
        assets[assetId] = MediaAsset(assetId,assetType,contractAddress,tokenId,metadata,block.timestamp,msg.sender,0,0);
        assetsByType[assetType].push(assetId);
        assetsByCreator[msg.sender].push(assetId);
        emit AssetRegistered(assetId, assetType, msg.sender);
        return assetId;
    }
    
    function recordView(uint256 assetId) external {
        assets[assetId].viewCount++;
    }
    
    function recordRevenue(uint256 assetId, uint256 amount) external {
        assets[assetId].revenue += amount;
    }
    
    function getAssetsByType(AssetType assetType) external view returns (uint256[] memory) {
        return assetsByType[assetType];
    }
    
    function getAssetsByCreator(address creator) external view returns (uint256[] memory) {
        return assetsByCreator[creator];
    }
    
    function getAsset(uint256 assetId) external view returns (MediaAsset memory) {
        return assets[assetId];
    }
}
