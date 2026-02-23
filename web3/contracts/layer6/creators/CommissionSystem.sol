// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CommissionSystem - Custom work orders for OAN creators (Layer 6, Phase 6.3)
contract CommissionSystem is AccessControl, ReentrancyGuard {
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");

    enum CommissionStatus { Open, Accepted, InProgress, Submitted, Completed, Disputed, Cancelled }
    enum CommissionType   { AIModule, NFTArt, SmartContract, Strategy, Custom }

    struct Milestone {
        uint256 milestoneId;
        string  description;
        uint256 payment;
        bool    completed;
        uint256 dueDate;
        string  deliverableURI;
    }

    struct Commission {
        uint256          commissionId;
        address          client;
        address          creator;
        string           title;
        string           description;
        CommissionType   commType;
        uint256          budget;
        uint256          deadline;
        CommissionStatus status;
        uint256          createdAt;
        uint256          acceptedAt;
        uint256          completedAt;
        string           deliverableURI;
        uint256          milestoneCount;
        uint256          milestonesCompleted;
        bool             hasDispute;
    }

    uint256 private _commissionCounter;
    mapping(uint256 => Commission)  public commissions;
    mapping(uint256 => Milestone[]) public milestones;
    mapping(address => uint256[])   public clientCommissions;
    mapping(address => uint256[])   public creatorCommissions;
    mapping(uint256 => address[])   public commissionApplicants;

    address public treasury;
    uint256 public platformFeeBps = 500;
    uint256 public totalCommissions;
    uint256 public totalVolume;

    event CommissionCreated(uint256 indexed commissionId, address indexed client, uint256 budget);
    event CommissionAccepted(uint256 indexed commissionId, address indexed creator);
    event MilestoneCompleted(uint256 indexed commissionId, uint256 milestoneIndex);
    event CommissionCompleted(uint256 indexed commissionId, address indexed creator, uint256 payment);
    event DisputeRaised(uint256 indexed commissionId, address indexed raiser);
    event DisputeResolved(uint256 indexed commissionId, bool favorClient);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITER_ROLE,       msg.sender);
    }

    function createCommission(
        string memory title,
        string memory description,
        CommissionType commType,
        uint256 deadline,
        Milestone[] memory _milestones
    ) external payable returns (uint256) {
        require(msg.value > 0 && deadline > block.timestamp, "Invalid params");
        require(_milestones.length > 0 && _milestones.length <= 10, "1-10 milestones");

        uint256 commissionId = ++_commissionCounter;
        Commission storage c = commissions[commissionId];
        c.commissionId   = commissionId;
        c.client         = msg.sender;
        c.title          = title;
        c.description    = description;
        c.commType       = commType;
        c.budget         = msg.value;
        c.deadline       = deadline;
        c.status         = CommissionStatus.Open;
        c.createdAt      = block.timestamp;
        c.milestoneCount = _milestones.length;

        for (uint256 i = 0; i < _milestones.length; i++) milestones[commissionId].push(_milestones[i]);

        clientCommissions[msg.sender].push(commissionId);
        totalCommissions++;
        emit CommissionCreated(commissionId, msg.sender, msg.value);
        return commissionId;
    }

    function applyForCommission(uint256 commissionId) external {
        require(commissions[commissionId].status == CommissionStatus.Open, "Not open");
        commissionApplicants[commissionId].push(msg.sender);
    }

    function acceptCreator(uint256 commissionId, address creator) external {
        Commission storage c = commissions[commissionId];
        require(c.client == msg.sender && c.status == CommissionStatus.Open, "Invalid");
        c.creator    = creator;
        c.status     = CommissionStatus.Accepted;
        c.acceptedAt = block.timestamp;
        creatorCommissions[creator].push(commissionId);
        emit CommissionAccepted(commissionId, creator);
    }

    function startWork(uint256 commissionId) external {
        Commission storage c = commissions[commissionId];
        require(c.creator == msg.sender && c.status == CommissionStatus.Accepted, "Invalid");
        c.status = CommissionStatus.InProgress;
    }

    function submitMilestone(uint256 commissionId, uint256 milestoneIndex, string memory deliverableURI) external {
        Commission storage c = commissions[commissionId];
        require(c.creator == msg.sender && c.status == CommissionStatus.InProgress, "Invalid");
        milestones[commissionId][milestoneIndex].deliverableURI = deliverableURI;
        milestones[commissionId][milestoneIndex].completed      = true;
        c.milestonesCompleted++;
        emit MilestoneCompleted(commissionId, milestoneIndex);
    }

    function approveMilestone(uint256 commissionId, uint256 milestoneIndex) external nonReentrant {
        Commission storage c = commissions[commissionId];
        require(c.client == msg.sender, "Not client");
        Milestone storage m = milestones[commissionId][milestoneIndex];
        require(m.completed, "Not submitted");

        uint256 payment = m.payment;
        uint256 fee     = (payment * platformFeeBps) / 10000;
        payable(treasury).transfer(fee);
        payable(c.creator).transfer(payment - fee);
        totalVolume += payment;

        if (c.milestonesCompleted == c.milestoneCount) {
            c.status      = CommissionStatus.Completed;
            c.completedAt = block.timestamp;
            emit CommissionCompleted(commissionId, c.creator, c.budget);
        }
    }

    function raiseDispute(uint256 commissionId) external {
        Commission storage c = commissions[commissionId];
        require(msg.sender == c.client || msg.sender == c.creator, "Not party");
        require(c.status == CommissionStatus.InProgress || c.status == CommissionStatus.Submitted, "Invalid status");
        c.hasDispute = true;
        c.status     = CommissionStatus.Disputed;
        emit DisputeRaised(commissionId, msg.sender);
    }

    function resolveDispute(uint256 commissionId, bool favorClient, uint256 clientRefundBps) external onlyRole(ARBITER_ROLE) nonReentrant {
        Commission storage c = commissions[commissionId];
        require(c.status == CommissionStatus.Disputed, "Not disputed");
        require(clientRefundBps <= 10000, "Invalid bps");
        c.status = CommissionStatus.Completed;

        uint256 balance = address(this).balance;
        uint256 pot     = balance < c.budget ? balance : c.budget;

        if (favorClient) {
            uint256 refund    = (pot * clientRefundBps) / 10000;
            uint256 remainder = pot - refund;
            payable(c.client).transfer(refund);
            if (remainder > 0) payable(c.creator).transfer(remainder);
        } else {
            payable(c.creator).transfer(pot);
        }
        emit DisputeResolved(commissionId, favorClient);
    }

    function getApplicants(uint256 commissionId) external view returns (address[] memory)  { return commissionApplicants[commissionId]; }
    function getMilestones(uint256 commissionId) external view returns (Milestone[] memory) { return milestones[commissionId]; }
    function supportsInterface(bytes4 i) public view override(AccessControl) returns (bool) { return super.supportsInterface(i); }
}
