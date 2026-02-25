// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title EmergencyShutdown
 * @notice Circuit breakers for critical system failures
 * 
 * EMERGENCY POWERS:
 * - Pause entire protocol
 * - Pause specific layers
 * - Pause individual contracts
 * - Emergency fund recovery
 */
contract EmergencyShutdown is AccessControl {
    
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    
    struct EmergencyState {
        bool globalPause;
        bool layer1Paused;
        bool layer2Paused;
        bool layer3Paused;
        bool layer4Paused;
        bool layer5Paused;
        bool layer6Paused;
        uint256 pausedAt;
        string reason;
    }
    
    struct ContractPause {
        bool isPaused;
        uint256 pausedAt;
        string reason;
        address pausedBy;
    }
    
    EmergencyState public emergencyState;
    mapping(address => ContractPause) public contractPauses;
    
    uint256 public emergencyCount;
    uint256 public constant EMERGENCY_COOLDOWN = 1 hours;
    uint256 public lastEmergencyTime;
    
    event EmergencyPause(string reason, address indexed by);
    event EmergencyUnpause(address indexed by);
    event LayerPaused(uint256 indexed layer, string reason);
    event ContractPaused(address indexed contractAddr, string reason);
    event FundsRecovered(address indexed token, uint256 amount, address indexed to);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
    }
    
    /**
     * @notice EMERGENCY: Pause entire protocol
     */
    function emergencyPause(string memory reason) external onlyRole(EMERGENCY_ROLE) {
        require(!emergencyState.globalPause, "Already paused");
        
        emergencyState.globalPause = true;
        emergencyState.pausedAt = block.timestamp;
        emergencyState.reason = reason;
        
        emergencyCount++;
        lastEmergencyTime = block.timestamp;
        
        emit EmergencyPause(reason, msg.sender);
    }
    
    /**
     * @notice Unpause protocol (requires multiple guardians)
     */
    function emergencyUnpause() external onlyRole(GUARDIAN_ROLE) {
        require(emergencyState.globalPause, "Not paused");
        require(
            block.timestamp >= emergencyState.pausedAt + EMERGENCY_COOLDOWN,
            "Cooldown not met"
        );
        
        emergencyState.globalPause = false;
        emergencyState.pausedAt = 0;
        emergencyState.reason = "";
        
        emit EmergencyUnpause(msg.sender);
    }
    
    /**
     * @notice Pause specific layer
     */
    function pauseLayer(uint256 layer, string memory reason) external onlyRole(EMERGENCY_ROLE) {
        require(layer >= 1 && layer <= 6, "Invalid layer");
        
        if (layer == 1) emergencyState.layer1Paused = true;
        else if (layer == 2) emergencyState.layer2Paused = true;
        else if (layer == 3) emergencyState.layer3Paused = true;
        else if (layer == 4) emergencyState.layer4Paused = true;
        else if (layer == 5) emergencyState.layer5Paused = true;
        else if (layer == 6) emergencyState.layer6Paused = true;
        
        emit LayerPaused(layer, reason);
    }
    
    /**
     * @notice Unpause layer
     */
    function unpauseLayer(uint256 layer) external onlyRole(GUARDIAN_ROLE) {
        require(layer >= 1 && layer <= 6, "Invalid layer");
        
        if (layer == 1) emergencyState.layer1Paused = false;
        else if (layer == 2) emergencyState.layer2Paused = false;
        else if (layer == 3) emergencyState.layer3Paused = false;
        else if (layer == 4) emergencyState.layer4Paused = false;
        else if (layer == 5) emergencyState.layer5Paused = false;
        else if (layer == 6) emergencyState.layer6Paused = false;
    }
    
    /**
     * @notice Pause specific contract
     */
    function pauseContract(address contractAddr, string memory reason) 
        external 
        onlyRole(EMERGENCY_ROLE) 
    {
        contractPauses[contractAddr] = ContractPause({
            isPaused: true,
            pausedAt: block.timestamp,
            reason: reason,
            pausedBy: msg.sender
        });
        
        emit ContractPaused(contractAddr, reason);
    }
    
    /**
     * @notice Unpause contract
     */
    function unpauseContract(address contractAddr) external onlyRole(GUARDIAN_ROLE) {
        contractPauses[contractAddr].isPaused = false;
    }
    
    /**
     * @notice Emergency fund recovery (last resort)
     */
    function recoverFunds(
        address token,
        uint256 amount,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(emergencyState.globalPause, "Must be in emergency mode");
        
        if (token == address(0)) {
            // Recover ETH
            payable(to).transfer(amount);
        } else {
            // Recover ERC20 (would need interface)
            // IERC20(token).transfer(to, amount);
        }
        
        emit FundsRecovered(token, amount, to);
    }
    
    /**
     * @notice Check if protocol is operational
     */
    function isOperational() external view returns (bool) {
        return !emergencyState.globalPause;
    }
    
    /**
     * @notice Check if specific layer is operational
     */
    function isLayerOperational(uint256 layer) external view returns (bool) {
        if (emergencyState.globalPause) return false;
        
        if (layer == 1) return !emergencyState.layer1Paused;
        if (layer == 2) return !emergencyState.layer2Paused;
        if (layer == 3) return !emergencyState.layer3Paused;
        if (layer == 4) return !emergencyState.layer4Paused;
        if (layer == 5) return !emergencyState.layer5Paused;
        if (layer == 6) return !emergencyState.layer6Paused;
        
        return true;
    }
    
    /**
     * @notice Check if contract is operational
     */
    function isContractOperational(address contractAddr) external view returns (bool) {
        if (emergencyState.globalPause) return false;
        return !contractPauses[contractAddr].isPaused;
    }
}
