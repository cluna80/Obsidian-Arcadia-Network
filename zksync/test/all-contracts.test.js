// test/all-contracts.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ZK Contracts Suite", function () {
  // Test helpers
  const deployContract = async (contractName) => {
    return await ethers.getContractFactory(contractName).deploy();
  };

  // Individual contract tests
  describe("ZKEmergencyShutdown", function () {
    let contract;

    beforeEach(async () => {
      contract = await deployContract("ZKEmergencyShutdown");
    });

    it("should deploy successfully", async () => {
      expect(contract.address).to.not.equal("0x0000000000000000000000000000000
