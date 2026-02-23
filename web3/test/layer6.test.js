const { expect } = require("chai");
const { ethers }  = require("hardhat");

// ─── helpers ────────────────────────────────────────────────
const toWei       = (n) => ethers.parseEther(String(n));
const blockTs     = async () => (await ethers.provider.getBlock("latest")).timestamp;
const advanceTime = async (secs) => {
  await ethers.provider.send("evm_increaseTime", [secs]);
  await ethers.provider.send("evm_mine");
};

// ── StadiumNFT: constructor(address treasury)
//    mintStadium(name, location, capacity, sportTypes[], tier, hostingFeeBps, tokenURI)
async function deployNFT(owner) {
  const F   = await ethers.getContractFactory("StadiumNFT");
  const nft = await F.deploy(owner.address);
  await nft.waitForDeployment();
  return nft;
}

async function mintOne(nft, signer) {
  return nft.connect(signer).mintStadium(
    "Test Stadium", "X:0,Y:0,Z:0", 5000,
    [0],   // SportType.Boxing
    0,     // StadiumTier.Community
    500,   // 5% hosting fee
    "ipfs://meta",
    { value: toWei(0.1) }
  );
}

// ════════════════════════════════════════════════════════════
// PHASE 6.1 – Universal Asset Trading
// ════════════════════════════════════════════════════════════
describe("Phase 6.1: Universal Asset Trading", function () {

  describe("UniversalMarketplace", function () {
    let market, nft, owner, seller, buyer;
    beforeEach(async () => {
      [owner, seller, buyer] = await ethers.getSigners();
      const MF = await ethers.getContractFactory("UniversalMarketplace");
      market   = await MF.deploy(owner.address);
      await market.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, seller);
      await nft.connect(seller).setApprovalForAll(await market.getAddress(), true);
    });

    it("should list an ERC-721 item", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      const l = await market.listings(1);
      expect(l.seller).to.equal(seller.address);
      expect(l.price).to.equal(toWei(0.5));
    });

    it("should buy a listed item and transfer NFT", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      await market.connect(buyer).buyItem(1, { value: toWei(0.5) });
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
      expect((await market.listings(1)).status).to.equal(1);
    });

    it("should reject buy with insufficient payment", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      await expect(market.connect(buyer).buyItem(1, { value: toWei(0.1) }))
        .to.be.revertedWith("Insufficient payment");
    });

    it("should cancel a listing", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      await market.connect(seller).cancelListing(1);
      expect((await market.listings(1)).status).to.equal(2);
    });

    it("should update listing price", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      await market.connect(seller).updatePrice(1, toWei(1.0));
      expect((await market.listings(1)).price).to.equal(toWei(1.0));
    });

    it("should set creator royalty", async () => {
      await market.connect(seller).setCreatorRoyalty(await nft.getAddress(), 1, 500);
      expect(await market.creatorRoyaltyBps(await nft.getAddress(), 1)).to.equal(500);
    });

    it("should return user listings", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      expect((await market.getUserListings(seller.address)).length).to.equal(1);
    });

    it("should track total volume after sale", async () => {
      await market.connect(seller).listItem(await nft.getAddress(), 1, 1, toWei(0.5), 0, 7*86400, "sports");
      await market.connect(buyer).buyItem(1, { value: toWei(0.5) });
      expect(await market.totalVolume()).to.equal(toWei(0.5));
    });
  });

  describe("AuctionHouse", function () {
    let auction, nft, owner, seller, bidder1, bidder2;
    beforeEach(async () => {
      [owner, seller, bidder1, bidder2] = await ethers.getSigners();
      const AF = await ethers.getContractFactory("AuctionHouse");
      auction  = await AF.deploy(owner.address);
      await auction.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, seller);
      await nft.connect(seller).setApprovalForAll(await auction.getAddress(), true);
    });

    it("should create an English auction", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      expect((await auction.auctions(1)).auctionType).to.equal(0);
    });

    it("should place a bid", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      await auction.connect(bidder1).placeBid(1, { value: toWei(0.15) });
      expect((await auction.auctions(1)).currentBidder).to.equal(bidder1.address);
    });

    it("should reject bid below minimum", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      await expect(auction.connect(bidder1).placeBid(1, { value: toWei(0.05) }))
        .to.be.revertedWith("Bid too low");
    });

    it("should store refund for outbid bidder", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      await auction.connect(bidder1).placeBid(1, { value: toWei(0.15) });
      await auction.connect(bidder2).placeBid(1, { value: toWei(0.2) });
      expect(await auction.pendingReturns(bidder1.address)).to.equal(toWei(0.15));
    });

    it("should settle auction after end time", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      await auction.connect(bidder1).placeBid(1, { value: toWei(0.2) });
      await advanceTime(3700);
      await auction.settleAuction(1);
      expect(await nft.ownerOf(1)).to.equal(bidder1.address);
    });

    it("should create Dutch auction and return start price", async () => {
      await auction.connect(seller).createDutchAuction(
        await nft.getAddress(), 1, 1, 0, toWei(1), toWei(0.1), 3600
      );
      expect(await auction.getDutchPrice(1)).to.equal(toWei(1));
    });

    it("should buy Dutch auction at start price", async () => {
      await auction.connect(seller).createDutchAuction(
        await nft.getAddress(), 1, 1, 0, toWei(1), toWei(0.1), 3600
      );
      await auction.connect(bidder1).buyDutch(1, { value: toWei(1) });
      expect(await nft.ownerOf(1)).to.equal(bidder1.address);
    });

    it("should cancel English auction with no bids", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      await auction.connect(seller).cancelAuction(1);
      expect(await nft.ownerOf(1)).to.equal(seller.address);
    });

    it("should let outbid bidder withdraw pending return", async () => {
      await auction.connect(seller).createEnglishAuction(
        await nft.getAddress(), 1, 1, 0, toWei(0.1), toWei(0.05), 3600, toWei(0.01)
      );
      await auction.connect(bidder1).placeBid(1, { value: toWei(0.15) });
      await auction.connect(bidder2).placeBid(1, { value: toWei(0.2) });
      await auction.connect(bidder1).withdraw();
      expect(await auction.pendingReturns(bidder1.address)).to.equal(0);
    });
  });

  describe("BundleMarketplace", function () {
    let bundle, nft, owner, seller, buyer;
    beforeEach(async () => {
      [owner, seller, buyer] = await ethers.getSigners();
      const BF = await ethers.getContractFactory("BundleMarketplace");
      bundle   = await BF.deploy(owner.address);
      await bundle.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, seller);
      await mintOne(nft, seller);
      await nft.connect(seller).setApprovalForAll(await bundle.getAddress(), true);
    });

    it("should create a bundle", async () => {
      const items = [
        { nftContract: await nft.getAddress(), tokenId: 1, amount: 1, tokenType: 0 },
        { nftContract: await nft.getAddress(), tokenId: 2, amount: 1, tokenType: 0 },
      ];
      await bundle.connect(seller).createBundle("Pack", "Two stadiums", items, toWei(0.5), 7*86400, 1000);
      expect((await bundle.bundles(1)).seller).to.equal(seller.address);
    });

    it("should buy bundle and receive all NFTs", async () => {
      const items = [
        { nftContract: await nft.getAddress(), tokenId: 1, amount: 1, tokenType: 0 },
        { nftContract: await nft.getAddress(), tokenId: 2, amount: 1, tokenType: 0 },
      ];
      await bundle.connect(seller).createBundle("Pack", "Two stadiums", items, toWei(0.5), 7*86400, 1000);
      await bundle.connect(buyer).buyBundle(1, { value: toWei(0.5) });
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
      expect(await nft.ownerOf(2)).to.equal(buyer.address);
    });

    it("should reject bundle with fewer than 2 items", async () => {
      const items = [{ nftContract: await nft.getAddress(), tokenId: 1, amount: 1, tokenType: 0 }];
      await expect(
        bundle.connect(seller).createBundle("Solo", "One item", items, toWei(0.5), 7*86400, 0)
      ).to.be.revertedWith("2-20 items");
    });

    it("should cancel bundle and return NFTs", async () => {
      const items = [
        { nftContract: await nft.getAddress(), tokenId: 1, amount: 1, tokenType: 0 },
        { nftContract: await nft.getAddress(), tokenId: 2, amount: 1, tokenType: 0 },
      ];
      await bundle.connect(seller).createBundle("Pack", "Two stadiums", items, toWei(0.5), 7*86400, 0);
      await bundle.connect(seller).cancelBundle(1);
      expect(await nft.ownerOf(1)).to.equal(seller.address);
    });
  });

  describe("OfferSystem", function () {
    let offerSys, nft, owner, offerer, nftOwner;
    beforeEach(async () => {
      [owner, offerer, nftOwner] = await ethers.getSigners();
      const OF = await ethers.getContractFactory("OfferSystem");
      offerSys = await OF.deploy(owner.address);
      await offerSys.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, nftOwner);
      await nft.connect(nftOwner).setApprovalForAll(await offerSys.getAddress(), true);
    });

    it("should make an offer", async () => {
      await offerSys.connect(offerer).makeOffer(
        await nft.getAddress(), 1, 1, 0, 86400, "Want this!", { value: toWei(0.3) }
      );
      expect((await offerSys.offers(1)).offerPrice).to.equal(toWei(0.3));
    });

    it("should accept an offer and transfer NFT", async () => {
      await offerSys.connect(offerer).makeOffer(
        await nft.getAddress(), 1, 1, 0, 86400, "Want this!", { value: toWei(0.3) }
      );
      await offerSys.connect(nftOwner).acceptOffer(1);
      expect(await nft.ownerOf(1)).to.equal(offerer.address);
    });

    it("should reject an offer", async () => {
      await offerSys.connect(offerer).makeOffer(
        await nft.getAddress(), 1, 1, 0, 86400, "Want this!", { value: toWei(0.3) }
      );
      await offerSys.connect(nftOwner).rejectOffer(1);
      expect((await offerSys.offers(1)).status).to.equal(2);
    });

    it("should cancel and refund offer", async () => {
      await offerSys.connect(offerer).makeOffer(
        await nft.getAddress(), 1, 1, 0, 86400, "Want this!", { value: toWei(0.3) }
      );
      const before = await ethers.provider.getBalance(offerer.address);
      await offerSys.connect(offerer).cancelOffer(1);
      expect(await ethers.provider.getBalance(offerer.address)).to.be.gt(before);
    });

    it("should make a counter offer", async () => {
      await offerSys.connect(offerer).makeOffer(
        await nft.getAddress(), 1, 1, 0, 86400, "Want this!", { value: toWei(0.3) }
      );
      await offerSys.connect(nftOwner).makeCounterOffer(1, toWei(0.5));
      expect((await offerSys.getCounterOffers(1)).length).to.equal(1);
    });

    it("should claim back expired offer", async () => {
      await offerSys.connect(offerer).makeOffer(
        await nft.getAddress(), 1, 1, 0, 3600, "Expire me", { value: toWei(0.2) }
      );
      await advanceTime(3700);
      await offerSys.connect(offerer).claimExpiredOffer(1);
      expect((await offerSys.offers(1)).status).to.equal(4);
    });
  });
});

