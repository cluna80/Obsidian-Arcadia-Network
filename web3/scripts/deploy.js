const hre = require("hardhat");

async function main() {
  console.log("Deploying OANEntity...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Account:", deployer.address);
  
  const OANEntity = await ethers.getContractFactory("OANEntity");
  const oanEntity = await OANEntity.deploy();
  await oanEntity.deployed();
  
  console.log("Contract deployed to:", oanEntity.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
