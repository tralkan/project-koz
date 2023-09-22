import { buildModule } from "@nomicfoundation/hardhat-ignition";

const Module = buildModule("Module", (m) => {
  const addresses = ["0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE"];
  const _guardians_addr = m.getParameter("_guardians_addr", addresses);
  const _dns = m.getParameter(
    "_dns",
    "0xC68d43b78b5B720b0A1392269aFaC939DDfA40EE"
  );
  const ids: any[] = [];
  const _guardians_id = m.getParameter("_guardians_id", ids);

  const contract = m.contract("Account", [
    _guardians_addr,
    _dns,
    _guardians_id,
  ]);

  return {
    contract,
  };
});

export default Module;