// ════════════════════════════════════════════════════════════
// PHASE 6.2 – AI Tools & Modules
// ════════════════════════════════════════════════════════════
describe("Phase 6.2: AI Tools & Modules", function () {

  describe("AIToolMarketplace", function () {
    let aiMarket, owner, creator, buyer;
    beforeEach(async () => {
      [owner, creator, buyer] = await ethers.getSigners();
      aiMarket = await (await ethers.getContractFactory("AIToolMarketplace")).deploy(owner.address);
      await aiMarket.waitForDeployment();
    });

    it("should list an AI tool", async () => {
      await aiMarket.connect(creator).listTool("CombatAI","Fighter",0,0,toWei(0.1),toWei(0.01),"ipfs://","1.0");
      expect((await aiMarket.tools(1)).name).to.equal("CombatAI");
    });
    it("should purchase a tool (perpetual)", async () => {
      await aiMarket.connect(creator).listTool("CombatAI","Fighter",0,0,toWei(0.1),toWei(0.01),"ipfs://","1.0");
      await aiMarket.connect(buyer).purchaseTool(1,0,{ value: toWei(0.1) });
      expect(await aiMarket.hasAccess(buyer.address,1)).to.equal(true);
    });
    it("should reject purchasing own tool", async () => {
      await aiMarket.connect(creator).listTool("CombatAI","Fighter",0,0,toWei(0.1),toWei(0.01),"ipfs://","1.0");
      await expect(aiMarket.connect(creator).purchaseTool(1,0,{ value: toWei(0.1) }))
        .to.be.revertedWith("Cannot buy own tool");
    });
    it("should rate a tool after purchase", async () => {
      await aiMarket.connect(creator).listTool("CombatAI","Fighter",0,0,toWei(0.1),toWei(0.01),"ipfs://","1.0");
      await aiMarket.connect(buyer).purchaseTool(1,0,{ value: toWei(0.1) });
      await aiMarket.connect(buyer).rateTool(1,5);
      expect((await aiMarket.tools(1)).ratingCount).to.equal(1);
    });
    it("should verify a tool (curator only)", async () => {
      await aiMarket.connect(creator).listTool("CombatAI","Fighter",0,0,toWei(0.1),toWei(0.01),"ipfs://","1.0");
      await aiMarket.connect(owner).verifyTool(1);
      expect((await aiMarket.tools(1)).isVerified).to.equal(true);
    });
    it("should reject rating without owning", async () => {
      await aiMarket.connect(creator).listTool("CombatAI","Fighter",0,0,toWei(0.1),toWei(0.01),"ipfs://","1.0");
      await expect(aiMarket.connect(buyer).rateTool(1,5)).to.be.revertedWith("Must own tool to rate");
    });
  });

  describe("ModuleRegistry", function () {
    let registry, author;
    beforeEach(async () => {
      [, author] = await ethers.getSigners();
      registry = await (await ethers.getContractFactory("ModuleRegistry")).deploy();
      await registry.waitForDeployment();
    });
    it("should register a module", async () => {
      await registry.connect(author).registerModule("CombatTree","Tree",0,"1.0",["combat"],"h","ipfs://",[]);
      expect((await registry.modules(1)).name).to.equal("CombatTree");
    });
    it("should reject duplicate module name", async () => {
      await registry.connect(author).registerModule("CombatTree","Tree",0,"1.0",[],"h","ipfs://",[]);
      await expect(registry.connect(author).registerModule("CombatTree","Dup",0,"1.0",[],"h2","ipfs://2",[]))
        .to.be.revertedWith("Name taken");
    });
    it("should update a module", async () => {
      await registry.connect(author).registerModule("NavModule","Nav",4,"1.0",[],"h","ipfs://v1",[]);
      await registry.connect(author).updateModule(1,"2.0","ipfs://v2");
      expect((await registry.modules(1)).version).to.equal("2.0");
    });
    it("should track active module count", async () => {
      await registry.connect(author).registerModule("Mod1","First",0,"1.0",[],"h1","ipfs://1",[]);
      await registry.connect(author).registerModule("Mod2","Second",1,"1.0",[],"h2","ipfs://2",[]);
      expect(await registry.activeModules()).to.equal(2);
    });
  });

  describe("ToolLicensing", function () {
    let licensing, owner, licensor, licensee, addr4;
    beforeEach(async () => {
      [owner, licensor, licensee, addr4] = await ethers.getSigners();
      licensing = await (await ethers.getContractFactory("ToolLicensing")).deploy(owner.address);
      await licensing.waitForDeployment();
    });
    it("should create a license template", async () => {
      await licensing.connect(licensor).createTemplate(1,0,0,toWei(0.05),100,50,false,true,"ipfs://",500);
      expect((await licensing.templates(1)).licensor).to.equal(licensor.address);
    });
    it("should acquire a license", async () => {
      await licensing.connect(licensor).createTemplate(1,0,0,toWei(0.05),100,50,false,true,"ipfs://",500);
      await licensing.connect(licensee).acquireLicense(1,{ value: toWei(0.05) });
      expect(await licensing.isLicenseValid(licensee.address,1)).to.equal(true);
    });
    it("should reject license beyond max users", async () => {
      await licensing.connect(licensor).createTemplate(1,0,0,toWei(0.05),1,50,false,true,"ipfs://",0);
      await licensing.connect(licensee).acquireLicense(1,{ value: toWei(0.05) });
      await expect(licensing.connect(addr4).acquireLicense(1,{ value: toWei(0.05) }))
        .to.be.revertedWith("License limit reached");
    });
  });

  describe("ToolRating", function () {
    let rating, reviewer, reviewer2;
    beforeEach(async () => {
      [, reviewer, reviewer2] = await ethers.getSigners();
      rating = await (await ethers.getContractFactory("ToolRating")).deploy();
      await rating.waitForDeployment();
    });
    it("should submit a review", async () => {
      await rating.connect(reviewer).submitReview(1,5,"Excellent","Best tool I have used");
      expect((await rating.reviews(1)).rating).to.equal(5);
    });
    it("should reject duplicate reviews", async () => {
      await rating.connect(reviewer).submitReview(1,5,"Great","Really good tool here");
      await expect(rating.connect(reviewer).submitReview(1,4,"Again","Trying to review twice"))
        .to.be.revertedWith("Already reviewed");
    });
    it("should vote helpful on a review", async () => {
      await rating.connect(reviewer).submitReview(1,5,"Excellent","Best tool I have used");
      await rating.connect(reviewer2).voteHelpful(1,true);
      expect((await rating.reviews(1)).helpfulVotes).to.equal(1);
    });
    it("should flag a review", async () => {
      await rating.connect(reviewer).submitReview(1,1,"Bad","Terrible tool to use!");
      await rating.connect(reviewer2).flagReview(1);
      expect((await rating.reviews(1)).isFlagged).to.equal(true);
    });
    it("should update tool star counts correctly", async () => {
      await rating.connect(reviewer).submitReview(1,5,"Perfect","Absolutely love this tool");
      expect((await rating.toolStats(1)).fiveStars).to.equal(1);
    });
  });
});

