import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

describe("MerkleVault", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContractFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const MerkleVault = await ethers.getContractFactory("MerkleVault");
    const TestCoin = await ethers.getContractFactory("TestCoin");
    const merkleVault = await MerkleVault.deploy();
    const testCoin = await TestCoin.deploy();

    return { merkleVault, testCoin, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should deploy with zero balance", async function () {
      const { merkleVault, testCoin } = await loadFixture(
        deployContractFixture
      );

      expect(await merkleVault.balance(testCoin.address)).to.equal(0);
    });
  });

  it("Should allow deposit", async function () {
    const { merkleVault, testCoin, owner, otherAccount } = await loadFixture(
      deployContractFixture
    );

    await testCoin.mint(otherAccount.address, 1 * 1e8);

    await testCoin.connect(otherAccount).approve(merkleVault.address, 1 * 1e8);
    expect(
      await merkleVault
        .connect(otherAccount)
        .depositToken(testCoin.address, 1 * 1e8)
    )
      .to.emit(merkleVault, "NewDeposit")
      .withArgs(testCoin.address, otherAccount.address, 1 * 1e8);

    expect(await merkleVault.balance(testCoin.address)).to.equal(1 * 1e8);
  });

  it("Should allow deposits", async function () {
    const { merkleVault, testCoin, owner, otherAccount } = await loadFixture(
      deployContractFixture
    );

    await testCoin.mint(otherAccount.address, 1 * 1e8);
    await testCoin.mint(owner.address, 1 * 1e8);

    await testCoin.connect(otherAccount).approve(merkleVault.address, 1 * 1e8);
    expect(
      await merkleVault
        .connect(otherAccount)
        .depositToken(testCoin.address, 1 * 1e8)
    )
      .to.emit(merkleVault, "NewDeposit")
      .withArgs(testCoin.address, otherAccount.address, 1 * 1e8);

    await testCoin.approve(merkleVault.address, 1 * 1e8);
    expect(await merkleVault.depositToken(testCoin.address, 1 * 1e8))
      .to.emit(merkleVault, "NewDeposit")
      .withArgs(testCoin.address, otherAccount.address, 1 * 1e8);

    expect(await merkleVault.balance(testCoin.address)).to.equal(2 * 1e8);
  });

  it("Should allow post of merkle root", async function () {
    const { merkleVault, testCoin, owner, otherAccount } = await loadFixture(
      deployContractFixture
    );

    const values = [
      [owner.address, 1e4],
      [otherAccount.address, 1e4],
    ];

    const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

    await merkleVault.updateRoot(tree.root);

    expect(await merkleVault.merkleRoot()).to.equal(tree.root);
  });

  it("Should allow withdrawals based on merkle proof", async function () {
    const { merkleVault, testCoin, owner, otherAccount } = await loadFixture(
      deployContractFixture
    );

    await testCoin.mint(otherAccount.address, 1 * 1e8);
    await testCoin.mint(owner.address, 1 * 1e8);

    await testCoin.connect(otherAccount).approve(merkleVault.address, 1 * 1e8);
    expect(
      await merkleVault
        .connect(otherAccount)
        .depositToken(testCoin.address, 1 * 1e8)
    )
      .to.emit(merkleVault, "NewDeposit")
      .withArgs(testCoin.address, otherAccount.address, 1 * 1e8);

    await testCoin.approve(merkleVault.address, 1 * 1e8);
    expect(await merkleVault.depositToken(testCoin.address, 1 * 1e8))
      .to.emit(merkleVault, "NewDeposit")
      .withArgs(testCoin.address, otherAccount.address, 1 * 1e8);

    expect(await merkleVault.balance(testCoin.address)).to.equal(2 * 1e8);

    const values = [
      [owner.address, 1e4],
      [otherAccount.address, 1e4],
    ];

    const tree = StandardMerkleTree.of(values, ["address", "uint256"]);

    await merkleVault.updateRoot(tree.root);

    expect(await merkleVault.merkleRoot()).to.equal(tree.root);

    for (const [i, v] of tree.entries()) {
      const proof = tree.getProof(i);

      console.log("Value:", v);
      console.log("Proof:", proof);

      const a: string = v[0].toString();

      expect(await testCoin.connect(a).balanceOf(a)).to.equal(0);

      console.log("Withdraw", a, testCoin.address, 1 * 1e4, proof);

      await merkleVault.withdraw(a, testCoin.address, 1 * 1e4, proof);

      expect(await testCoin.connect(a).balanceOf(a)).to.equal(1 * 1e4);
    }
  });
});
