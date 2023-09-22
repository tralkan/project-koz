import { ethers } from "hardhat";

async function main() {
  const addresses = ["0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE"];
  const dns = "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE";
  const ids: any[] = [];

  const contract = await ethers.deployContract("Account", [
    addresses,
    dns,
    ids,
  ]);
  await contract.waitForDeployment();

  console.log(`Deployed to ${contract.target}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