// ════════════════════════════════════════════════════════════
// PHASE 6.3 – Creator Economy
// ════════════════════════════════════════════════════════════
describe("Phase 6.3: Creator Economy", function () {

  describe("CreatorProfiles", function () {
    let profiles, owner, creator1, creator2, follower;
    beforeEach(async () => {
      [owner, creator1, creator2, follower] = await ethers.getSigners();
      profiles = await (await ethers.getContractFactory("CreatorProfiles")).deploy();
      await profiles.waitForDeployment();
    });
    it("should create a creator profile", async () => {
      await profiles.connect(creator1).createProfile("krizz","OAN builder","ipfs://a",["contracts"],"ipfs://p");
      expect((await profiles.profiles(1)).username).to.equal("krizz");
    });
    it("should reject duplicate profile", async () => {
      await profiles.connect(creator1).createProfile("krizz","bio","ipfs://a",[],"ipfs://p");
      await expect(profiles.connect(creator1).createProfile("krizz2","bio","ipfs://a",[],"ipfs://p"))
        .to.be.revertedWith("Already has profile");
    });
    it("should reject taken username", async () => {
      await profiles.connect(creator1).createProfile("krizz","bio","ipfs://a",[],"ipfs://p");
      await expect(profiles.connect(creator2).createProfile("krizz","bio2","ipfs://a2",[],"ipfs://p2"))
        .to.be.revertedWith("Username taken");
    });
    it("should add portfolio item", async () => {
      await profiles.connect(creator1).createProfile("krizz","bio","ipfs://a",[],"ipfs://p");
      await profiles.connect(creator1).addPortfolioItem(ethers.ZeroAddress,1,"NFT","Great",true);
      expect((await profiles.getPortfolio(1)).length).to.equal(1);
    });
    it("should follow a creator", async () => {
      await profiles.connect(creator1).createProfile("krizz","bio","ipfs://a",[],"ipfs://p");
      await profiles.connect(follower).follow(1);
      expect((await profiles.profiles(1)).followersCount).to.equal(1);
    });
    it("should reject self-follow", async () => {
      await profiles.connect(creator1).createProfile("krizz","bio","ipfs://a",[],"ipfs://p");
      await expect(profiles.connect(creator1).follow(1)).to.be.revertedWith("Cannot follow self");
    });
    it("should verify a profile (verifier only)", async () => {
      await profiles.connect(creator1).createProfile("krizz","bio","ipfs://a",[],"ipfs://p");
      await profiles.connect(owner).verifyProfile(1);
      expect((await profiles.profiles(1)).isVerified).to.equal(true);
    });
  });

  describe("CommissionSystem", function () {
    let commissions, owner, client, creator;
    beforeEach(async () => {
      [owner, client, creator] = await ethers.getSigners();
      commissions = await (await ethers.getContractFactory("CommissionSystem")).deploy(owner.address);
      await commissions.waitForDeployment();
    });
    it("should create a commission", async () => {
      const ts = await blockTs();
      const ms = [{ milestoneId:0, description:"Design", payment:toWei(0.05), completed:false, dueDate:ts+86400, deliverableURI:"" }];
      await commissions.connect(client).createCommission("Custom AI","Build AI",0,ts+86400*7,ms,{ value:toWei(0.1) });
      expect((await commissions.commissions(1)).client).to.equal(client.address);
    });
    it("should apply for a commission", async () => {
      const ts = await blockTs();
      const ms = [{ milestoneId:0, description:"Build", payment:toWei(0.05), completed:false, dueDate:ts+86400, deliverableURI:"" }];
      await commissions.connect(client).createCommission("Test","Desc",0,ts+86400,ms,{ value:toWei(0.1) });
      await commissions.connect(creator).applyForCommission(1);
      expect((await commissions.getApplicants(1))[0]).to.equal(creator.address);
    });
    it("should accept a creator for a commission", async () => {
      const ts = await blockTs();
      const ms = [{ milestoneId:0, description:"Build", payment:toWei(0.05), completed:false, dueDate:ts+86400, deliverableURI:"" }];
      await commissions.connect(client).createCommission("Test","Desc",0,ts+86400,ms,{ value:toWei(0.1) });
      await commissions.connect(creator).applyForCommission(1);
      await commissions.connect(client).acceptCreator(1,creator.address);
      expect((await commissions.commissions(1)).creator).to.equal(creator.address);
    });
  });

  describe("RoyaltyEngine", function () {
    let royalty, owner, creator, marketplace;
    beforeEach(async () => {
      [owner, creator, marketplace] = await ethers.getSigners();
      royalty = await (await ethers.getContractFactory("RoyaltyEngine")).deploy(owner.address);
      await royalty.waitForDeployment();
      await royalty.connect(owner).grantRole(ethers.keccak256(ethers.toUtf8Bytes("MARKETPLACE_ROLE")), marketplace.address);
    });
    it("should set royalty config", async () => {
      await royalty.connect(creator).setRoyalty(ethers.ZeroAddress,1,500,[],[]);
      expect((await royalty.getRoyaltyInfo(ethers.ZeroAddress,1,toWei(1))).royaltyAmount).to.equal(toWei(0.05));
    });
    it("should process royalty payment", async () => {
      await royalty.connect(creator).setRoyalty(ethers.ZeroAddress,1,500,[],[]);
      await royalty.connect(marketplace).processRoyalty(ethers.ZeroAddress,1,marketplace.address,{ value:toWei(1) });
      expect(await royalty.pendingRoyalties(creator.address)).to.equal(toWei(0.05));
    });
    it("should withdraw pending royalties", async () => {
      await royalty.connect(creator).setRoyalty(ethers.ZeroAddress,1,500,[],[]);
      await royalty.connect(marketplace).processRoyalty(ethers.ZeroAddress,1,marketplace.address,{ value:toWei(1) });
      const before = await ethers.provider.getBalance(creator.address);
      await royalty.connect(creator).withdrawRoyalties();
      expect(await ethers.provider.getBalance(creator.address)).to.be.gt(before);
    });
    it("should reject royalty above max", async () => {
      await expect(royalty.connect(creator).setRoyalty(ethers.ZeroAddress,1,2000,[],[]))
        .to.be.revertedWith("Exceeds max royalty");
    });
  });

  describe("CreatorStaking", function () {
    let staking, owner, creator;
    beforeEach(async () => {
      [owner, creator] = await ethers.getSigners();
      staking = await (await ethers.getContractFactory("CreatorStaking")).deploy(owner.address);
      await staking.waitForDeployment();
      // Fund reward pool so unstake has enough ETH to pay principal + any accrued reward
      await staking.connect(owner).fundRewardPool({ value: toWei(1) });
    });
    it("should stake ETH at Bronze tier", async () => {
      await staking.connect(creator).stake(1,{ value:toWei(0.01) });
      expect((await staking.stakes(creator.address)).isActive).to.equal(true);
    });
    it("should reject stake below tier minimum", async () => {
      await expect(staking.connect(creator).stake(2,{ value:toWei(0.001) }))
        .to.be.revertedWith("Insufficient stake");
    });
    it("should slash a creator stake", async () => {
      await staking.connect(creator).stake(1,{ value:toWei(0.01) });
      await staking.connect(owner).slash(creator.address,5000,"Misconduct");
      expect((await staking.stakes(creator.address)).amount).to.equal(toWei(0.005));
    });
    it("should return stake tier", async () => {
      await staking.connect(creator).stake(1,{ value:toWei(0.01) });
      expect(await staking.getStakeTier(creator.address)).to.equal(1);
    });
    it("should unstake after lock expires", async () => {
      await staking.connect(creator).stake(1,{ value:toWei(0.01) });
      await advanceTime(7*86400+1);
      const before = await ethers.provider.getBalance(creator.address);
      await staking.connect(creator).unstake();
      expect(await ethers.provider.getBalance(creator.address)).to.be.gt(before);
    });
  });
});

