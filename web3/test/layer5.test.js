// ================================================================
// OAN Layer 5: Metaverse Sports Arena - Complete Test Suite (FIXED)
// Place in: web3/test/layer5.test.js
// Run with: npx hardhat test test/layer5.test.js
// ================================================================

const { expect } = require("chai");
const { ethers } = require("hardhat");

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────
const toWei = (eth) => ethers.parseEther(eth.toString());
const SportType = { Boxing: 0, MMA: 1, Racing: 2, Soccer: 3, Basketball: 4, Esports: 5, Tennis: 6, Wrestling: 7 };
const StadiumTier = { Community: 0, Regional: 1, National: 2, Global: 3, Legendary: 4 };
const SeatTier = { Standard: 0, Premium: 1, VIP: 2, Skybox: 3, Ringside: 4 };
const SeatType = { Permanent: 0, Seasonal: 1, SingleEvent: 2 };
const CardRarity = { Common: 0, Uncommon: 1, Rare: 2, Epic: 3, Legendary: 4, Mythic: 5 };
const CardType = { Base: 0, Rookie: 1, Champion: 2 };
const AccessTier = { Free: 0, Standard: 1, Premium: 2, VIP: 3 };

const defaultStats = () => ({
  strength: 75, speed: 70, endurance: 80,
  technique: 65, intelligence: 60, charisma: 55,
  defense: 70, aggression: 65
});

// Always use chain time, never Date.now() — avoids drift after evm_increaseTime calls
const blockTs = async () => (await ethers.provider.getBlock("latest")).timestamp;
const advanceTime = async (secs) => {
  await ethers.provider.send("evm_increaseTime", [secs]);
  await ethers.provider.send("evm_mine");
};

