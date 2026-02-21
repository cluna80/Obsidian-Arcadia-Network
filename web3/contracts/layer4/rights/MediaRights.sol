// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MediaRights
 * @notice Ownership and licensing control for all media assets
 * 
 * KEY FEATURES:
 * - Fractional ownership
 * - Territorial rights (different owners per region)
 * - Time-limited licenses
 * - Exclusive vs non-exclusive rights
 * - Sub-licensing capabilities
 */
contract MediaRights is Ownable {
    
    struct RightsBundle {
        uint256 bundleId;
        uint256 mediaAssetId;
        RightType rightType;
        address owner;
        uint256 percentage;              // For fractional ownership (basis points)
        string[] territories;            // Geographic regions
        uint256 startDate;
        uint256 endDate;                 // 0 = perpetual
        bool exclusive;
        bool transferable;
        bool sublicensable;
    }
    
    struct License {
        uint256 licenseId;
        uint256 bundleId;
        address licensee;
        uint256 fee;
        uint256 startDate;
        uint256 endDate;
        string[] allowedUses;            // streaming, theatrical, home video, etc
        bool active;
    }
    
    enum RightType {
        Distribution, Reproduction, PublicPerformance,
        Streaming, Theatrical, HomeVideo, Merchandising,
        Adaptation, Sequel, Remake
    }
    
    mapping(uint256 => RightsBundle) public rightsBundles;
    mapping(uint256 => License) public licenses;
    mapping(uint256 => uint256[]) public assetRights;        // assetId => bundleIds
    mapping(uint256 => uint256[]) public assetLicenses;      // assetId => licenseIds
    mapping(address => uint256[]) public ownerRights;        // owner => bundleIds
    
    uint256 public bundleCount;
    uint256 public licenseCount;
    
    event RightsCreated(uint256 indexed bundleId, uint256 indexed assetId, RightType rightType);
    event LicenseGranted(uint256 indexed licenseId, uint256 indexed bundleId, address indexed licensee);
    event RightsTransferred(uint256 indexed bundleId, address indexed from, address indexed to);
    event LicenseRevoked(uint256 indexed licenseId);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @notice Create rights bundle for media asset
     * @dev Can have fractional ownership (multiple bundles per asset)
     */
    function createRightsBundle(
        uint256 mediaAssetId,
        RightType rightType,
        uint256 percentage,
        string[] memory territories,
        uint256 duration,
        bool exclusive,
        bool transferable,
        bool sublicensable
    ) external returns (uint256) {
        bundleCount++;
        uint256 bundleId = bundleCount;
        
        uint256 endDate = duration == 0 ? 0 : block.timestamp + duration;
        
        rightsBundles[bundleId] = RightsBundle({
            bundleId: bundleId,
            mediaAssetId: mediaAssetId,
            rightType: rightType,
            owner: msg.sender,
            percentage: percentage,
            territories: territories,
            startDate: block.timestamp,
            endDate: endDate,
            exclusive: exclusive,
            transferable: transferable,
            sublicensable: sublicensable
        });
        
        assetRights[mediaAssetId].push(bundleId);
        ownerRights[msg.sender].push(bundleId);
        
        emit RightsCreated(bundleId, mediaAssetId, rightType);
        return bundleId;
    }
    
    /**
     * @notice Grant license to use rights
     * @dev Requires rights owner approval
     */
    function grantLicense(
        uint256 bundleId,
        address licensee,
        uint256 fee,
        uint256 duration,
        string[] memory allowedUses
    ) external payable returns (uint256) {
        RightsBundle storage bundle = rightsBundles[bundleId];
        require(bundle.owner == msg.sender, "Not rights owner");
        require(bundle.sublicensable, "Not sublicensable");
        require(msg.value >= fee, "Insufficient payment");
        
        licenseCount++;
        uint256 licenseId = licenseCount;
        
        licenses[licenseId] = License({
            licenseId: licenseId,
            bundleId: bundleId,
            licensee: licensee,
            fee: fee,
            startDate: block.timestamp,
            endDate: block.timestamp + duration,
            allowedUses: allowedUses,
            active: true
        });
        
        assetLicenses[bundle.mediaAssetId].push(licenseId);
        
        // Pay rights owner
        payable(bundle.owner).transfer(msg.value);
        
        emit LicenseGranted(licenseId, bundleId, licensee);
        return licenseId;
    }
    
    /**
     * @notice Transfer rights ownership
     */
    function transferRights(uint256 bundleId, address newOwner) external {
        RightsBundle storage bundle = rightsBundles[bundleId];
        require(bundle.owner == msg.sender, "Not owner");
        require(bundle.transferable, "Not transferable");
        
        address oldOwner = bundle.owner;
        bundle.owner = newOwner;
        
        ownerRights[newOwner].push(bundleId);
        
        emit RightsTransferred(bundleId, oldOwner, newOwner);
    }
    
    /**
     * @notice Revoke license
     */
    function revokeLicense(uint256 licenseId) external {
        License storage license = licenses[licenseId];
        RightsBundle storage bundle = rightsBundles[license.bundleId];
        
        require(bundle.owner == msg.sender, "Not rights owner");
        require(license.active, "Already revoked");
        
        license.active = false;
        
        emit LicenseRevoked(licenseId);
    }
    
    /**
     * @notice Check if license is valid
     */
    function isLicenseValid(uint256 licenseId) external view returns (bool) {
        License storage license = licenses[licenseId];
        return license.active && block.timestamp <= license.endDate;
    }
    
    /**
     * @notice Get rights bundle
     */
    function getRightsBundle(uint256 bundleId) external view returns (RightsBundle memory) {
        return rightsBundles[bundleId];
    }
    
    /**
     * @notice Get license
     */
    function getLicense(uint256 licenseId) external view returns (License memory) {
        return licenses[licenseId];
    }
    
    /**
     * @notice Get asset rights
     */
    function getAssetRights(uint256 assetId) external view returns (uint256[] memory) {
        return assetRights[assetId];
    }
}
