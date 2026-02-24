const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OAN INTEGRATION TESTS - Full System Workflows", function () {
  let owner, addr1;

  before(async function () {
    [owner, addr1] = await ethers.getSigners();
  });

  describe("Complete Entity Lifecycle - Birth to Legacy", function () {
    let oanEntity, registry, did, reputation, behavioralIdentity, memoryVault, temporal, legacy;

    before(async function () {
      console.log("\n    Deploying Layer 2 contracts...");
      const OANEntity = await ethers.getContractFactory("OANEntity");
      oanEntity = await OANEntity.deploy();
      const EntityRegistry = await ethers.getContractFactory("EntityRegistry");
      registry = await EntityRegistry.deploy();
      const DecentralizedIdentity = await ethers.getContractFactory("DecentralizedIdentity");
      did = await DecentralizedIdentity.deploy();
      const ReputationOracle = await ethers.getContractFactory("ReputationOracle");
      reputation = await ReputationOracle.deploy();

      console.log("    Deploying Layer 3 contracts...");
      const BehavioralIdentity = await ethers.getContractFactory("BehavioralIdentity");
      behavioralIdentity = await BehavioralIdentity.deploy();
      const MemoryVault = await ethers.getContractFactory("MemoryVault");
      memoryVault = await MemoryVault.deploy();
      const TemporalEntities = await ethers.getContractFactory("TemporalEntities");
      temporal = await TemporalEntities.deploy();
      const LegacySystem = await ethers.getContractFactory("LegacySystem");
      legacy = await LegacySystem.deploy();

      console.log("    All contracts deployed!\n");
    });

    it("FULL LIFECYCLE: Entity birth → life → death → legacy", async function () {
      console.log("\n    Starting complete entity lifecycle test...\n");

      const dslHash = ethers.keccak256(ethers.toUtf8Bytes("warrior_bot_dsl"));
      const mintTx = await oanEntity.mintEntity(
        owner.address,
        "WarriorBot",
        "Fighter",
        dslHash,
        "ipfs://metadata/warrior"
      );
      await mintTx.wait();
      const entityId = 1;
      console.log("    Entity minted: WarriorBot (ID: " + entityId + ")");

      await registry.registerEntity(
        await oanEntity.getAddress(),
        entityId,
        owner.address,
        "Fighter",
        dslHash
      );
      console.log("    Registered in entity registry");

      const didTx = await did.createDID(entityId.toString(), owner.address, "ipfs://did/warrior");
      await didTx.wait();
      const didString = await did.getDID(entityId.toString());
      console.log("    DID created:", didString);

      await reputation.initializeReputation(entityId, 0);
      console.log("    Reputation initialized at 0");

      const biTx = await behavioralIdentity.createIdentity();
      await biTx.wait();
      const identityId = await behavioralIdentity.getIdentityByAddress(owner.address);
      console.log("    Behavioral identity created (ID: " + identityId + ")");

      await memoryVault.createVault(entityId);
      console.log("    Memory vault created");

      await temporal.createTemporalEntity(
        entityId,
        25 * 365 * 24 * 3600,
        80 * 365 * 24 * 3600
      );
      console.log("    Temporal entity created (Age: 25, Life expectancy: 80)");

      await temporal.setSkill(entityId, "combat", 75, 100);
      console.log("    Skill learned: Combat level 75");

      await reputation.updateReputation(entityId, 50);
      await reputation.recordAction(entityId, true);
      console.log("    Battle won! Reputation: +50");

      await behavioralIdentity.recordDecision(identityId, 80, true, false);
      console.log("    Aggressive decision recorded");

      await memoryVault.storeMemory(
        entityId,
        "First legendary battle victory against Dragon",
        3,
        ethers.keccak256(ethers.toUtf8Bytes("dragon_battle"))
      );
      console.log("    Legendary memory stored");

      await reputation.updateReputation(entityId, 30);
      await reputation.recordAction(entityId, true);
      console.log("    Second battle won! Reputation: +30");

      await temporal.useSkill(entityId, "combat");
      console.log("    Combat skill used (prevents decay)");

      const repScore = await reputation.getScore(entityId);
      const repData = await reputation.getScore(entityId);
      const [, repTotalActions, repSuccessfulActions] = await reputation.getReputationData(entityId);
      console.log("    Success Rate:", repSuccessfulActions.toString(), "/", repTotalActions.toString());

      const identity = await behavioralIdentity.getIdentity(identityId);
      console.log("    Total Decisions:", identity.totalDecisions.toString());
      console.log("    Successful:", identity.successfulDecisions.toString());

      const memories = await memoryVault.getMemories(entityId);
      console.log("    Total Memories:", memories.length);

      const isAlive = await temporal.isAlive(entityId);
      console.log("    Status:", isAlive ? "ALIVE" : "DECEASED");

      await temporal.markDeceased(entityId);
      const stillAlive = await temporal.isAlive(entityId);
      console.log("    Entity deceased. Status:", stillAlive ? "ALIVE" : "DECEASED");

      const heirId = 2;
      await legacy.createHeir(entityId, heirId, repScore, 100);
      console.log("    Heir created (ID: " + heirId + ")");
      console.log("    Reputation transferred to heir:", repScore.toString());

      const legacyData = await legacy.legacies(entityId);
      console.log("    Legacy recorded for dynasty tracking");

      const dynasty = await legacy.getDynastyTree(entityId);
      console.log("    Dynasty tree established with " + dynasty.length + " members");

      console.log("\n    LIFECYCLE COMPLETE!\n");

      expect(repScore).to.equal(100);
      expect(identity.totalDecisions).to.equal(1);
      expect(memories.length).to.equal(1);
      expect(stillAlive).to.be.false;
      expect(legacyData.heirId).to.equal(heirId);
    });
  });

  describe("Complete Behavior Economy - Intelligence Marketplace", function () {
    let behaviorMarket, cognitiveStyles;

    before(async function () {
      console.log("\n    Deploying Intelligence Layer contracts...");
      const BehaviorMarketplace = await ethers.getContractFactory("BehaviorMarketplace");
      behaviorMarket = await BehaviorMarketplace.deploy();
      const CognitiveStyles = await ethers.getContractFactory("CognitiveStyles");
      cognitiveStyles = await CognitiveStyles.deploy();
      console.log("    Intelligence contracts deployed!\n");
    });

    it("INTELLIGENCE ECONOMY: Create → Mint → List → Buy → Execute", async function () {
      console.log("\n    Testing complete intelligence marketplace workflow...\n");

      const codeHash = ethers.keccak256(ethers.toUtf8Bytes("aggressive_trading_v1"));
      const mintTx = await behaviorMarket.mintBehavior(
        "Aggressive Trading v1",
        0,
        codeHash,
        ethers.parseEther("1"),
        500
      );
      await mintTx.wait();
      const behaviorId = 1;
      console.log("    Behavior minted (ID: " + behaviorId + ")");

      await behaviorMarket.listBehavior(behaviorId, ethers.parseEther("1"));
      console.log("    Behavior listed for 1 ETH");

      const balanceBefore = await ethers.provider.getBalance(owner.address);
      await behaviorMarket.connect(addr1).buyBehavior(behaviorId, { value: ethers.parseEther("1") });
      const balanceAfter = await ethers.provider.getBalance(owner.address);
      console.log("    Behavior purchased");
      console.log("    Seller earned:", ethers.formatEther(balanceAfter - balanceBefore), "ETH");

      await behaviorMarket.connect(addr1).recordExecution(behaviorId, true);
      await behaviorMarket.connect(addr1).recordExecution(behaviorId, true);
      await behaviorMarket.connect(addr1).recordExecution(behaviorId, false);
      await behaviorMarket.connect(addr1).recordExecution(behaviorId, true);

      const stats = await behaviorMarket.getBehaviorStats(behaviorId);
      const successRate = (Number(stats.successfulExecutions) * 100) / Number(stats.totalExecutions);
      console.log("    Total Executions:", stats.totalExecutions.toString());
      console.log("    Successful:", stats.successfulExecutions.toString());
      console.log("    Success Rate:", successRate.toFixed(1) + "%");

      console.log("\n    INTELLIGENCE ECONOMY COMPLETE!\n");

      expect(await behaviorMarket.ownerOf(behaviorId)).to.equal(addr1.address);
      expect(stats.totalExecutions).to.equal(4);
      expect(stats.successfulExecutions).to.equal(3);
    });
  });

  describe("Cross-World Identity - Portable Reputation", function () {
    let crossWorld, reputation, did, cognitiveFingerprint, reputationIdentity;

    before(async function () {
      console.log("\n    Deploying Identity Layer contracts...");
      const CrossWorldIdentity = await ethers.getContractFactory("CrossWorldIdentity");
      crossWorld = await CrossWorldIdentity.deploy();
      const ReputationOracle = await ethers.getContractFactory("ReputationOracle");
      reputation = await ReputationOracle.deploy();
      const DecentralizedIdentity = await ethers.getContractFactory("DecentralizedIdentity");
      did = await DecentralizedIdentity.deploy();
      const CognitiveFingerprint = await ethers.getContractFactory("CognitiveFingerprint");
      cognitiveFingerprint = await CognitiveFingerprint.deploy();
      const ReputationIdentity = await ethers.getContractFactory("ReputationIdentity");
      reputationIdentity = await ReputationIdentity.deploy();
      console.log("    Identity contracts deployed!\n");
    });

    it("CROSS-WORLD: Build reputation across 3 worlds → Transfer → Verify", async function () {
      const identityId = 1;

      console.log("\n    Testing cross-world identity system...\n");

      await crossWorld.createUniversalIdentity(identityId, owner.address);
      await did.createDID(identityId.toString(), owner.address, "ipfs://universal");
      await cognitiveFingerprint.generateFingerprint(identityId, 85, 90, 75, 80, 95, 70, 88);

      try {
        await reputation.initializeReputation(identityId, 0);
      } catch (e) {
        if (!e.message.includes('Already initialized')) throw e;
        console.log("Main identity already initialized, skipping");
      }
      console.log("    Universal identity created");

      console.log("\n    Building reputation in 3 worlds...");

      await crossWorld.linkWorld(identityId, 1, 150, 1000);
      try {
        await reputation.initializeReputation(1, 0);
      } catch (e) {
        if (!e.message.includes('Already initialized')) throw e;
        console.log("World 1 already initialized, skipping");
      }
      await reputation.updateReputation(1, 150);
      await reputation.recordAction(1, true);
      await reputation.recordAction(1, true);
      await reputation.recordAction(1, true);

      await crossWorld.linkWorld(identityId, 2, 200, 500);
      try {
        await reputation.initializeReputation(2, 0);
      } catch (e) {
        if (!e.message.includes('Already initialized')) throw e;
        console.log("World 2 already initialized, skipping");
      }
      await reputation.updateReputation(2, 200);
      await reputation.recordAction(2, true);
      await reputation.recordAction(2, true);

      await crossWorld.linkWorld(identityId, 3, 100, 750);
      try {
        await reputation.initializeReputation(3, 0);
      } catch (e) {
        if (!e.message.includes('Already initialized')) throw e;
        console.log("World 3 already initialized, skipping");
      }
      await reputation.updateReputation(3, 100);

      await crossWorld.verifyIdentity(identityId);
      const profile = await crossWorld.getUniversalProfile(identityId);
      console.log("    Identity VERIFIED ✓");
      console.log("    Total Worlds:", profile.linkedWorlds.length);
      console.log("    Total Reputation:", profile.totalReputation.toString());

      await crossWorld.transferReputation(identityId, 2, 3, 50);

      const aggregateRep = await reputationIdentity.aggregateReputation(identityId);
      console.log("    Aggregate Reputation Score:", aggregateRep.toString());

      console.log("\n    CROSS-WORLD IDENTITY COMPLETE!\n");

      expect(profile.isVerified).to.be.true;
      expect(profile.linkedWorlds.length).to.equal(3);
      expect(profile.totalReputation).to.be.gt(0);
    });
  });

  describe("Programmable Reality - World Creation", function () {
    let worldPhysics, economicLaws, worldComposer, realityMarket;

    before(async function () {
      console.log("\n    Deploying Reality Layer contracts...");
      const WorldPhysics = await ethers.getContractFactory("WorldPhysics");
      worldPhysics = await WorldPhysics.deploy();
      const EconomicLaws = await ethers.getContractFactory("EconomicLaws");
      economicLaws = await EconomicLaws.deploy();
      const WorldComposer = await ethers.getContractFactory("WorldComposer");
      worldComposer = await WorldComposer.deploy();
      const RealityMarketplace = await ethers.getContractFactory("RealityMarketplace");
      realityMarket = await RealityMarketplace.deploy();
      console.log("    Reality contracts deployed!\n");
    });

    it("REALITY: Create physics → Create economy → Compose world → Sell", async function () {
      console.log("\n    Testing programmable reality system...\n");

      await worldPhysics.createPhysicsModule("Anti-Gravity Module", 0, {
        gravityStrength: -50,
        energyDrainRate: 500,
        timeFlowRate: 200,
        causalityStrength: 80,
        entropyRate: 30,
        quantumFluctuation: 20
      });
      const physicsId = 1;

      await worldPhysics.createPhysicsModule("Chaos Module", 4, {
        gravityStrength: 0,
        energyDrainRate: 1000,
        timeFlowRate: 150,
        causalityStrength: 30,
        entropyRate: 95,
        quantumFluctuation: 90
      });
      const chaosId = 2;

      await economicLaws.createEconomicSystem("Post-Scarcity Paradise", 0, {
        infiniteResources: true,
        inflationRate: 0,
        taxRate: 0,
        tradeFrequency: 10000,
        priceControls: false,
        resourceDecay: false,
        wealthDistribution: 100
      });
      const economyId = 1;

      await worldComposer.composeWorld(
        "Floating Chaos Realm",
        [physicsId, chaosId],
        [economyId]
      );
      const worldId = 1;
      console.log("    World composed: Floating Chaos Realm");

      await worldComposer.publishWorld(worldId, ethers.parseEther("5"));

      await realityMarket.listModule(physicsId, ethers.parseEther("0.5"), "physics");

      await realityMarket.connect(addr1).licenseModule(physicsId, 30 * 24 * 3600, {
        value: ethers.parseEther("0.1")
      });
      const hasLicense = await realityMarket.hasLicense(physicsId, addr1.address);

      console.log("\n    PROGRAMMABLE REALITY COMPLETE!\n");

      const world = await worldComposer.getWorld(worldId);
      expect(world.isPublished).to.be.true;
      expect(world.physicsModules.length).to.equal(2);
      expect(world.economicSystems.length).to.equal(1);
      expect(hasLicense).to.be.true;
    });
  });

  describe("Emotional Ecosystem - NPCs with Feelings", function () {
    let emotions, trust, socialInfluence;

    before(async function () {
      console.log("\n    Deploying Psychology Layer contracts...");

      const EmotionalState = await ethers.getContractFactory("EmotionalState");
      emotions = await EmotionalState.deploy();

      console.log("EmotionalState functions:", emotions.interface.fragments.map(f => f.name));

      const TrustDynamics = await ethers.getContractFactory("TrustDynamics");
      trust = await TrustDynamics.deploy();

      const SocialInfluence = await ethers.getContractFactory("SocialInfluence");
      socialInfluence = await SocialInfluence.deploy();

      console.log("    Psychology contracts deployed!\n");
    });

    it("EMOTIONS: NPCs form relationships → Build trust → React emotionally", async function () {
      console.log("\n    Testing emotional ecosystem...\n");

      await emotions.initializeEmotions(1);
      await emotions.initializeEmotions(2);
      await emotions.initializeEmotions(3);

      await trust.buildTrust(1, 2, 85);
      await trust.buildTrust(2, 1, 80);
      const trustScore = await trust.getTrustScore(1, 2);
      console.log("    Trust built: NPC1 → NPC2 =", trustScore.toString());

      await socialInfluence.follow(1, 3);
      await socialInfluence.follow(2, 3);
      const influenceScore = await socialInfluence.getInfluenceScore(3);
      console.log("    NPC 3 influence score:", influenceScore.toString());

      console.log("\n    4️⃣ EVENTS: Emotional reactions to events...");
      console.log("    → Scary event occurs...");
      await emotions.updateFear(1, 70);
      const state1 = await emotions.getEmotions(1);
      console.log("    NPC 1 Fear:", state1.fear.toString());

      console.log("    → Victory celebration...");
      await emotions.updateTrust(2, 60);
      const state2 = await emotions.getEmotions(2);
      console.log("    NPC 2 Trust (proxy for joy):", state2.trust.toString());

      await trust.recordBetrayal(2, 1, 50);
      const trustAfter = await trust.getTrustScore(1, 2);
      console.log("    Trust BROKEN! Score:", trustAfter.toString());

      console.log("\n    EMOTIONAL ECOSYSTEM COMPLETE!\n");

      expect(trustScore).to.be.gt(0);
      expect(trustAfter).to.be.lt(trustScore);
      expect(state1.fear).to.be.gt(50);
    });
  });
});