// ════════════════════════════════════════════════════════════
// PHASE 6.4 – Reputation Marketplace
// ════════════════════════════════════════════════════════════
describe("Phase 6.4: Reputation Marketplace", function () {

  describe("ReputationExchange", function () {
    let repEx, owner, user1, user2;
    beforeEach(async () => {
      [owner, user1, user2] = await ethers.getSigners();
      repEx = await (await ethers.getContractFactory("ReputationExchange")).deploy(owner.address);
      await repEx.waitForDeployment();
      await repEx.connect(owner).setReputation(user1.address,800,0);
    });
    it("should list reputation for rent", async () => {
      await repEx.connect(user1).listReputation(toWei(0.01),0,true,false);
      expect((await repEx.listings(1)).reputationScore).to.equal(800);
    });
    it("should rent reputation", async () => {
      await repEx.connect(user1).listReputation(toWei(0.01),0,true,false);
      await repEx.connect(user2).rentReputation(1,5,{ value:toWei(0.05) });
      expect((await repEx.rentals(1)).renter).to.equal(user2.address);
    });
    it("should sell reputation", async () => {
      await repEx.connect(user1).listReputation(0,toWei(0.5),false,true);
      await repEx.connect(user2).buyReputation(1,{ value:toWei(0.5) });
      expect(await repEx.reputationScores(user2.address)).to.equal(800);
    });
    it("should reject listing without reputation", async () => {
      await expect(repEx.connect(user2).listReputation(toWei(0.01),0,true,false))
        .to.be.revertedWith("No reputation");
    });
  });

  describe("EndorsementNFT", function () {
    let endorsement, endorser, recipient;
    beforeEach(async () => {
      [, endorser, recipient] = await ethers.getSigners();
      endorsement = await (await ethers.getContractFactory("EndorsementNFT")).deploy();
      await endorsement.waitForDeployment();
    });
    it("should issue an endorsement NFT", async () => {
      await endorsement.connect(endorser).issueEndorsement(recipient.address,0,"Solidity",8,"ipfs://",0,"ipfs://");
      expect((await endorsement.endorsements(1)).strength).to.equal(8);
    });
    it("should reject self-endorsement", async () => {
      await expect(endorsement.connect(endorser).issueEndorsement(endorser.address,0,"Solidity",8,"ipfs://",0,"ipfs://"))
        .to.be.revertedWith("No self-endorsement");
    });
    it("should reject duplicate endorsement of same type", async () => {
      await endorsement.connect(endorser).issueEndorsement(recipient.address,0,"Solidity",8,"ipfs://",0,"ipfs://");
      await expect(endorsement.connect(endorser).issueEndorsement(recipient.address,0,"Solidity",5,"ipfs://2",0,"ipfs://2"))
        .to.be.revertedWith("Already endorsed");
    });
    it("should be soulbound — block transfers", async () => {
      await endorsement.connect(endorser).issueEndorsement(recipient.address,0,"Solidity",8,"ipfs://",0,"ipfs://");
      await expect(endorsement.connect(recipient).transferFrom(recipient.address,endorser.address,1))
        .to.be.revertedWith("Soulbound: non-transferable");
    });
    it("should revoke an endorsement", async () => {
      await endorsement.connect(endorser).issueEndorsement(recipient.address,0,"Solidity",8,"ipfs://",0,"ipfs://");
      await endorsement.connect(endorser).revokeEndorsement(1,"Changed mind");
      expect((await endorsement.endorsements(1)).isRevoked).to.equal(true);
    });
  });

  describe("InfluencerMarket", function () {
    let influencer, owner, brand, inf;
    beforeEach(async () => {
      [owner, brand, inf] = await ethers.getSigners();
      influencer = await (await ethers.getContractFactory("InfluencerMarket")).deploy(owner.address);
      await influencer.waitForDeployment();
    });
    it("should register an influencer", async () => {
      await influencer.connect(inf).registerInfluencer(50000,450,["gaming"],toWei(0.1));
      expect((await influencer.influencers(inf.address)).followerCount).to.equal(50000);
    });
    it("should create a campaign", async () => {
      const ts = await blockTs();
      await influencer.connect(brand).createCampaign(0,"Promote",ethers.ZeroAddress,ts+86400*7,"Post 3x",100000,{ value:toWei(0.5) });
      expect((await influencer.campaigns(1)).budget).to.equal(toWei(0.5));
    });
    it("should apply for open campaign", async () => {
      const ts = await blockTs();
      await influencer.connect(brand).createCampaign(0,"Promote",ethers.ZeroAddress,ts+86400,"Post",1000,{ value:toWei(0.1) });
      await influencer.connect(inf).applyForCampaign(1);
      expect((await influencer.getApplicants(1))[0]).to.equal(inf.address);
    });
  });

  describe("TrustScoring", function () {
    let trust, owner, scorer, user;
    beforeEach(async () => {
      [owner, scorer, user] = await ethers.getSigners();
      trust = await (await ethers.getContractFactory("TrustScoring")).deploy();
      await trust.waitForDeployment();
      await trust.connect(owner).grantRole(ethers.keccak256(ethers.toUtf8Bytes("SCORER_ROLE")), scorer.address);
      await trust.connect(scorer).createProfile(user.address);
    });
    it("should create a trust profile at 500", async () => {
      expect(await trust.getTrustScore(user.address)).to.equal(500);
    });
    it("should update score positively", async () => {
      await trust.connect(scorer).updateScore(user.address,100,"trade","Good trade");
      expect(await trust.getTrustScore(user.address)).to.equal(600);
    });
    it("should update score negatively", async () => {
      await trust.connect(scorer).updateScore(user.address,-100,"trade","Scam");
      expect(await trust.getTrustScore(user.address)).to.equal(400);
    });
    it("should update trust level correctly", async () => {
      await trust.connect(scorer).updateScore(user.address,250,"community","Very active");
      expect(await trust.getTrustLevel(user.address)).to.equal("Trusted");
    });
    it("should blacklist a user", async () => {
      await trust.connect(owner).blacklist(user.address,"Fraud");
      expect(await trust.getTrustScore(user.address)).to.equal(0);
    });
  });
});