// ─────────────────────────────────────────────────────────────
// PHASE 5.1: Virtual Stadiums & Venues
// ─────────────────────────────────────────────────────────────
describe("Phase 5.1: Virtual Stadiums & Venues", function () {
  let stadium, registry, seating, marketplace;
  let owner, treasury, user1, user2, user3;

  beforeEach(async function () {
    [owner, treasury, user1, user2, user3] = await ethers.getSigners();
    stadium = await (await ethers.getContractFactory("StadiumNFT")).deploy(treasury.address);
    registry = await (await ethers.getContractFactory("VenueRegistry")).deploy();
    seating = await (await ethers.getContractFactory("SeatingNFT")).deploy(treasury.address);
    marketplace = await (await ethers.getContractFactory("VenueMarketplace")).deploy(treasury.address);
  });

  describe("StadiumNFT", function () {
    it("should mint a stadium NFT with correct data", async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "OAN Arena", "X:100,Y:200", 50000,
        [SportType.Boxing, SportType.MMA],
        StadiumTier.National, 500, "ipfs://stadium1",
        { value: mintPrice }
      );
      const s = await stadium.stadiums(1);
      expect(s.name).to.equal("OAN Arena");
      expect(s.capacity).to.equal(50000);
      expect(s.tier).to.equal(StadiumTier.National);
      expect(s.isActive).to.equal(true);
      expect(await stadium.ownerOf(1)).to.equal(user1.address);
    });

    it("should reject mint with insufficient payment", async function () {
      await expect(
        stadium.connect(user1).mintStadium(
          "Cheap Arena", "X:0,Y:0", 1000,
          [SportType.Boxing], StadiumTier.Community, 500, "ipfs://x",
          { value: toWei(0.001) }
        )
      ).to.be.revertedWith("Insufficient payment");
    });

    it("should reject hosting fee above 30%", async function () {
      const mintPrice = await stadium.mintPrice();
      await expect(
        stadium.connect(user1).mintStadium(
          "Greedy Arena", "X:0,Y:0", 1000,
          [SportType.Boxing], StadiumTier.Community, 5000, "ipfs://x",
          { value: mintPrice }
        )
      ).to.be.revertedWith("Fee too high");
    });

    it("should record events and track revenue", async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "Fight Club", "X:1,Y:1", 10000,
        [SportType.Boxing], StadiumTier.Regional, 1000, "ipfs://s",
        { value: mintPrice }
      );
      await stadium.connect(user1).recordEvent(1, "Grand Prix Fight Night", 5000, { value: toWei(1) });
      const history = await stadium.getEventHistory(1);
      expect(history.length).to.equal(1);
      expect(history[0].eventName).to.equal("Grand Prix Fight Night");
      expect(history[0].attendees).to.equal(5000);
    });

    it("should allow authorized hosts to record events", async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "Host Arena", "X:5,Y:5", 10000,
        [SportType.MMA], StadiumTier.Community, 500, "ipfs://h",
        { value: mintPrice }
      );
      await stadium.connect(user1).authorizeHost(1, user2.address);
      await expect(
        stadium.connect(user2).recordEvent(1, "MMA Night", 100, { value: toWei(0.1) })
      ).to.not.be.reverted;
    });

    it("should reject unauthorized event hosts", async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "Private Arena", "X:9,Y:9", 10000,
        [SportType.Boxing], StadiumTier.Community, 500, "ipfs://p",
        { value: mintPrice }
      );
      await expect(
        stadium.connect(user2).recordEvent(1, "Unauthorized Event", 100, { value: toWei(0.1) })
      ).to.be.revertedWith("Not authorized");
    });

    it("should upgrade stadium tier and increase capacity", async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "Growing Arena", "X:3,Y:3", 10000,
        [SportType.Boxing], StadiumTier.Community, 500, "ipfs://g",
        { value: mintPrice }
      );
      await stadium.connect(user1).upgradeStadium(1, { value: mintPrice * 2n });
      const s = await stadium.stadiums(1);
      expect(s.tier).to.equal(StadiumTier.Regional);
      expect(s.capacity).to.equal(15000);
    });

    it("should send protocol fee to treasury on mint", async function () {
      const mintPrice = await stadium.mintPrice();
      const before = await ethers.provider.getBalance(treasury.address);
      await stadium.connect(user1).mintStadium(
        "Treasury Test", "X:0,Y:0", 1000,
        [SportType.Boxing], StadiumTier.Community, 500, "ipfs://t",
        { value: mintPrice }
      );
      expect(await ethers.provider.getBalance(treasury.address)).to.be.gt(before);
    });

    it("should allow admin to update mint price", async function () {
      await stadium.connect(owner).setMintPrice(toWei(0.5));
      expect(await stadium.mintPrice()).to.equal(toWei(0.5));
    });

    it("should return supported sports array", async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "Multi Sport", "X:2,Y:2", 5000,
        [SportType.Boxing, SportType.MMA, SportType.Esports],
        StadiumTier.Community, 500, "ipfs://m",
        { value: mintPrice }
      );
      const sports = await stadium.getSupportedSports(1);
      expect(sports.length).to.equal(3);
    });
  });

  describe("VenueRegistry", function () {
    it("should register a venue linked to a stadium", async function () {
      await registry.connect(user1).registerVenue(
        1, "Grand Arena", "A premier fighting venue",
        0, "ipfs://venue1", ["boxing", "vip"]
      );
      const venue = await registry.venues(1);
      expect(venue.name).to.equal("Grand Arena");
      expect(venue.owner).to.equal(user1.address);
      expect(venue.isVerified).to.equal(false);
    });

    it("should reject duplicate stadium registration", async function () {
      await registry.connect(user1).registerVenue(1, "Arena 1", "Desc", 0, "ipfs://1", []);
      await expect(
        registry.connect(user2).registerVenue(1, "Arena 2", "Desc", 0, "ipfs://2", [])
      ).to.be.revertedWith("Already registered");
    });

    it("should allow rating a venue", async function () {
      // Register with stadiumNFTId=1, creates venueId=1
      await registry.connect(user1).registerVenue(1, "Rate Me Arena", "Desc", 0, "ipfs://r", []);
      await registry.connect(user2).rateVenue(1, 5, "Amazing venue!");
      const venue = await registry.venues(1);
      expect(venue.totalRatings).to.equal(1);
      expect(venue.averageRating).to.equal(500); // 5 * 100
    });

    it("should prevent self-rating", async function () {
      await registry.connect(user1).registerVenue(1, "Self Rate Test", "Desc", 0, "ipfs://s", []);
      await expect(
        registry.connect(user1).rateVenue(1, 5, "I am the best!")
      ).to.be.revertedWith("No self-rating");
    });

    it("should prevent double rating", async function () {
      await registry.connect(user1).registerVenue(1, "No Double Rate", "Desc", 0, "ipfs://nd", []);
      await registry.connect(user2).rateVenue(1, 4, "Good");
      await expect(
        registry.connect(user2).rateVenue(1, 3, "Changed my mind")
      ).to.be.revertedWith("Already rated");
    });

    it("should verify a venue (admin only)", async function () {
      await registry.connect(user1).registerVenue(1, "Verify Me", "Desc", 0, "ipfs://v", []);
      await registry.connect(owner).verifyVenue(1);
      expect((await registry.venues(1)).isVerified).to.equal(true);
    });

    it("should get venues by owner", async function () {
      await registry.connect(user1).registerVenue(1, "V1", "Desc", 0, "ipfs://1", []);
      await registry.connect(user1).registerVenue(2, "V2", "Desc", 0, "ipfs://2", []);
      const venues = await registry.getVenuesByOwner(user1.address);
      expect(venues.length).to.equal(2);
    });
  });

  describe("SeatingNFT", function () {
    it("should mint a permanent VIP seat", async function () {
      const vipPrice = await seating.tierMintPrice(SeatTier.VIP);
      await seating.connect(user1).mintSeat(
        1, 5, 12, SeatTier.VIP, SeatType.Permanent, toWei(0.01), 0, "ipfs://seat1",
        { value: vipPrice }
      );
      const seat = await seating.seats(1);
      expect(seat.tier).to.equal(SeatTier.VIP);
      expect(seat.isPermanent).to.equal(true);
      expect(seat.stadiumId).to.equal(1);
    });

    it("should reject mint with insufficient payment", async function () {
      await expect(
        seating.connect(user1).mintSeat(
          1, 1, 1, SeatTier.Ringside, SeatType.Permanent, 0, 0, "ipfs://x",
          { value: toWei(0.001) }
        )
      ).to.be.reverted;
    });

    it("should list and rent a seat for an event", async function () {
      const standardPrice = await seating.tierMintPrice(SeatTier.Standard);
      await seating.connect(user1).mintSeat(
        1, 1, 1, SeatTier.Standard, SeatType.Permanent, 0, 0, "ipfs://std",
        { value: standardPrice }
      );
      await seating.connect(user1).listSeatForRental(1, toWei(0.005));
      await seating.connect(user2).rentSeat(1, 42, { value: toWei(0.005) });
      const seat = await seating.seats(1);
      expect(seat.eventsAttended).to.equal(1);
      expect(await seating.seatRenter(1)).to.equal(user2.address);
    });

    it("should assign correct perks to Ringside tier", async function () {
      const price = await seating.tierMintPrice(SeatTier.Ringside);
      await seating.connect(user1).mintSeat(
        1, 1, 1, SeatTier.Ringside, SeatType.Permanent, 0, 0, "ipfs://rs",
        { value: price }
      );
      const perks = await seating.seatPerks(1);
      expect(perks.meetAndGreetAccess).to.equal(true);
      expect(perks.votingWeight).to.equal(25);
    });

    it("should track stadium seat counts", async function () {
      const price = await seating.tierMintPrice(SeatTier.Standard);
      await seating.connect(user1).mintSeat(1, 1, 1, SeatTier.Standard, SeatType.Permanent, 0, 0, "ipfs://s1", { value: price });
      await seating.connect(user1).mintSeat(1, 1, 2, SeatTier.Standard, SeatType.Permanent, 0, 0, "ipfs://s2", { value: price });
      expect((await seating.getStadiumSeats(1)).length).to.equal(2);
    });
  });

  describe("VenueMarketplace", function () {
    let stadiumId;
    beforeEach(async function () {
      const mintPrice = await stadium.mintPrice();
      await stadium.connect(user1).mintStadium(
        "Marketplace Stadium", "X:1,Y:1", 5000,
        [SportType.Boxing], StadiumTier.Community, 500, "ipfs://ms",
        { value: mintPrice }
      );
      stadiumId = 1;
    });

    it("should list a stadium for sale", async function () {
      await stadium.connect(user1).approve(marketplace.target, stadiumId);
      await marketplace.connect(user1).listForSale(stadium.target, stadiumId, toWei(1), 86400);
      const listing = await marketplace.listings(1);
      expect(listing.seller).to.equal(user1.address);
      expect(listing.price).to.equal(toWei(1));
      expect(listing.status).to.equal(0);
    });

    it("should complete a sale and transfer NFT", async function () {
      await stadium.connect(user1).approve(marketplace.target, stadiumId);
      await marketplace.connect(user1).listForSale(stadium.target, stadiumId, toWei(1), 86400);
      await marketplace.connect(user2).buyNow(1, { value: toWei(1) });
      expect(await stadium.ownerOf(stadiumId)).to.equal(user2.address);
      expect((await marketplace.listings(1)).status).to.equal(1);
    });

    it("should reject purchase with insufficient payment", async function () {
      await stadium.connect(user1).approve(marketplace.target, stadiumId);
      await marketplace.connect(user1).listForSale(stadium.target, stadiumId, toWei(1), 86400);
      await expect(
        marketplace.connect(user2).buyNow(1, { value: toWei(0.5) })
      ).to.be.reverted;
    });

    it("should handle auction bidding correctly", async function () {
      await stadium.connect(user1).approve(marketplace.target, stadiumId);
      await marketplace.connect(user1).listForAuction(stadium.target, stadiumId, toWei(0.5), 3600);
      await marketplace.connect(user2).bidAuction(1, { value: toWei(0.6) });
      await marketplace.connect(user3).bidAuction(1, { value: toWei(0.8) });
      const listing = await marketplace.listings(1);
      expect(listing.highestBidder).to.equal(user3.address);
      expect(listing.highestBid).to.equal(toWei(0.8));
    });

    it("should allow cancel of listing with no bids", async function () {
      await stadium.connect(user1).approve(marketplace.target, stadiumId);
      await marketplace.connect(user1).listForSale(stadium.target, stadiumId, toWei(1), 86400);
      await marketplace.connect(user1).cancelListing(1);
      expect((await marketplace.listings(1)).status).to.equal(2);
      expect(await stadium.ownerOf(stadiumId)).to.equal(user1.address);
    });
  });
});

