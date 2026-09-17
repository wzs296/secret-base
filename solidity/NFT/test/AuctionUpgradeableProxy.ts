import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { encodeFunctionData, type Address } from "viem";

describe("Auction UUPS upgrade flow", async function () {
  const { viem } = await network.create();

  it("should deploy implementation and proxy, initialize, then upgrade", async function () {
    const [owner, alice] = await viem.getWalletClients();

    const nft = await viem.deployContract("NFT", ["https://example.com/metadata/"]);
    const priceOracle = await viem.deployContract("PriceOracle", []);

    const implementationV1 = await viem.deployContract("AuctionUpgradeable", []);

    const initializeData = encodeFunctionData({
      abi: implementationV1.abi,
      functionName: "initialize",
      args: [priceOracle.address, owner.account.address],
    });

    const proxy = await viem.deployContract("ERC1967ProxyWrapper", [
      implementationV1.address,
      initializeData,
    ]);

    const auctionProxy = await viem.getContractAt("AuctionUpgradeable", proxy.address);

    await nft.write.mint([owner.account.address]);
    await nft.write.approve([auctionProxy.address, 1n], { account: owner.account });

    await auctionProxy.write.createAuction([nft.address, 1n, 60n], {
      account: owner.account,
    });

    const created = await auctionProxy.read.getAuction([1n]);
    assert.equal(created.seller.toLowerCase(), owner.account.address.toLowerCase());

    const implementationV2 = await viem.deployContract("AuctionUpgradeableV2", []);
    const initializeV2Data = encodeFunctionData({
      abi: implementationV2.abi,
      functionName: "initializeV2",
      args: [],
    });

    await auctionProxy.write.upgradeToAndCall(
      [implementationV2.address, initializeV2Data],
      { account: owner.account },
    );

    const upgraded = await viem.getContractAt("AuctionUpgradeableV2", proxy.address);
    const version = await upgraded.read.getVersion();
    assert.equal(version, 2n);

    const newAuction = await upgraded.read.getAuction([1n]);
    assert.equal(newAuction.seller.toLowerCase(), owner.account.address.toLowerCase());
  });
});
