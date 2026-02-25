const { Wallet, Provider } = require("zksync-ethers");
const { Deployer } = require("@matterlabs/hardhat-zksync-deploy");

async function main() {
  console.log("\ní´ Deploying ZKSync + Layer 7 Integration...\n");

  // Setup provider and wallet
  const provider = new Provider("https://sepolia.era.zksync.dev");
  const wallet = new Wallet(process.env.PRIVATE_KEY, provider);
  const deployer = new Deployer(hre, wallet);

  // Deploy contracts
  console.log("í³ Deploying ZKSync contracts...\n");

  // 1. Deploy ZK Bridge
  const zkBridge = await deployer.deploy(
    await deployer.loadArtifact("ZKEntityBridge"),
    ["0x0000000000000000000000000000000000000000"] // L1 bridge address
  );
  console.log(`âœ… ZKEntityBridge: ${zkBridge.address}`);

  // 2. Deploy ZK Reputation Oracle
  const zkReputation = await deployer.deploy(
    await deployer.loadArtifact("ZKReputationOracle")
  );
  console.log(`âœ… ZKReputationOracle: ${zkReputation.address}`);

  // 3. Deploy ZK Marketplace
  const zkMarketplace = await deployer.deploy(
    await deployer.loadArtifact("ZKMarketplace")
  );
  console.log(`âœ… ZKMarketplace: ${zkMarketplace.address}`);

  // 4. Deploy ZK Voting
  const zkVoting = await deployer.deploy(
    await deployer.loadArtifact("ZKVoting")
  );
  console.log(`âœ… ZKVoting: ${zkVoting.address}`);

  // 5. Deploy Layer 7 Integration
  const integration = await deployer.deploy(
    await deployer.loadArtifact("ZKLayer7Integration"),
    [
      "0x0000000000000000000000000000000000000000", // executionGuardian
      "0x0000000000000000000000000000000000000000", // reputationGuardian
      zkReputation.address,
      zkBridge.address
    ]
  );
  console.log(`âœ… ZKLayer7Integration: ${integration.address}`);

  // 6. Deploy ZK Emergency Shutdown
  const emergency = await deployer.deploy(
    await deployer.loadArtifact("ZKEmergencyShutdown")
  );
  console.log(`âœ… ZKEmergencyShutdown: ${emergency.address}`);

  // 7. Deploy ZK Behavior Auditor
  const auditor = await deployer.deploy(
    await deployer.loadArtifact("ZKBehaviorAuditor")
  );
  console.log(`âœ… ZKBehaviorAuditor: ${auditor.address}`);

  // 8. Deploy ZK Slashing
  const slashing = await deployer.deploy(
    await deployer.loadArtifact("ZKSlashing")
  );
  console.log(`âœ… ZKSlashing: ${slashing.address}`);

  console.log("\ní¾‰ All contracts deployed!\n");
  console.log("Contract Addresses:");
  console.log("==================");
  console.log(`ZKEntityBridge:       ${zkBridge.address}`);
  console.log(`ZKReputationOracle:   ${zkReputation.address}`);
  console.log(`ZKMarketplace:        ${zkMarketplace.address}`);
  console.log(`ZKVoting:             ${zkVoting.address}`);
  console.log(`ZKLayer7Integration:  ${integration.address}`);
  console.log(`ZKEmergencyShutdown:  ${emergency.address}`);
  console.log(`ZKBehaviorAuditor:    ${auditor.address}`);
  console.log(`ZKSlashing:           ${slashing.address}`);
  console.log("\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