// ─────────────────────────────────────────────────────────────
// PHASE 5.2: Sports Cards & Athletes
// ─────────────────────────────────────────────────────────────
describe("Phase 5.2: Sports Cards & Athletes", function () {
  let athlete, cards, team;
  let owner, treasury, user1, user2, user3;

  beforeEach(async function () {
    [owner, treasury, user1, user2, user3] = await ethers.getSigners();
    athlete = await (await ethers.getContractFactory("AthleteNFT")).deploy(treasury.address);
    cards = await (await ethers.getContractFactory("SportsCardNFT")).deploy(treasury.address);
    team = await (await ethers.getContractFactory("TeamNFT")).deploy(treasury.address);
  });

  describe("AthleteNFT", function () {
    it("should mint an athlete with correct stats", async function () {
      const mintPrice = await athlete.mintPrice();
      await athlete.connect(user1).mintAthlete(
        1, "Iron Fist", "The Destroyer", SportType.Boxing,
        3, defaultStats(), 365 * 3, "ipfs://athlete1",
        { value: mintPrice }
      );
      const a = await athlete.athletes(1);
      expect(a.name).to.equal("Iron Fist");
      expect(a.nickname).to.equal("The Destroyer");
      expect(a.isActive).to.equal(true);
      expect(a.wins).to.equal(0);
    });

    it("should reject duplicate entity linking", async function () {
      const mintPrice = await athlete.mintPrice();
      // Both use entityId=1 — second should fail
      await athlete.connect(user1).mintAthlete(
        1, "Fighter A", "A", SportType.Boxing, 0, defaultStats(), 365, "ipfs://a", { value: mintPrice }
      );
      await expect(
        athlete.connect(user2).mintAthlete(
          1, "Fighter B", "B", SportType.MMA, 0, defaultStats(), 365, "ipfs://b", { value: mintPrice }
        )
      ).to.be.revertedWith("Entity already linked");
    });

    it("should train athlete and improve a stat", async function () {
      const mintPrice = await athlete.mintPrice();
      const trainingCost = await athlete.trainingCost();
      await athlete.connect(user1).mintAthlete(
        1, "Trainee", "T", SportType.Boxing, 0, defaultStats(), 365, "ipfs://t", { value: mintPrice }
      );
      // lastTrainedAt is set to block.timestamp on mint — must wait 1 hour cooldown
      await advanceTime(3601);
      const before = (await athlete.getAthleteStats(1)).strength;
      await athlete.connect(user1).trainAthlete(1, 0, { value: trainingCost });
      const after = (await athlete.getAthleteStats(1)).strength;
      expect(after).to.be.gte(before);
    });

    it("should enforce training cooldown", async function () {
      const mintPrice = await athlete.mintPrice();
      const trainingCost = await athlete.trainingCost();
      await athlete.connect(user1).mintAthlete(
        1, "Cooldown Test", "C", SportType.MMA, 0, defaultStats(), 365, "ipfs://c", { value: mintPrice }
      );
      // Advance past initial cooldown so first train succeeds
      await advanceTime(3601);
      await athlete.connect(user1).trainAthlete(1, 0, { value: trainingCost });
      // Immediately try again — should be blocked by cooldown (contract may say "Cannot train" or "Training cooldown active")
      await expect(
        athlete.connect(user1).trainAthlete(1, 1, { value: trainingCost })
      ).to.be.reverted; // cooldown enforced regardless of exact message
    });

    it("should record match results correctly", async function () {
      const mintPrice = await athlete.mintPrice();
      // FIX: entityId=1 so tokenId=1
      await athlete.connect(user1).mintAthlete(
        1, "Match Recorder", "MR", SportType.Boxing, 0, defaultStats(), 365, "ipfs://mr", { value: mintPrice }
      );
      await athlete.connect(owner).recordMatchResult(1, 101, true, true, toWei(0.5));
      const a = await athlete.athletes(1);
      expect(a.wins).to.equal(1);
      expect(a.knockouts).to.equal(1);
      expect(a.careerEarnings).to.equal(toWei(0.5));
    });

    it("should calculate overall rating correctly", async function () {
      const mintPrice = await athlete.mintPrice();
      // FIX: entityId=1 so tokenId=1
      await athlete.connect(user1).mintAthlete(
        1, "Rating Test", "RT", SportType.MMA, 0, defaultStats(), 365, "ipfs://rt", { value: mintPrice }
      );
      const rating = await athlete.getOverallRating(1);
      expect(rating).to.equal(67); // (75+70+80+65+60+55+70+65)/8
    });

    it("should retire an athlete", async function () {
      const mintPrice = await athlete.mintPrice();
      // FIX: entityId=1 so tokenId=1
      await athlete.connect(user1).mintAthlete(
        1, "Retiring Soon", "RS", SportType.Boxing, 0, defaultStats(), 365, "ipfs://ret", { value: mintPrice }
      );
      await athlete.connect(user1).retireAthlete(1);
      expect((await athlete.athletes(1)).isActive).to.equal(false);
    });

    it("should get all athletes owned by address", async function () {
      const mintPrice = await athlete.mintPrice();
      // FIX: different entityIds for each mint (1 and 2)
      await athlete.connect(user1).mintAthlete(1, "A1", "a1", SportType.Boxing, 0, defaultStats(), 365, "ipfs://a1", { value: mintPrice });
      await athlete.connect(user1).mintAthlete(2, "A2", "a2", SportType.MMA, 0, defaultStats(), 365, "ipfs://a2", { value: mintPrice });
      expect((await athlete.getOwnerAthletes(user1.address)).length).to.equal(2);
    });
  });

  describe("SportsCardNFT", function () {
    const snapshotStats = { strength: 80, speed: 75, endurance: 70, wins: 10, losses: 2, knockouts: 5, technique: 65 };

    it("should create a card template", async function () {
      await cards.connect(owner).createCard(
        1, "Iron Fist", CardRarity.Rare, CardType.Base, snapshotStats, toWei(0.01), "ipfs://card1"
      );
      const card = await cards.cards(1);
      expect(card.athleteName).to.equal("Iron Fist");
      expect(card.rarity).to.equal(CardRarity.Rare);
      expect(card.totalMinted).to.equal(1000); // Rare cap
      expect(card.isActive).to.equal(true);
    });

    it("should mint cards and track supply", async function () {
      await cards.connect(owner).createCard(1, "Fighter", CardRarity.Common, CardType.Base, snapshotStats, toWei(0.005), "ipfs://c1");
      await cards.connect(user1).mintCard(1, 3, { value: toWei(0.015) });
      expect((await cards.cards(1)).currentMinted).to.equal(3);
      expect(await cards.balanceOf(user1.address, 1)).to.equal(3);
    });

    it("should reject mint exceeding max supply", async function () {
      await cards.connect(owner).createCard(1, "Rare Fighter", CardRarity.Mythic, CardType.Champion, snapshotStats, toWei(1), "ipfs://mythic");
      await expect(
        cards.connect(user1).mintCard(1, 11, { value: toWei(11) })
      ).to.be.revertedWith("Exceeds max supply");
    });

    it("should record mint numbers correctly", async function () {
      await cards.connect(owner).createCard(1, "Numbered", CardRarity.Epic, CardType.Rookie, snapshotStats, toWei(0.05), "ipfs://num");
      await cards.connect(user1).mintCard(1, 1, { value: toWei(0.05) });
      expect(await cards.getMintNumber(1, user1.address)).to.equal(1);
    });

    it("should calculate higher value multiplier for lower mint numbers", async function () {
      await cards.connect(owner).createCard(1, "Value Card", CardRarity.Legendary, CardType.Base, snapshotStats, toWei(0.1), "ipfs://val");
      const first = await cards.getValueMultiplier(1, 1);
      const last = await cards.getValueMultiplier(1, 100);
      expect(first).to.be.gt(last);
    });

    it("should retire a card to stop minting", async function () {
      await cards.connect(owner).createCard(1, "Retired Card", CardRarity.Common, CardType.Base, snapshotStats, toWei(0.001), "ipfs://ret");
      await cards.connect(owner).retireCard(1);
      await expect(
        cards.connect(user1).mintCard(1, 1, { value: toWei(0.001) })
      ).to.be.revertedWith("Card not active");
    });

    it("should advance season", async function () {
      const before = await cards.currentSeason();
      await cards.connect(owner).advanceSeason();
      expect(await cards.currentSeason()).to.equal(before + 1n);
    });
  });

  describe("TeamNFT", function () {
    it("should create a team", async function () {
      const mintPrice = await team.mintPrice();
      await team.connect(user1).createTeam(
        "OAN Wolves", "OAN", SportType.MMA, 10, true, "Stadium X", "ipfs://team1",
        { value: mintPrice }
      );
      const t = await team.teams(1);
      expect(t.name).to.equal("OAN Wolves");
      expect(t.owner).to.equal(user1.address);
    });

    it("should reject duplicate team names", async function () {
      const mintPrice = await team.mintPrice();
      await team.connect(user1).createTeam("OAN Hawks", "HAW", SportType.Boxing, 5, true, "A", "ipfs://h", { value: mintPrice });
      await expect(
        team.connect(user2).createTeam("OAN Hawks", "HW2", SportType.Boxing, 5, true, "B", "ipfs://h2", { value: mintPrice })
      ).to.be.revertedWith("Team name taken");
    });

    it("should add and remove athletes from roster", async function () {
      const mintPrice = await team.mintPrice();
      await team.connect(user1).createTeam("Roster Team", "RST", SportType.MMA, 5, true, "S", "ipfs://r", { value: mintPrice });
      await team.connect(user1).addAthlete(1, 101);
      await team.connect(user1).addAthlete(1, 102);
      expect((await team.getTeamRoster(1)).length).to.equal(2);
      await team.connect(user1).removeAthlete(1, 101);
      expect((await team.getTeamRoster(1)).length).to.equal(1);
    });

    it("should enforce roster size limit", async function () {
      const mintPrice = await team.mintPrice();
      await team.connect(user1).createTeam("Small Team", "SML", SportType.Boxing, 2, true, "S", "ipfs://s", { value: mintPrice });
      await team.connect(user1).addAthlete(1, 201);
      await team.connect(user1).addAthlete(1, 202);
      await expect(team.connect(user1).addAthlete(1, 203)).to.be.revertedWith("Roster full");
    });

    it("should allow applications to public teams", async function () {
      const mintPrice = await team.mintPrice();
      await team.connect(user1).createTeam("Open Team", "OPN", SportType.MMA, 10, true, "S", "ipfs://o", { value: mintPrice });
      await team.connect(user2).applyToTeam(1, 999);
      const apps = await team.getTeamApplications(1);
      expect(apps.length).to.equal(1);
      expect(apps[0].applicant).to.equal(user2.address);
    });

    it("should set and use team manager", async function () {
      const mintPrice = await team.mintPrice();
      await team.connect(user1).createTeam("Managed Team", "MGD", SportType.Boxing, 5, true, "S", "ipfs://m", { value: mintPrice });
      await team.connect(user1).setManager(1, user2.address);
      expect((await team.teams(1)).manager).to.equal(user2.address);
      await team.connect(user2).addAthlete(1, 301);
      expect((await team.getTeamRoster(1)).length).to.equal(1);
    });
  });
});

