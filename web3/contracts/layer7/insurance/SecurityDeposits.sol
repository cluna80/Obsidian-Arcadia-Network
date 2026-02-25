// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SecurityDeposits
/// @notice Manage collateral deposits for protocol participants
contract SecurityDeposits is AccessControl, ReentrancyGuard {

    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    enum DepositStatus { Active, Locked, Released, Slashed }

    struct Deposit {
        uint256       id;
        address       depositor;
        uint256       amount;
        uint256       lockedUntil;
        DepositStatus status;
        uint256       depositedAt;
        string        purpose;      // e.g. "marketplace", "validator", "oracle"
    }

    struct DepositRequirement {
        uint256 minAmount;
        uint256 lockDuration;
        bool    required;
    }

    uint256 public depositCounter;
    uint256 public totalDeposited;
    uint256 public totalSlashed;

    mapping(uint256 => Deposit)              public deposits;
    mapping(address => uint256[])            public depositorIds;
    mapping(address => uint256)              public totalDepositorBalance;
    mapping(string  => DepositRequirement)   public requirements;   // purpose → requirement
    address public treasury;

    event DepositMade(uint256 indexed depositId, address indexed depositor, uint256 amount, string purpose);
    event DepositLocked(uint256 indexed depositId, uint256 lockedUntil);
    event DepositReleased(uint256 indexed depositId, address indexed depositor, uint256 amount);
    event DepositSlashed(uint256 indexed depositId, address indexed depositor, uint256 amount, string reason);
    event RequirementSet(string purpose, uint256 minAmount, uint256 lockDuration);

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SLASHER_ROLE,       msg.sender);
        _grantRole(MANAGER_ROLE,       msg.sender);
    }

    /// @notice Make a security deposit
    function deposit(string calldata purpose) external payable nonReentrant returns (uint256 depositId) {
        DepositRequirement storage req = requirements[purpose];
        if (req.required) {
            require(msg.value >= req.minAmount, "Below minimum deposit");
        }
        require(msg.value > 0, "No value sent");

        depositCounter++;
        depositId = depositCounter;

        uint256 lockDuration = req.lockDuration;
        deposits[depositId] = Deposit({
            id:          depositId,
            depositor:   msg.sender,
            amount:      msg.value,
            lockedUntil: block.timestamp + lockDuration,
            status:      DepositStatus.Active,
            depositedAt: block.timestamp,
            purpose:     purpose
        });

        depositorIds[msg.sender].push(depositId);
        totalDepositorBalance[msg.sender] += msg.value;
        totalDeposited += msg.value;

        emit DepositMade(depositId, msg.sender, msg.value, purpose);
    }

    /// @notice Lock a deposit for additional duration
    function lockDeposit(uint256 depositId, uint256 additionalTime) external onlyRole(MANAGER_ROLE) {
        Deposit storage dep = deposits[depositId];
        require(dep.status == DepositStatus.Active, "Deposit not active");
        dep.lockedUntil += additionalTime;
        dep.status       = DepositStatus.Locked;
        emit DepositLocked(depositId, dep.lockedUntil);
    }

    /// @notice Release a deposit back to depositor
    function releaseDeposit(uint256 depositId) external nonReentrant {
        Deposit storage dep = deposits[depositId];
        require(dep.depositor == msg.sender || hasRole(MANAGER_ROLE, msg.sender), "Not authorized");
        require(dep.status == DepositStatus.Active || dep.status == DepositStatus.Locked, "Not releasable");
        require(block.timestamp >= dep.lockedUntil, "Still locked");

        uint256 amount = dep.amount;
        dep.status     = DepositStatus.Released;
        dep.amount     = 0;

        totalDepositorBalance[dep.depositor] -= amount;
        totalDeposited -= amount;

        payable(dep.depositor).transfer(amount);
        emit DepositReleased(depositId, dep.depositor, amount);
    }

    /// @notice Slash a deposit (send to treasury)
    function slashDeposit(uint256 depositId, uint256 slashAmount, string calldata reason)
        external onlyRole(SLASHER_ROLE) nonReentrant
    {
        Deposit storage dep = deposits[depositId];
        require(dep.status == DepositStatus.Active || dep.status == DepositStatus.Locked, "Not slashable");
        require(slashAmount <= dep.amount, "Slash exceeds deposit");

        dep.amount -= slashAmount;
        totalDepositorBalance[dep.depositor] -= slashAmount;
        totalDeposited -= slashAmount;
        totalSlashed   += slashAmount;

        if (dep.amount == 0) {
            dep.status = DepositStatus.Slashed;
        }

        payable(treasury).transfer(slashAmount);
        emit DepositSlashed(depositId, dep.depositor, slashAmount, reason);
    }

    /// @notice Set deposit requirement for a purpose
    function setRequirement(string calldata purpose, uint256 minAmount, uint256 lockDuration, bool required)
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        requirements[purpose] = DepositRequirement({
            minAmount:    minAmount,
            lockDuration: lockDuration,
            required:     required
        });
        emit RequirementSet(purpose, minAmount, lockDuration);
    }

    /// @notice Check if depositor meets requirement for a purpose
    function meetsRequirement(address depositor, string calldata purpose) external view returns (bool) {
        DepositRequirement storage req = requirements[purpose];
        if (!req.required) return true;
        return totalDepositorBalance[depositor] >= req.minAmount;
    }

    /// @notice Get all deposit IDs for a depositor
    function getDepositorIds(address depositor) external view returns (uint256[] memory) {
        return depositorIds[depositor];
    }

    /// @notice Get total active balance for a depositor
    function getBalance(address depositor) external view returns (uint256) {
        return totalDepositorBalance[depositor];
    }
}
