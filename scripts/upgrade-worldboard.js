const hre = require("hardhat");

async function main() {
  const proxyAddress = process.env.WORLDBOARD_PROXY;
  if (!proxyAddress) throw new Error("Missing env WORLDBOARD_PROXY (proxy address)");

  const WorldBoard = await hre.ethers.getContractFactory("WorldBoardUpgradeable");
  const upgraded = await hre.upgrades.upgradeProxy(proxyAddress, WorldBoard, { kind: "uups" });
  await upgraded.waitForDeployment();

  console.log("Upgraded proxy:", proxyAddress);
  const implAddr = await hre.upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("New implementation:", implAddr);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});