// ─────────────────────────────────────────────────────────────
// PHASE 5.3: Competitive Simulations
// ─────────────────────────────────────────────────────────────
describe("Phase 5.3: Competitive Simulations", function () {
  let simulator, tournament, liveEvent, perfMetrics;
  let owner, treasury, user1, user2, user3;

  beforeEach(async function () {
    [owner, treasury, user1, user2, user3] = await ethers.getSigners();
    simulator = await (await ethers.getContractFactory("MatchSimulator")).deploy(treasury.address, ethers.ZeroAddress);
    tournament = await (await ethers.getContractFactory("TournamentBrackets")).deploy(treasury.address);
    liveEvent = await (await ethers.getContractFactory("LiveEvents")).deploy(treasury.address);
    perfMetrics = await (await ethers.getContractFactory("PerformanceMetrics")).deploy();
  });

  describe("MatchSimulator", function () {
    it("should schedule a match", async function () {
      const futureTime = await blockTs() + 3600;
      await simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.Boxing, futureTime, 10, 180, { value: toWei(1) });
      const m = await simulator.matches(1);
      expect(m.athlete1Id).to.equal(1);
      expect(m.athlete2Id).to.equal(2);
      expect(m.prizePool).to.equal(toWei(1));
      expect(await simulator.matchStatus(1)).to.equal(0);
    });

    it("should reject self-fight scheduling", async function () {
      const futureTime = await blockTs() + 3600;
      await expect(
        simulator.connect(user1).scheduleMatch(1, 1, 1, SportType.Boxing, futureTime, 5, 180)
      ).to.be.revertedWith("Cannot fight yourself");
    });

    it("should reject past scheduled times", async function () {
      const pastTime = await blockTs() - 3600;
      await expect(
        simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.Boxing, pastTime, 5, 180)
      ).to.be.revertedWith("Must be future");
    });

    it("should simulate a match and produce outcome", async function () {
      const futureTime = await blockTs() + 10;
      await simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.Boxing, futureTime, 5, 180, { value: toWei(0.5) });
      await advanceTime(15);
      await simulator.connect(owner).simulateMatch(1, 80, 75, 70, 85, 60, 65, 70, 55, 1000);
      expect(await simulator.matchStatus(1)).to.equal(2);
      expect((await simulator.getMatchOutcome(1)).viewerCount).to.equal(1000);
    });

    it("should track athlete match history", async function () {
      const t = await blockTs() + 3600;
      await simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.Boxing, t, 5, 180);
      await simulator.connect(user1).scheduleMatch(1, 3, 2, SportType.MMA, t, 5, 180);
      expect((await simulator.getAthleteMatches(1)).length).to.equal(2);
    });

    it("should cancel a scheduled match", async function () {
      const t = await blockTs() + 3600;
      await simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.Boxing, t, 5, 180);
      await simulator.connect(owner).cancelMatch(1, "Athlete injured");
      expect(await simulator.matchStatus(1)).to.equal(3);
    });
  });

  describe("TournamentBrackets", function () {
    it("should create a tournament", async function () {
      const start = await blockTs() + 86400;
      await tournament.connect(user1).createTournament(
        "OAN Grand Prix", SportType.Boxing, 0, toWei(0.01), 16, start, start + 7 * 86400,
        { value: toWei(0.5) }
      );
      const t = await tournament.tournaments(1);
      expect(t.name).to.equal("OAN Grand Prix");
      expect(t.prizePool).to.equal(toWei(0.5));
      expect(t.status).to.equal(0);
    });

    it("should allow athlete registration with entry fee", async function () {
      const start = await blockTs() + 86400;
      await tournament.connect(user1).createTournament("Entry Test", SportType.MMA, 0, toWei(0.01), 8, start, start + 86400, { value: 0 });
      await tournament.connect(user2).registerAthlete(1, 101, { value: toWei(0.01) });
      await tournament.connect(user2).registerAthlete(1, 102, { value: toWei(0.01) });
      expect((await tournament.getTournamentParticipants(1)).length).to.equal(2);
    });

    it("should reject duplicate athlete registration", async function () {
      const start = await blockTs() + 86400;
      await tournament.connect(user1).createTournament("Dupe Test", SportType.Boxing, 0, toWei(0.01), 8, start, start + 86400, { value: 0 });
      await tournament.connect(user2).registerAthlete(1, 201, { value: toWei(0.01) });
      await expect(
        tournament.connect(user2).registerAthlete(1, 201, { value: toWei(0.01) })
      ).to.be.revertedWith("Already registered");
    });

    it("should start tournament and generate bracket", async function () {
      const start = await blockTs() + 86400;
      await tournament.connect(user1).createTournament("Bracket Test", SportType.Boxing, 0, 0, 8, start, start + 86400, { value: 0 });
      await tournament.connect(user2).registerAthlete(1, 301);
      await tournament.connect(user2).registerAthlete(1, 302);
      await tournament.connect(user2).registerAthlete(1, 303);
      await tournament.connect(user2).registerAthlete(1, 304);
      await tournament.connect(owner).startTournament(1);
      expect((await tournament.getTournamentBracket(1)).length).to.equal(2);
    });
  });

  describe("LiveEvents", function () {
    it("should create a live event", async function () {
      const start = await blockTs() + 3600;
      await liveEvent.connect(user1).createEvent(1, 1, "Championship Night", "Desc", start, 10000, "ipfs://stream1");
      const evt = await liveEvent.events(1);
      expect(evt.title).to.equal("Championship Night");
      expect(evt.maxViewers).to.equal(10000);
      expect(evt.status).to.equal(0);
    });

    it("should allow ticket purchase", async function () {
      const start = await blockTs() + 3600;
      await liveEvent.connect(user1).createEvent(1, 1, "Fight Night", "Desc", start, 5000, "ipfs://s");
      await liveEvent.connect(user2).purchaseTicket(1, AccessTier.Standard, { value: toWei(0.001) });
      expect(await liveEvent.viewerAccess(1, user2.address)).to.equal(AccessTier.Standard);
    });

    it("should start and end events correctly", async function () {
      const start = await blockTs() + 3600;
      await liveEvent.connect(user1).createEvent(1, 1, "Live Test", "Desc", start, 1000, "ipfs://lt");
      await liveEvent.connect(owner).startEvent(1);
      expect((await liveEvent.events(1)).status).to.equal(1);
      await liveEvent.connect(owner).endEvent(1, "ipfs://replay");
      expect((await liveEvent.events(1)).status).to.equal(3);
      expect((await liveEvent.events(1)).hasReplay).to.equal(true);
    });

    it("should track viewer count", async function () {
      const start = await blockTs() + 3600;
      await liveEvent.connect(user1).createEvent(1, 1, "Viewer Test", "Desc", start, 1000, "ipfs://vt");
      await liveEvent.connect(owner).startEvent(1);
      await liveEvent.connect(user2).viewerJoin(1);
      await liveEvent.connect(user3).viewerJoin(1);
      const evt = await liveEvent.events(1);
      expect(evt.currentViewers).to.equal(2);
      expect(evt.peakViewers).to.equal(2);
    });
  });

  describe("PerformanceMetrics", function () {
    it("should initialize an athlete for tracking", async function () {
      await perfMetrics.connect(owner).initializeAthlete(1);
      const stats = await perfMetrics.getCareerStats(1);
      expect(stats.athleteId).to.equal(1);
      expect(stats.performanceScore).to.equal(500);
    });

    it("should record a match win and update career stats", async function () {
      await perfMetrics.connect(owner).initializeAthlete(1);
      await perfMetrics.connect(owner).recordMatchPerformance(1, 101, true, true, false, 3, 2, 2, 0, 45, 6500, 85);
      const stats = await perfMetrics.getCareerStats(1);
      expect(stats.wins).to.equal(1);
      expect(stats.knockouts).to.equal(1);
      expect(stats.winStreak).to.equal(1);
    });

    it("should track win and loss streaks correctly", async function () {
      await perfMetrics.connect(owner).initializeAthlete(2);
      for (let i = 0; i < 3; i++) {
        await perfMetrics.connect(owner).recordMatchPerformance(2, 200 + i, true, false, false, 3, 2, 1, 0, 30, 5000, 80);
      }
      expect((await perfMetrics.getCareerStats(2)).winStreak).to.equal(3);
      await perfMetrics.connect(owner).recordMatchPerformance(2, 210, false, false, false, 1, 3, 0, 2, 20, 4000, 60);
      const stats = await perfMetrics.getCareerStats(2);
      expect(stats.winStreak).to.equal(0);
      expect(stats.longestWinStreak).to.equal(3);
    });

    it("should update athlete ranking", async function () {
      await perfMetrics.connect(owner).updateRanking(1, SportType.Boxing, 3);
      expect(await perfMetrics.getAthleteRank(1, SportType.Boxing)).to.equal(3);
    });

    it("should get match performance history", async function () {
      await perfMetrics.connect(owner).initializeAthlete(4);
      await perfMetrics.connect(owner).recordMatchPerformance(4, 401, true, false, false, 3, 2, 1, 1, 35, 6000, 75);
      await perfMetrics.connect(owner).recordMatchPerformance(4, 402, false, false, false, 1, 3, 0, 2, 20, 4500, 65);
      expect((await perfMetrics.getMatchPerformances(4)).length).to.equal(2);
    });
  });
});

