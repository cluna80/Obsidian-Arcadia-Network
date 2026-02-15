// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title OANDAO
 * @dev Main DAO contract coordinating all governance components
 */
contract OANDAO is AccessControl {
    
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    
    address public tokenAddress;
    address public treasuryAddress;
    address public proposalSystemAddress;
    address public votingMechanismAddress;
    
    bool public initialized;
    
    struct DAOConfig {
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 proposalThreshold;
        uint256 quorumPercentage;
        uint256 timelockDelay;
    }
    
    DAOConfig public config;
    
    event DAOInitialized(
        address indexed token,
        address indexed treasury,
        address indexed proposalSystem
    );
    event ConfigUpdated(DAOConfig newConfig);
    event ComponentUpgraded(string component, address newAddress);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNOR_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
        
        // Set default config
        config = DAOConfig({
            votingDelay: 1 days,
            votingPeriod: 3 days,
            proposalThreshold: 100_000 * 10**18,
            quorumPercentage: 4,
            timelockDelay: 2 days
        });
    }
    
    function initialize(
        address _token,
        address _treasury,
        address _proposalSystem,
        address _votingMechanism
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!initialized, "Already initialized");
        require(_token != address(0), "Invalid token");
        require(_treasury != address(0), "Invalid treasury");
        require(_proposalSystem != address(0), "Invalid proposal system");
        require(_votingMechanism != address(0), "Invalid voting mechanism");
        
        tokenAddress = _token;
        treasuryAddress = _treasury;
        proposalSystemAddress = _proposalSystem;
        votingMechanismAddress = _votingMechanism;
        
        initialized = true;
        
        emit DAOInitialized(_token, _treasury, _proposalSystem);
    }
    
    function updateConfig(DAOConfig memory newConfig) 
        external onlyRole(GOVERNOR_ROLE) 
    {
        config = newConfig;
        emit ConfigUpdated(newConfig);
    }
    
    function upgradeComponent(string memory component, address newAddress) 
        external onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newAddress != address(0), "Invalid address");
        
        bytes32 componentHash = keccak256(abi.encodePacked(component));
        
        if (componentHash == keccak256(abi.encodePacked("treasury"))) {
            treasuryAddress = newAddress;
        } else if (componentHash == keccak256(abi.encodePacked("proposalSystem"))) {
            proposalSystemAddress = newAddress;
        } else if (componentHash == keccak256(abi.encodePacked("votingMechanism"))) {
            votingMechanismAddress = newAddress;
        } else {
            revert("Unknown component");
        }
        
        emit ComponentUpgraded(component, newAddress);
    }
    
    function getDAOAddresses() external view returns (
        address token,
        address treasury,
        address proposalSystem,
        address votingMechanism
    ) {
        return (tokenAddress, treasuryAddress, proposalSystemAddress, votingMechanismAddress);
    }
    
    function getConfig() external view returns (DAOConfig memory) {
        return config;
    }
}
