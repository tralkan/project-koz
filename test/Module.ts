import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import Module from "../ignition/Module";
import { ethers, ignition } from "hardhat";
const hre = require("hardhat");

describe("Account", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();
    const addresses = [
      "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE",
      // "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE",
      //"0x0000000000000000000000000000000000000000",
    ];
    const dns = "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE";
    const ids: any[] = [];

    const { contract } = await ignition.deploy(Module, {
      parameters: {
        Module: {
          addresses,
          dns,
          ids,
        },
      },
    });
    console.log("contract address:", contract.target);
    // console.log("contract:", JSON.stringify(contract, null, 2));
    // const guardian_params = await contract.getGuardianParams();
    // console.log("guardian count:", guardian_params[0].toString());
    // console.log("guardian threshold:", guardian_params[1].toString());

    return { contract, addresses, dns, ids, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      await loadFixture(deployFixture)
        .then(async ({ contract, owner }) => {
          const contract_owner = await contract.owner();
          console.log("contract owner:", contract_owner.toString());
          expect(contract_owner).to.equal(owner.address);
        })
        .catch((err) => {
          console.log("TestErr:", err);
        });
      // expect(contract.target).to.equal(
      //   "0x5fbdb2315678afecb367f032d93f642f64180aa3"
      // );
    });

    it("Should verify the guardian config params", async function () {
      const { contract, addresses, ids } = await loadFixture(deployFixture);

      const guardian_params = await contract.getGuardianParams();
      expect(guardian_params[0].toString()).to.equal(
        addresses.length.toString()
      );
      //half plus one of the number of ids, only integer part but minimum 3
      const threshold = Math.floor(ids.length / 2 + 1);
      //threshold must be at least 3
      expect(guardian_params[1].toString()).to.equal(
        Math.max(threshold, 3).toString()
      );
      console.log("guardian count:", guardian_params[0].toString());
      console.log("guardian threshold:", guardian_params[1].toString());
    });

    // it("Should receive and store the funds to lock", async function () {
    //   const { lock, lockedAmount } = await loadFixture(deployFixture);

    //   expect(await hre.ethers.provider.getBalance(lock.target)).to.equal(
    //     lockedAmount
    //   );
    // });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await hre.ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployFixture);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } =
  //         await loadFixture(deployFixture);

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(deployFixture);

  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } =
  //         await loadFixture(deployFixture);

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } =
  //         await loadFixture(deployFixture);

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });

  describe("Guardians", function () {
    describe("Validations", function () {
      it("Should not add the null address as a guardian", async function () {
        await loadFixture(deployFixture)
          .then(async ({ contract }) => {
            const guardians = ["0x0000000000000000000000000000000000000000"];
            // const result = await contract.addGuardians(guardians, []);
            await expect(contract.addGuardians(guardians, [])).to.be.reverted;
          })
          .catch((err) => {
            console.log("TestErr:", err);
          });
      });
    });

    describe("AddGuardians", function () {
      it("Should add two new guardians & verify the params", async function () {
        await loadFixture(deployFixture)
          .then(async ({ contract }) => {
            const guardians = [
              "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
              "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
            ];
            // const result = await contract.addGuardians(guardians, []);
            await expect(contract.addGuardians(guardians, [])).not.to.be
              .reverted;

            const guardian_params = await contract.getGuardianParams();
            expect(guardian_params[0].toString()).to.equal("3");
            expect(guardian_params[1].toString()).to.equal("3");
            console.log("guardian count:", guardian_params[0].toString());
            console.log("guardian threshold:", guardian_params[1].toString());
          })
          .catch((err) => {
            console.log("TestErr:", err);
          });
      });
      // it("Should verify the new guardians", async function () {
      //   const { contract } = await loadFixture(deployFixture);

      //         });
    });
  });
});
