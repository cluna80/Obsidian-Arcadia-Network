// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DAOTreasury
 * @dev Treasury management for OAN DAO
 */
contract DAOTreasury is AccessControl, ReentrancyGuard {

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    struct Payment {
        address recipient;
        uint256 amount;
        string description;
        uint256 executedAt;
        bool completed;
    }

    mapping(uint256 => Payment) public payments;
    uint256 public paymentCount;

    uint256 public totalSpent;
    uint256 public totalReceived;

    event FundsReceived(address indexed from, uint256 amount);
    event PaymentExecuted(uint256 indexed paymentId, address indexed recipient, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event TokenWithdrawal(address indexed token, address indexed to, uint256 amount);
    event EmergencyWithdrawal(address indexed to, uint256 amount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(TREASURER_ROLE, msg.sender);
    }

    /* ========================================================= */
    /* ===================== RECEIVING FUNDS =================== */
    /* ========================================================= */

    receive() external payable {
        totalReceived += msg.value;
        emit FundsReceived(msg.sender, msg.value);
    }

    /* ========================================================= */
    /* ===================== DAO PAYMENTS ====================== */
    /* ========================================================= */

    function executePayment(
        address recipient,
        uint256 amount,
        string memory description
    )
        external
        onlyRole(EXECUTOR_ROLE)
        nonReentrant
        returns (uint256)
    {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(address(this).balance >= amount, "Insufficient funds");

        uint256 paymentId = paymentCount++;

        payments[paymentId] = Payment({
            recipient: recipient,
            amount: amount,
            description: description,
            executedAt: block.timestamp,
            completed: true
        });

        totalSpent += amount;

        payable(recipient).transfer(amount);

        emit PaymentExecuted(paymentId, recipient, amount);

        return paymentId;
    }

    /* ========================================================= */
    /* ===================== STANDARD WITHDRAW ================= */
    /* ========================================================= */

    /**
     *  Matches your test suite
     */
    function withdraw(address to, uint256 amount)
        external
        onlyRole(TREASURER_ROLE)
        nonReentrant
    {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Invalid amount");
        require(amount <= address(this).balance, "Insufficient balance");

        totalSpent += amount;

        payable(to).transfer(amount);

        emit Withdrawal(to, amount);
    }

    /**
     *  ERC20 Treasury Support (CRITICAL FEATURE)
     */
    function withdrawToken(address token, address to, uint256 amount)
        external
        onlyRole(TREASURER_ROLE)
        nonReentrant
    {
        require(token != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");

        IERC20(token).transfer(to, amount);

        emit TokenWithdrawal(token, to, amount);
    }

    /* ========================================================= */
    /* ===================== EMERGENCY MODE ==================== */
    /* ========================================================= */

    function emergencyWithdraw(address to, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "Invalid address");
        require(amount <= address(this).balance, "Insufficient balance");

        payable(to).transfer(amount);

        emit EmergencyWithdrawal(to, amount);
    }

    /* ========================================================= */
    /* ===================== VIEW FUNCTIONS ==================== */
    /* ========================================================= */

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getPayment(uint256 paymentId) external view returns (Payment memory) {
        return payments[paymentId];
    }

    function getTreasuryStats() external view returns (
        uint256 balance,
        uint256 spent,
        uint256 received,
        uint256 paymentsCount
    ) {
        return (
            address(this).balance,
            totalSpent,
            totalReceived,
            paymentCount
        );
    }
}
