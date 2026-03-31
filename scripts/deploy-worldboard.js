const hre = require("hardhat");

async function main() {
  const token = process.env.CRAFT_TOKEN;
  const slotCount = process.env.SLOT_COUNT ? Number(process.env.SLOT_COUNT) : 10;
  const claimPrice = process.env.CLAIM_PRICE_WEI || "0";

  if (!token) throw new Error("Missing env CRAFT_TOKEN (ERC20 address)");
  if (!Number.isFinite(slotCount) || slotCount <= 0) throw new Error("Bad SLOT_COUNT");

  const WorldBoard = await hre.ethers.getContractFactory("WorldBoardUpgradeable");
  const proxy = await hre.upgrades.deployProxy(
    WorldBoard,
    [token, slotCount, claimPrice],
    { kind: "uups" }
  );
  await proxy.waitForDeployment();

  const proxyAddr = await proxy.getAddress();
  console.log("WorldBoard proxy deployed:", proxyAddr);

  const implAddr = await hre.upgrades.erc1967.getImplementationAddress(proxyAddr);
  console.log("Implementation:", implAddr);

  const initialOwner = process.env.INITIAL_OWNER;
  if (initialOwner && initialOwner.toLowerCase() !== (await WorldBoard.signer.getAddress()).toLowerCase()) {
    console.log("Transferring ownership to:", initialOwner);
    const contract = WorldBoard.attach(proxyAddr);
    const tx = await contract.transferOwnership(initialOwner);
    await tx.wait();
    console.log("Ownership transferred.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
