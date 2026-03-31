const hre = require("hardhat");

async function main() {
    const proxyAddr = "0x624a576E416876Da330e0D82f628D325F23DF18b";
    const initialOwner = process.env.INITIAL_OWNER;

    if (!initialOwner) {
        console.error("Missing INITIAL_OWNER in .env");
        return;
    }

    const WorldBoard = await hre.ethers.getContractAt("WorldBoardUpgradeable", proxyAddr);
    console.log("Current owner:", await WorldBoard.owner());

    if ((await WorldBoard.owner()).toLowerCase() !== initialOwner.toLowerCase()) {
        console.log("Transferring ownership to:", initialOwner);
        const tx = await WorldBoard.transferOwnership(initialOwner);
        await tx.wait();
        console.log("Ownership transferred.");
    } else {
        console.log("Ownership already set to INITIAL_OWNER");
    }
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
});
