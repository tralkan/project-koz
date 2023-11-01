import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import {
  hashMessage,
  keccak256,
  solidityPackedKeccak256,
  toUtf8Bytes,
} from "ethers";
import { ethers } from "hardhat";
const hre = require("hardhat");

describe("TyronSSIAccount", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const accounts = await hre.ethers.getSigners();

    const signer = accounts[0].address;
    console.log("Signer:", signer);

    const wallet1 = ethers.Wallet.createRandom();
    const wallet2 = ethers.Wallet.createRandom();
    const wallet3 = ethers.Wallet.createRandom();
    const wallet4 = ethers.Wallet.createRandom();

    const addresses = [
      //signer.address, @dev Error: VM Exception while processing transaction: reverted with reason string 'Account: A guardian cannot be the account owner.'
      "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE",
      wallet1.address,
      wallet2.address,
      wallet3.address,
      wallet4.address,
      //"0x0000000000000000000000000000000000000000" @devError: VM Exception while processing transaction: reverted with reason string 'Account: A guardian cannot be null.'
    ];
    const dns = "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE";
    const ids: any[] = [];

    const entryPoint = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

    const TyronSSI = await hre.ethers.getContractFactory("TyronSSIAccount");
    const contract = await TyronSSI.deploy(addresses, dns, ids, entryPoint);
    console.log("Account:", contract.target);

    return {
      contract,
      addresses,
      signer,
      accounts,
      wallet1,
      wallet2,
      wallet3,
      wallet4,
    };
  }

  describe("Initialize", function () {
    it("Sets the right owner", async function () {
      const { contract, signer } = await loadFixture(deployFixture);
      expect(await contract.owner()).to.equal(signer);
    });

    it("Verifies the guardian config params", async function () {
      const { contract, addresses } = await loadFixture(deployFixture);

      const guardian_params = await contract.getGuardianParams();
      const count = guardian_params[0].toString();
      console.log("Guardian count", count);
      expect(count).to.equal(addresses.length.toString());

      //half plus one of the number of guardians, only integer part but minimum 3
      const threshold = Math.floor(Number(count) / 2 + 1);

      //threshold must be at least 3
      expect(guardian_params[1].toString()).to.equal(
        Math.max(threshold, 3).toString()
      );
      console.log("Guardian threshold:", guardian_params[1].toString());
    });
  });

  describe("Social Recovery", function () {
    it("Adds guardians", async function () {
      const { contract, accounts } = await loadFixture(deployFixture);
      const addresses = [
        //"0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE", Error: VM Exception while processing transaction: reverted with reason string 'Account: A guardian cannot be repeated.'
        accounts[1].address,
        accounts[2].address,
      ];

      await contract.addGuardians(addresses, []);

      const guardian_params = await contract.getGuardianParams();
      const count = guardian_params[0].toString();
      console.log("Guardian count", count);

      //half plus one of the number of guardians, only integer part but minimum 3
      const threshold = Math.floor(Number(count) / 2 + 1);

      //threshold must be at least 3
      expect(guardian_params[1].toString()).to.equal(
        Math.max(threshold, 3).toString()
      );
      console.log("Guardian threshold:", guardian_params[1].toString());
    });

    // it("Social recovers the account", async function () {
    //   const { contract, accounts, wallet1, wallet2, wallet3, wallet4 } =
    //     await loadFixture(deployFixture);

    //   //@notice Transfers the ownership to account1
    //   const new_signer = accounts[1].address;

    //   const hash_ = solidityPackedKeccak256(["address"], [new_signer]);

    //   const hash = keccak256(toUtf8Bytes(new_signer));
    //   console.log("Digest:", hash_);
    //   console.log("Digest:", hash);

    //   const addr1 = wallet1.address;
    //   const addr2 = wallet2.address;
    //   const addr3 = wallet3.address;
    //   const addr4 = wallet4.address;
    //   const addresses: string[] = [addr1, addr2, addr3, addr4];

    //   const sig1 = await wallet1.signMessage(hash);
    //   console.log("Guardian signature:", sig1);
    //   console.log(sig1);
    //   const sig2 = await wallet2.signMessage(hash);
    //   console.log("Guardian signature:", sig2);
    //   const sig3 = await wallet3.signMessage(hash);
    //   console.log("Guardian signature:", sig3);
    //   const sig4 = await wallet4.signMessage(hash);
    //   console.log("Guardian signature:", sig4);
    //   const signatures: string[] = [sig1, sig2, sig3, sig4];

    //   await contract.socialRecovery(new_signer, addresses, signatures);

    //   // expect(await contract.owner()).to.equal(new_signer);
    // });
  });
});
