require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,           // high optimization for gas efficiency
      },
      viaIR: true,             // fixes "stack too deep" issues
      evmVersion: "paris",     // stable EVM version
    },
  },

  mocha: {
    timeout: 300000,         // 5 minutes per test → safe for big deploys/simulations
    parallel: false,         // disables parallel execution → fixes Windows async crash
    bail: false,             // keep running even if one test fails
    slow: 20000,             // mark tests slower than 20s
    reporter: "spec",        // clean, readable console output
    exit: true,              // force clean process exit
    ui: "bdd",               // standard describe/it style
    fullTrace: true,         // show full stack traces on failures
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },

  // Optional: if you want gas reporting on every test run
  gasReporter: {
    enabled: process.env.REPORT_GAS === "true",
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY || undefined,
  },
};