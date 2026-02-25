const { expect } = require("chai");
const { ethers }  = require("hardhat");

// ── OAN Stress Tests ──────────────────────────────────────────────────────────
// High-volume, edge case, and gas exhaustion tests across all L7 contracts

describe("OAN Stress Tests — High Volume & Edge Cases", function () {
  this.timeout(300000); // 5 min for stress tests

  let trustOracle, identityVerifier, behaviorValidator, consensusChecker;
  let securityDeposits, insuranceFund, disputeResolution, compensationEngine;
  let owner, oracle;
  let signers; // pool of test accounts
  let treasury;

  const SMALL_ETH = ethers.parseEther("0.01");

  before(async () => {
    signers = await ethers.getSigners();
    [owner, oracle, treasury] = signers;

    const TrustOracle        = await ethers.getContractFactory("TrustOracle");
    const IdentityVerifier   = await ethers.getContractFactory("IdentityVerifier");
    const BehaviorValidator  = await ethers.getContractFactory("BehaviorValidator");
    const ConsensusChecker   = await ethers.getContractFactory("ConsensusChecker");
    const SecurityDeposits   = await ethers.getContractFactory("SecurityDeposits");
    const InsuranceFund      = await ethers.getContractFactory("InsuranceFund");
    const DisputeResolution  = await ethers.getContractFactory("DisputeResolution");
    const CompensationEngine = await ethers.getContractFactory("CompensationEngine");

    trustOracle        = await TrustOracle.deploy();
    identityVerifier   = await IdentityVerifier.deploy();
    behaviorValidator  = await BehaviorValidator.deploy();
    consensusChecker   = await ConsensusChecker.deploy(3);
    securityDeposits   = await SecurityDeposits.deploy(treasury.address);
    insuranceFund      = await InsuranceFund.deploy(treasury.address);
    disputeResolution  = await DisputeResolution.deploy(treasury.address);
    compensationEngine = await CompensationEngine.deploy();

    // Roles
    await trustOracle.grantRole(await trustOracle.ORACLE_ROLE(),    oracle.address);
    await trustOracle.grantRole(await trustOracle.VALIDATOR_ROLE(), oracle.address);
    await identityVerifier.grantRole(await identityVerifier.KYC_PROVIDER_ROLE(),   oracle.address);
    await behaviorValidator.grantRole(await behaviorValidator.REPORTER_ROLE(),      oracle.address);
    await behaviorValidator.grantRole(await behaviorValidator.ANALYST_ROLE(),       oracle.address);
    await securityDeposits.grantRole(await securityDeposits.SLASHER_ROLE(),        oracle.address);
    await disputeResolution.grantRole(await disputeResolution.ARBITRATOR_ROLE(),   oracle.address);
    await compensationEngine.grantRole(await compensationEngine.COMPENSATOR_ROLE(), oracle.address);
    await compensationEngine.grantRole(await compensationEngine.FUNDER_ROLE(),      owner.address);
    await insuranceFund.grantRole(await insuranceFund.CONTRIBUTOR_ROLE(),  owner.address);
    await insuranceFund.grantRole(await insuranceFund.CLAIMS_ADMIN_ROLE(), oracle.address);

    // Fund pools
    await compensationEngine.connect(owner).depositFunds({ value: ethers.parseEther("100") });
    await insuranceFund.connect(owner).fundPool({ value: ethers.parseEther("500") });
  });

  // ── TrustOracle stress ──────────────────────────────────────────────────────

  describe("TrustOracle — High Volume", () => {
    it("should handle 20 claims for same subject", async () => {
      const subject = signers[5].address;
      for (let i = 0; i < 20; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`claim-${i}`));
        await trustOracle.connect(oracle).submitClaim(subject, i % 5, h, `ipfs://${i}`);
        await trustOracle.connect(oracle).verifyClaim(i + 1, 500 + i * 10);
      }
      const score = await trustOracle.getTrustScore(subject);
      expect(score).to.be.greaterThan(0);
      const claims = await trustOracle.getSubjectClaims(subject);
      expect(claims.length).to.equal(20);
    });

    it("should handle claims for 10 different subjects simultaneously", async () => {
      const subjects = signers.slice(6, 16);
      const startId  = (await trustOracle.claimCounter()) + 1n;
      for (let i = 0; i < subjects.length; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`multi-${i}`));
        await trustOracle.connect(oracle).submitClaim(subjects[i].address, 0, h, `ipfs://m${i}`);
        await trustOracle.connect(oracle).verifyClaim(startId + BigInt(i), 600);
      }
      for (const s of subjects) {
        expect(await trustOracle.getTrustScore(s.address)).to.equal(600);
      }
    });

    it("should handle max score boundary correctly", async () => {
      const h = ethers.keccak256(ethers.toUtf8Bytes("max-score"));
      const subject = signers[16].address;
      await trustOracle.connect(oracle).submitClaim(subject, 0, h, "ipfs://max");
      await trustOracle.connect(oracle).verifyClaim(await trustOracle.claimCounter(), 1000);
      expect(await trustOracle.getTrustScore(subject)).to.equal(1000);
    });
  });

  // ── IdentityVerifier stress ─────────────────────────────────────────────────

  describe("IdentityVerifier — Edge Cases", () => {
    it("should handle 5 proofs across all verification levels", async () => {
      const subject = signers[17].address;
      for (let level = 1; level <= 4; level++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`level-${level}-proof`));
        await identityVerifier.connect(oracle).issueProof(subject, 0, level, h, "US");
      }
      expect(await identityVerifier.getVerificationLevel(subject)).to.equal(4);
    });

    it("should correctly handle revocation of highest level proof", async () => {
      const subject = signers[18].address;
      const h1 = ethers.keccak256(ethers.toUtf8Bytes("lvl2-proof"));
      const h2 = ethers.keccak256(ethers.toUtf8Bytes("lvl4-proof"));
      const startId = (await identityVerifier.proofCounter()) + 1n;
      await identityVerifier.connect(oracle).issueProof(subject, 0, 2, h1, "EU");
      await identityVerifier.connect(oracle).issueProof(subject, 1, 4, h2, "EU");
      await identityVerifier.connect(oracle).revokeProof(startId + 1n, "Expired");
      expect(await identityVerifier.getVerificationLevel(subject)).to.equal(2);
    });

    it("should process 10 subjects with simultaneous KYC", async () => {
      const batch = signers.slice(3, 13);
      for (let i = 0; i < batch.length; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`batch-kyc-${i}-${batch[i].address}`));
        await identityVerifier.connect(oracle).issueProof(batch[i].address, 0, 2, h, "GLOBAL");
      }
      for (const s of batch) {
        expect(await identityVerifier.meetsLevel(s.address, 1)).to.be.true;
      }
    });
  });

  // ── BehaviorValidator stress ────────────────────────────────────────────────

  describe("BehaviorValidator — Escalation Scenarios", () => {
    it("should accumulate risk score across multiple violations", async () => {
      const subject = signers[4].address;
      const violations = [
        { type: 0, severity: 0 },  // Spam Low
        { type: 0, severity: 1 },  // Spam Medium
        { type: 1, severity: 1 },  // Fraud Medium
        { type: 4, severity: 2 },  // Harassment High
      ];
      const startId = (await behaviorValidator.reportCounter()) + 1n;
      for (let i = 0; i < violations.length; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`stress-ev-${i}`));
        await behaviorValidator.connect(oracle).reportBehavior(
          subject, violations[i].type, violations[i].severity, h, `Violation ${i}`
        );
        await behaviorValidator.connect(oracle).confirmViolation(startId + BigInt(i));
      }
      const profile = await behaviorValidator.profiles(subject);
      expect(profile.riskScore).to.be.greaterThan(0);
      expect(profile.confirmedViolations).to.equal(4);
    });

    it("should auto-ban at max risk score", async () => {
      const subject = signers[19].address;
      // Exploit + Critical = 400 * 4 = 1600 → capped at 1000 → auto-ban
      const h = ethers.keccak256(ethers.toUtf8Bytes("exploit-critical"));
      await behaviorValidator.connect(oracle).reportBehavior(
        subject, 5, 3, h, "Critical exploit attempt"
      );
      await behaviorValidator.connect(oracle).confirmViolation(
        await behaviorValidator.reportCounter()
      );
      const profile = await behaviorValidator.profiles(subject);
      expect(profile.riskScore).to.equal(1000);
      expect(await behaviorValidator.isAllowed(subject)).to.be.false;
    });

    it("should handle rate limit configuration and checking", async () => {
      const subject = signers[3].address;
      await behaviorValidator.setRateLimit(subject, 5, 3600);
      for (let i = 0; i < 5; i++) {
        await behaviorValidator.connect(oracle).checkRateLimit(subject);
      }
      const result = await behaviorValidator.connect(oracle).checkRateLimit.staticCall(subject);
      expect(result).to.be.false; // 6th call should be over limit
    });
  });

  // ── SecurityDeposits stress ─────────────────────────────────────────────────

  describe("SecurityDeposits — Concurrent Deposits & Slashing", () => {
    it("should handle 10 simultaneous deposits", async () => {
      const depositors = signers.slice(3, 13);
      for (const d of depositors) {
        await securityDeposits.connect(d).deposit("stress", { value: SMALL_ETH });
      }
      for (const d of depositors) {
        expect(await securityDeposits.getBalance(d.address)).to.be.greaterThanOrEqual(SMALL_ETH);
      }
    });

    it("should slash multiple deposits in sequence", async () => {
      const allIds = await securityDeposits.getDepositorIds(signers[3].address);
      const depositId = allIds[allIds.length - 1];
      await securityDeposits.connect(oracle).slashDeposit(
        depositId, SMALL_ETH / 2n, "Stress slash"
      );
      expect(await securityDeposits.totalSlashed()).to.be.greaterThan(0);
    });

    it("should handle zero-balance correctly after full slash", async () => {
      await securityDeposits.connect(signers[3]).deposit("full", { value: SMALL_ETH });
      const ids = await securityDeposits.getDepositorIds(signers[3].address);
      const lastId = ids[ids.length - 1];
      await securityDeposits.connect(oracle).slashDeposit(lastId, SMALL_ETH, "Full slash");
      const dep = await securityDeposits.deposits(lastId);
      expect(dep.amount).to.equal(0);
      expect(dep.status).to.equal(3); // Slashed
    });
  });

  // ── DisputeResolution stress ────────────────────────────────────────────────

  describe("DisputeResolution — Multiple Active Disputes", () => {
    it("should handle 5 simultaneous disputes", async () => {
      const pairs = [
        [signers[3], signers[4]],
        [signers[5], signers[6]],
        [signers[7], signers[8]],
        [signers[9], signers[10]],
        [signers[11], signers[12]],
      ];
      const startId = (await disputeResolution.disputeCounter()) + 1n;
      for (let i = 0; i < pairs.length; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`stress-dispute-${i}`));
        await disputeResolution.connect(pairs[i][0]).fileDispute(
          pairs[i][1].address, 0, h, `Stress dispute ${i}`, { value: SMALL_ETH }
        );
      }
      // Resolve all
      for (let i = 0; i < pairs.length; i++) {
        await disputeResolution.connect(oracle).resolveDispute(startId + BigInt(i), 3); // Split
      }
      // Verify all closed
      for (let i = 0; i < pairs.length; i++) {
        const d = await disputeResolution.disputes(startId + BigInt(i));
        expect(d.status).to.equal(6); // Closed
      }
    });
  });

  // ── CompensationEngine stress ───────────────────────────────────────────────

  describe("CompensationEngine — Batch Processing", () => {
    it("should process 10 auto-approved payouts", async () => {
      const recipients = signers.slice(3, 13);
      for (let i = 0; i < recipients.length; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`auto-${i}`));
        await compensationEngine.connect(oracle).requestCompensation(
          recipients[i].address,
          ethers.parseEther("0.05"),
          0, h, `Auto payout ${i}`, 0
        );
      }
      expect(await compensationEngine.totalCompensated())
        .to.be.greaterThanOrEqual(ethers.parseEther("0.5"));
    });

    it("should process a batch of 5 approved payouts", async () => {
      const recipients = signers.slice(13, 18);
      const reqIds = [];
      const startId = (await compensationEngine.requestCounter()) + 1n;
      for (let i = 0; i < recipients.length; i++) {
        const h = ethers.keccak256(ethers.toUtf8Bytes(`batch-${i}-v2`));
        await compensationEngine.connect(oracle).requestCompensation(
          recipients[i].address,
          ethers.parseEther("0.2"),
          0, h, `Batch payout ${i}`, 0
        );
        const reqId = startId + BigInt(i);
        await compensationEngine.connect(oracle).approveCompensation(reqId);
        reqIds.push(reqId);
      }
      await compensationEngine.connect(oracle).createBatch(reqIds);
      const batchId = await compensationEngine.batchCounter();
      await expect(
        compensationEngine.connect(oracle).executeBatch(batchId)
      ).to.emit(compensationEngine, "BatchExecuted");
    });
  });

  // ── Gas limit edge cases ────────────────────────────────────────────────────

  describe("Edge Cases — Boundary Conditions", () => {
    it("should handle zero ETH correctly in compensation", async () => {
      const h = ethers.keccak256(ethers.toUtf8Bytes("zero-check"));
      await expect(
        compensationEngine.connect(oracle).requestCompensation(
          signers[3].address, 0, 0, h, "Zero amount", 0
        )
      ).to.be.revertedWith("Amount must be > 0");
    });

    it("should handle zero address defendant in dispute", async () => {
      const h = ethers.keccak256(ethers.toUtf8Bytes("zero-addr"));
      await expect(
        disputeResolution.connect(signers[3]).fileDispute(
          ethers.ZeroAddress, 0, h, "Zero addr", { value: SMALL_ETH }
        )
      ).to.be.revertedWith("Invalid defendant");
    });

    it("should handle max coverage exceeded in insurance", async () => {
      const tooMuch = ethers.parseEther("200"); // over 100 ETH max
      await expect(
        insuranceFund.connect(signers[3]).purchasePolicy(
          0, tooMuch, 86400, { value: ethers.parseEther("2") }
        )
      ).to.be.revertedWith("Coverage exceeds max");
    });

    it("should prevent replay of same proof hash in identity", async () => {
      const h = ethers.keccak256(ethers.toUtf8Bytes("replay-hash-test"));
      await identityVerifier.connect(oracle).issueProof(signers[3].address, 0, 1, h, "US");
      await expect(
        identityVerifier.connect(oracle).issueProof(signers[4].address, 0, 1, h, "US")
      ).to.be.revertedWith("Proof hash already used");
    });

    it("should correctly handle empty claim array for new subject", async () => {
      const claims = await trustOracle.getSubjectClaims(ethers.ZeroAddress);
      expect(claims.length).to.equal(0);
    });
  });
});