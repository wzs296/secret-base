import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import type { Address } from "viem";

describe("NFT Integration Tests", async function () {
  const { viem, networkHelpers } = await network.create();
  const publicClient = await viem.getPublicClient();

  async function deployNFT() {
    const [owner] = await viem.getWalletClients();
    const nft = await viem.deployContract("NFT", ["https://example.com/metadata/"]);
    return { nft, owner };
  }

  it("Should deploy NFT contract with correct initialization", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);

    const name = await nft.read.name();
    const symbol = await nft.read.symbol();
    const totalMinted = await nft.read.totalMinted();

    assert.equal(name, "NFT");
    assert.equal(symbol, "NFT");
    assert.equal(totalMinted, 0n);
  });

  it("Should mint a single NFT", async function () {
    const { nft, owner } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    await nft.write.mint([aliceAddress]);

    const ownerOf = await nft.read.ownerOf([1n]);
    const balance = await nft.read.balanceOf([aliceAddress]);
    const totalMinted = await nft.read.totalMinted();

    assert.equal(ownerOf.toLowerCase(), aliceAddress.toLowerCase());
    assert.equal(balance, 1n);
    assert.equal(totalMinted, 1n);
  });

  it("Should emit TokenMinted event when minting", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    
    await viem.assertions.emitWithArgs(
      nft.write.mint([aliceAddress]),
      nft,
      "TokenMinted",
      [aliceAddress, 1n]
    );
  });

  it("Should mint batch of NFTs", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;

    await nft.write.mintBatch([aliceAddress, 3n]);

    const totalMinted = await nft.read.totalMinted();
    const balance = await nft.read.balanceOf([aliceAddress]);

    assert.equal(totalMinted, 3n);
    assert.equal(balance, 3n);
  });

  it("Should transfer NFT between addresses", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice, bob] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    const bobAddress = bob.account.address as Address;

    await nft.write.mint([aliceAddress]);

    await nft.write.transferFrom([aliceAddress, bobAddress, 1n], {
      account: alice.account,
    });

    const newOwner = (await nft.read.ownerOf([1n])) as Address;
    const aliceBalance = await nft.read.balanceOf([aliceAddress]);
    const bobBalance = await nft.read.balanceOf([bobAddress]);

    assert.equal(newOwner.toLowerCase(), bobAddress.toLowerCase());
    assert.equal(aliceBalance, 0n);
    assert.equal(bobBalance, 1n);
  });

  it("Should approve and transfer NFT", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice, bob] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    const bobAddress = bob.account.address as Address;

    await nft.write.mint([aliceAddress]);

    // Alice approves Bob to transfer the NFT
    await nft.write.approve([bobAddress, 1n], { account: alice.account });

    const approved = await nft.read.getApproved([1n]);
    assert.equal(approved.toLowerCase(), bobAddress.toLowerCase());

    // Bob transfers the NFT to himself
    await nft.write.transferFrom([aliceAddress, bobAddress, 1n], {
      account: bob.account,
    });

    const newOwner = await nft.read.ownerOf([1n]);
    assert.equal(newOwner.toLowerCase(), bobAddress.toLowerCase());
  });

  it("Should return correct token URI", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    await nft.write.mint([aliceAddress]);

    const tokenURI = await nft.read.tokenURI([1n]);
    assert.equal(tokenURI, "https://example.com/metadata/1.json");
  });

  it("Should update base URI", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    
    const newBaseURI = "https://new.example.com/";
    await nft.write.setBaseURI([newBaseURI]);

    await nft.write.mint([aliceAddress]);
    const tokenURI = await nft.read.tokenURI([1n]);

    assert.equal(tokenURI, "https://new.example.com/1.json");
  });

  it("Should reject transfer from non-approved sender", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice, bob] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    const bobAddress = bob.account.address as Address;

    await nft.write.mint([aliceAddress]);

    // Bob tries to transfer Alice's NFT without approval
    await viem.assertions.revertWithCustomError(
      nft.write.transferFrom([aliceAddress, bobAddress, 1n], {
        account: bob.account,
      }),
      nft,
      "ERC721InsufficientApproval"
    );
  });

  it("Should support set approval for all", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice, bob] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;
    const bobAddress = bob.account.address as Address;

    // Alice approves Bob for all tokens
    await nft.write.setApprovalForAll([bobAddress, true], {
      account: alice.account,
    });

    const isApproved = await nft.read.isApprovedForAll([aliceAddress, bobAddress]);
    assert.equal(isApproved, true);

    // Mint and transfer
    await nft.write.mint([aliceAddress]);
    await nft.write.transferFrom([aliceAddress, bobAddress, 1n], {
      account: bob.account,
    });

    const newOwner = await nft.read.ownerOf([1n]);
    assert.equal(newOwner.toLowerCase(), bobAddress.toLowerCase());
  });

  it("Only owner can mint NFTs", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    const aliceAddress = alice.account.address as Address;

    await viem.assertions.revertWithCustomError(
      nft.write.mint([aliceAddress], { account: alice.account }),
      nft,
      "OwnableUnauthorizedAccount"
    );
  });

  it("Only owner can set base URI", async function () {
    const { nft } = await networkHelpers.loadFixture(deployNFT);
    const [, alice] = await viem.getWalletClients();

    await viem.assertions.revertWithCustomError(
      nft.write.setBaseURI(["https://new.example.com/"], {
        account: alice.account,
      }),
      nft,
      "OwnableUnauthorizedAccount"
    );
  });
});