// ════════════════════════════════════════════════════════════
// PHASE 6.5 – Dynamic Pricing
// ════════════════════════════════════════════════════════════
describe("Phase 6.5: Dynamic Pricing", function () {

  describe("PriceOracles", function () {
    let oracles, owner;
    beforeEach(async () => {
      [owner] = await ethers.getSigners();
      oracles = await (await ethers.getContractFactory("PriceOracles")).deploy();
      await oracles.waitForDeployment();
    });
    it("should create a price feed", async () => {
      await oracles.createFeed("STADIUM",toWei(1));
      expect((await oracles.feeds(1)).assetId).to.equal("STADIUM");
    });
    it("should update price and track history", async () => {
      await oracles.createFeed("STADIUM",toWei(1));
      await oracles.updatePrice(1,toWei(1.5),toWei(10));
      expect((await oracles.feeds(1)).currentPrice).to.equal(toWei(1.5));
    });
    it("should get price by asset ID", async () => {
      await oracles.createFeed("ATHLETE",toWei(0.5));
      const [price,,isStale] = await oracles.getPrice("ATHLETE");
      expect(price).to.equal(toWei(0.5));
      expect(isStale).to.equal(false);
    });
    it("should calculate price change percent", async () => {
      await oracles.createFeed("CARD",toWei(1));
      await oracles.updatePrice(1,toWei(1.1),0);
      expect(await oracles.getPriceChange(1)).to.equal(1000);
    });
    it("should reject duplicate feed", async () => {
      await oracles.createFeed("NFT",toWei(1));
      await expect(oracles.createFeed("NFT",toWei(2))).to.be.revertedWith("Feed already exists");
    });
  });

  describe("DutchAuction", function () {
    let dutchAuction, nft, owner, seller, buyer;
    beforeEach(async () => {
      [owner, seller, buyer] = await ethers.getSigners();
      dutchAuction = await (await ethers.getContractFactory("DutchAuction")).deploy(owner.address);
      await dutchAuction.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, seller);
      await nft.connect(seller).setApprovalForAll(await dutchAuction.getAddress(), true);
    });
    it("should start a Dutch auction", async () => {
      await dutchAuction.connect(seller).startAuction(await nft.getAddress(),1,toWei(1),toWei(0.1),3600,600,toWei(0.1));
      expect((await dutchAuction.auctions(1)).startPrice).to.equal(toWei(1));
    });
    it("should return start price at auction start", async () => {
      await dutchAuction.connect(seller).startAuction(await nft.getAddress(),1,toWei(1),toWei(0.1),3600,600,toWei(0.1));
      expect(await dutchAuction.getCurrentPrice(1)).to.equal(toWei(1));
    });
    it("should drop price after one interval", async () => {
      await dutchAuction.connect(seller).startAuction(await nft.getAddress(),1,toWei(1),toWei(0.1),3600,600,toWei(0.1));
      await advanceTime(600);
      expect(await dutchAuction.getCurrentPrice(1)).to.equal(toWei(0.9));
    });
    it("should allow buying at current price", async () => {
      await dutchAuction.connect(seller).startAuction(await nft.getAddress(),1,toWei(1),toWei(0.1),3600,600,toWei(0.1));
      await dutchAuction.connect(buyer).buy(1,{ value:toWei(1) });
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
    });
    it("should allow seller to reclaim after expiry", async () => {
      await dutchAuction.connect(seller).startAuction(await nft.getAddress(),1,toWei(1),toWei(0.1),3600,600,toWei(0.1));
      await advanceTime(3700);
      await dutchAuction.connect(seller).reclaim(1);
      expect(await nft.ownerOf(1)).to.equal(seller.address);
    });
  });

  describe("BondingCurves", function () {
    let curves, owner, creator, buyer;
    beforeEach(async () => {
      [owner, creator, buyer] = await ethers.getSigners();
      curves = await (await ethers.getContractFactory("BondingCurves")).deploy(owner.address);
      await curves.waitForDeployment();
    });
    it("should create a linear bonding curve", async () => {
      await curves.connect(creator).createCurve("Test Curve",0,toWei(0.001),toWei(0.0001),1000);
      expect((await curves.curves(1)).name).to.equal("Test Curve");
    });
    it("should buy tokens on the curve", async () => {
      await curves.connect(creator).createCurve("Curve",0,toWei(0.001),toWei(0.0001),1000);
      const cost = await curves.calculateBuyCost(1,10);
      await curves.connect(buyer).buy(1,10,{ value:cost });
      expect(await curves.getHoldings(1,buyer.address)).to.equal(10);
    });
    it("should sell tokens back", async () => {
      await curves.connect(creator).createCurve("Curve",0,toWei(0.001),toWei(0.0001),1000);
      const cost = await curves.calculateBuyCost(1,20);
      await curves.connect(buyer).buy(1,20,{ value:cost });
      await curves.connect(buyer).sell(1,10);
      expect(await curves.getHoldings(1,buyer.address)).to.equal(10);
    });
    it("should reject buy exceeding max supply", async () => {
      await curves.connect(creator).createCurve("SmallCurve",0,toWei(0.001),toWei(0.0001),5);
      const cost = await curves.calculateBuyCost(1,10);
      await expect(curves.connect(buyer).buy(1,10,{ value:cost }))
        .to.be.revertedWith("Exceeds max supply");
    });
    it("should increase price after buys (linear)", async () => {
      // Large slope so price visibly increases after 10 purchases
      await curves.connect(creator).createCurve("GrowCurve",0,toWei(0.001),toWei(0.1),1000);
      const priceBefore = await curves.getCurrentPrice(1);
      const cost = await curves.calculateBuyCost(1,10);
      await curves.connect(buyer).buy(1,10,{ value:cost });
      expect(await curves.getCurrentPrice(1)).to.be.gt(priceBefore);
    });
  });

  describe("FloorProtection", function () {
    let floor, owner;
    const FAKE = "0x0000000000000000000000000000000000000001";
    beforeEach(async () => {
      [owner] = await ethers.getSigners();
      floor = await (await ethers.getContractFactory("FloorProtection")).deploy();
      await floor.waitForDeployment();
    });
    it("should set floor config", async () => {
      await floor.setFloorConfig(FAKE,toWei(1),8000);
      expect((await floor.floorConfigs(FAKE)).floorPrice).to.equal(toWei(1));
    });
    it("should fund the reserve", async () => {
      await floor.setFloorConfig(FAKE,toWei(1),8000);
      await floor.fundReserve(FAKE,{ value:toWei(5) });
      expect((await floor.floorConfigs(FAKE)).buybackReserve).to.equal(toWei(5));
    });
    it("should detect buyback trigger correctly", async () => {
      await floor.setFloorConfig(FAKE,toWei(1),8000);
      await floor.fundReserve(FAKE,{ value:toWei(5) });
      expect(await floor.shouldTriggerBuyback(FAKE,toWei(0.7))).to.equal(true);
      expect(await floor.shouldTriggerBuyback(FAKE,toWei(0.9))).to.equal(false);
    });
    it("should trigger a buyback", async () => {
      await floor.setFloorConfig(FAKE,toWei(1),8000);
      await floor.fundReserve(FAKE,{ value:toWei(5) });
      await floor.triggerBuyback(FAKE,42,toWei(0.5));
      expect((await floor.floorConfigs(FAKE)).totalBuybacks).to.equal(1);
    });
    it("should update floor price", async () => {
      await floor.setFloorConfig(FAKE,toWei(1),8000);
      await floor.updateFloor(FAKE,toWei(1.5));
      expect((await floor.floorConfigs(FAKE)).floorPrice).to.equal(toWei(1.5));
    });
  });
});