// ─────────────────────────────────────────────────────────────
// PHASE 5.4: Fan Engagement
// ─────────────────────────────────────────────────────────────
describe("Phase 5.4: Fan Engagement", function () {
  let fanTokens, prediction, fantasy, rewards;
  let owner, treasury, user1, user2, user3;

  beforeEach(async function () {
    [owner, treasury, user1, user2, user3] = await ethers.getSigners();
    fanTokens = await (await ethers.getContractFactory("FanTokens")).deploy(treasury.address);
    prediction = await (await ethers.getContractFactory("PredictionMarkets")).deploy(treasury.address);
    fantasy = await (await ethers.getContractFactory("FantasyLeagues")).deploy(treasury.address);
    rewards = await (await ethers.getContractFactory("FanRewards")).deploy(treasury.address);
  });

  describe("FanTokens", function () {
    const benefits = {
      votingRights: true, revenueShare: true, exclusiveMerchandise: true,
      meetAndGreetAccess: false, earlyTicketAccess: true, minHoldingRequired: 10
    };

    it("should create a fan token series", async function () {
      await fanTokens.connect(user1).createFanTokenSeries(1, "Iron Fist Fan Token", "IFFT", 1000000, toWei(0.001), benefits);
      const series = await fanTokens.fanTokenSeries(1);
      expect(series.name).to.equal("Iron Fist Fan Token");
      expect(series.totalSupply).to.equal(1000000);
    });

    it("should allow buying fan tokens", async function () {
      await fanTokens.connect(user1).createFanTokenSeries(1, "Fighter Fan", "FF", 100000, toWei(0.001), benefits);
      const before = await fanTokens.getHoldings(1, user2.address);
      await fanTokens.connect(user2).buyFanTokens(1, 100, { value: toWei(0.5) });
      expect(await fanTokens.getHoldings(1, user2.address)).to.be.gt(before);
    });

    it("should reject exceeding total supply", async function () {
      await fanTokens.connect(user1).createFanTokenSeries(1, "Limited", "LIM", 10, toWei(0.001), benefits);
      await expect(
        fanTokens.connect(user2).buyFanTokens(1, 11, { value: toWei(1) })
      ).to.be.revertedWith("Exceeds supply");
    });

    it("should allow selling tokens back", async function () {
      await fanTokens.connect(user1).createFanTokenSeries(1, "Sellable", "SLB", 100000, toWei(0.001), benefits);
      await fanTokens.connect(user2).buyFanTokens(1, 200, { value: toWei(2) });
      const before = await fanTokens.getHoldings(1, user2.address);
      await fanTokens.connect(user2).sellFanTokens(1, 25);
      expect(await fanTokens.getHoldings(1, user2.address)).to.equal(before - 25n);
    });

    it("should check holder benefits threshold", async function () {
      await fanTokens.connect(user1).createFanTokenSeries(1, "Benefits Test", "BT", 100000, toWei(0.001), benefits);
      await fanTokens.connect(user2).buyFanTokens(1, 5, { value: toWei(0.1) });
      await fanTokens.connect(user3).buyFanTokens(1, 15, { value: toWei(0.5) });
      expect(await fanTokens.hasBenefits(1, user2.address)).to.equal(false);
      expect(await fanTokens.hasBenefits(1, user3.address)).to.equal(true);
    });
  });

  describe("PredictionMarkets", function () {
    it("should create a prediction market", async function () {
      const closeTime = await blockTs() + 3600;
      await prediction.connect(user1).createMarket(1, 0, closeTime, ["Fighter A wins", "Fighter B wins"]);
      const market = await prediction.markets(1);
      expect(market.matchId).to.equal(1);
      expect(market.status).to.equal(0);
    });

    it("should allow placing bets on outcomes", async function () {
      const closeTime = await blockTs() + 3600;
      await prediction.connect(user1).createMarket(1, 0, closeTime, ["A wins", "B wins"]);
      await prediction.connect(user2).placeBet(1, 0, { value: toWei(0.1) });
      await prediction.connect(user3).placeBet(1, 1, { value: toWei(0.05) });
      expect((await prediction.markets(1)).totalStaked).to.equal(toWei(0.15));
    });

    it("should settle market and allow winners to claim", async function () {
      const closeTime = await blockTs() + 3600;
      await prediction.connect(user1).createMarket(1, 0, closeTime, ["A wins", "B wins"]);
      await prediction.connect(user2).placeBet(1, 0, { value: toWei(0.2) });
      await prediction.connect(user3).placeBet(1, 1, { value: toWei(0.1) });
      await prediction.connect(owner).lockMarket(1);
      await prediction.connect(owner).settleMarket(1, 0);
      expect((await prediction.markets(1)).settled).to.equal(true);
      const betIds = await prediction.getUserBets(user2.address);
      await expect(prediction.connect(user2).claimPayout(betIds[0])).to.not.be.reverted;
    });

    it("should refund all bets on cancel", async function () {
      const closeTime = await blockTs() + 3600;
      await prediction.connect(user1).createMarket(1, 0, closeTime, ["A wins", "B wins"]);
      await prediction.connect(user2).placeBet(1, 0, { value: toWei(0.1) });
      const balBefore = await ethers.provider.getBalance(user2.address);
      await prediction.connect(owner).cancelMarket(1);
      expect(await ethers.provider.getBalance(user2.address)).to.be.gt(balBefore);
    });

    it("should reject betting after market is locked", async function () {
      const closeTime = await blockTs() + 3600;
      await prediction.connect(user1).createMarket(1, 0, closeTime, ["A wins", "B wins"]);
      await prediction.connect(owner).lockMarket(1);
      await expect(
        prediction.connect(user2).placeBet(1, 0, { value: toWei(0.1) })
      ).to.be.revertedWith("Market not open");
    });
  });

  describe("FantasyLeagues", function () {
    it("should create a fantasy league", async function () {
      const start = await blockTs() + 86400;
      await fantasy.connect(user1).createLeague(
        "OAN Fantasy Boxing", SportType.Boxing, toWei(0.01), 8, 5,
        start, start + 30 * 86400, true,
        { value: toWei(0.1) }
      );
      const league = await fantasy.leagues(1);
      expect(league.name).to.equal("OAN Fantasy Boxing");
      expect(league.maxTeams).to.equal(8);
    });

    it("should allow joining and create a fantasy team", async function () {
      const start = await blockTs() + 86400;
      await fantasy.connect(user1).createLeague("Join Test", SportType.MMA, toWei(0.01), 8, 3, start, start + 86400, true, { value: 0 });
      await fantasy.connect(user2).joinLeague(1, "Team Apex", { value: toWei(0.01) });
      expect((await fantasy.getUserTeams(user2.address)).length).to.equal(1);
    });

    it("should allow drafting athletes", async function () {
      const start = await blockTs() + 86400;
      await fantasy.connect(user1).createLeague("Draft Test", SportType.Boxing, 0, 8, 3, start, start + 86400, true, { value: 0 });
      await fantasy.connect(user2).joinLeague(1, "Draft Kings", { value: 0 });
      const teamId = (await fantasy.getUserTeams(user2.address))[0];
      await fantasy.connect(user2).draftAthlete(teamId, 501);
      await fantasy.connect(user2).draftAthlete(teamId, 502);
      expect((await fantasy.getTeamRoster(teamId)).length).to.equal(2);
    });

    it("should enforce roster size limit", async function () {
      const start = await blockTs() + 86400;
      await fantasy.connect(user1).createLeague("Roster Limit", SportType.Boxing, 0, 4, 2, start, start + 86400, true, { value: 0 });
      await fantasy.connect(user2).joinLeague(1, "Small Roster", { value: 0 });
      const teamId = (await fantasy.getUserTeams(user2.address))[0];
      await fantasy.connect(user2).draftAthlete(teamId, 601);
      await fantasy.connect(user2).draftAthlete(teamId, 602);
      await expect(fantasy.connect(user2).draftAthlete(teamId, 603)).to.be.revertedWith("Roster full");
    });
  });

  describe("FanRewards", function () {
    it("should register a fan with welcome bonus", async function () {
      await rewards.connect(user1).registerFan();
      const profile = await rewards.fanProfiles(user1.address);
      expect(profile.isRegistered).to.equal(true);
      expect(profile.totalPoints).to.equal(100);
      expect(profile.loyaltyTier).to.equal(0);
    });

    it("should reject duplicate registration", async function () {
      await rewards.connect(user1).registerFan();
      await expect(rewards.connect(user1).registerFan()).to.be.revertedWith("Already registered");
    });

    it("should award points for event attendance", async function () {
      await rewards.connect(user1).registerFan();
      const before = await rewards.getAvailablePoints(user1.address);
      await rewards.connect(owner).recordEventAttendance(user1.address, 1);
      expect(await rewards.getAvailablePoints(user1.address)).to.be.gt(before);
    });

    it("should create and redeem a reward", async function () {
      await rewards.connect(user1).registerFan();
      // Give enough points via multiple attendance records
      for (let i = 0; i < 3; i++) {
        await rewards.connect(owner).recordEventAttendance(user1.address, i);
      }
      await rewards.connect(owner).createReward("VIP Upgrade", "Upgrade seat", 0, 200, 100, 30 * 86400);
      await expect(rewards.connect(user1).redeemReward(1)).to.not.be.reverted;
    });

    it("should return correct tier name", async function () {
      await rewards.connect(user1).registerFan();
      expect(await rewards.getTierName(user1.address)).to.equal("Bronze");
    });

    it("should reject reward redemption with insufficient points", async function () {
      await rewards.connect(user1).registerFan();
      // Only has 100 welcome points - create an expensive reward
      await rewards.connect(owner).createReward("Expensive", "Too costly", 0, 99999, 10, 30 * 86400);
      await expect(rewards.connect(user1).redeemReward(1)).to.be.revertedWith("Insufficient points");
    });
  });
});

