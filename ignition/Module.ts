import { buildModule } from "@nomicfoundation/hardhat-ignition";

const Module = buildModule("Module", (m) => {
  const CustomSlotIni = m.contract("CustomSlotIni", []);

  const addresses = ["0x1c61dE56e7b39efaCfEcE6fEDa5807dcDFBaB7c6"];
  const guardiansAddr = m.getParameter("guardiansAddr", addresses);
  const dns = m.getParameter(
    "dns",
    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
  );
  const ids: any[] = [];
  const guardiansId = m.getParameter("guardiansId", ids);

  const anEntryPoint = m.getParameter(
    "anEntryPoint",
    "0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789",
  );
  const contract = m.contract("TyronSSIAccount", [
    guardiansAddr,
    dns,
    guardiansId,
    anEntryPoint,
  ]);

  return {
    contract,
  };
});

export default Module;
