import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ProjectDeployment", (m) => {
  const deployer = m.getAccount(0);

  const nft = m.contract("NFT", ["https://example.com/metadata/"]);
  const priceOracle = m.contract("PriceOracle");
  const auction = m.contract("Auction", [priceOracle, deployer]);
  const proxyFactory = m.contract("ProxyFactory");
  const auctionUpgradeable = m.contract("AuctionUpgradeable");
  const auctionUpgradeableV2 = m.contract("AuctionUpgradeableV2");

  return {
    nft,
    priceOracle,
    auction,
    proxyFactory,
    auctionUpgradeable,
    auctionUpgradeableV2,
  };
});