// ════════════════════════════════════════════════════════════
// PHASE 6.6 – Advanced Trading
// ════════════════════════════════════════════════════════════
describe("Phase 6.6: Advanced Trading", function () {

  describe("SwapProtocol", function () {
    let swap, nft, owner, partyA, partyB;
    beforeEach(async () => {
      [owner, partyA, partyB] = await ethers.getSigners();
      swap = await (await ethers.getContractFactory("SwapProtocol")).deploy(owner.address);
      await swap.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, partyA);  // tokenId 1
      await mintOne(nft, partyB);  // tokenId 2
      await nft.connect(partyA).setApprovalForAll(await swap.getAddress(), true);
      await nft.connect(partyB).setApprovalForAll(await swap.getAddress(), true);
    });
    it("should propose a swap", async () => {
      const offer = [{ nftContract:await nft.getAddress(), tokenId:1, amount:1, tokenType:0 }];
      const want  = [{ nftContract:await nft.getAddress(), tokenId:2, amount:1, tokenType:0 }];
      await swap.connect(partyA).proposeSwap(partyB.address,offer,want,86400,"Swap!");
      expect((await swap.swapOffers(1)).offeror).to.equal(partyA.address);
    });
    it("should accept a swap and exchange NFTs", async () => {
      const offer = [{ nftContract:await nft.getAddress(), tokenId:1, amount:1, tokenType:0 }];
      const want  = [{ nftContract:await nft.getAddress(), tokenId:2, amount:1, tokenType:0 }];
      await swap.connect(partyA).proposeSwap(partyB.address,offer,want,86400,"Swap!");
      await swap.connect(partyB).acceptSwap(1);
      expect(await nft.ownerOf(1)).to.equal(partyB.address);
      expect(await nft.ownerOf(2)).to.equal(partyA.address);
    });
    it("should cancel a swap and return NFT", async () => {
      const offer = [{ nftContract:await nft.getAddress(), tokenId:1, amount:1, tokenType:0 }];
      const want  = [{ nftContract:await nft.getAddress(), tokenId:2, amount:1, tokenType:0 }];
      await swap.connect(partyA).proposeSwap(partyB.address,offer,want,86400,"Swap!");
      await swap.connect(partyA).cancelSwap(1);
      expect(await nft.ownerOf(1)).to.equal(partyA.address);
    });
    it("should reject swap with no items", async () => {
      await expect(swap.connect(partyA).proposeSwap(partyB.address,[],[],86400,"Empty"))
        .to.be.revertedWith("Must offer and want items");
    });
    it("should reject self-swap", async () => {
      const items = [{ nftContract:await nft.getAddress(), tokenId:1, amount:1, tokenType:0 }];
      await expect(swap.connect(partyA).proposeSwap(partyA.address,items,items,86400,"Self"))
        .to.be.revertedWith("No self-swap");
    });
  });

  describe("FractionalOwnership", function () {
    let frac, nft, owner, curator, buyer;
    beforeEach(async () => {
      [owner, curator, buyer] = await ethers.getSigners();
      frac = await (await ethers.getContractFactory("FractionalOwnership")).deploy(owner.address);
      await frac.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, curator);
      await nft.connect(curator).setApprovalForAll(await frac.getAddress(), true);
    });
    it("should fractionalize an NFT into shares", async () => {
      await frac.connect(curator).fractionalize(await nft.getAddress(),1,1000,toWei(0.001),toWei(0.5),"Rare Shares","RS");
      expect((await frac.vaults(1)).totalShares).to.equal(1000);
    });
    it("should create an ERC-20 token for the vault", async () => {
      await frac.connect(curator).fractionalize(await nft.getAddress(),1,1000,toWei(0.001),toWei(0.5),"Rare Shares","RS");
      const token = await ethers.getContractAt("FractionalToken", await frac.vaultTokens(1));
      expect(await token.balanceOf(curator.address)).to.equal(1000);
    });
    it("should initiate a buyout above reserve price", async () => {
      await frac.connect(curator).fractionalize(await nft.getAddress(),1,1000,toWei(0.001),toWei(0.5),"Rare Shares","RS");
      await frac.connect(buyer).initiateBuyout(1,{ value:toWei(0.5) });
      expect((await frac.vaults(1)).buyoutActive).to.equal(true);
    });
    it("should reject buyout below reserve price", async () => {
      await frac.connect(curator).fractionalize(await nft.getAddress(),1,1000,toWei(0.001),toWei(0.5),"Rare Shares","RS");
      await expect(frac.connect(buyer).initiateBuyout(1,{ value:toWei(0.1) }))
        .to.be.revertedWith("Below reserve price");
    });
    it("should complete buyout after 3 days", async () => {
      await frac.connect(curator).fractionalize(await nft.getAddress(),1,1000,toWei(0.001),toWei(0.5),"Rare Shares","RS");
      await frac.connect(buyer).initiateBuyout(1,{ value:toWei(0.5) });
      await advanceTime(3*86400+1);
      await frac.connect(buyer).completeBuyout(1);
      expect(await nft.ownerOf(1)).to.equal(buyer.address);
    });
  });

  describe("RentalMarket", function () {
    let rental, nft, owner, nftOwner, renter;
    beforeEach(async () => {
      [owner, nftOwner, renter] = await ethers.getSigners();
      rental = await (await ethers.getContractFactory("RentalMarket")).deploy(owner.address);
      await rental.waitForDeployment();
      nft = await deployNFT(owner);
      await mintOne(nft, nftOwner);
      await nft.connect(nftOwner).setApprovalForAll(await rental.getAddress(), true);
    });
    it("should list an NFT for rental", async () => {
      await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),1,30);
      expect((await rental.listings(1)).pricePerDay).to.equal(toWei(0.01));
    });
    it("should rent an NFT", async () => {
      await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),1,30);
      await rental.connect(renter).rent(1,1,{ value:toWei(0.11) });
      expect((await rental.listings(1)).currentRenter).to.equal(renter.address);
    });
    it("should reject rent with insufficient payment", async () => {
      await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),1,30);
      await expect(rental.connect(renter).rent(1,1,{ value:toWei(0.01) }))
        .to.be.revertedWith("Insufficient payment");
    });
    it("should return NFT on time and refund collateral", async () => {
      await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),1,30);
      await rental.connect(renter).rent(1,1,{ value:toWei(0.11) });
      const before = await ethers.provider.getBalance(renter.address);
      await rental.connect(renter).returnNFT(1);
      expect(await ethers.provider.getBalance(renter.address)).to.be.gt(before);
    });
    it("should allow owner to withdraw unlisted NFT", async () => {
      await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),1,30);
      await rental.connect(nftOwner).withdrawListing(1);
      expect(await nft.ownerOf(1)).to.equal(nftOwner.address);
    });
    it("should reject duration below minimum", async () => {
      await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),3,30);
      await expect(rental.connect(renter).rent(1,1,{ value:toWei(0.11) }))
        .to.be.revertedWith("Duration out of range");
    });
  });

  describe("DerivativesMarket", function () {
    let derivatives, owner, writer, holder;
    const FAKE = "0x0000000000000000000000000000000000000001";
    beforeEach(async () => {
      [owner, writer, holder] = await ethers.getSigners();
      derivatives = await (await ethers.getContractFactory("DerivativesMarket")).deploy(owner.address);
      await derivatives.waitForDeployment();
      await derivatives.connect(owner).updateFloorPrice(FAKE, toWei(2));
    });
    it("should write a call option", async () => {
      const ts = await blockTs();
      await derivatives.connect(writer).writeOption(FAKE,0,toWei(1.5),toWei(0.05),ts+86400,true,{ value:toWei(0.2) });
      expect((await derivatives.options(1)).optionType).to.equal(0);
    });
    it("should buy a call option", async () => {
      const ts = await blockTs();
      await derivatives.connect(writer).writeOption(FAKE,0,toWei(1.5),toWei(0.05),ts+86400,true,{ value:toWei(0.2) });
      await derivatives.connect(holder).buyOption(1,{ value:toWei(0.05) });
      expect((await derivatives.options(1)).holder).to.equal(holder.address);
    });
    it("should exercise a call option when in the money", async () => {
      const ts = await blockTs();
      await derivatives.connect(writer).writeOption(FAKE,0,toWei(1.5),toWei(0.05),ts+86400,true,{ value:toWei(1) });
      await derivatives.connect(holder).buyOption(1,{ value:toWei(0.05) });
      const before = await ethers.provider.getBalance(holder.address);
      await derivatives.connect(holder).exerciseOption(1);
      expect(await ethers.provider.getBalance(holder.address)).to.be.gt(before);
    });
    it("should expire option and return collateral to writer", async () => {
      const ts = await blockTs();
      await derivatives.connect(writer).writeOption(FAKE,0,toWei(1.5),toWei(0.05),ts+3600,true,{ value:toWei(0.2) });
      await advanceTime(3700);
      const before = await ethers.provider.getBalance(writer.address);
      await derivatives.connect(owner).expireOption(1);
      expect(await ethers.provider.getBalance(writer.address)).to.be.gt(before);
    });
    it("should write a put option with full collateral", async () => {
      const ts = await blockTs();
      await derivatives.connect(writer).writeOption(FAKE,1,toWei(1.5),toWei(0.05),ts+86400,true,{ value:toWei(1.5) });
      expect((await derivatives.options(1)).optionType).to.equal(1);
    });
    it("should reject call option with insufficient collateral", async () => {
      const ts = await blockTs();
      await expect(
        derivatives.connect(writer).writeOption(FAKE,0,toWei(2),toWei(0.05),ts+86400,true,{ value:toWei(0.01) })
      ).to.be.revertedWith("Insufficient call collateral (min 10% of strike)");
    });
  });
});

