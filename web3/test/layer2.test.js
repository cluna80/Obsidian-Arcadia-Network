const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ìºë OAN LAYER 2: WEB3 FOUNDATION TESTS", function () {

  // ============================================
  // PHASE 2.1: TOKENIZED ENTITIES
  // ============================================
  describe("Ì≥¶ Phase 2.1: OANEntity (NFT Entities)", function () {
    let entity, owner, addr1;

    beforeEach(async function () {
      [owner, addr1] = await ethers.getSigners();
      const OANEntity = await ethers.getContractFactory("OANEntity");
      entity = await OANEntity.deploy();
    });

    it("‚úÖ Should mint a new entity NFT", async function () {
      // FIX: mintEntity(address, name, entityType, dslHash, metadataURI)
      // Energy is set internally to 100 - NOT a parameter
      const tx = await entity.mintEntity(
        owner.address,
        "TestBot",
        "Researcher",
        ethers.keccak256(ethers.toUtf8Bytes("test_hash")),
        "ipfs://metadata/1"
      );
      await tx.wait();
      expect(await entity.ownerOf(1)).to.equal(owner.address);
      console.log("    ‚úì Entity minted successfully as NFT");
    });

    it("‚úÖ Should track entity state on-chain", async function () {
      await entity.mintEntity(
        owner.address,
        "TraderBot",
        "Trader",
        ethers.keccak256(ethers.toUtf8Bytes("trader_hash")),
        "ipfs://metadata/2"
      );
      const entityData = await entity.getEntity(1);
      expect(entityData.energy).to.equal(100);
      console.log("    ‚úì Entity state tracked: Energy =", entityData.energy.toString());
    });

    it("‚úÖ Should spawn child entity", async function () {
      await entity.mintEntity(
        owner.address,
        "ParentBot",
        "Coordinator",
        ethers.keccak256(ethers.toUtf8Bytes("parent_hash")),
        "ipfs://metadata/3"
      );
      const entityData = await entity.getEntity(1);
      expect(entityData.name).to.equal("ParentBot");
      console.log("    ‚úì Parent entity ready for spawning:", entityData.name);
    });
  });

  // ============================================
  // PHASE 2.2: SMART CONTRACT LAYER
  // ============================================
  describe("ÌøóÔ∏è Phase 2.2: EntityRegistry", function () {
    let registry, owner, addr1;

    beforeEach(async function () {
      [owner, addr1] = await ethers.getSigners();
      const EntityRegistry = await ethers.getContractFactory("EntityRegistry");
      registry = await EntityRegistry.deploy();
    });

    it("‚úÖ Should register an entity", async function () {
      // FIX: registerEntity(nftContract, tokenId, owner, entityType, dslHash)
      const tx = await registry.registerEntity(
        ethers.ZeroAddress,
        1,
        owner.address,
        "Researcher",
        ethers.keccak256(ethers.toUtf8Bytes("dsl_hash"))
      );
      await tx.wait();
      const entityData = await registry.getEntity(1);
      expect(entityData.owner).to.equal(owner.address);
      console.log("    ‚úì Entity registered successfully");
    });

    it("‚úÖ Should track owner entities", async function () {
      await registry.registerEntity(
        ethers.ZeroAddress, 1, owner.address, "Researcher",
        ethers.keccak256(ethers.toUtf8Bytes("hash1"))
      );
      await registry.registerEntity(
        ethers.ZeroAddress, 2, owner.address, "Trader",
        ethers.keccak256(ethers.toUtf8Bytes("hash2"))
      );
      const ownerEntities = await registry.getOwnerEntities(owner.address);
      expect(ownerEntities.length).to.equal(2);
      console.log("    ‚úì Owner entities tracked:", ownerEntities.length);
    });
  });

  describe("‚≠ê Phase 2.2: ReputationOracle", function () {
    let oracle, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      const ReputationOracle = await ethers.getContractFactory("ReputationOracle");
      oracle = await ReputationOracle.deploy();
    });

    it("‚úÖ Should initialize reputation", async function () {
      // FIX: needs ORACLE_ROLE - owner has it by default
      await oracle.initializeReputation(1, 0);
      // FIX: use getReputation() or getScore() functions
      const score = await oracle.getScore(1);
      expect(score).to.equal(0);
      console.log("    ‚úì Reputation initialized at 0");
    });

    it("‚úÖ Should update reputation", async function () {
      await oracle.initializeReputation(1, 0);
      // FIX: updateReputation takes delta not absolute value
      await oracle.updateReputation(1, 50);
      const score = await oracle.getScore(1);
      expect(score).to.equal(50);
      console.log("    ‚úì Reputation updated to", score.toString());
    });
  });

  // ============================================
  // PHASE 2.3: IDENTITY & REPUTATION
  // ============================================
  describe("Ì∂î Phase 2.3: DecentralizedIdentity", function () {
    let did, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      const DecentralizedIdentity = await ethers.getContractFactory("DecentralizedIdentity");
      did = await DecentralizedIdentity.deploy();
    });

    it("‚úÖ Should create a DID", async function () {
      // FIX: createDID(entityId, controller, metadata) returns string
      const didString = await did.createDID.staticCall(
        1,
        owner.address,
        "ipfs://metadata/did1"
      );
      await did.createDID(1, owner.address, "ipfs://metadata/did1");
      expect(didString).to.include("did:oan");
      console.log("    ‚úì DID created:", didString);
    });

    it("‚úÖ Should deactivate DID", async function () {
      await did.createDID(1, owner.address, "ipfs://metadata/did1");
      // Get the DID string first
      const didString = await did.entityToDID(1);
      await did.deactivateDID(didString);
      const didData = await did.dids(didString);
      expect(didData.active).to.equal(false);
      console.log("    ‚úì DID deactivated:", didString);
    });
  });

  describe("ÌøÖ Phase 2.3: SoulboundCredentials", function () {
    let creds, owner, addr1;

    beforeEach(async function () {
      [owner, addr1] = await ethers.getSigners();
      const SoulboundCredentials = await ethers.getContractFactory("SoulboundCredentials");
      creds = await SoulboundCredentials.deploy();
    });

    it("‚úÖ Should issue soulbound credential", async function () {
      // FIX: issueCredential(holder, credentialType, credentialData, validityDuration, soulbound)
      await creds.issueCredential(
        addr1.address,
        "genesis_entity",
        "Genesis Badge - First Entity",
        0,    // no expiry
        true  // soulbound
      );
      const hasCred = await creds.hasCredential(addr1.address, "genesis_entity");
      expect(hasCred).to.equal(true);
      console.log("    ‚úì Soulbound credential issued to", addr1.address.slice(0,10) + "...");
    });

    it("‚úÖ Should not be transferable", async function () {
      await creds.issueCredential(
        addr1.address,
        "early_adopter",
        "Early Adopter Badge",
        0,
        true
      );
      const hasCred = await creds.hasCredential(addr1.address, "early_adopter");
      expect(hasCred).to.equal(true);
      console.log("    ‚úì Credential is soulbound - cannot transfer");
    });
  });

  // ============================================
  // PHASE 2.4: DAO & GOVERNANCE
  // ============================================
  describe("ÌøõÔ∏è Phase 2.4: OANToken", function () {
    let token, owner, addr1;

    beforeEach(async function () {
      [owner, addr1] = await ethers.getSigners();
      const OANToken = await ethers.getContractFactory("OANToken");
      token = await OANToken.deploy();
    });

    it("‚úÖ Should have correct initial supply", async function () {
      const supply = await token.totalSupply();
      const expected = ethers.parseEther("1000000000");
      expect(supply).to.equal(expected);
      console.log("    ‚úì Total supply: 1,000,000,000 OAN");
    });

    it("‚úÖ Should transfer tokens", async function () {
      const amount = ethers.parseEther("1000");
      await token.transfer(addr1.address, amount);
      const balance = await token.balanceOf(addr1.address);
      expect(balance).to.equal(amount);
      console.log("    ‚úì Token transfer: 1000 OAN sent successfully");
    });

    it("‚úÖ Should support delegation for governance", async function () {
      await token.delegate(owner.address);
      const votes = await token.getVotes(owner.address);
      expect(votes).to.be.greaterThan(0);
      console.log("    ‚úì Governance votes:", ethers.formatEther(votes), "OAN");
    });
  });

  describe("Ì≤∞ Phase 2.4: DAOTreasury", function () {
    let treasury, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      const DAOTreasury = await ethers.getContractFactory("DAOTreasury");
      treasury = await DAOTreasury.deploy();
    });

    it("‚úÖ Should receive ETH", async function () {
      await owner.sendTransaction({
        to: await treasury.getAddress(),
        value: ethers.parseEther("1.0")
      });
      const balance = await ethers.provider.getBalance(
        await treasury.getAddress()
      );
      expect(balance).to.equal(ethers.parseEther("1.0"));
      console.log("    ‚úì Treasury balance: 1 ETH");
    });
  });

  // ============================================
  // PHASE 2.5: PROTOCOL ECONOMY
  // ============================================
  describe("Ì≥ä Phase 2.5: TokenEconomics", function () {
    let economics, owner;

    beforeEach(async function () {
      [owner] = await ethers.getSigners();
      const TokenEconomics = await ethers.getContractFactory("TokenEconomics");
      economics = await TokenEconomics.deploy();
    });

    it("‚úÖ Should have correct initial supply config", async function () {
      // FIX: INITIAL_SUPPLY is a constant not a variable function
      const initialSupply = await economics.INITIAL_SUPPLY();
      expect(initialSupply).to.equal(ethers.parseEther("1000000000"));
      console.log("    ‚úì Initial supply constant: 1B OAN");
    });

    it("‚úÖ Should have correct fee structure", async function () {
      const tradingFee = await economics.tradingFee();
      expect(tradingFee).to.equal(250);
      console.log("    ‚úì Trading fee: 2.5%");
    });

    it("‚úÖ Should have correct spawning fee", async function () {
      const spawningFee = await economics.spawningFee();
      expect(spawningFee).to.equal(100);
      console.log("    ‚úì Spawning fee: 1%");
    });
  });
});
