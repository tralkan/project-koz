import { ethers } from "hardhat";

async function main() {
  const [signer, otherAccount] = await ethers.getSigners();
  console.log(`Signer address: ${signer.address}`);

  const addresses = [
    "0x1c61dE56e7b39efaCfEcE6fEDa5807dcDFBaB7c6",
    otherAccount.address,
  ];
  const dns = "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE";
  const ids: any[] = [];
  const entryPoint = "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789";

  const contract = await ethers.deployContract("TyronSSIAccount", [
    addresses,
    dns,
    ids,
    entryPoint,
  ]);
  await contract.waitForDeployment().then(async () => {
    console.log(`Account deployed to: ${contract.target}`);

    // const txn = await contract.initialize(signer);
    // console.log(`Initialised at ${JSON.stringify(txn, null, 2)}`);
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