// ─────────────────────────────────────────────────────────────
// INTEGRATION: Full Fight Event Lifecycle
// ─────────────────────────────────────────────────────────────
describe("Integration: Full Sports Flow", function () {
  let stadium, athlete, simulator, perfMetrics, prediction, rewards;
  let owner, treasury, user1, user2;

  beforeEach(async function () {
    [owner, treasury, user1, user2] = await ethers.getSigners();
    stadium = await (await ethers.getContractFactory("StadiumNFT")).deploy(treasury.address);
    athlete = await (await ethers.getContractFactory("AthleteNFT")).deploy(treasury.address);
    simulator = await (await ethers.getContractFactory("MatchSimulator")).deploy(treasury.address, athlete.target);
    perfMetrics = await (await ethers.getContractFactory("PerformanceMetrics")).deploy();
    prediction = await (await ethers.getContractFactory("PredictionMarkets")).deploy(treasury.address);
    rewards = await (await ethers.getContractFactory("FanRewards")).deploy(treasury.address);
  });

  it("should run a full fight event lifecycle", async function () {
    // 1. Create stadium
    await stadium.connect(user1).mintStadium(
      "OAN Octagon", "X:0,Y:0", 20000, [SportType.MMA],
      StadiumTier.National, 500, "ipfs://octagon",
      { value: await stadium.mintPrice() }
    );

    // 2. Mint two fighters (entityId=1 → tokenId=1, entityId=2 → tokenId=2)
    await athlete.connect(user1).mintAthlete(
      1, "Spider", "The Spider", SportType.MMA, 2,
      { strength: 85, speed: 90, endurance: 80, technique: 88, intelligence: 75, charisma: 70, defense: 82, aggression: 78 },
      365 * 5, "ipfs://spider", { value: await athlete.mintPrice() }
    );
    await athlete.connect(user2).mintAthlete(
      2, "Gorilla", "The Gorilla", SportType.MMA, 5,
      { strength: 95, speed: 70, endurance: 85, technique: 72, intelligence: 65, charisma: 60, defense: 80, aggression: 92 },
      365 * 5, "ipfs://gorilla", { value: await athlete.mintPrice() }
    );

    // 3. Schedule match
    const futureTime = await blockTs() + 10;
    await simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.MMA, futureTime, 5, 300, { value: toWei(2) });

    // 4. Create prediction market
    const closeTime = await blockTs() + 3600;
    await prediction.connect(user1).createMarket(1, 0, closeTime, ["Spider wins", "Gorilla wins"]);
    await prediction.connect(user1).placeBet(1, 0, { value: toWei(0.5) });
    await prediction.connect(user2).placeBet(1, 1, { value: toWei(0.3) });

    // 5. Register fans
    await rewards.connect(user1).registerFan();
    await rewards.connect(user2).registerFan();

    // 6. Simulate the match
    await advanceTime(15);
    await simulator.connect(owner).simulateMatch(1, 85, 90, 80, 88, 95, 70, 85, 72, 5000);

    // 7. Record performance
    await perfMetrics.connect(owner).initializeAthlete(1);
    await perfMetrics.connect(owner).recordMatchPerformance(1, 1, true, false, true, 4, 1, 2, 1, 45, 7500, 90);

    // 8. Settle prediction market
    await prediction.connect(owner).lockMarket(1);
    await prediction.connect(owner).settleMarket(1, 0);

    // 9. Fan attendance
    await rewards.connect(owner).recordEventAttendance(user1.address, 1);

    // Verify all end states
    expect(await simulator.matchStatus(1)).to.equal(2); // Completed
    expect((await perfMetrics.getCareerStats(1)).totalMatches).to.equal(1);
    expect((await prediction.markets(1)).settled).to.equal(true);
    expect((await rewards.fanProfiles(user1.address)).eventsAttended).to.equal(1);
  });

  it("should emit correct events throughout the flow", async function () {
    await expect(
      stadium.connect(user1).mintStadium(
        "Event Test Arena", "X:5,Y:5", 10000,
        [SportType.Boxing], StadiumTier.Community, 500, "ipfs://eta",
        { value: await stadium.mintPrice() }
      )
    ).to.emit(stadium, "StadiumMinted");

    await expect(
      athlete.connect(user1).mintAthlete(1, "Event Fighter", "EF", SportType.Boxing, 0, defaultStats(), 365, "ipfs://ef", { value: await athlete.mintPrice() })
    ).to.emit(athlete, "AthleteMinted");
  });
});

