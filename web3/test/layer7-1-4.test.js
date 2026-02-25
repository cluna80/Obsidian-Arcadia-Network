const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Layer 7: Phase 7.1-7.4 - Safety & Reliability", function() {
  let owner, guardian, user1, user2;
  
  beforeEach(async function() {
    [owner, guardian, user1, user2] = await ethers.getSigners();
  });

  describe("Phase 7.1: Secure Execution", function() {
    let executionGuardian, sandboxEnvironment, resourceLimiter, emergencyShutdown;

    beforeEach(async function() {
      const ExecutionGuardian = await ethers.getContractFactory("ExecutionGuardian");
      executionGuardian = await ExecutionGuardian.deploy();

      const SandboxEnvironment = await ethers.getContractFactory("SandboxEnvironment");
      sandboxEnvironment = await SandboxEnvironment.deploy();

      const ResourceLimiter = await ethers.getContractFactory("ResourceLimiter");
      resourceLimiter = await ResourceLimiter.deploy();

      const EmergencyShutdown = await ethers.getContractFactory("EmergencyShutdown");
      emergencyShutdown = await EmergencyShutdown.deploy();

      const EXECUTOR_ROLE = await executionGuardian.EXECUTOR_ROLE();
      await executionGuardian.grantRole(EXECUTOR_ROLE, owner.address);

      const LIMITER_ROLE = await resourceLimiter.LIMITER_ROLE();
      await resourceLimiter.grantRole(LIMITER_ROLE, owner.address);
    });

    it("should set action policy", async function() {
      const actionHash = ethers.keccak256(ethers.toUtf8Bytes("test_action"));
      await executionGuardian.setActionPolicy(
        actionHash,
        true,
        false,
        60,
        100,
        0,
        0
      );

      const policy = await executionGuardian.actionPolicies(actionHash);
      expect(policy.isAllowed).to.be.true;
      expect(policy.cooldown).to.equal(60);
    });

    it("should validate action", async function() {
      const actionHash = ethers.keccak256(ethers.toUtf8Bytes("test_action"));
      await executionGuardian.setActionPolicy(actionHash, true, false, 0, 100, 0, 0);

      const tx = await executionGuardian.validateAction(1, actionHash, 100);
      await tx.wait();
      
      expect(tx).to.not.be.null;
    });

    it("should freeze entity", async function() {
      await executionGuardian.freezeEntity(1, "Test freeze");
      const limits = await executionGuardian.entityLimits(1);
      expect(limits.isFrozen).to.be.true;
    });

    it("should create sandbox", async function() {
      const MANAGER_ROLE = await sandboxEnvironment.SANDBOX_MANAGER_ROLE();
      await sandboxEnvironment.grantRole(MANAGER_ROLE, owner.address);

      await sandboxEnvironment.createSandbox(1, 1000000, 10000, 60);
      const sandbox = await sandboxEnvironment.sandboxes(1);
      expect(sandbox.entityId).to.equal(1);
    });

    it("should check resource availability", async function() {
      // FIX: Use call to get return value
      const result = await resourceLimiter.checkResourceAvailability.staticCall(1, 100000);
      expect(result.allowed).to.be.true;
    });

    it("should pause system", async function() {
      await emergencyShutdown.emergencyPause("Test emergency");
      const state = await emergencyShutdown.emergencyState();
      expect(state.globalPause).to.be.true;
    });
  });

  describe("Phase 7.2: Auditable Behavior", function() {
    let actionLogger, behaviorAuditor, proofOfExecution, transparencyRegistry;

    beforeEach(async function() {
      const ActionLogger = await ethers.getContractFactory("ActionLogger");
      actionLogger = await ActionLogger.deploy();

      const BehaviorAuditor = await ethers.getContractFactory("BehaviorAuditor");
      behaviorAuditor = await BehaviorAuditor.deploy();

      const ProofOfExecution = await ethers.getContractFactory("ProofOfExecution");
      proofOfExecution = await ProofOfExecution.deploy();

      const TransparencyRegistry = await ethers.getContractFactory("TransparencyRegistry");
      transparencyRegistry = await TransparencyRegistry.deploy();

      const AUDITOR_ROLE = await behaviorAuditor.AUDITOR_ROLE();
      await behaviorAuditor.grantRole(AUDITOR_ROLE, owner.address);
    });

    it("should log action", async function() {
      const actionHash = ethers.keccak256(ethers.toUtf8Bytes("test_action"));
      const resultHash = ethers.keccak256(ethers.toUtf8Bytes("result"));

      await actionLogger.logAction(
        1,
        actionHash,
        owner.address,
        100000,
        true,
        resultHash,
        "0x"
      );

      const log = await actionLogger.logs(1);
      expect(log.entityId).to.equal(1);
    });

    it("should audit entity behavior", async function() {
      const tx = await behaviorAuditor.auditEntity(1, 50, 5, 10);
      await tx.wait();
      
      const profile = await behaviorAuditor.profiles(1);
      expect(profile.entityId).to.equal(1);
    });

    it("should submit proof of execution", async function() {
      const actionRoot = ethers.keccak256(ethers.toUtf8Bytes("actions"));
      const stateRoot = ethers.keccak256(ethers.toUtf8Bytes("state"));
      const resultRoot = ethers.keccak256(ethers.toUtf8Bytes("result"));

      await proofOfExecution.submitProof(1, actionRoot, stateRoot, resultRoot);
      const proof = await proofOfExecution.proofs(1);
      expect(proof.entityId).to.equal(1);
    });

    it("should create audit record", async function() {
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes("audit_data"));
      await transparencyRegistry.createRecord(
        1,
        0,
        dataHash,
        "Test record",
        true
      );
      const record = await transparencyRegistry.records(1);
      expect(record.entityId).to.equal(1);
    });
  });

  describe("Phase 7.3: Reputation Enforcement", function() {
    let reputationGuardian, slashingMechanism, reputationRecovery, blacklistRegistry;

    beforeEach(async function() {
      const ReputationGuardian = await ethers.getContractFactory("ReputationGuardian");
      reputationGuardian = await ReputationGuardian.deploy();

      const SlashingMechanism = await ethers.getContractFactory("SlashingMechanism");
      slashingMechanism = await SlashingMechanism.deploy(owner.address);

      const ReputationRecovery = await ethers.getContractFactory("ReputationRecovery");
      reputationRecovery = await ReputationRecovery.deploy();

      const BlacklistRegistry = await ethers.getContractFactory("BlacklistRegistry");
      blacklistRegistry = await BlacklistRegistry.deploy();

      const GUARDIAN_ROLE = await reputationGuardian.GUARDIAN_ROLE();
      await reputationGuardian.grantRole(GUARDIAN_ROLE, owner.address);

      const SLASHER_ROLE = await slashingMechanism.SLASHER_ROLE();
      await slashingMechanism.grantRole(SLASHER_ROLE, owner.address);
    });

    it("should record violation", async function() {
      await reputationGuardian.recordViolation(1, 0, "Test violation");
      const violations = await reputationGuardian.getViolations(1);
      expect(violations.length).to.be.greaterThan(0);
    });

    it("should restrict entity", async function() {
      await reputationGuardian.restrictEntity(1, "Bad behavior");
      const status = await reputationGuardian.reputationStatus(1);
      expect(status.isRestricted).to.be.true;
    });

    it("should slash stake", async function() {
      await slashingMechanism.depositStake(1, 86400, { value: ethers.parseEther("1") });
      await slashingMechanism.slash(1, 0, "Fraud detected");
      
      const hasBeenSlashed = await slashingMechanism.hasBeenSlashed(1);
      expect(hasBeenSlashed).to.be.true;
    });

    it("should create recovery plan", async function() {
      const RECOVERY_ROLE = await reputationRecovery.RECOVERY_MANAGER_ROLE();
      await reputationRecovery.grantRole(RECOVERY_ROLE, owner.address);

      await reputationRecovery.createRecoveryPlan(1, 0, 500, 86400 * 30);
      const plan = await reputationRecovery.recoveryPlans(1);
      expect(plan.entityId).to.equal(1);
    });

    it("should add to blacklist", async function() {
      const MANAGER_ROLE = await blacklistRegistry.BLACKLIST_MANAGER_ROLE();
      await blacklistRegistry.grantRole(MANAGER_ROLE, owner.address);

      await blacklistRegistry.addToBlacklist(
        1,
        user1.address,
        0,
        "Evidence",
        true,
        0
      );

      const isBlacklisted = await blacklistRegistry.isBlacklisted(user1.address);
      expect(isBlacklisted).to.be.true;
    });
  });

  describe("Phase 7.4: Stability Protocols", function() {
    let circuitBreaker, rateLimiter, healthMonitor, recoveryProtocol;

    beforeEach(async function() {
      const CircuitBreaker = await ethers.getContractFactory("CircuitBreaker");
      circuitBreaker = await CircuitBreaker.deploy();

      const RateLimiter = await ethers.getContractFactory("RateLimiter");
      rateLimiter = await RateLimiter.deploy();

      const HealthMonitor = await ethers.getContractFactory("HealthMonitor");
      healthMonitor = await HealthMonitor.deploy();

      const RecoveryProtocol = await ethers.getContractFactory("RecoveryProtocol");
      recoveryProtocol = await RecoveryProtocol.deploy();

      const BREAKER_ROLE = await circuitBreaker.BREAKER_ROLE();
      await circuitBreaker.grantRole(BREAKER_ROLE, owner.address);

      const LIMITER_ROLE = await rateLimiter.LIMITER_ROLE();
      await rateLimiter.grantRole(LIMITER_ROLE, owner.address);

      const MONITOR_ROLE = await healthMonitor.MONITOR_ROLE();
      await healthMonitor.grantRole(MONITOR_ROLE, owner.address);

      const RECOVERY_ROLE = await recoveryProtocol.RECOVERY_ROLE();
      await recoveryProtocol.grantRole(RECOVERY_ROLE, owner.address);
    });

    it("should record transaction metrics", async function() {
      await circuitBreaker.recordTransaction(ethers.parseEther("1"), true, 10);
      const metrics = await circuitBreaker.getCurrentMetrics();
      expect(metrics.transactionCount).to.equal(1);
    });

    it("should check rate limit", async function() {
      const functionHash = ethers.keccak256(ethers.toUtf8Bytes("test_function"));
      // FIX: Use staticCall
      const result = await rateLimiter.checkRateLimit.staticCall(1, functionHash);
      expect(result.allowed).to.be.true;
    });

    it("should record transaction in health monitor", async function() {
      await healthMonitor.recordTransaction(true, 100000);
      const metrics = await healthMonitor.metrics();
      expect(metrics.totalTransactions).to.equal(1);
    });

    it("should create snapshot", async function() {
      const stateRoot = ethers.keccak256(ethers.toUtf8Bytes("state"));
      await recoveryProtocol.createSnapshot(stateRoot, "Test snapshot");
      const snapshot = await recoveryProtocol.snapshots(1);
      expect(snapshot.snapshotId).to.equal(1);
    });

    it("should check circuit breaker operational", async function() {
      const operational = await circuitBreaker.isOperational();
      expect(operational).to.be.true;
    });
  });
});
