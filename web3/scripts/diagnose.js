// Quick diagnostic - run with: npx hardhat run scripts/diagnose.js
const { ethers } = require("hardhat");

async function main() {
  const [owner, treasury] = await ethers.getSigners();
  const contracts = [
    ["StadiumNFT", [treasury.address]],
    ["VenueRegistry", []],
    ["SeatingNFT", [treasury.address]],
    ["VenueMarketplace", [treasury.address]],
    ["AthleteNFT", [treasury.address]],
    ["SportsCardNFT", [treasury.address]],
    ["TeamNFT", [treasury.address]],
    ["CardMarketplace", [treasury.address]],
    ["MatchSimulator", [treasury.address, ethers.ZeroAddress]],
    ["TournamentBrackets", [treasury.address]],
    ["LiveEvents", [treasury.address]],
    ["PerformanceMetrics", []],
    ["FanTokens", [treasury.address]],
    ["PredictionMarkets", [treasury.address]],
    ["FantasyLeagues", [treasury.address]],
    ["FanRewards", [treasury.address]],
  ];
  for (const [name, args] of contracts) {
    try {
      const F = await ethers.getContractFactory(name);
      await F.deploy(...args);
      console.log(`✅ ${name}`);
    } catch (e) {
      console.log(`❌ ${name}: ${e.message.split('\n')[0]}`);
    }
  }
}
main().catch(console.error);