// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title AvatarAthletes - 3D athlete avatars in the OAN metaverse
/// @notice Layer 5, Phase 5.5
contract AvatarAthletes is AccessControl, ReentrancyGuard {
    bytes32 public constant AVATAR_MANAGER = keccak256("AVATAR_MANAGER");

    struct Vector3 { int256 x; int256 y; int256 z; }

    struct WearableSet {
        uint256 glovesId;
        uint256 shortsId;
        uint256 shoesId;
        uint256 accessoryId;
        uint256 beltId;
    }

    struct AvatarAthlete {
        uint256 athleteId;
        string modelURI;           // IPFS hash for 3D model
        string animationSetURI;    // Fighting moves, taunts, celebrations
        WearableSet equipment;
        Vector3 position;
        uint256 currentVenueId;    // 0 = not in a venue
        bool isOnline;
        uint256 lastActivity;
        string[] unlockedEmotes;
        uint256 customizationLevel; // 0-10, higher = more customization options
    }

    struct WearableItem {
        uint256 itemId;
        string name;
        string itemURI;
        uint8 slot;                // 0=gloves, 1=shorts, 2=shoes, 3=accessory, 4=belt
        uint256 price;
        bool isExclusive;
        uint256 athleteId;         // 0 = available to all
    }

    mapping(uint256 => AvatarAthlete) public avatars;
    mapping(uint256 => WearableItem) public wearables;
    mapping(uint256 => uint256[]) public athleteWardobe;  // athleteId => owned wearableIds
    mapping(uint256 => uint256[]) public venueOccupants;  // venueId => athleteIds currently there

    uint256 private _wearableIdCounter;
    address public treasury;
    uint256 public platformFeePercent = 250;

    event AvatarCreated(uint256 indexed athleteId, string modelURI);
    event AvatarMoved(uint256 indexed athleteId, int256 x, int256 y, int256 z, uint256 venueId);
    event WearableEquipped(uint256 indexed athleteId, uint256 wearableId, uint8 slot);
    event WearablePurchased(uint256 indexed athleteId, uint256 wearableId);
    event EmoteUnlocked(uint256 indexed athleteId, string emote);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AVATAR_MANAGER, msg.sender);
    }

    function createAvatar(uint256 athleteId, string memory modelURI, string memory animationSetURI) external {
        require(avatars[athleteId].athleteId == 0, "Avatar already exists");

        avatars[athleteId] = AvatarAthlete({
            athleteId: athleteId,
            modelURI: modelURI,
            animationSetURI: animationSetURI,
            equipment: WearableSet(0, 0, 0, 0, 0),
            position: Vector3(0, 0, 0),
            currentVenueId: 0,
            isOnline: false,
            lastActivity: block.timestamp,
            unlockedEmotes: new string[](0),
            customizationLevel: 0
        });

        emit AvatarCreated(athleteId, modelURI);
    }

    function moveAvatar(uint256 athleteId, int256 x, int256 y, int256 z, uint256 venueId) external onlyRole(AVATAR_MANAGER) {
        AvatarAthlete storage avatar = avatars[athleteId];

        // Remove from old venue
        if (avatar.currentVenueId != 0) {
            _removeFromVenue(avatar.currentVenueId, athleteId);
        }

        avatar.position = Vector3(x, y, z);
        avatar.currentVenueId = venueId;
        avatar.isOnline = true;
        avatar.lastActivity = block.timestamp;

        if (venueId != 0) venueOccupants[venueId].push(athleteId);

        emit AvatarMoved(athleteId, x, y, z, venueId);
    }

    function createWearable(
        string memory name,
        string memory itemURI,
        uint8 slot,
        uint256 price,
        bool isExclusive,
        uint256 exclusiveAthleteId
    ) external onlyRole(AVATAR_MANAGER) returns (uint256) {
        uint256 wearableId = ++_wearableIdCounter;
        wearables[wearableId] = WearableItem(wearableId, name, itemURI, slot, price, isExclusive, exclusiveAthleteId);
        return wearableId;
    }

    function purchaseWearable(uint256 athleteId, uint256 wearableId) external payable nonReentrant {
        WearableItem memory item = wearables[wearableId];
        require(item.price > 0, "Wearable not found");
        require(msg.value >= item.price, "Insufficient payment");
        require(!item.isExclusive || item.athleteId == athleteId, "Exclusive to specific athlete");

        athleteWardobe[athleteId].push(wearableId);

        uint256 fee = (msg.value * platformFeePercent) / 10000;
        payable(treasury).transfer(fee);

        emit WearablePurchased(athleteId, wearableId);
    }

    function equipWearable(uint256 athleteId, uint256 wearableId) external {
        WearableItem memory item = wearables[wearableId];
        require(_ownsWearable(athleteId, wearableId), "Don't own this wearable");

        AvatarAthlete storage avatar = avatars[athleteId];
        if (item.slot == 0) avatar.equipment.glovesId = wearableId;
        else if (item.slot == 1) avatar.equipment.shortsId = wearableId;
        else if (item.slot == 2) avatar.equipment.shoesId = wearableId;
        else if (item.slot == 3) avatar.equipment.accessoryId = wearableId;
        else avatar.equipment.beltId = wearableId;

        emit WearableEquipped(athleteId, wearableId, item.slot);
    }

    function _ownsWearable(uint256 athleteId, uint256 wearableId) internal view returns (bool) {
        uint256[] memory wardrobe = athleteWardobe[athleteId];
        for (uint256 i = 0; i < wardrobe.length; i++) {
            if (wardrobe[i] == wearableId) return true;
        }
        return false;
    }

    function _removeFromVenue(uint256 venueId, uint256 athleteId) internal {
        uint256[] storage occupants = venueOccupants[venueId];
        for (uint256 i = 0; i < occupants.length; i++) {
            if (occupants[i] == athleteId) {
                occupants[i] = occupants[occupants.length - 1];
                occupants.pop();
                break;
            }
        }
    }

    function getVenueOccupants(uint256 venueId) external view returns (uint256[] memory) {
        return venueOccupants[venueId];
    }

    function getAthletesWardrobe(uint256 athleteId) external view returns (uint256[] memory) {
        return athleteWardobe[athleteId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


// ============================================================
