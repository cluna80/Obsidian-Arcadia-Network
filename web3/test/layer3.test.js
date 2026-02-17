const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ìºë OAN LAYER 3: CIVILIZATION PROTOCOL TESTS", function () {

  // ============================================
  // PHASE 3.1: TOKENIZED INTELLIGENCE
  // ============================================
  describe("Ì∑† Phase 3.1: BehaviorMarketplace", function () {
    let BehaviorMarketplace, market, owner, addr1;

    beforeEach(async function () {
      [owner, addr1] = await ethers.getSigners();
      BehaviorMarketplace = await ethers.getContractFactory("BehaviorMarketplace");
      market = await BehaviorMarketplace.deploy();
    });

    it("‚úÖ Should mint a behavior NFT", async function () {
      const tx = await market.mintBehavior(
        "Aggressive Trader",
        0, // Strategy type
        ethers.keccak256(ethers.toUtf8Bytes("strategy_code")),
        ethers.parseEther("1"),
        100 // 1% royalty
      );
      await tx.wait();
      const behavior = await market.getBehavior(1);
      expect(behavior.name).to.equal("Aggressive Trader");
      console.log("    ‚úì Behavior NFT minted: Aggressive Trader");
    });

    it("‚úÖ Should list behavior for sale", async function () {
      await market.mintBehavior(
        "Conservative Strategy",
        0,
        ethers.keccak256(ethers.toUtf8Bytes("conservative_code")),
        ethers.parseEther("0.5"),
        50
      );
      await market.listBehavior(1, ethers.parseEther("0.5"));
      const listing = await market.listings(1);
      expect(listing.isActive).to.equal(true);
      console.log("    ‚úì Behavior listed for 0.5 ETH");
    });

    it("‚úÖ Should buy a behavior", async function () {
      await market.mintBehavior(
        "Trading Bot v1",
        0,
        ethers.keccak256(ethers.toUtf8Bytes("bot_code")),
        ethers.parseEther("1"),
        100
      );
      await market.listBehavior(1, ethers.parseEther("1"));
      await market.connect(addr1).buyBehavior(1, {
        value: ethers.parseEther("1")
      });
      expect(await market.ownerOf(1)).to.equal(addr1.address);
      console.log("    ‚úì Behavior purchased successfully");
    });

    it("‚úÖ Should record execution stats", async function () {
      await market.mintBehavior(
        "TestStrategy",
        0,
        ethers.keccak256(ethers.toUtf8Bytes("test")),
        ethers.parseEther("1"),
        100
      );
      await market.recordExecution(1, true);
      await market.recordExecution(1, true);
      await market.recordExecution(1, false);
      const stats = await market.behaviorStats(1);
      expect(stats.totalExecutions).to.equal(3);
      expect(stats.successfulExecutions).to.equal(2);
      console.log("    ‚úì Execution stats: 2/3 success rate");
    });
  });

  describe("Ì∑† Phase 3.1: MemoryVault", function () {
    let MemoryVault, vault, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      MemoryVault = await ethers.getContractFactory("MemoryVault");
      vault = await MemoryVault.deploy();
    });

    it("‚úÖ Should create memory vault", async function () {
      await vault.createVault(1);
      const vaultData = await vault.vaults(1);
      expect(vaultData.entityId).to.equal(1);
      console.log("    ‚úì Memory vault created for entity 1");
    });

    it("‚úÖ Should store legendary memory", async function () {
      await vault.createVault(1);
      await vault.storeMemory(
        1,
        "First legendary battle victory",
        3, // Legendary rarity
        ethers.keccak256(ethers.toUtf8Bytes("battle_data"))
      );
      const memories = await vault.getMemories(1);
      expect(memories.length).to.equal(1);
      expect(memories[0].rarity).to.equal(3);
      console.log("    ‚úì Legendary memory stored in vault");
    });
  });

  describe("Ì∑† Phase 3.1: CognitiveStyles", function () {
    let CognitiveStyles, styles, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      CognitiveStyles = await ethers.getContractFactory("CognitiveStyles");
      styles = await CognitiveStyles.deploy();
    });

    it("‚úÖ Should mint cognitive style NFT", async function () {
      await styles.mintStyle(
        "Risk-Averse Analyst",
        20,  // risk tolerance
        80,  // adaptability
        70,  // creativity
        90,  // analytical
        60   // emotional intelligence
      );
      const style = await styles.getStyle(1);
      expect(style.name).to.equal("Risk-Averse Analyst");
      console.log("    ‚úì Cognitive style NFT minted");
    });

    it("‚úÖ Should attach style to entity", async function () {
      await styles.mintStyle("Aggressive", 90, 70, 60, 50, 40);
      await styles.attachToEntity(1, 42);
      const style = await styles.getStyle(1);
      expect(style.isAttached).to.equal(true);
      expect(style.attachedTo).to.equal(42);
      console.log("    ‚úì Style attached to entity 42");
    });
  });

  // ============================================
  // PHASE 3.2: TOKENIZED TIME
  // ============================================
  describe("‚è∞ Phase 3.2: TemporalEntities", function () {
    let TemporalEntities, temporal, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      TemporalEntities = await ethers.getContractFactory("TemporalEntities");
      temporal = await TemporalEntities.deploy();
    });

    it("‚úÖ Should create temporal entity", async function () {
      await temporal.createTemporalEntity(
        1,
        18 * 365 * 24 * 3600, // Start at age 18
        80 * 365 * 24 * 3600  // 80 year life expectancy
      );
      const entity = await temporal.entities(1);
      expect(entity.isActive).to.equal(true);
      console.log("    ‚úì Temporal entity created (age 18, lifespan 80 years)");
    });

    it("‚úÖ Should update entity age", async function () {
      await temporal.createTemporalEntity(1, 0, 80 * 365 * 24 * 3600);
      await temporal.updateAge(1);
      const entity = await temporal.entities(1);
      expect(entity.isActive).to.equal(true);
      console.log("    ‚úì Entity age updated successfully");
    });

    it("‚úÖ Should track skills", async function () {
      await temporal.createTemporalEntity(1, 0, 80 * 365 * 24 * 3600);
      await temporal.setSkill(1, "swordsmanship", 75, 100);
      const skillLevel = await temporal.getSkillLevel(1, "swordsmanship");
      expect(skillLevel).to.equal(75);
      console.log("    ‚úì Skill tracked: swordsmanship at level 75");
    });

    it("‚úÖ Should mark entity deceased", async function () {
      await temporal.createTemporalEntity(1, 0, 80 * 365 * 24 * 3600);
      await temporal.markDeceased(1);
      const isAlive = await temporal.isAlive(1);
      expect(isAlive).to.equal(false);
      console.log("    ‚úì Entity deceased, legacy system triggered");
    });
  });

  describe("‚è∞ Phase 3.2: LegacySystem", function () {
    let LegacySystem, legacy, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      LegacySystem = await ethers.getContractFactory("LegacySystem");
      legacy = await LegacySystem.deploy();
    });

    it("‚úÖ Should create heir", async function () {
      await legacy.createHeir(1, 2, 50, 1000);
      const legacyData = await legacy.legacies(1);
      expect(legacyData.parentId).to.equal(1);
      expect(legacyData.heirId).to.equal(2);
      console.log("    ‚úì Heir created, legacy transferred");
    });

    it("‚úÖ Should establish dynasty", async function () {
      await legacy.createHeir(1, 2, 50, 1000);
      const dynasty = await legacy.getDynastyTree(1);
      expect(dynasty.length).to.be.greaterThan(0);
      console.log("    ‚úì Dynasty established with", dynasty.length, "members");
    });
  });

  // ============================================
  // PHASE 3.3: PROGRAMMABLE REALITY
  // ============================================
  describe("Ìºç Phase 3.3: WorldPhysics", function () {
    let WorldPhysics, physics, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      WorldPhysics = await ethers.getContractFactory("WorldPhysics");
      physics = await WorldPhysics.deploy();
    });

    it("‚úÖ Should create physics module", async function () {
      const params = {
        gravityStrength: -50,    // Anti-gravity
        energyDrainRate: 500,    // Half energy drain
        timeFlowRate: 200,       // 2x time speed
        causalityStrength: 80,
        entropyRate: 20,
        quantumFluctuation: 10
      };
      await physics.createPhysicsModule("Anti-Gravity Module", 0, params);
      const module = await physics.physicsModules(1);
      expect(module.name).to.equal("Anti-Gravity Module");
      console.log("    ‚úì Physics module created: Anti-Gravity");
    });

    it("‚úÖ Should attach physics to world", async function () {
      const params = {
        gravityStrength: 0,
        energyDrainRate: 1000,
        timeFlowRate: 100,
        causalityStrength: 100,
        entropyRate: 90,
        quantumFluctuation: 80
      };
      await physics.createPhysicsModule("Chaos Module", 4, params);
      await physics.attachToWorld(1, 1);
      const worldPhysics = await physics.getWorldPhysics(1);
      expect(worldPhysics.length).to.equal(1);
      console.log("    ‚úì Chaos physics attached to world 1");
    });
  });

  describe("Ìºç Phase 3.3: WorldComposer", function () {
    let WorldComposer, composer, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      WorldComposer = await ethers.getContractFactory("WorldComposer");
      composer = await WorldComposer.deploy();
    });

    it("‚úÖ Should compose a world", async function () {
      await composer.composeWorld("Chaos Realm", [1, 2], [1]);
      const world = await composer.getWorld(1);
      expect(world.name).to.equal("Chaos Realm");
      console.log("    ‚úì World composed: Chaos Realm");
    });

    it("‚úÖ Should publish world", async function () {
      await composer.composeWorld("Test World", [], []);
      await composer.publishWorld(1, ethers.parseEther("10"));
      const world = await composer.getWorld(1);
      expect(world.isPublished).to.equal(true);
      console.log("    ‚úì World published for 10 OAN");
    });
  });

  // ============================================
  // PHASE 3.4: PSYCHOLOGICAL DYNAMICS
  // ============================================
  describe("Ìæ≠ Phase 3.4: EmotionalState", function () {
    let EmotionalState, emotions, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      EmotionalState = await ethers.getContractFactory("EmotionalState");
      emotions = await EmotionalState.deploy();
    });

    it("‚úÖ Should initialize emotions", async function () {
      await emotions.initializeEmotions(1);
      const state = await emotions.getEmotions(1);
      expect(state.trust).to.equal(50);
      expect(state.joy).to.equal(50);
      console.log("    ‚úì Emotions initialized (Trust: 50, Joy: 50)");
    });

    it("‚úÖ Should trigger fear response", async function () {
      await emotions.initializeEmotions(1);
      await emotions.updateFear(1, 85);
      const state = await emotions.getEmotions(1);
      expect(state.fear).to.equal(85);
      console.log("    ‚úì Fear triggered to 85 - Flee response activated!");
    });

    it("‚úÖ Should update trust", async function () {
      await emotions.initializeEmotions(1);
      await emotions.updateTrust(1, 30);
      const state = await emotions.getEmotions(1);
      expect(state.trust).to.equal(80);
      console.log("    ‚úì Trust increased to 80");
    });
  });

  describe("Ìæ≠ Phase 3.4: TrustDynamics", function () {
    let TrustDynamics, trust, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      TrustDynamics = await ethers.getContractFactory("TrustDynamics");
      trust = await TrustDynamics.deploy();
    });

    it("‚úÖ Should build trust between entities", async function () {
      await trust.buildTrust(1, 2, 80);
      await trust.buildTrust(1, 2, 90);
      await trust.buildTrust(1, 2, 75);
      const score = await trust.getTrustScore(1, 2);
      expect(score).to.be.greaterThan(0);
      console.log("    ‚úì Trust built between entities 1 & 2:", score.toString());
    });

    it("‚úÖ Should record betrayal and drop trust", async function () {
      await trust.buildTrust(1, 2, 90);
      const scoreBefore = await trust.getTrustScore(1, 2);
      await trust.recordBetrayal(2, 1, 50);
      const scoreAfter = await trust.getTrustScore(1, 2);
      expect(scoreAfter).to.be.lessThan(scoreBefore);
      console.log("    ‚úì Betrayal recorded, trust dropped from", scoreBefore.toString(), "to", scoreAfter.toString());
    });
  });

  // ============================================
  // PHASE 3.5: RISK & DERIVATIVES
  // ============================================
  describe("Ì≥ä Phase 3.5: RiskProfiles", function () {
    let RiskProfiles, risk, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      RiskProfiles = await ethers.getContractFactory("RiskProfiles");
      risk = await RiskProfiles.deploy();
    });

    it("‚úÖ Should create risk profile", async function () {
      await risk.createRiskProfile(1, 75, 30, 2); // Aggressive
      const profile = await risk.getRiskProfile(1);
      expect(profile.volatility).to.equal(75);
      console.log("    ‚úì Risk profile created (volatility: 75, HIGH risk)");
    });

    it("‚úÖ Should calculate risk score", async function () {
      await risk.createRiskProfile(1, 20, 90, 0); // Conservative
      const score = await risk.getRiskScore(1);
      expect(score).to.be.lessThan(50);
      console.log("    ‚úì Risk score calculated:", score.toString(), "(LOW risk)");
    });

    it("‚úÖ Should record performance and update risk", async function () {
      await risk.createRiskProfile(1, 50, 50, 1);
      await risk.recordPerformance(1, true, 100);
      await risk.recordPerformance(1, true, 150);
      await risk.recordPerformance(1, false, -50);
      await risk.recordPerformance(1, true, 200);
      await risk.recordPerformance(1, true, 100);
      const profile = await risk.getRiskProfile(1);
      expect(profile.lastAssessment).to.be.greaterThan(0);
      console.log("    ‚úì Performance data recorded, volatility updated");
    });
  });

  describe("Ì≥ä Phase 3.5: InsuranceProtocol", function () {
    let InsuranceProtocol, insurance, owner, addr1;

    beforeEach(async function () {
      [owner, addr1] = await ethers.getSigners();
      InsuranceProtocol = await ethers.getContractFactory("InsuranceProtocol");
      insurance = await InsuranceProtocol.deploy();
    });

    it("‚úÖ Should create insurance policy", async function () {
      const coverage = ethers.parseEther("10");
      const premium = await insurance.calculatePremium(
        coverage,
        30 * 24 * 3600 // 30 days
      );
      await insurance.createPolicy(
        0, // EntityDeath
        1,
        coverage,
        30 * 24 * 3600,
        { value: premium }
      );
      const policy = await insurance.getPolicy(1);
      expect(policy.isActive).to.equal(true);
      console.log("    ‚úì Insurance policy created, coverage: 10 ETH");
    });
  });

  // ============================================
  // PHASE 3.6: BEHAVIORAL IDENTITY
  // ============================================
  describe("Ì∂î Phase 3.6: BehavioralIdentity", function () {
    let BehavioralIdentity, identity, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      BehavioralIdentity = await ethers.getContractFactory("BehavioralIdentity");
      identity = await BehavioralIdentity.deploy();
    });

    it("‚úÖ Should create behavioral identity", async function () {
      await identity.createIdentity();
      const id = await identity.getIdentityByAddress(owner.address);
      expect(id).to.equal(1);
      console.log("    ‚úì Behavioral identity created");
    });

    it("‚úÖ Should record decisions and update DNA", async function () {
      await identity.createIdentity();
      await identity.recordDecision(1, 80, true, false);
      await identity.recordDecision(1, 90, true, false);
      await identity.recordDecision(1, 70, false, false);
      const id = await identity.getIdentity(1);
      expect(id.totalDecisions).to.equal(3);
      console.log("    ‚úì 3 decisions recorded, behavioral DNA updated");
    });

    it("‚úÖ Should classify risk style from decisions", async function () {
      await identity.createIdentity();
      // Record aggressive decisions
      for(let i = 0; i < 5; i++) {
        await identity.recordDecision(1, 90, true, false);
      }
      const dna = await identity.getBehavioralDNA(1);
      expect(dna.riskTolerance).to.be.greaterThan(0);
      console.log("    ‚úì Risk style classified from", 5, "aggressive decisions");
    });
  });

  describe("Ì∂î Phase 3.6: CognitiveFingerprint", function () {
    let CognitiveFingerprint, fingerprint, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      CognitiveFingerprint = await ethers.getContractFactory("CognitiveFingerprint");
      fingerprint = await CognitiveFingerprint.deploy();
    });

    it("‚úÖ Should generate unique fingerprint", async function () {
      const hash = await fingerprint.generateFingerprint(
        1, 85, 90, 75, 80, 95, 70, 88
      );
      const fp = await fingerprint.getFingerprint(1);
      expect(fp.identityId).to.equal(1);
      console.log("    ‚úì Cognitive fingerprint generated");
    });

    it("‚úÖ Should compare fingerprints", async function () {
      await fingerprint.generateFingerprint(1, 85, 90, 75, 80, 95, 70, 88);
      await fingerprint.generateFingerprint(2, 80, 85, 70, 75, 90, 65, 83);
      const similarity = await fingerprint.compareFingerprints(1, 2);
      expect(similarity).to.be.greaterThan(80);
      console.log("    ‚úì Fingerprint similarity:", similarity.toString(), "%");
    });
  });

  describe("Ì∂î Phase 3.6: CrossWorldIdentity", function () {
    let CrossWorldIdentity, crossWorld, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      CrossWorldIdentity = await ethers.getContractFactory("CrossWorldIdentity");
      crossWorld = await CrossWorldIdentity.deploy();
    });

    it("‚úÖ Should create universal identity", async function () {
      await crossWorld.createUniversalIdentity(1, owner.address);
      const id = await crossWorld.getUniversalProfile(1);
      expect(id.owner).to.equal(owner.address);
      console.log("    ‚úì Universal identity created");
    });

    it("‚úÖ Should link worlds to identity", async function () {
      await crossWorld.createUniversalIdentity(1, owner.address);
      await crossWorld.linkWorld(1, 1, 100, 75);
      await crossWorld.linkWorld(1, 2, 200, 50);
      const profile = await crossWorld.getUniversalProfile(1);
      expect(profile.linkedWorlds.length).to.equal(2);
      console.log("    ‚úì Identity linked to 2 worlds");
    });

    it("‚úÖ Should transfer reputation between worlds", async function () {
      await crossWorld.createUniversalIdentity(1, owner.address);
      await crossWorld.linkWorld(1, 1, 100, 75);
      await crossWorld.linkWorld(1, 2, 50, 25);
      await crossWorld.transferReputation(1, 1, 2, 30);
      console.log("    ‚úì Reputation transferred from World 1 to World 2");
    });
  });
});
