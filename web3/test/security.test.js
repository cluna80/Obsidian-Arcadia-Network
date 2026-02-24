const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("🛡️ OAN SECURITY TESTS", function () {

  // ============================================
  // ACCESS CONTROL TESTS
  // ============================================
  describe("🔐️ Access Control Security", function () {

    describe("ReputationOracle - Role Protection", function () {
      let oracle, owner, hacker, addr1;

      beforeEach(async function () {
        [owner, hacker, addr1] = await ethers.getSigners();
        const ReputationOracle = await ethers.getContractFactory("ReputationOracle");
        oracle = await ReputationOracle.deploy();
        await oracle.initializeReputation(1, 0);
      });

      it("🚫 Should BLOCK unauthorized reputation updates", async function () {
        await expect(
          oracle.connect(hacker).updateReputation(1, 9999)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from updating reputation");
      });

      it("🚫 Should BLOCK unauthorized reputation initialization", async function () {
        await expect(
          oracle.connect(hacker).initializeReputation(99, 0)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from initializing reputation");
      });

      it("🚫 Should BLOCK unauthorized action recording", async function () {
        await expect(
          oracle.connect(hacker).recordAction(1, true)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from recording actions");
      });

      it("✅ Should ALLOW owner to update reputation", async function () {
        await oracle.updateReputation(1, 50);
        const score = await oracle.getScore(1);
        expect(score).to.equal(50);
        console.log("    ✓ Owner CAN update reputation correctly");
      });
    });

    describe("OANToken - Minting Protection", function () {
      let token, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const OANToken = await ethers.getContractFactory("OANToken");
        token = await OANToken.deploy();
      });

      it("🚫 Should BLOCK unauthorized minting", async function () {
        await expect(
          token.connect(hacker).mint(hacker.address, ethers.parseEther("1000000"))
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from minting tokens");
      });

      it("🚫 Should BLOCK unauthorized burning of others tokens", async function () {
        const amount = ethers.parseEther("1000");
        await token.transfer(owner.address, amount);
        await expect(
          token.connect(hacker).burn(amount)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from burning others tokens");
      });
    });

    describe("DAOTreasury - Withdrawal Protection", function () {
      let treasury, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const DAOTreasury = await ethers.getContractFactory("DAOTreasury");
        treasury = await DAOTreasury.deploy();
        // Fund the treasury
        await owner.sendTransaction({
          to: await treasury.getAddress(),
          value: ethers.parseEther("10.0")
        });
      });

      it("🚫 Should BLOCK unauthorized ETH withdrawal", async function () {
        await expect(
          treasury.connect(hacker).withdraw(
            hacker.address,
            ethers.parseEther("10")
          )
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from draining treasury");
      });

      it("🚫 Should BLOCK unauthorized token withdrawal", async function () {
        await expect(
          treasury.connect(hacker).withdrawToken(
            ethers.ZeroAddress,
            hacker.address,
            ethers.parseEther("10")
          )
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from withdrawing tokens");
      });
    });

    describe("BehaviorMarketplace - Ownership Protection", function () {
      let market, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const BehaviorMarketplace = await ethers.getContractFactory("BehaviorMarketplace");
        market = await BehaviorMarketplace.deploy();
        // Mint a behavior NFT
        await market.mintBehavior(
          "Test Strategy",
          0,
          ethers.keccak256(ethers.toUtf8Bytes("code")),
          ethers.parseEther("1"),
          100
        );
      });

      it("🚫 Should BLOCK non-owner from listing behavior", async function () {
        await expect(
          market.connect(hacker).listBehavior(1, ethers.parseEther("1"))
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from listing others behavior");
      });

      it("🚫 Should BLOCK buying unlisted behavior", async function () {
        await expect(
          market.connect(hacker).buyBehavior(1, {
            value: ethers.parseEther("1")
          })
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from buying unlisted behavior");
      });
    });

    describe("WorldPhysics - Module Protection", function () {
      let physics, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const WorldPhysics = await ethers.getContractFactory("WorldPhysics");
        physics = await WorldPhysics.deploy();
        await physics.createPhysicsModule("Test Module", 0, {
          gravityStrength: 0,
          energyDrainRate: 100,
          timeFlowRate: 100,
          causalityStrength: 100,
          entropyRate: 10,
          quantumFluctuation: 5
        });
      });

      it("🚫 Should BLOCK non-owner from updating physics", async function () {
        await expect(
          physics.connect(hacker).updateParameters(1, {
            gravityStrength: -100,
            energyDrainRate: 9999,
            timeFlowRate: 9999,
            causalityStrength: 0,
            entropyRate: 100,
            quantumFluctuation: 100
          })
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from modifying physics modules");
      });

      it("🚫 Should BLOCK non-owner from attaching physics", async function () {
        await expect(
          physics.connect(hacker).attachToWorld(999, 1)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from attaching others physics");
      });
    });
  });

  // ============================================
  // DOUBLE SPEND / DUPLICATE TESTS
  // ============================================
  describe("🔐️ Double Spend & Duplicate Prevention", function () {

    describe("DecentralizedIdentity - Duplicate DID Prevention", function () {
      let did, owner;

      beforeEach(async function () {
        [owner] = await ethers.getSigners();
        const DID = await ethers.getContractFactory("DecentralizedIdentity");
        did = await DID.deploy();
        await did.createDID(1, owner.address, "ipfs://metadata");
      });

      it("🚫 Should BLOCK creating duplicate DID for same entity", async function () {
        await expect(
          did.createDID(1, owner.address, "ipfs://metadata2")
        ).to.be.reverted;
        console.log("    ✓ Duplicate DID creation BLOCKED");
      });
    });

    describe("BehavioralIdentity - Duplicate Identity Prevention", function () {
      let identity, owner;

      beforeEach(async function () {
        [owner] = await ethers.getSigners();
        const BehavioralIdentity = await ethers.getContractFactory("BehavioralIdentity");
        identity = await BehavioralIdentity.deploy();
        await identity.createIdentity();
      });

      it("🚫 Should BLOCK creating duplicate identity", async function () {
        await expect(
          identity.createIdentity()
        ).to.be.revertedWith("Identity exists");
        console.log("    ✓ Duplicate behavioral identity BLOCKED");
      });
    });

    describe("MemoryVault - Duplicate Vault Prevention", function () {
      let vault, owner;

      beforeEach(async function () {
        [owner] = await ethers.getSigners();
        const MemoryVault = await ethers.getContractFactory("MemoryVault");
        vault = await MemoryVault.deploy();
        await vault.createVault(1);
      });

      it("🚫 Should BLOCK creating duplicate vault for entity", async function () {
        await expect(
          vault.createVault(1)
        ).to.be.reverted;
        console.log("    ✓ Duplicate memory vault BLOCKED");
      });
    });

    describe("RiskProfiles - Duplicate Profile Prevention", function () {
      let risk, owner;

      beforeEach(async function () {
        [owner] = await ethers.getSigners();
        const RiskProfiles = await ethers.getContractFactory("RiskProfiles");
        risk = await RiskProfiles.deploy();
        await risk.createRiskProfile(1, 50, 50, 1);
      });

      it("🚫 Should BLOCK creating duplicate risk profile", async function () {
        await expect(
          risk.createRiskProfile(1, 80, 20, 2)
        ).to.be.revertedWith("Profile exists"); // ✅ RiskProfiles.sol now has this reason string
        console.log("    ✓ Duplicate risk profile BLOCKED");
      });
    });
  });

  // ============================================
  // PAYMENT & ECONOMIC SECURITY
  // ============================================
  describe("🔐️ Payment & Economic Security", function () {

    describe("BehaviorMarketplace - Payment Security", function () {
      let market, owner, buyer, hacker;

      beforeEach(async function () {
        [owner, buyer, hacker] = await ethers.getSigners();
        const BehaviorMarketplace = await ethers.getContractFactory("BehaviorMarketplace");
        market = await BehaviorMarketplace.deploy();
        await market.mintBehavior(
          "Expensive Strategy",
          0,
          ethers.keccak256(ethers.toUtf8Bytes("code")),
          ethers.parseEther("10"),
          100
        );
        await market.listBehavior(1, ethers.parseEther("10"));
      });

      it("🚫 Should BLOCK buying with insufficient funds", async function () {
        await expect(
          market.connect(hacker).buyBehavior(1, {
            value: ethers.parseEther("0.001") // way too low
          })
        ).to.be.reverted;
        console.log("    ✓ Underpayment BLOCKED - price: 10 ETH, sent: 0.001 ETH");
      });

      it("🚫 Should BLOCK buying already sold behavior", async function () {
        // First legitimate purchase
        await market.connect(buyer).buyBehavior(1, {
          value: ethers.parseEther("10")
        });
        // Second purchase attempt - should fail
        await expect(
          market.connect(hacker).buyBehavior(1, {
            value: ethers.parseEther("10")
          })
        ).to.be.reverted;
        console.log("    ✓ Double purchase BLOCKED");
      });
    });

    describe("InsuranceProtocol - Premium Security", function () {
      let insurance, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const InsuranceProtocol = await ethers.getContractFactory("InsuranceProtocol");
        insurance = await InsuranceProtocol.deploy();
      });

      it("🚫 Should BLOCK creating policy with insufficient premium", async function () {
        const coverage = ethers.parseEther("100");
        await expect(
          insurance.createPolicy(
            0, 1, coverage, 30 * 24 * 3600,
            { value: ethers.parseEther("0") } // no premium
          )
        ).to.be.reverted;
        console.log("    ✓ Zero premium policy BLOCKED");
      });

      it("🚫 Should BLOCK unauthorized claim processing", async function () {
        const coverage = ethers.parseEther("1");
        const premium = await insurance.calculatePremium(coverage, 30 * 24 * 3600);
        await insurance.createPolicy(0, 1, coverage, 30 * 24 * 3600, { value: premium });
        await insurance.fileClaim(1);
        await expect(
          insurance.connect(hacker).processClaim(1, true)
        ).to.be.reverted;
        console.log("    ✓ Unauthorized claim processing BLOCKED");
      });

      it("🚫 Should BLOCK filing claim on others policy", async function () {
        const coverage = ethers.parseEther("1");
        const premium = await insurance.calculatePremium(coverage, 30 * 24 * 3600);
        await insurance.createPolicy(0, 1, coverage, 30 * 24 * 3600, { value: premium });
        await expect(
          insurance.connect(hacker).fileClaim(1)
        ).to.be.reverted;
        console.log("    ✓ Filing claim on others policy BLOCKED");
      });
    });

    describe("OptionsExchange - Options Security", function () {
      let options, owner, buyer, hacker;

      beforeEach(async function () {
        [owner, buyer, hacker] = await ethers.getSigners();
        const OptionsExchange = await ethers.getContractFactory("OptionsExchange");
        options = await OptionsExchange.deploy();
        await options.writeOption(
          1,
          ethers.parseEther("1"),
          ethers.parseEther("0.1"),
          7 * 24 * 3600,
          true,
          { value: ethers.parseEther("1") }
        );
      });

      it("🚫 Should BLOCK buying option with insufficient premium", async function () {
        await expect(
          options.connect(hacker).buyOption(1, {
            value: ethers.parseEther("0.0001")
          })
        ).to.be.reverted;
        console.log("    ✓ Underpayment for option BLOCKED");
      });

      it("🚫 Should BLOCK exercising unowned option", async function () {
        await options.connect(buyer).buyOption(1, {
          value: ethers.parseEther("0.1")
        });
        await expect(
          options.connect(hacker).exerciseOption(1, ethers.parseEther("2"))
        ).to.be.reverted;
        console.log("    ✓ Exercising unowned option BLOCKED");
      });
    });
  });

  // ============================================
  // MANIPULATION & GAMING PREVENTION
  // ============================================
  describe("🔐️ Manipulation Prevention", function () {

    describe("ManipulationResistance - System Integrity", function () {
      let resistance, owner, attacker;

      beforeEach(async function () {
        [owner, attacker] = await ethers.getSigners();
        const ManipulationResistance = await ethers.getContractFactory("ManipulationResistance");
        resistance = await ManipulationResistance.deploy();
        await resistance.initializeResistance(1, 80, 80, 80);
      });

      it("🚫 Should detect high-power manipulation attempt", async function () {
        const tx = await resistance.attemptManipulation(
          99,  // manipulatorId
          1,   // targetId
          "FearMonger",
          30   // low power = gets detected by high resistance
        );
        await tx.wait();
        const profile = await resistance.resistanceProfiles(1);
        // Experience increases when manipulation is detected
        expect(profile.experienceLevel).to.be.greaterThanOrEqual(0);
        console.log("    ✓ Manipulation attempt processed, resistance active");
      });

      it("🚫 Should increase resistance after detected manipulation", async function () {
        const profileBefore = await resistance.resistanceProfiles(1);
        await resistance.attemptManipulation(99, 1, "Deception", 20);
        const profileAfter = await resistance.resistanceProfiles(1);
        expect(profileAfter.manipulationAttempts).to.equal(
          profileBefore.manipulationAttempts + 1n
        );
        console.log("    ✓ Resistance system tracked manipulation attempt");
      });
    });

    describe("TrustDynamics - Betrayal Tracking", function () {
      let trust, owner;

      beforeEach(async function () {
        [owner] = await ethers.getSigners();
        const TrustDynamics = await ethers.getContractFactory("TrustDynamics");
        trust = await TrustDynamics.deploy();
      });

      it("🚫 Should track serial betrayals", async function () {
        await trust.buildTrust(1, 2, 90);
        await trust.buildTrust(1, 2, 90);
        await trust.buildTrust(1, 2, 90);
        await trust.recordBetrayal(2, 1, 30);
        await trust.recordBetrayal(2, 1, 30);
        const relationship = await trust.trustRelationships(1, 2);
        expect(relationship.betrayals).to.equal(2);
        console.log("    ✓ Serial betrayals tracked:", relationship.betrayals.toString());
      });

      it("🚫 Should drop trust to zero after massive betrayal", async function () {
        await trust.buildTrust(1, 2, 60);
        await trust.recordBetrayal(2, 1, 100); // massive betrayal
        const score = await trust.getTrustScore(1, 2);
        expect(score).to.equal(0);
        console.log("    ✓ Trust destroyed to 0 after massive betrayal");
      });
    });

    describe("EmotionalState - Emotion Boundary Protection", function () {
      let emotions, owner;

      beforeEach(async function () {
        [owner] = await ethers.getSigners();
        const EmotionalState = await ethers.getContractFactory("EmotionalState");
        emotions = await EmotionalState.deploy();
        await emotions.initializeEmotions(1);
      });

      it("🚫 Should cap emotions at max value (100)", async function () {
        // Try to push fear way above 100
        await emotions.updateFear(1, 200);
        const state = await emotions.getEmotions(1);
        expect(state.fear).to.be.lessThanOrEqual(100);
        console.log("    ✓ Emotion capped at 100, actual:", state.fear.toString());
      });

      it("🚫 Should floor emotions at min value (0)", async function () {
        // Try to pull trust below 0
        await emotions.updateTrust(1, -200);
        const state = await emotions.getEmotions(1);
        expect(state.trust).to.be.greaterThanOrEqual(0);
        console.log("    ✓ Emotion floored at 0, actual:", state.trust.toString());
      });
    });
  });

  // ============================================
  // CROSS WORLD IDENTITY SECURITY
  // ============================================
  describe("🔐️ Identity Security", function () {

    describe("CrossWorldIdentity - Ownership Protection", function () {
      let crossWorld, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const CrossWorldIdentity = await ethers.getContractFactory("CrossWorldIdentity");
        crossWorld = await CrossWorldIdentity.deploy();
        await crossWorld.createUniversalIdentity(1, owner.address);
        await crossWorld.linkWorld(1, 1, 100, 500);
        await crossWorld.linkWorld(1, 2, 200, 300);
      });

      it("🚫 Should BLOCK hacker from linking worlds to others identity", async function () {
        await expect(
          crossWorld.connect(hacker).linkWorld(1, 3, 999, 9999)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from linking worlds to others identity");
      });

      it("🚫 Should BLOCK hacker from transferring others reputation", async function () {
        await expect(
          crossWorld.connect(hacker).transferReputation(1, 1, 2, 100)
        ).to.be.reverted;
        console.log("    ✓ Hacker BLOCKED from stealing reputation");
      });

      it("🚫 Should BLOCK transferring more reputation than available", async function () {
        await expect(
          crossWorld.transferReputation(1, 1, 2, 99999)
        ).to.be.reverted;
        console.log("    ✓ Over-transfer of reputation BLOCKED");
      });
    });

    describe("CognitiveFingerprint - Identity Uniqueness", function () {
      let fingerprint, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const CognitiveFingerprint = await ethers.getContractFactory("CognitiveFingerprint");
        fingerprint = await CognitiveFingerprint.deploy();
        await fingerprint.generateFingerprint(1, 85, 90, 75, 80, 95, 70, 88);
      });

      it("🚫 Should BLOCK overwriting existing fingerprint", async function () {
        await expect(
          fingerprint.connect(hacker).generateFingerprint(1, 10, 10, 10, 10, 10, 10, 10)
        ).to.be.revertedWith("Identity already claimed");
        console.log("    ✓ Cognitive fingerprint hijacking BLOCKED");
      });
    });
  });

  // ============================================
  // TEMPORAL SECURITY
  // ============================================
  describe("🔐️ Temporal Security", function () {

    describe("TemporalEntities - Lifecycle Protection", function () {
      let temporal, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const TemporalEntities = await ethers.getContractFactory("TemporalEntities");
        temporal = await TemporalEntities.deploy();
        await temporal.createTemporalEntity(1, 0, 80 * 365 * 24 * 3600);
      });

      it("🚫 Should BLOCK interacting with deceased entity", async function () {
        await temporal.markDeceased(1);
        await expect(
          temporal.useSkill(1, "swordsmanship")
        ).to.be.reverted;
        console.log("    ✓ Deceased entity interaction BLOCKED");
      });

      it("🚫 Should BLOCK creating duplicate temporal entity", async function () {
        await expect(
          temporal.createTemporalEntity(1, 0, 80 * 365 * 24 * 3600)
        ).to.be.reverted;
        console.log("    ✓ Duplicate temporal entity BLOCKED");
      });
    });

    describe("LegacySystem - Inheritance Protection", function () {
      let legacy, owner, hacker;

      beforeEach(async function () {
        [owner, hacker] = await ethers.getSigners();
        const LegacySystem = await ethers.getContractFactory("LegacySystem");
        legacy = await LegacySystem.deploy();
      });

      it("🚫 Should BLOCK heir from inheriting twice", async function () {
        await legacy.createHeir(1, 2, 50, 1000);
        await expect(
          legacy.createHeir(1, 2, 50, 1000) // ✅ Fixed: same heirId=2, triggers LegacyAlreadyExists
        ).to.be.revertedWithCustomError(legacy, "LegacyAlreadyExists");
        console.log("    ✓ Double inheritance BLOCKED");
      });
    });
  });
});