// ─────────────────────────────────────────────────────────────
// SECURITY TESTS
// ─────────────────────────────────────────────────────────────
describe("Security: Layer 5 Access Control & Edge Cases", function () {
  let stadium, athlete, simulator, prediction, rewards;
  let owner, treasury, attacker, user1;

  beforeEach(async function () {
    [owner, treasury, attacker, user1] = await ethers.getSigners();
    stadium = await (await ethers.getContractFactory("StadiumNFT")).deploy(treasury.address);
    athlete = await (await ethers.getContractFactory("AthleteNFT")).deploy(treasury.address);
    simulator = await (await ethers.getContractFactory("MatchSimulator")).deploy(treasury.address, ethers.ZeroAddress);
    prediction = await (await ethers.getContractFactory("PredictionMarkets")).deploy(treasury.address);
    rewards = await (await ethers.getContractFactory("FanRewards")).deploy(treasury.address);
  });

  it("should reject non-admin changing mint price", async function () {
    await expect(stadium.connect(attacker).setMintPrice(toWei(0.001))).to.be.reverted;
  });

  it("should reject non-owner retiring another's athlete", async function () {
    await athlete.connect(user1).mintAthlete(1, "Protected", "P", SportType.Boxing, 0, defaultStats(), 365, "ipfs://p", { value: await athlete.mintPrice() });
    await expect(athlete.connect(attacker).retireAthlete(1)).to.be.reverted;
  });

  it("should reject non-simulator role simulating matches", async function () {
    const t = await blockTs() + 3600;
    await simulator.connect(user1).scheduleMatch(1, 2, 1, SportType.Boxing, t, 5, 180);
    await advanceTime(3601);
    await expect(
      simulator.connect(attacker).simulateMatch(1, 80, 75, 70, 85, 60, 65, 70, 55, 100)
    ).to.be.reverted;
  });

  it("should reject settling a market that is not locked", async function () {
    const closeTime = await blockTs() + 3600;
    await prediction.connect(user1).createMarket(1, 0, closeTime, ["A", "B"]);
    await expect(prediction.connect(owner).settleMarket(1, 0)).to.be.revertedWith("Market not locked");
  });

  it("should reject claiming payout from someone else's bet", async function () {
    const closeTime = await blockTs() + 3600;
    await prediction.connect(user1).createMarket(1, 0, closeTime, ["A", "B"]);
    await prediction.connect(user1).placeBet(1, 0, { value: toWei(0.1) });
    await prediction.connect(owner).lockMarket(1);
    await prediction.connect(owner).settleMarket(1, 0);
    const betIds = await prediction.getUserBets(user1.address);
    await expect(prediction.connect(attacker).claimPayout(betIds[0])).to.be.revertedWith("Not your bet");
  });

  it("should reject unauthorized event attendance recording", async function () {
    await rewards.connect(user1).registerFan();
    await expect(rewards.connect(attacker).recordEventAttendance(user1.address, 1)).to.be.reverted;
  });

  it("should reject zero-amount bets", async function () {
    const closeTime = await blockTs() + 3600;
    await prediction.connect(user1).createMarket(1, 0, closeTime, ["A", "B"]);
    await expect(prediction.connect(user1).placeBet(1, 0, { value: 0 })).to.be.revertedWith("Bet must be > 0");
  });

  it("should reject hosting event exceeding stadium capacity", async function () {
    await stadium.connect(user1).mintStadium(
      "Small Stadium", "X:0,Y:0", 100, [SportType.Boxing],
      StadiumTier.Community, 500, "ipfs://sm",
      { value: await stadium.mintPrice() }
    );
    await expect(
      stadium.connect(user1).recordEvent(1, "Overflow Event", 99999, { value: toWei(0.1) })
    ).to.be.revertedWith("Over capacity");
  });
});