// ════════════════════════════════════════════════════════════
// INTEGRATION
// ════════════════════════════════════════════════════════════
describe("Integration: Full Layer 6 Trading Flow", function () {
  it("should run a complete list → buy flow", async () => {
    const [owner, seller, buyer] = await ethers.getSigners();
    const market = await (await ethers.getContractFactory("UniversalMarketplace")).deploy(owner.address);
    await market.waitForDeployment();
    const nft = await deployNFT(owner);
    await mintOne(nft, seller);
    await nft.connect(seller).setApprovalForAll(await market.getAddress(), true);
    await market.connect(seller).listItem(await nft.getAddress(),1,1,toWei(1),0,7*86400,"sports");
    await market.connect(buyer).buyItem(1,{ value:toWei(1) });
    expect(await nft.ownerOf(1)).to.equal(buyer.address);
    expect(await market.totalVolume()).to.equal(toWei(1));
  });

  it("should run fractionalise → buyout flow", async () => {
    const [owner, curator, buyer] = await ethers.getSigners();
    const frac = await (await ethers.getContractFactory("FractionalOwnership")).deploy(owner.address);
    await frac.waitForDeployment();
    const nft = await deployNFT(owner);
    await mintOne(nft, curator);
    await nft.connect(curator).setApprovalForAll(await frac.getAddress(), true);
    await frac.connect(curator).fractionalize(await nft.getAddress(),1,1000,toWei(0.001),toWei(0.5),"Shares","SH");
    await frac.connect(buyer).initiateBuyout(1,{ value:toWei(0.5) });
    await advanceTime(3*86400+1);
    await frac.connect(buyer).completeBuyout(1);
    expect(await nft.ownerOf(1)).to.equal(buyer.address);
  });
});

