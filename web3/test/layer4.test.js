const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OAN LAYER 4: MEDIA SYSTEMS - COMPLETE TEST SUITE", function () {

  describe("Phase 4.1: NFT Movies & Scenes", function () {

    describe("MovieNFT - Film Production", function () {
      let movieNFT, owner, director, actor1;

      beforeEach(async function () {
        [owner, director, actor1] = await ethers.getSigners();
        const MovieNFT = await ethers.getContractFactory("MovieNFT");
        movieNFT = await MovieNFT.deploy();
      });

      it("Should mint a movie NFT", async function () {
        await movieNFT.mintMovie("Cyber Warriors", "ipfs://Qm123", director.address, 0);
        const movie = await movieNFT.getMovie(1);
        expect(movie.title).to.equal("Cyber Warriors");
      });

      it("Should add scenes to movie", async function () {
        await movieNFT.mintMovie("Epic Film", "ipfs://Qm456", director.address, 0);
        await movieNFT.addScene(1, 42);
        await movieNFT.addScene(1, 73);
        const movie = await movieNFT.getMovie(1);
        expect(movie.sceneIds.length).to.equal(2);
      });

      it("Should set revenue shares", async function () {
        await movieNFT.mintMovie("Revenue Film", "ipfs://Qm789", director.address, 0);
        await movieNFT.setRevenueShares(
          1,
          [director.address, actor1.address, owner.address],
          [3000, 4000, 3000]
        );
        const [recipients] = await movieNFT.getRevenueShares(1);
        expect(recipients.length).to.equal(3);
      });

      it("Should publish movie", async function () {
        await movieNFT.mintMovie("Ready Film", "ipfs://Qm101", director.address, 0);
        await movieNFT.addScene(1, 1);
        await movieNFT.publishMovie(1);
        const movie = await movieNFT.getMovie(1);
        expect(movie.isPublished).to.equal(true);
      });

      it("Should distribute revenue automatically", async function () {
        await movieNFT.mintMovie("Blockbuster", "ipfs://Qm202", director.address, 0);
        await movieNFT.addScene(1, 1);
        await movieNFT.setRevenueShares(
          1,
          [director.address, actor1.address],
          [5000, 5000]
        );
        await movieNFT.publishMovie(1);

        const directorBalanceBefore = await ethers.provider.getBalance(director.address);

        await movieNFT.distributeRevenue(1, { value: ethers.parseEther("10") });

        const directorBalanceAfter = await ethers.provider.getBalance(director.address);
        expect(directorBalanceAfter - directorBalanceBefore)
          .to.equal(ethers.parseEther("5"));
      });
    });

    describe("SceneNFT - Composable Scenes", function () {
      let sceneNFT, owner, creator;

      beforeEach(async function () {
        [owner, creator] = await ethers.getSigners();
        const SceneNFT = await ethers.getContractFactory("SceneNFT");
        sceneNFT = await SceneNFT.deploy();
      });

      it("Should mint a scene NFT", async function () {
        await sceneNFT.mintScene("Epic Battle Scene", "ipfs://scene1", 180, 1, ethers.parseEther("0.1"));
        const scene = await sceneNFT.getScene(1);
        expect(scene.description).to.equal("Epic Battle Scene");
      });

      it("Should license scene for use", async function () {
        await sceneNFT.connect(creator).mintScene("Reusable Scene", "ipfs://scene2", 120, 0, ethers.parseEther("0.5"));

        await sceneNFT.connect(owner).licenseScene(1, { value: ethers.parseEther("0.5") });

        const scene = await sceneNFT.getScene(1);
        expect(scene.timesUsed).to.equal(1);
      });

      it("Should track scene usage", async function () {
        await sceneNFT.mintScene("Popular Scene", "ipfs://scene3", 90, 0, ethers.parseEther("0.1"));
        await sceneNFT.licenseScene(1, { value: ethers.parseEther("0.1") });
        await sceneNFT.licenseScene(1, { value: ethers.parseEther("0.1") });
        await sceneNFT.licenseScene(1, { value: ethers.parseEther("0.1") });
        const scene = await sceneNFT.getScene(1);
        expect(scene.timesUsed).to.equal(3);
      });
    });
  });

  describe("Phase 4.3: Rights & Revenue", function () {

    describe("ResaleRoyalties - Secondary Market", function () {
      let royalties, owner, seller, buyer;

      beforeEach(async function () {
        [owner, seller, buyer] = await ethers.getSigners();
        const ResaleRoyalties = await ethers.getContractFactory("ResaleRoyalties");
        royalties = await ResaleRoyalties.deploy();
      });

      it("Should configure royalty", async function () {
        await royalties.connect(owner).configureRoyalty(1, 500);
        const config = await royalties.getRoyaltyConfig(1);
        expect(config.royaltyBps).to.equal(500);
      });

      it("Should record sale and pay royalty", async function () {
        await royalties.connect(owner).configureRoyalty(1, 1000);
        await royalties.connect(owner).approveMarketplace(buyer.address, true);

        await royalties.connect(buyer).recordSale(
          1,
          seller.address,
          buyer.address,
          ethers.parseEther("10"),
          { value: ethers.parseEther("10") }
        );

        const earnings = await royalties.getCreatorEarnings(owner.address);
        expect(earnings).to.equal(ethers.parseEther("1"));
      });

      it("Should track creator earnings", async function () {
        await royalties.connect(owner).configureRoyalty(1, 500);
        await royalties.connect(owner).approveMarketplace(buyer.address, true);

        await royalties.connect(buyer).recordSale(
          1,
          seller.address,
          buyer.address,
          ethers.parseEther("20"),
          { value: ethers.parseEther("20") }
        );

        const earnings = await royalties.getCreatorEarnings(owner.address);
        expect(earnings).to.equal(ethers.parseEther("1"));
      });

      it("Should reject unauthorized marketplace", async function () {
        await royalties.connect(owner).configureRoyalty(1, 500);

        await expect(
          royalties.connect(buyer).recordSale(
            1,
            seller.address,
            buyer.address,
            ethers.parseEther("10"),
            { value: ethers.parseEther("10") }
          )
        ).to.be.revertedWith("Unauthorized marketplace");
      });
    });
  });
});