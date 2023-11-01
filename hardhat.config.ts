import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ignition";
import "@nomicfoundation/hardhat-foundry";

//@notice add your private key with zkETH
const eoa = "50d93bd0114305bcf7b4ada311a84067e0b7e123c7f2891c4e65da646b1e26c1"; //process.env.ACCOUNT_PRIVATE_KEY;
const config: HardhatUserConfig = {
  solidity: "0.8.21",
  networks: {
    zkEVM: {
      url: `https://rpc.public.zkevm-test.net`,
      accounts: [eoa!],
    },
  },
};

export default config;
