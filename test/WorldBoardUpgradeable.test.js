const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("WorldBoardUpgradeable", function () {
  it("pays 90% to previous holder, rebates 10% to new claimer (and locks 90% in-contract if slot empty)", async function () {
    const [deployer, alice, bob] = await ethers.getSigners();

    const Mock = await ethers.getContractFactory("MockERC20");
    const token = await Mock.deploy("CRAFT", "CRAFT");
    await token.waitForDeployment();

    const price = ethers.parseUnits("100", 18);
    const outbid = (price * 11000n) / 10000n; // +10%
    await token.mint(alice.address, price);
    await token.mint(bob.address, outbid);

    const Board = await ethers.getContractFactory("WorldBoardUpgradeable");
    const board = await upgrades.deployProxy(
      Board,
      [await token.getAddress(), 5, price],
      { kind: "uups" }
    );
    await board.waitForDeployment();

    const rebate = (price * 1000n) / 10000n; // 10%
    const ninety = price - rebate; // 90%

    // Alice claims first: 10% rebated to Alice, 90% stays in the contract
    await token.connect(alice).approve(await board.getAddress(), price);
    await (await board.connect(alice)["claim(uint256,string)"](0, "codeA")).wait();

    expect(await token.balanceOf(await board.getAddress())).to.equal(ninety);
    expect(await token.balanceOf(alice.address)).to.equal(rebate);

    // Owner can withdraw locked funds (e.g. from empty-slot claims)
    await (await board.withdrawToken(await token.getAddress(), deployer.address, ninety)).wait();
    expect(await token.balanceOf(await board.getAddress())).to.equal(0n);

    // Bob must outbid by at least 10%
    await token.connect(bob).approve(await board.getAddress(), outbid);
    let reverted = false;
    try {
      await board.connect(bob)["claim(uint256,string,uint256)"](0, "codeB", outbid - 1n);
    } catch {
      reverted = true;
    }
    expect(reverted).to.equal(true);
    await (await board.connect(bob)["claim(uint256,string,uint256)"](0, "codeB", outbid)).wait();

    const bobRebate = (outbid * 1000n) / 10000n;
    const bobPrevPayout = outbid - bobRebate;

    // Alice started with 100, got 10 rebate (so 10 left), then got 90% of Bob's outbid => 10 + 99 = 109
    expect(await token.balanceOf(alice.address)).to.equal(rebate + bobPrevPayout);
    // Bob paid outbid and got 10% back => bobRebate
    expect(await token.balanceOf(bob.address)).to.equal(bobRebate);
    // Since we withdrew the locked funds, the contract should stay at 0.
    expect(await token.balanceOf(await board.getAddress())).to.equal(0n);

    const slot = await board.getSlot(0);
    expect(slot.holder).to.equal(bob.address);
    expect(slot.worldCode).to.equal("codeB");

    expect(await board.lastClaimPrice(0)).to.equal(outbid);
    // Next minimum is last + 10% (rounded up).
    expect(await board.minClaimPrice(0)).to.equal((outbid * 11000n) / 10000n);
  });

  it("getSlots batches reads", async function () {
    const [deployer] = await ethers.getSigners();
    const Mock = await ethers.getContractFactory("MockERC20");
    const token = await Mock.deploy("CRAFT", "CRAFT");
    await token.waitForDeployment();

    const Board = await ethers.getContractFactory("WorldBoardUpgradeable");
    const board = await upgrades.deployProxy(
      Board,
      [await token.getAddress(), 3, 1],
      { kind: "uups" }
    );
    await board.waitForDeployment();

    const slots = await board.getSlots(0, 10);
    expect(slots.length).to.equal(3);
  });
});
