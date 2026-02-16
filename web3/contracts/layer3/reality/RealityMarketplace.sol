// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RealityMarketplace is Ownable, ReentrancyGuard {
    
    struct Listing {uint256 moduleId;address seller;uint256 price;bool isActive;string moduleType;uint256 listedAt;}
    struct License {uint256 moduleId;address licensee;uint256 expiresAt;uint256 paidAmount;}
    
    mapping(uint256 => Listing) public listings;
    mapping(uint256 => License[]) public moduleLicenses;
    uint256 public listingCount;
    uint256 public platformFee = 250;
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    event ModuleListed(uint256 indexed listingId, uint256 moduleId, uint256 price);
    event ModuleSold(uint256 indexed listingId, address buyer, uint256 price);
    event ModuleLicensed(uint256 indexed moduleId, address licensee, uint256 duration);
    
    constructor() Ownable(msg.sender) {}
    
    function listModule(uint256 moduleId,uint256 price,string memory moduleType) external {listingCount++;listings[listingCount] = Listing(moduleId,msg.sender,price,true,moduleType,block.timestamp);emit ModuleListed(listingCount, moduleId, price);}
    
    function buyModule(uint256 listingId) external payable nonReentrant {Listing storage listing = listings[listingId];require(listing.isActive && msg.value >= listing.price);uint256 fee = (listing.price * platformFee) / FEE_DENOMINATOR;payable(listing.seller).transfer(listing.price - fee);listing.isActive = false;emit ModuleSold(listingId, msg.sender, listing.price);}
    
    function licenseModule(uint256 moduleId, uint256 duration) external payable {require(msg.value > 0);License memory newLicense = License(moduleId,msg.sender,block.timestamp + duration,msg.value);moduleLicenses[moduleId].push(newLicense);emit ModuleLicensed(moduleId, msg.sender, duration);}
    
    function hasLicense(uint256 moduleId, address user) external view returns (bool) {License[] memory licenses = moduleLicenses[moduleId];for(uint256 i = 0; i < licenses.length; i++){if(licenses[i].licensee == user && licenses[i].expiresAt > block.timestamp) return true;}return false;}
}
