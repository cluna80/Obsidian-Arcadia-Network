// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ToolLicensing - Fine-grained license terms for OAN AI tools (Layer 6, Phase 6.2)
contract ToolLicensing is AccessControl, ReentrancyGuard {
    bytes32 public constant LICENSOR_ROLE = keccak256("LICENSOR_ROLE");

    enum LicenseModel { Perpetual, Monthly, Annual, PerUse, Freemium, Enterprise }
    enum UsageScope   { Personal, Commercial, Research, AllUses }

    struct LicenseTemplate {
        uint256      templateId;
        uint256      toolId;
        address      licensor;
        LicenseModel model;
        UsageScope   scope;
        uint256      price;
        uint256      maxUsers;
        uint256      maxUsagePerDay;
        bool         allowSublicensing;
        bool         allowModification;
        string       termsURI;
        uint256      royaltyBps;
        bool         isActive;
        uint256      totalLicensed;
    }

    struct License {
        uint256    licenseId;
        uint256    templateId;
        uint256    toolId;
        address    licensee;
        UsageScope scope;
        uint256    grantedAt;
        uint256    expiresAt;
        uint256    usageCount;
        uint256    maxUsage;
        bool       isActive;
        bool       isSublicense;
        address    sublicensedFrom;
    }

    uint256 private _templateCounter;
    uint256 private _licenseCounter;

    mapping(uint256 => LicenseTemplate) public templates;
    mapping(uint256 => License)         public licenses;
    mapping(address => uint256[])       public licensorTemplates;
    mapping(address => uint256[])       public licenseeLicenses;
    mapping(uint256 => uint256[])       public toolLicenses;
    mapping(address => mapping(uint256 => uint256)) public activeLicense; // licensee => toolId => licenseId

    address public treasury;
    uint256 public platformFeeBps = 300;
    uint256 public totalLicenses;
    uint256 public totalRevenue;

    event TemplateCreated(uint256 indexed templateId, uint256 indexed toolId, LicenseModel model, uint256 price);
    event LicenseGranted(uint256 indexed licenseId, uint256 indexed templateId, address indexed licensee);
    event LicenseRevoked(uint256 indexed licenseId, string reason);
    event UsageRecorded(uint256 indexed licenseId, uint256 totalUsage);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LICENSOR_ROLE,      msg.sender);
    }

    function createTemplate(
        uint256 toolId,
        LicenseModel model,
        UsageScope scope,
        uint256 price,
        uint256 maxUsers,
        uint256 maxUsagePerDay,
        bool allowSublicensing,
        bool allowModification,
        string memory termsURI,
        uint256 royaltyBps
    ) external returns (uint256) {
        require(price > 0 && royaltyBps <= 3000, "Invalid params");

        uint256 templateId = ++_templateCounter;
        templates[templateId] = LicenseTemplate({
            templateId:       templateId,
            toolId:           toolId,
            licensor:         msg.sender,
            model:            model,
            scope:            scope,
            price:            price,
            maxUsers:         maxUsers,
            maxUsagePerDay:   maxUsagePerDay,
            allowSublicensing: allowSublicensing,
            allowModification: allowModification,
            termsURI:         termsURI,
            royaltyBps:       royaltyBps,
            isActive:         true,
            totalLicensed:    0
        });

        licensorTemplates[msg.sender].push(templateId);
        emit TemplateCreated(templateId, toolId, model, price);
        return templateId;
    }

    function acquireLicense(uint256 templateId) external payable nonReentrant returns (uint256) {
        LicenseTemplate storage t = templates[templateId];
        require(t.isActive,                                     "Template not active");
        require(msg.value >= t.price,                           "Insufficient payment");
        require(t.maxUsers == 0 || t.totalLicensed < t.maxUsers, "License limit reached");

        uint256 duration = 0;
        if      (t.model == LicenseModel.Monthly)  duration = 30 days;
        else if (t.model == LicenseModel.Annual)   duration = 365 days;
        else if (t.model == LicenseModel.PerUse)   duration = 1 days;

        uint256 licenseId = ++_licenseCounter;
        licenses[licenseId] = License({
            licenseId:      licenseId,
            templateId:     templateId,
            toolId:         t.toolId,
            licensee:       msg.sender,
            scope:          t.scope,
            grantedAt:      block.timestamp,
            expiresAt:      duration == 0 ? 0 : block.timestamp + duration,
            usageCount:     0,
            maxUsage:       t.model == LicenseModel.PerUse ? 1 : 0,
            isActive:       true,
            isSublicense:   false,
            sublicensedFrom: address(0)
        });

        licenseeLicenses[msg.sender].push(licenseId);
        toolLicenses[t.toolId].push(licenseId);
        activeLicense[msg.sender][t.toolId] = licenseId;
        t.totalLicensed++;

        uint256 fee = (msg.value * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(t.licensor).transfer(msg.value - fee);
        totalLicenses++;
        totalRevenue += msg.value;

        emit LicenseGranted(licenseId, templateId, msg.sender);
        return licenseId;
    }

    function recordUsage(uint256 licenseId) external onlyRole(LICENSOR_ROLE) {
        License storage l = licenses[licenseId];
        require(l.isActive, "Inactive");
        require(l.expiresAt == 0 || block.timestamp <= l.expiresAt, "Expired");
        l.usageCount++;
        if (l.maxUsage > 0 && l.usageCount >= l.maxUsage) l.isActive = false;
        emit UsageRecorded(licenseId, l.usageCount);
    }

    function revokeLicense(uint256 licenseId, string memory reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        licenses[licenseId].isActive = false;
        emit LicenseRevoked(licenseId, reason);
    }

    function isLicenseValid(address user, uint256 toolId) external view returns (bool) {
        uint256 licenseId = activeLicense[user][toolId];
        if (licenseId == 0) return false;
        License memory l = licenses[licenseId];
        return l.isActive && (l.expiresAt == 0 || block.timestamp <= l.expiresAt);
    }

    function getLicenseeHistory(address licensee) external view returns (uint256[] memory) { return licenseeLicenses[licensee]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