// ════════════════════════════════════════════════════════════
// SECURITY – Access Control & Edge Cases
// ════════════════════════════════════════════════════════════
describe("Security: Layer 6 Access Control & Edge Cases", function () {
  it("should reject non-admin setting platform fee", async () => {
    const [owner, attacker] = await ethers.getSigners();
    // AuctionHouse has setPlatformFee with clear admin guard
    const auction = await (await ethers.getContractFactory("AuctionHouse")).deploy(owner.address);
    await auction.waitForDeployment();
    await expect(auction.connect(attacker).setPlatformFee(9999)).to.be.reverted;
  });

  it("should reject non-oracle updating price feed", async () => {
    const [owner, attacker] = await ethers.getSigners();
    const oracles = await (await ethers.getContractFactory("PriceOracles")).deploy();
    await oracles.waitForDeployment();
    await oracles.createFeed("TEST",toWei(1));
    await expect(oracles.connect(attacker).updatePrice(1,toWei(2),0)).to.be.reverted;
  });

  it("should reject non-guardian triggering buyback", async () => {
    const [owner, attacker] = await ethers.getSigners();
    const floor = await (await ethers.getContractFactory("FloorProtection")).deploy();
    await floor.waitForDeployment();
    const FAKE = "0x0000000000000000000000000000000000000001";
    await floor.setFloorConfig(FAKE,toWei(1),8000);
    await floor.fundReserve(FAKE,{ value:toWei(1) });
    await expect(floor.connect(attacker).triggerBuyback(FAKE,1,toWei(0.5))).to.be.reverted;
  });

  it("should reject non-counterparty accepting a swap", async () => {
    const [owner, partyA, partyB, attacker] = await ethers.getSigners();
    const swap = await (await ethers.getContractFactory("SwapProtocol")).deploy(owner.address);
    await swap.waitForDeployment();
    const nft = await deployNFT(owner);
    await mintOne(nft, partyA);
    await mintOne(nft, partyB);
    await nft.connect(partyA).setApprovalForAll(await swap.getAddress(), true);
    const offer = [{ nftContract:await nft.getAddress(), tokenId:1, amount:1, tokenType:0 }];
    const want  = [{ nftContract:await nft.getAddress(), tokenId:2, amount:1, tokenType:0 }];
    await swap.connect(partyA).proposeSwap(partyB.address,offer,want,86400,"swap");
    await expect(swap.connect(attacker).acceptSwap(1)).to.be.revertedWith("Not counterparty");
  });

  it("should reject exercising option not in the money", async () => {
    const [owner, writer, holder] = await ethers.getSigners();
    const deriv = await (await ethers.getContractFactory("DerivativesMarket")).deploy(owner.address);
    await deriv.waitForDeployment();
    const FAKE = "0x0000000000000000000000000000000000000001";
    await deriv.updateFloorPrice(FAKE, toWei(1));  // floor=1, strike=2 → OTM
    const ts = await blockTs();
    await deriv.connect(writer).writeOption(FAKE,0,toWei(2),toWei(0.05),ts+86400,true,{ value:toWei(0.5) });
    await deriv.connect(holder).buyOption(1,{ value:toWei(0.05) });
    await expect(deriv.connect(holder).exerciseOption(1)).to.be.revertedWith("Option not in the money");
  });

  it("should reject sell on bonding curve without holdings", async () => {
    const [owner, creator, attacker] = await ethers.getSigners();
    const curves = await (await ethers.getContractFactory("BondingCurves")).deploy(owner.address);
    await curves.waitForDeployment();
    await curves.connect(creator).createCurve("TestCurve",0,toWei(0.001),toWei(0.0001),1000);
    await expect(curves.connect(attacker).sell(1,1)).to.be.revertedWith("Insufficient holdings");
  });

  it("should reject renting when NFT is already rented", async () => {
    const [owner, nftOwner, renter1, renter2] = await ethers.getSigners();
    const rental = await (await ethers.getContractFactory("RentalMarket")).deploy(owner.address);
    await rental.waitForDeployment();
    const nft = await deployNFT(owner);
    await mintOne(nft, nftOwner);
    await nft.connect(nftOwner).setApprovalForAll(await rental.getAddress(), true);
    await rental.connect(nftOwner).listForRental(await nft.getAddress(),1,toWei(0.01),toWei(0.1),1,30);
    await rental.connect(renter1).rent(1,1,{ value:toWei(0.11) });
    await expect(rental.connect(renter2).rent(1,1,{ value:toWei(0.11) }))
      .to.be.revertedWith("Not available");
  });
});