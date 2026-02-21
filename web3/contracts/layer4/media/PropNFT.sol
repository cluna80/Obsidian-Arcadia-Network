// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PropNFT is ERC721, Ownable {
    
    uint256 private _propIds;
    
    struct Prop {
        uint256 propId;
        string name;
        string ipfsHash;
        PropCategory category;
        uint256 rentalPricePerDay;
        uint256 purchasePrice;
        address creator;
        uint256 timesRented;
        bool exclusiveLicense;
    }
    
    enum PropCategory {Vehicle, Weapon, Furniture, Building, Effect, Sound, Music, Environment, Character}
    
    struct Rental {
        uint256 propId;
        address renter;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }
    
    mapping(uint256 => Prop) public props;
    mapping(uint256 => Rental[]) public rentalHistory;
    mapping(uint256 => mapping(address => bool)) public currentRentals;
    
    event PropMinted(uint256 indexed propId, string name, address indexed creator);
    event PropRented(uint256 indexed propId, address indexed renter, uint256 duration);
    event PropPurchased(uint256 indexed propId, address indexed buyer, uint256 price);
    
    constructor() ERC721("OAN Prop", "PROP") Ownable(msg.sender) {}
    
    function mintProp(
        string memory name,
        string memory ipfsHash,
        PropCategory category,
        uint256 rentalPrice,
        uint256 purchasePrice,
        bool exclusiveLicense
    ) external returns (uint256) {
        _propIds++;
        uint256 propId = _propIds;
        _safeMint(msg.sender, propId);
        props[propId] = Prop(propId,name,ipfsHash,category,rentalPrice,purchasePrice,msg.sender,0,exclusiveLicense);
        emit PropMinted(propId, name, msg.sender);
        return propId;
    }
    
    function rentProp(uint256 propId, uint256 durationDays) external payable {
        Prop storage prop = props[propId];
        require(msg.value >= prop.rentalPricePerDay * durationDays, "Insufficient payment");
        if (prop.exclusiveLicense) {require(!_isCurrentlyRented(propId), "Already rented (exclusive)");}
        uint256 endTime = block.timestamp + (durationDays * 1 days);
        rentalHistory[propId].push(Rental(propId,msg.sender,block.timestamp,endTime,true));
        currentRentals[propId][msg.sender] = true;
        prop.timesRented++;
        payable(prop.creator).transfer(msg.value);
        emit PropRented(propId, msg.sender, durationDays);
    }
    
    function purchaseProp(uint256 propId) external payable {
        Prop storage prop = props[propId];
        require(msg.value >= prop.purchasePrice, "Insufficient payment");
        address previousOwner = ownerOf(propId);
        _transfer(previousOwner, msg.sender, propId);
        payable(previousOwner).transfer(msg.value);
        emit PropPurchased(propId, msg.sender, msg.value);
    }
    
    function _isCurrentlyRented(uint256 propId) internal view returns (bool) {
        Rental[] storage rentals = rentalHistory[propId];
        for(uint i = 0; i < rentals.length; i++) {
            if (rentals[i].active && block.timestamp < rentals[i].endTime) {return true;}
        }
        return false;
    }
    
    function getProp(uint256 propId) external view returns (Prop memory) {
        return props[propId];
    }
}
