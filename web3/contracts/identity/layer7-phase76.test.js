const { expect } = require("chai");
const { ethers }  = require("hardhat");

describe("Layer 7 — Phase 7.6: Insurance & Guarantees", function () {
  let securityDeposits, insuranceFund, disputeResolution, compensationEngine;
  let owner, slasher, manager, claimsAdmin, contributor, compensator, funder;
  let depositor, depositor2, plaintiff, defendant, arbitrator, juror;
  let treasury;

  const ONE_ETH   = ethers.parseEther("1.0");
  const HALF_ETH  = ethers.parseEther("0.5");
  const SMALL_ETH = ethers.parseEther("0.01");

  beforeEach(async () => {
    [owner, slasher, manager, claimsAdmin, contributor, compensator,
     funder, depositor, depositor2, plaintiff, defendant,
     arbitrator, juror, treasury] = await ethers.getSigners();

    const SecurityDeposits   = await ethers.getContractFactory("SecurityDeposits");
    const InsuranceFund      = await ethers.getContractFactory("InsuranceFund");
    const DisputeResolution  = await ethers.getContractFactory("DisputeResolution");
    const CompensationEngine = await ethers.getContractFactory("CompensationEngine");

    securityDeposits   = await SecurityDeposits.deploy(treasury.address);
    insuranceFund      = await InsuranceFund.deploy(treasury.address);
    disputeResolution  = await DisputeResolution.deploy(treasury.address);
    compensationEngine = await CompensationEngine.deploy();

    // Grant roles
    await securityDeposits.grantRole(await securityDeposits.SLASHER_ROLE(), slasher.address);
    await securityDeposits.grantRole(await securityDeposits.MANAGER_ROLE(), manager.address);
    await insuranceFund.grantRole(await insuranceFund.CLAIMS_ADMIN_ROLE(), claimsAdmin.address);
    await insuranceFund.grantRole(await insuranceFund.CONTRIBUTOR_ROLE(),  contributor.address);
    await disputeResolution.grantRole(await disputeResolution.ARBITRATOR_ROLE(), arbitrator.address);
    await disputeResolution.grantRole(await disputeResolution.JUROR_ROLE(),      juror.address);
    await compensationEngine.grantRole(await compensationEngine.COMPENSATOR_ROLE(), compensator.address);
    await compensationEngine.grantRole(await compensationEngine.FUNDER_ROLE(),      funder.address);
  });

  // ── SecurityDeposits ────────────────────────────────────────────────────────

  describe("SecurityDeposits", () => {
    it("should accept a deposit", async () => {
      await expect(
        securityDeposits.connect(depositor).deposit("marketplace", { value: ONE_ETH })
      ).to.emit(securityDeposits, "DepositMade").withArgs(1, depositor.address, ONE_ETH, "marketplace");

      expect(await securityDeposits.getBalance(depositor.address)).to.equal(ONE_ETH);
    });

    it("should release a deposit after lock period", async () => {
      await securityDeposits.connect(depositor).deposit("marketplace", { value: ONE_ETH });
      const before = await ethers.provider.getBalance(depositor.address);
      await securityDeposits.connect(depositor).releaseDeposit(1);
      const after  = await ethers.provider.getBalance(depositor.address);
      expect(after).to.be.greaterThan(before);
    });

    it("should slash a deposit", async () => {
      await securityDeposits.connect(depositor).deposit("marketplace", { value: ONE_ETH });
      await expect(
        securityDeposits.connect(slasher).slashDeposit(1, HALF_ETH, "Fraud detected")
      ).to.emit(securityDeposits, "DepositSlashed");

      expect(await securityDeposits.getBalance(depositor.address)).to.equal(HALF_ETH);
      expect(await securityDeposits.totalSlashed()).to.equal(HALF_ETH);
    });

    it("should enforce minimum deposit requirement", async () => {
      await securityDeposits.setRequirement("validator", ONE_ETH, 0, true);
      await expect(
        securityDeposits.connect(depositor).deposit("validator", { value: SMALL_ETH })
      ).to.be.revertedWith("Below minimum deposit");
    });

    it("should lock a deposit", async () => {
      await securityDeposits.connect(depositor).deposit("marketplace", { value: ONE_ETH });
      await securityDeposits.connect(manager).lockDeposit(1, 86400);
      const dep = await securityDeposits.deposits(1);
      expect(dep.status).to.equal(1); // Locked
    });

    it("should check meetsRequirement", async () => {
      await securityDeposits.setRequirement("oracle", ONE_ETH, 0, true);
      expect(await securityDeposits.meetsRequirement(depositor.address, "oracle")).to.be.false;
      await securityDeposits.connect(depositor).deposit("oracle", { value: ONE_ETH });
      expect(await securityDeposits.meetsRequirement(depositor.address, "oracle")).to.be.true;
    });

    it("should revert slash exceeding deposit", async () => {
      await securityDeposits.connect(depositor).deposit("marketplace", { value: ONE_ETH });
      await expect(
        securityDeposits.connect(slasher).slashDeposit(1, ethers.parseEther("2.0"), "Overslash")
      ).to.be.revertedWith("Slash exceeds deposit");
    });
  });

  // ── InsuranceFund ───────────────────────────────────────────────────────────

  describe("InsuranceFund", () => {
    beforeEach(async () => {
      // Fund the pool
      await insuranceFund.connect(contributor).fundPool({ value: ethers.parseEther("100") });
    });

    it("should fund the pool", async () => {
      const balance = await insuranceFund.getPoolBalance();
      expect(balance).to.equal(ethers.parseEther("100"));
    });

    it("should purchase a policy", async () => {
      const coverage  = ethers.parseEther("10");
      const premium   = coverage * 100n / 10000n; // 1%
      await expect(
        insuranceFund.connect(depositor).purchasePolicy(0, coverage, 365 * 86400, { value: premium })
      ).to.emit(insuranceFund, "PolicyIssued");

      const policies = await insuranceFund.getHolderPolicies(depositor.address);
      expect(policies.length).to.equal(1);
    });

    it("should submit a claim", async () => {
      const coverage = ethers.parseEther("5");
      const premium  = coverage * 100n / 10000n;
      await insuranceFund.connect(depositor).purchasePolicy(0, coverage, 365 * 86400, { value: premium });
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("bug-evidence"));
      await expect(
        insuranceFund.connect(depositor).submitClaim(1, coverage / 2n, evHash, "Smart contract bug")
      ).to.emit(insuranceFund, "ClaimSubmitted");
    });

    it("should approve and pay a claim", async () => {
      const coverage = ethers.parseEther("5");
      const premium  = coverage * 100n / 10000n;
      await insuranceFund.connect(depositor).purchasePolicy(0, coverage, 365 * 86400, { value: premium });
      const evHash   = ethers.keccak256(ethers.toUtf8Bytes("proof"));
      await insuranceFund.connect(depositor).submitClaim(1, ethers.parseEther("1"), evHash, "Loss");

      const before = await ethers.provider.getBalance(depositor.address);
      await expect(
        insuranceFund.connect(claimsAdmin).approveClaim(1, ethers.parseEther("1"))
      ).to.emit(insuranceFund, "ClaimPaid");
      const after = await ethers.provider.getBalance(depositor.address);
      expect(after).to.be.greaterThan(before);
    });

    it("should reject a claim", async () => {
      const coverage = ethers.parseEther("5");
      const premium  = coverage * 100n / 10000n;
      await insuranceFund.connect(depositor).purchasePolicy(0, coverage, 365 * 86400, { value: premium });
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("proof2"));
      await insuranceFund.connect(depositor).submitClaim(1, ethers.parseEther("1"), evHash, "Disputed");
      await expect(
        insuranceFund.connect(claimsAdmin).rejectClaim(1, "Insufficient evidence")
      ).to.emit(insuranceFund, "ClaimRejected");
    });

    it("should revert claim exceeding coverage", async () => {
      const coverage = ethers.parseEther("5");
      const premium  = coverage * 100n / 10000n;
      await insuranceFund.connect(depositor).purchasePolicy(0, coverage, 365 * 86400, { value: premium });
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("big"));
      await expect(
        insuranceFund.connect(depositor).submitClaim(1, ethers.parseEther("10"), evHash, "Too much")
      ).to.be.revertedWith("Exceeds coverage");
    });
  });

  // ── DisputeResolution ───────────────────────────────────────────────────────

  describe("DisputeResolution", () => {
    it("should file a dispute", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("evidence"));
      await expect(
        disputeResolution.connect(plaintiff).fileDispute(
          defendant.address, 0, evHash, "Marketplace fraud", { value: SMALL_ETH }
        )
      ).to.emit(disputeResolution, "DisputeFiled");

      const dispute = await disputeResolution.disputes(1);
      expect(dispute.plaintiff).to.equal(plaintiff.address);
      expect(dispute.defendant).to.equal(defendant.address);
    });

    it("should respond to a dispute", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("ev1"));
      await disputeResolution.connect(plaintiff).fileDispute(
        defendant.address, 0, evHash, "Fraud", { value: SMALL_ETH }
      );
      const responseHash = ethers.keccak256(ethers.toUtf8Bytes("response"));
      await expect(
        disputeResolution.connect(defendant).respondToDispute(1, responseHash, { value: SMALL_ETH })
      ).to.emit(disputeResolution, "DisputeResponded");
    });

    it("should resolve in favor of plaintiff", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("ev2"));
      await disputeResolution.connect(plaintiff).fileDispute(
        defendant.address, 0, evHash, "Fraud", { value: SMALL_ETH }
      );
      await expect(
        disputeResolution.connect(arbitrator).resolveDispute(1, 1) // FavorPlaintiff
      ).to.emit(disputeResolution, "DisputeResolved").withArgs(1, 1);
    });

    it("should resolve in favor of defendant", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("ev3"));
      await disputeResolution.connect(plaintiff).fileDispute(
        defendant.address, 1, evHash, "Service dispute", { value: SMALL_ETH }
      );
      await expect(
        disputeResolution.connect(arbitrator).resolveDispute(1, 2) // FavorDefendant
      ).to.emit(disputeResolution, "DisputeResolved").withArgs(1, 2);
    });

    it("should split resolution", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("ev4"));
      await disputeResolution.connect(plaintiff).fileDispute(
        defendant.address, 2, evHash, "Split case", { value: SMALL_ETH }
      );
      await expect(
        disputeResolution.connect(arbitrator).resolveDispute(1, 3) // Split
      ).to.emit(disputeResolution, "DisputeResolved");
    });

    it("should revert if defendant disputes themselves", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("self"));
      await expect(
        disputeResolution.connect(plaintiff).fileDispute(
          plaintiff.address, 0, evHash, "Self dispute", { value: SMALL_ETH }
        )
      ).to.be.revertedWith("Cannot dispute yourself");
    });

    it("should revert insufficient filing fee", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("fee"));
      await expect(
        disputeResolution.connect(plaintiff).fileDispute(
          defendant.address, 0, evHash, "No fee", { value: 0 }
        )
      ).to.be.revertedWith("Insufficient filing fee");
    });

    it("should get plaintiff disputes", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("list"));
      await disputeResolution.connect(plaintiff).fileDispute(
        defendant.address, 0, evHash, "First", { value: SMALL_ETH }
      );
      const disputes = await disputeResolution.getPlaintiffDisputes(plaintiff.address);
      expect(disputes.length).to.equal(1);
    });
  });

  // ── CompensationEngine ──────────────────────────────────────────────────────

  describe("CompensationEngine", () => {
    beforeEach(async () => {
      await compensationEngine.connect(funder).depositFunds({ value: ethers.parseEther("10") });
    });

    it("should fund the pool", async () => {
      expect(await compensationEngine.getPoolBalance()).to.equal(ethers.parseEther("10"));
    });

    it("should auto-approve small compensation", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("small-loss"));
      const before = await ethers.provider.getBalance(depositor.address);
      await compensationEngine.connect(compensator).requestCompensation(
        depositor.address, ethers.parseEther("0.05"), 0, evHash, "Bug bounty", 0
      );
      const after = await ethers.provider.getBalance(depositor.address);
      expect(after).to.be.greaterThan(before);
    });

    it("should require approval for large compensation", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("large-loss"));
      await compensationEngine.connect(compensator).requestCompensation(
        depositor.address, ethers.parseEther("1"), 0, evHash, "Large claim", 0
      );
      const req = await compensationEngine.requests(1);
      expect(req.status).to.equal(0); // Pending
    });

    it("should approve and pay compensation", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("pay-loss"));
      await compensationEngine.connect(compensator).requestCompensation(
        depositor.address, ethers.parseEther("1"), 0, evHash, "Fraud loss", 0
      );
      await compensationEngine.connect(compensator).approveCompensation(1);
      const before = await ethers.provider.getBalance(depositor.address);
      await compensationEngine.connect(compensator).processPayout(1);
      const after  = await ethers.provider.getBalance(depositor.address);
      expect(after).to.be.greaterThan(before);
    });

    it("should cancel a pending request", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("cancel"));
      await compensationEngine.connect(compensator).requestCompensation(
        depositor.address, ethers.parseEther("1"), 0, evHash, "Cancelled", 0
      );
      await compensationEngine.cancelCompensation(1);
      const req = await compensationEngine.requests(1);
      expect(req.status).to.equal(5); // Cancelled
    });

    it("should execute a batch payout", async () => {
      const h1 = ethers.keccak256(ethers.toUtf8Bytes("b1"));
      const h2 = ethers.keccak256(ethers.toUtf8Bytes("b2"));
      await compensationEngine.connect(compensator).requestCompensation(
        depositor.address, ethers.parseEther("0.1"), 0, h1, "Batch 1", 0
      );
      await compensationEngine.connect(compensator).requestCompensation(
        depositor2.address, ethers.parseEther("0.1"), 0, h2, "Batch 2", 0
      );
      await compensationEngine.connect(compensator).approveCompensation(1);
      await compensationEngine.connect(compensator).approveCompensation(2);
      const batchId = await compensationEngine.connect(compensator).createBatch([1, 2]);
      await expect(
        compensationEngine.connect(compensator).executeBatch(1)
      ).to.emit(compensationEngine, "BatchExecuted");
    });

    it("should track total received per recipient", async () => {
      const evHash = ethers.keccak256(ethers.toUtf8Bytes("track"));
      await compensationEngine.connect(compensator).requestCompensation(
        depositor.address, ethers.parseEther("0.05"), 0, evHash, "Track", 0
      );
      expect(await compensationEngine.getTotalReceived(depositor.address))
        .to.be.greaterThan(0);
    });
  });
});