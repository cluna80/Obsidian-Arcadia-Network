// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title ModuleRegistry - Catalog of all OAN AI modules (Layer 6, Phase 6.2)
contract ModuleRegistry is AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    enum ModuleType   { BehaviorTree, NeuralPattern, DecisionEngine, SocialProtocol, CombatStyle, EconomicAgent }
    enum ModuleStatus { Draft, Active, Deprecated, Banned }

    struct Module {
        uint256      moduleId;
        string       name;
        string       description;
        address      author;
        ModuleType   moduleType;
        ModuleStatus status;
        string       version;
        string       interfaceHash;
        string       implementationURI;
        uint256      registeredAt;
        uint256      updatedAt;
        bool         isCompatible;
        uint256      usageCount;
    }

    uint256 private _moduleCounter;
    mapping(uint256 => Module)      public modules;
    mapping(uint256 => string[])    public moduleTags;
    mapping(uint256 => string[])    public moduleDependencies;
    mapping(address => uint256[])   public authorModules;
    mapping(string  => uint256)     public moduleByName;
    mapping(ModuleType => uint256[]) public modulesByType;
    mapping(string  => uint256[])   public modulesByTag;

    uint256 public totalModules;
    uint256 public activeModules;

    event ModuleRegistered(uint256 indexed moduleId, address indexed author, string name, ModuleType moduleType);
    event ModuleUpdated(uint256 indexed moduleId, string newVersion);
    event ModuleStatusChanged(uint256 indexed moduleId, ModuleStatus newStatus);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE,     msg.sender);
    }

    function registerModule(
        string memory name,
        string memory description,
        ModuleType moduleType,
        string memory version,
        string[] memory tags,
        string memory interfaceHash,
        string memory implementationURI,
        string[] memory dependencies
    ) external returns (uint256) {
        require(bytes(name).length > 0,   "Name required");
        require(moduleByName[name] == 0,  "Name taken");

        uint256 moduleId = ++_moduleCounter;
        modules[moduleId] = Module({
            moduleId:          moduleId,
            name:              name,
            description:       description,
            author:            msg.sender,
            moduleType:        moduleType,
            status:            ModuleStatus.Active,
            version:           version,
            interfaceHash:     interfaceHash,
            implementationURI: implementationURI,
            registeredAt:      block.timestamp,
            updatedAt:         block.timestamp,
            isCompatible:      true,
            usageCount:        0
        });

        moduleTags[moduleId]         = tags;
        moduleDependencies[moduleId] = dependencies;
        moduleByName[name]           = moduleId;
        authorModules[msg.sender].push(moduleId);
        modulesByType[moduleType].push(moduleId);
        for (uint256 i = 0; i < tags.length; i++) modulesByTag[tags[i]].push(moduleId);

        totalModules++;
        activeModules++;
        emit ModuleRegistered(moduleId, msg.sender, name, moduleType);
        return moduleId;
    }

    function updateModule(uint256 moduleId, string memory newVersion, string memory newURI) external {
        require(modules[moduleId].author == msg.sender, "Not author");
        modules[moduleId].version          = newVersion;
        modules[moduleId].implementationURI = newURI;
        modules[moduleId].updatedAt        = block.timestamp;
        emit ModuleUpdated(moduleId, newVersion);
    }

    function setStatus(uint256 moduleId, ModuleStatus status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ModuleStatus old = modules[moduleId].status;
        if (old == ModuleStatus.Active   && status != ModuleStatus.Active) activeModules--;
        if (old != ModuleStatus.Active   && status == ModuleStatus.Active) activeModules++;
        modules[moduleId].status = status;
        emit ModuleStatusChanged(moduleId, status);
    }

    function recordUsage(uint256 moduleId) external onlyRole(REGISTRAR_ROLE) { modules[moduleId].usageCount++; }

    function getModuleTags(uint256 moduleId)         external view returns (string[] memory) { return moduleTags[moduleId]; }
    function getModuleDependencies(uint256 moduleId) external view returns (string[] memory) { return moduleDependencies[moduleId]; }
    function getAuthorModules(address author)        external view returns (uint256[] memory) { return authorModules[author]; }
    function getModulesByType(ModuleType t)          external view returns (uint256[] memory) { return modulesByType[t]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
