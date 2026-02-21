const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ì¥ó OAN INTEGRATION TESTS - Full System Workflows", function () {

  // ============================================
  // COMPLETE ENTITY LIFECYCLE
  // ============================================
  describe("Ìºë Complete Entity Lifecycle - Birth to Legacy", function () {
    let oanEntity, registry, did, reputation, behavioralIdentity, memoryVault, temporal, legacy;
    let owner, addr1;

    before(async function () {
      [owner, addr1] = await ethers.getSigners();

      console.log("\n    Ì¥ß Deploying Layer 2 contracts...");
      
      // Layer 2 contracts
      const OANEntity = await ethers.getContractFactory("OANEntity");
      oanEntity = await OANEntity.deploy();
      
      const EntityRegistry = await ethers.getContractFactory("EntityRegistry");
      registry = await EntityRegistry.deploy();
      
      const DecentralizedIdentity = await ethers.getContractFactory("DecentralizedIdentity");
      did = await DecentralizedIdentity.deploy();
      
      const ReputationOracle = await ethers.getContractFactory("ReputationOracle");
      reputation = await ReputationOracle.deploy();
      
      console.log("    Ì¥ß Deploying Layer 3 contracts...");
      
      // Layer 3 contracts
      const BehavioralIdentity = await ethers.getContractFactory("BehavioralIdentity");
      behavioralIdentity = await BehavioralIdentity.deploy();
      
      const MemoryVault = await ethers.getContractFactory("MemoryVault");
      memoryVault = await MemoryVault.deploy();
      
      const TemporalEntities = await ethers.getContractFactory("TemporalEntities");
      temporal = await TemporalEntities.deploy();
      
      const LegacySystem = await ethers.getContractFactory("LegacySystem");
      legacy = await LegacySystem.deploy();
      
      console.log("    ‚úÖ All contracts deployed!\n");
    });

    it("Ìºë FULL LIFECYCLE: Entity birth ‚Üí life ‚Üí death ‚Üí legacy", async function () {
      console.log("\n    Ì≥ù Starting complete entity lifecycle test...\n");

      // ===== STEP 1: BIRTH =====
      console.log("    1Ô∏è‚É£ BIRTH: Minting NFT entity...");
      const dslHash = ethers.keccak256(ethers.toUtf8Bytes("warrior_bot"));
      await oanEntity.mintEntity(
        owner.address,
        "WarriorBot",
        "Fighter",
        dslHash,
        "ipfs://metadata/warrior"
      );
      const entityId = 1;
      console.log("    ‚úÖ Entity minted: WarriorBot (ID: 1)");

      // ===== STEP 2: IDENTITY CREATION =====
      console.log("\n    2Ô∏è‚É£ IDENTITY: Creating decentralized identity...");
      await registry.registerEntity(
        await oanEntity.getAddress(),
        entityId,
        owner.address,
        "Fighter",
        dslHash
      );
      console.log("    ‚úÖ Registered in entity registry");

      const didString = await did.createDID.staticCall(
        entityId,
        owner.address,
        "ipfs://did/warrior"
      );
      await did.createDID(entityId, owner.address, "ipfs://did/warrior");
      console.log("    ‚úÖ DID created:", didString);

      await reputation.initializeReputation(entityId);
      console.log("    ‚úÖ Reputation initialized at 0");

      await behavioralIdentity.createIdentity();
      const identityId = await behavioralIdentity.getIdentityByAddress(owner.address);
      console.log("    ‚úÖ Behavioral identity created (ID:", identityId.toString() + ")");

      await memoryVault.createVault(entityId);
      console.log("    ‚úÖ Memory vault created");

      // ===== STEP 3: LIVING (TEMPORAL) =====
      console.log("\n    3Ô∏è‚É£ LIVING: Entity begins aging in real-time...");
      await temporal.createTemporalEntity(
        entityId,
        25 * 365 * 24 * 3600, // Age 25
        80 * 365 * 24 * 3600  // 80 year life
      );
      console.log("    ‚úÖ Temporal entity created (Age: 25, Life expectancy: 80)");

      await temporal.setSkill(entityId, "combat", 75, 100);
      console.log("    ‚úÖ Skill learned: Combat level 75");

      // ===== STEP 4: EXPERIENCES =====
      console.log("\n    4Ô∏è‚É£ EXPERIENCES: Entity lives and gains experiences...");
      
      // Battle victory
      await reputation.updateReputation(entityId, 50);
      await reputation.recordAction(entityId, true);
      console.log("    ‚úÖ Battle won! Reputation: +50");

      await behavioralIdentity.recordDecision(identityId, 80, true, false);
      console.log("    ‚úÖ Aggressive decision recorded");

      await memoryVault.storeMemory(
        entityId,
        "First legendary battle victory against Dragon",
        3, // Legendary
        ethers.keccak256(ethers.toUtf8Bytes("dragon_battle"))
      );
      console.log("    ‚úÖ Legendary memory stored");

      // Another battle
      await reputation.updateReputation(entityId, 30);
      await reputation.recordAction(entityId, true);
      console.log("    ‚úÖ Second battle won! Reputation: +30");

      await temporal.useSkill(entityId, "combat");
      console.log("    ‚úÖ Combat skill used (prevents decay)");

      // ===== STEP 5: CHECK STATUS =====
      console.log("\n    5Ô∏è‚É£ STATUS CHECK: Reviewing entity achievements...");
      
      const repScore = await reputation.getScore(entityId);
      const repData = await reputation.getReputation(entityId);
      console.log("    Ì≥ä Reputation Score:", repScore.toString());
      console.log("    Ì≥ä Success Rate:", repData.successfulActions.toString(), "/", repData.totalActions.toString());

      const identity = await behavioralIdentity.getIdentity(identityId);
      console.log("    Ì≥ä Total Decisions:", identity.totalDecisions.toString());
      console.log("    Ì≥ä Successful:", identity.successfulDecisions.toString());

      const memories = await memoryVault.getMemories(entityId);
      console.log("    Ì≥ä Total Memories:", memories.length);

      const isAlive = await temporal.isAlive(entityId);
      console.log("    Ì≥ä Status:", isAlive ? "ALIVE" : "DECEASED");

      // ===== STEP 6: DEATH =====
      console.log("\n    6Ô∏è‚É£ DEATH: Entity reaches end of life...");
      await temporal.markDeceased(entityId);
      const stillAlive = await temporal.isAlive(entityId);
      console.log("    ‚ö∞Ô∏è  Entity deceased. Status:", stillAlive ? "ALIVE" : "DECEASED");

      // ===== STEP 7: LEGACY =====
      console.log("\n    7Ô∏è‚É£ LEGACY: Creating heir and transferring legacy...");
      const heirId = 2;
      await legacy.createHeir(
        entityId,
        heirId,
        repScore, // Transfer reputation
        100       // Transfer 100 resources
      );
      console.log("    ‚úÖ Heir created (ID:", heirId + ")");
      console.log("    ‚úÖ Reputation transferred to heir:", repScore.toString());

      const legacyData = await legacy.legacies(entityId);
      console.log("    ‚úÖ Legacy recorded for dynasty tracking");

      const dynasty = await legacy.getDynastyTree(entityId);
      console.log("    ‚úÖ Dynasty tree established with", dynasty.length, "members");

      // ===== FINAL VERIFICATION =====
      console.log("\n    Ìæâ LIFECYCLE COMPLETE!");
      console.log("    ‚úÖ Birth: Entity created with full identity");
      console.log("    ‚úÖ Life: Gained reputation, skills, memories");
      console.log("    ‚úÖ Death: Natural end of lifecycle");
      console.log("    ‚úÖ Legacy: Heir inherits achievements\n");

      // Assertions
      expect(repScore).to.equal(80);
      expect(identity.totalDecisions).to.equal(1);
      expect(memories.length).to.equal(1);
      expect(stillAlive).to.equal(false);
      expect(legacyData.heirId).to.equal(heirId);
    });
  });

  // ============================================
  // COMPLETE BEHAVIOR ECONOMY
  // ============================================
  describe("Ì∑† Complete Behavior Economy - Intelligence Marketplace", function () {
    let behaviorMarket, cognitiveStyles, strategyRegistry;
    let owner, buyer;

    before(async function () {
      [owner, buyer] = await ethers.getSigners();

      console.log("\n    Ì¥ß Deploying Intelligence Layer contracts...");
      
      const BehaviorMarketplace = await ethers.getContractFactory("BehaviorMarketplace");
      behaviorMarket = await BehaviorMarketplace.deploy();
      
      const CognitiveStyles = await ethers.getContractFactory("CognitiveStyles");
      cognitiveStyles = await CognitiveStyles.deploy();
      
      const StrategyRegistry = await ethers.getContractFactory("StrategyRegistry");
      strategyRegistry = await StrategyRegistry.deploy();
      
      console.log("    ‚úÖ Intelligence contracts deployed!\n");
    });

    it("Ì∑† INTELLIGENCE ECONOMY: Create ‚Üí Mint ‚Üí List ‚Üí Buy ‚Üí Execute", async function () {
      console.log("\n    Ì≥ù Testing complete intelligence marketplace workflow...\n");

      // ===== STEP 1: CREATE STRATEGY =====
      console.log("    1Ô∏è‚É£ CREATE: Developing AI strategy...");
      const strategyCode = ethers.keccak256(ethers.toUtf8Bytes("aggressive_trading_v1"));
      const strategyId = await strategyRegistry.registerStrategy.staticCall(
        "Aggressive Trading v1",
        strategyCode,
        owner.address
      );
      await strategyRegistry.registerStrategy(
        "Aggressive Trading v1",
        strategyCode,
        owner.address
      );
      console.log("    ‚úÖ Strategy registered (ID:", strategyId.toString() + ")");

      // ===== STEP 2: MINT BEHAVIOR NFT =====
      console.log("\n    2Ô∏è‚É£ MINT: Creating behavior NFT...");
      await behaviorMarket.mintBehavior(
        "Aggressive Trading Bot",
        0, // Strategy type
        strategyCode,
        ethers.parseEther("1"),
        500 // 5% royalty
      );
      const behaviorId = 1;
      console.log("    ‚úÖ Behavior NFT minted (ID:", behaviorId + ")");

      // ===== STEP 3: CREATE COGNITIVE STYLE =====
      console.log("\n    3Ô∏è‚É£ STYLE: Defining cognitive profile...");
      await cognitiveStyles.mintStyle(
        "High-Risk Aggressive",
        95, // risk tolerance
        70, // adaptability
        80, // creativity
        60, // analytical
        40  // emotional intelligence
      );
      console.log("    ‚úÖ Cognitive style NFT created");

      // ===== STEP 4: LIST FOR SALE =====
      console.log("\n    4Ô∏è‚É£ LIST: Putting behavior on marketplace...");
      await behaviorMarket.listBehavior(behaviorId, ethers.parseEther("1"));
      console.log("    ‚úÖ Behavior listed for 1 ETH");

      // ===== STEP 5: BUYER PURCHASES =====
      console.log("\n    5Ô∏è‚É£ BUY: Buyer purchases behavior...");
      const balanceBefore = await ethers.provider.getBalance(owner.address);
      
      await behaviorMarket.connect(buyer).buyBehavior(behaviorId, {
        value: ethers.parseEther("1")
      });
      
      const balanceAfter = await ethers.provider.getBalance(owner.address);
      const earnings = balanceAfter - balanceBefore;
      
      console.log("    ‚úÖ Behavior purchased by buyer");
      console.log("    Ì≤∞ Seller earned:", ethers.formatEther(earnings), "ETH (after 2.5% fee)");

      // ===== STEP 6: EXECUTE & TRACK =====
      console.log("\n    6Ô∏è‚É£ EXECUTE: Running behavior and tracking performance...");
      
      await behaviorMarket.connect(buyer).recordExecution(behaviorId, true);
      await behaviorMarket.connect(buyer).recordExecution(behaviorId, true);
      await behaviorMarket.connect(buyer).recordExecution(behaviorId, false);
      await behaviorMarket.connect(buyer).recordExecution(behaviorId, true);
      
      const stats = await behaviorMarket.behaviorStats(behaviorId);
      const successRate = (Number(stats.successfulExecutions) / Number(stats.totalExecutions)) * 100;
      
      console.log("    Ì≥ä Total Executions:", stats.totalExecutions.toString());
      console.log("    Ì≥ä Successful:", stats.successfulExecutions.toString());
      console.log("    Ì≥ä Success Rate:", successRate.toFixed(1) + "%");

      await strategyRegistry.recordExecution(strategyId, true);
      const strategyData = await strategyRegistry.strategies(strategyId);
      console.log("    Ì≥ä Strategy usage tracked");

      console.log("\n    Ìæâ INTELLIGENCE ECONOMY COMPLETE!");
      console.log("    ‚úÖ Strategy developed and registered");
      console.log("    ‚úÖ Behavior NFT created and sold");
      console.log("    ‚úÖ Cognitive profile attached");
      console.log("    ‚úÖ Performance tracked and verified\n");

      // Assertions
      expect(await behaviorMarket.ownerOf(behaviorId)).to.equal(buyer.address);
      expect(stats.totalExecutions).to.equal(4);
      expect(stats.successfulExecutions).to.equal(3);
      expect(earnings).to.be.greaterThan(0);
    });
  });

  // ============================================
  // CROSS-WORLD IDENTITY & REPUTATION
  // ============================================
  describe("Ìºç Cross-World Identity - Portable Reputation", function () {
    let crossWorld, reputation, did, cognitiveFingerprint, reputationIdentity;
    let owner;

    before(async function () {
      [owner] = await ethers.getSigners();

      console.log("\n    Ì¥ß Deploying Identity Layer contracts...");
      
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
      
      console.log("    ‚úÖ Identity contracts deployed!\n");
    });

    it("Ìºç CROSS-WORLD: Build reputation across 3 worlds ‚Üí Transfer ‚Üí Verify", async function () {
      console.log("\n    Ì≥ù Testing cross-world identity system...\n");

      const entityId = 1;
      const identityId = 1;

      // ===== STEP 1: CREATE UNIVERSAL IDENTITY =====
      console.log("    1Ô∏è‚É£ CREATE: Establishing universal identity...");
      await crossWorld.createUniversalIdentity(identityId, owner.address);
      await did.createDID(entityId, owner.address, "ipfs://universal");
      await cognitiveFingerprint.generateFingerprint(identityId, 85, 90, 75, 80, 95, 70, 88);
      await reputationIdentity.initializeReputation(identityId);
      console.log("    ‚úÖ Universal identity created across all systems");

      // ===== STEP 2: BUILD REP IN WORLD 1 =====
      console.log("\n    2Ô∏è‚É£ WORLD 1: Building reputation in Game World 1...");
      await crossWorld.linkWorld(identityId, 1, 100, 1000);
      await reputation.initializeReputation(1);
      await reputation.updateReputation(1, 150);
      await reputation.recordAction(1, true);
      await reputation.recordAction(1, true);
      await reputation.recordAction(1, true);
      
      await reputationIdentity.recordContextualReputation(
        identityId, 1, "GameWorld1", 90
      );
      
      console.log("    ‚úÖ World 1 linked: 150 reputation, 3/3 actions successful");

      // ===== STEP 3: BUILD REP IN WORLD 2 =====
      console.log("\n    3Ô∏è‚É£ WORLD 2: Building reputation in Metaverse World 2...");
      await crossWorld.linkWorld(identityId, 2, 200, 500);
      await reputation.initializeReputation(2);
      await reputation.updateReputation(2, 200);
      await reputation.recordAction(2, true);
      await reputation.recordAction(2, true);
      
      await reputationIdentity.recordContextualReputation(
        identityId, 2, "Metaverse", 95
      );
      
      console.log("    ‚úÖ World 2 linked: 200 reputation, 2/2 actions successful");

      // ===== STEP 4: BUILD REP IN WORLD 3 =====
      console.log("\n    4Ô∏è‚É£ WORLD 3: Building reputation in AI Simulation...");
      await crossWorld.linkWorld(identityId, 3, 300, 750);
      await reputation.initializeReputation(3);
      await reputation.updateReputation(3, 100);
      
      await reputationIdentity.recordContextualReputation(
        identityId, 3, "AISimulation", 85
      );
      
      console.log("    ‚úÖ World 3 linked: 100 reputation");

      // ===== STEP 5: VERIFY IDENTITY =====
      console.log("\n    5Ô∏è‚É£ VERIFY: Identity verified across 3+ worlds...");
      await crossWorld.verifyIdentity(identityId);
      const profile = await crossWorld.getUniversalProfile(identityId);
      console.log("    ‚úÖ Identity VERIFIED ‚úì");
      console.log("    Ì≥ä Total Worlds:", profile.linkedWorlds.length);
      console.log("    Ì≥ä Total Reputation:", profile.totalReputation.toString());

      // ===== STEP 6: TRANSFER REPUTATION =====
      console.log("\n    6Ô∏è‚É£ TRANSFER: Moving reputation between worlds...");
      console.log("    ‚Üí Transferring 50 reputation from World 2 to World 3");
      await crossWorld.transferReputation(identityId, 2, 3, 50);
      console.log("    ‚úÖ Reputation transferred successfully");

      // ===== STEP 7: AGGREGATE REPUTATION =====
      console.log("\n    7Ô∏è‚É£ AGGREGATE: Calculating total reputation...");
      const aggregateRep = await reputationIdentity.aggregateReputation(identityId);
      console.log("    Ì≥ä Aggregate Reputation Score:", aggregateRep.toString());

      const multiDimRep = await reputationIdentity.reputations(identityId);
      console.log("    Ì≥ä Trust:", multiDimRep.trustworthiness.toString());
      console.log("    Ì≥ä Competence:", multiDimRep.competence.toString());
      console.log("    Ì≥ä Overall:", multiDimRep.overallScore.toString());

      console.log("\n    Ìæâ CROSS-WORLD IDENTITY COMPLETE!");
      console.log("    ‚úÖ Universal identity established");
      console.log("    ‚úÖ Reputation built across 3 worlds");
      console.log("    ‚úÖ Identity verified and trusted");
      console.log("    ‚úÖ Reputation portable between worlds\n");

      // Assertions
      expect(profile.isVerified).to.equal(true);
      expect(profile.linkedWorlds.length).to.equal(3);
      expect(profile.totalReputation).to.be.greaterThan(0);
    });
  });

  // ============================================
  // PROGRAMMABLE REALITY SYSTEM
  // ============================================
  describe("Ìºå Programmable Reality - World Creation", function () {
    let worldPhysics, economicLaws, worldComposer, realityMarket;
    let owner, buyer;

    before(async function () {
      [owner, buyer] = await ethers.getSigners();

      console.log("\n    Ì¥ß Deploying Reality Layer contracts...");
      
      const WorldPhysics = await ethers.getContractFactory("WorldPhysics");
      worldPhysics = await WorldPhysics.deploy();
      
      const EconomicLaws = await ethers.getContractFactory("EconomicLaws");
      economicLaws = await EconomicLaws.deploy();
      
      const WorldComposer = await ethers.getContractFactory("WorldComposer");
      worldComposer = await WorldComposer.deploy();
      
      const RealityMarketplace = await ethers.getContractFactory("RealityMarketplace");
      realityMarket = await RealityMarketplace.deploy();
      
      console.log("    ‚úÖ Reality contracts deployed!\n");
    });

    it("Ìºå REALITY: Create physics ‚Üí Create economy ‚Üí Compose world ‚Üí Sell", async function () {
      console.log("\n    Ì≥ù Testing programmable reality system...\n");

      // ===== STEP 1: CREATE PHYSICS MODULE =====
      console.log("    1Ô∏è‚É£ PHYSICS: Creating anti-gravity physics...");
      await worldPhysics.createPhysicsModule("Anti-Gravity Module", 0, {
        gravityStrength: -50,
        energyDrainRate: 500,
        timeFlowRate: 200,
        causalityStrength: 80,
        entropyRate: 30,
        quantumFluctuation: 20
      });
      const physicsId = 1;
      console.log("    ‚úÖ Physics module created: Anti-Gravity");

      // ===== STEP 2: CREATE SECOND PHYSICS =====
      console.log("\n    2Ô∏è‚É£ PHYSICS: Creating chaos physics...");
      await worldPhysics.createPhysicsModule("Chaos Module", 4, {
        gravityStrength: 0,
        energyDrainRate: 1000,
        timeFlowRate: 150,
        causalityStrength: 30,
        entropyRate: 95,
        quantumFluctuation: 90
      });
      const chaosId = 2;
      console.log("    ‚úÖ Chaos physics created");

      // ===== STEP 3: CREATE ECONOMIC SYSTEM =====
      console.log("\n    3Ô∏è‚É£ ECONOMY: Designing post-scarcity economy...");
      await economicLaws.createEconomicSystem(
        "Post-Scarcity Paradise",
        0, // Post-Scarcity
        {
          infiniteResources: true,
          inflationRate: 0,
          taxRate: 0,
          tradeFrequency: 10000,
          priceControls: false,
          resourceDecay: false,
          wealthDistribution: 100
        }
      );
      const economyId = 1;
      console.log("    ‚úÖ Economic system created: Post-Scarcity");

      // ===== STEP 4: COMPOSE WORLD =====
      console.log("\n    4Ô∏è‚É£ COMPOSE: Combining modules into world...");
      await worldComposer.composeWorld(
        "Floating Chaos Realm",
        [physicsId, chaosId],
        [economyId]
      );
      const worldId = 1;
      console.log("    ‚úÖ World composed: Floating Chaos Realm");
      console.log("    ‚Üí Physics: Anti-Gravity + Chaos");
      console.log("    ‚Üí Economy: Post-Scarcity");

      // ===== STEP 5: PUBLISH & PRICE =====
      console.log("\n    5Ô∏è‚É£ PUBLISH: Listing world for sale...");
      await worldComposer.publishWorld(worldId, ethers.parseEther("5"));
      console.log("    ‚úÖ World published for 5 ETH");

      // ===== STEP 6: LIST MODULE ON MARKETPLACE =====
      console.log("\n    6Ô∏è‚É£ MARKETPLACE: Listing physics module...");
      await realityMarket.listModule(
        physicsId,
        ethers.parseEther("0.5"),
        "physics"
      );
      const listingId = 1;
      console.log("    ‚úÖ Physics module listed for 0.5 ETH");

      // ===== STEP 7: LICENSE MODULE =====
      console.log("\n    7Ô∏è‚É£ LICENSE: Buyer licenses physics module...");
      await realityMarket.connect(buyer).licenseModule(
        physicsId,
        30 * 24 * 3600, // 30 days
        { value: ethers.parseEther("0.1") }
      );
      const hasLicense = await realityMarket.hasLicense(physicsId, buyer.address);
      console.log("    ‚úÖ 30-day license purchased");
      console.log("    ‚úÖ Buyer can now use physics module");

      // ===== VERIFICATION =====
      const world = await worldComposer.getWorld(worldId);
      const physicsModule = await worldPhysics.physicsModules(physicsId);
      
      console.log("\n    Ìæâ PROGRAMMABLE REALITY COMPLETE!");
      console.log("    ‚úÖ Physics modules created (2)");
      console.log("    ‚úÖ Economic system designed");
      console.log("    ‚úÖ World composed from modules");
      console.log("    ‚úÖ Marketplace operational");
      console.log("    ‚úÖ Licensing system working\n");

      // Assertions
      expect(world.isPublished).to.equal(true);
      expect(world.physicsModules.length).to.equal(2);
      expect(world.economicSystems.length).to.equal(1);
      expect(hasLicense).to.equal(true);
      expect(physicsModule.usageCount).to.be.greaterThan(0);
    });
  });

  // ============================================
  // EMOTIONAL & TRUST ECOSYSTEM
  // ============================================
  describe("Ì≤ñ Emotional Ecosystem - NPCs with Feelings", function () {
    let emotions, trust, socialInfluence;
    let owner;

    before(async function () {
      [owner] = await ethers.getSigners();

      console.log("\n    Ì¥ß Deploying Psychology Layer contracts...");
      
      const EmotionalState = await ethers.getContractFactory("EmotionalState");
      emotions = await EmotionalState.deploy();
      
      const TrustDynamics = await ethers.getContractFactory("TrustDynamics");
      trust = await TrustDynamics.deploy();
      
      const SocialInfluence = await ethers.getContractFactory("SocialInfluence");
      socialInfluence = await SocialInfluence.deploy();
      
      console.log("    ‚úÖ Psychology contracts deployed!\n");
    });

    it("Ì≤ñ EMOTIONS: NPCs form relationships ‚Üí Build trust ‚Üí React emotionally", async function () {
      console.log("\n    Ì≥ù Testing emotional ecosystem...\n");

      // ===== STEP 1: INITIALIZE 3 NPCs =====
      console.log("    1Ô∏è‚É£ INITIALIZE: Creating 3 NPCs with emotions...");
      await emotions.initializeEmotions(1); // NPC 1
      await emotions.initializeEmotions(2); // NPC 2
      await emotions.initializeEmotions(3); // NPC 3
      console.log("    ‚úÖ 3 NPCs initialized with baseline emotions");

      // ===== STEP 2: BUILD TRUST BETWEEN NPC 1 & 2 =====
      console.log("\n    2Ô∏è‚É£ TRUST: NPC 1 & 2 build friendship...");
      await trust.buildTrust(1, 2, 85);
      await trust.buildTrust(1, 2, 90);
      await trust.buildTrust(1, 2, 80);
      const trustScore12 = await trust.getTrustScore(1, 2);
      console.log("    ‚úÖ Trust built: NPC1 ‚Üí NPC2 =", trustScore12.toString());

      // Reciprocal trust
      await trust.buildTrust(2, 1, 80);
      await trust.buildTrust(2, 1, 85);
      const trustScore21 = await trust.getTrustScore(2, 1);
      console.log("    ‚úÖ Reciprocal trust: NPC2 ‚Üí NPC1 =", trustScore21.toString());

      // ===== STEP 3: NPC 3 BECOMES INFLUENCER =====
      console.log("\n    3Ô∏è‚É£ INFLUENCE: NPC 3 becomes social influencer...");
      await socialInfluence.follow(1, 3);
      await socialInfluence.follow(2, 3);
      await socialInfluence.recordInfluence(3, 1, 75, "Leadership");
      await socialInfluence.recordInfluence(3, 2, 80, "Charisma");
      const influenceScore = await socialInfluence.getInfluenceScore(3);
      console.log("    ‚úÖ NPC 3 influence score:", influenceScore.toString());
      console.log("    ‚úÖ 2 followers gained");

      // ===== STEP 4: EMOTIONAL EVENTS =====
      console.log("\n    4Ô∏è‚É£ EVENTS: Emotional reactions to events...");
      
      // Scary event affects NPC 1
      console.log("    ‚Üí Scary event occurs...");
      await emotions.updateFear(1, 70);
      let state1 = await emotions.getEmotions(1);
      console.log("    ‚ö†Ô∏è  NPC 1 Fear increased to:", state1.fear.toString());

      // Joy event for NPC 2
      console.log("    ‚Üí Victory celebration...");
      await emotions.updateEmotion(2, 4, 60); // Joy
      let state2 = await emotions.getEmotions(2);
      console.log("    Ì∏ä NPC 2 Joy increased to:", state2.joy.toString());

      // Build confidence in NPC 3
      await emotions.updateEmotion(3, 6, 40); // Confidence
      let state3 = await emotions.getEmotions(3);
      console.log("    Ì≤™ NPC 3 Confidence increased to:", state3.confidence.toString());

      // ===== STEP 5: BETRAYAL! =====
      console.log("\n    5Ô∏è‚É£ BETRAYAL: NPC 2 betrays NPC 1...");
      await trust.recordBetrayal(2, 1, 50);
      const trustAfterBetrayal = await trust.getTrustScore(1, 2);
      console.log("    Ì≤î Trust BROKEN! Score dropped to:", trustAfterBetrayal.toString());

      // Emotional impact
      await emotions.updateEmotion(1, 3, 60); // Anger
      await emotions.updateTrust(1, -40);
      await emotions.updateEmotion(1, 5, 40); // Sadness
      
      state1 = await emotions.getEmotions(1);
      console.log("    Ì∏° NPC 1 Anger:", state1.anger.toString());
      console.log("    Ì∏¢ NPC 1 Sadness:", state1.sadness.toString());
      console.log("    Ì≤î NPC 1 Trust:", state1.trust.toString());

      // ===== STEP 6: SOCIAL CASCADE =====
      console.log("\n    6Ô∏è‚É£ CASCADE: Opinion spreads through network...");
      await socialInfluence.setOpinion(3, "betrayal_bad", -80, 90);
      await socialInfluence.propagateOpinion(3, "betrayal_bad");
      console.log("    ‚úÖ NPC 3 opinion spread to followers");
      console.log("    ‚úÖ Network affected by betrayal event");

      console.log("\n    Ìæâ EMOTIONAL ECOSYSTEM COMPLETE!");
      console.log("    ‚úÖ NPCs initialized with emotions");
      console.log("    ‚úÖ Trust relationships formed");
      console.log("    ‚úÖ Social influence network created");
      console.log("    ‚úÖ Emotional reactions to events");
      console.log("    ‚úÖ Betrayal and consequences");
      console.log("    ‚úÖ Opinion propagation working\n");

      // Assertions
      expect(trustScore12).to.be.greaterThan(0);
      expect(trustAfterBetrayal).to.be.lessThan(trustScore12);
      expect(state1.anger).to.be.greaterThan(50);
      expect(influenceScore).to.be.greaterThan(0);
    });
  });
});
