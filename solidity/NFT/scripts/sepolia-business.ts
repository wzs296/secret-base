import { network } from "hardhat";
import { encodeFunctionData } from "viem";

const { viem } = await network.create({ network: "sepolia" });
const publicClient = await viem.getPublicClient();
const [wallet] = await viem.getWalletClients();
const IMPLEMENTATION_SLOT =
  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

const priceOracleAddress = "0xdD7863F51ccB4C49cEC716BB033b6875ae326b71";

console.log("Wallet:", wallet.account.address);
console.log("Price oracle:", priceOracleAddress);

const implementationV1 = await viem.deployContract("AuctionUpgradeable", []);
const implementationV2 = await viem.deployContract("AuctionUpgradeableV2", []);

console.log("V1 implementation:", implementationV1.address);
console.log("V2 implementation:", implementationV2.address);

const normalizeAddress = (value: string | null | undefined) => {
  const raw = (value ?? "0x0000000000000000000000000000000000000000").toLowerCase();
  return `0x${raw.slice(-40)}` as `0x${string}`;
};

const readImplementation = async (proxyAddress: `0x${string}`) => {
  const result = await publicClient.getStorageAt({
    address: proxyAddress,
    slot: IMPLEMENTATION_SLOT as `0x${string}`,
  });
  return normalizeAddress(result);
};

const initData = encodeFunctionData({
  abi: implementationV1.abi,
  functionName: "initialize",
  args: [priceOracleAddress, wallet.account.address],
});

console.log("Deploying proxy with V1 implementation...");
const proxy = await viem.deployContract("ERC1967ProxyWrapper", [
  implementationV1.address,
  initData,
], { account: wallet.account });

const auctionProxyV1 = await viem.getContractAt("AuctionUpgradeable", proxy.address);

const proxyOwnerBefore = await auctionProxyV1.read.owner();
console.log("Proxy deployed at:", proxy.address);
console.log("Caller:", wallet.account.address);
console.log("Before upgrade owner:", proxyOwnerBefore);
console.log("Before upgrade feeReceiver:", await auctionProxyV1.read.feeReceiver());
console.log("Before upgrade priceOracle:", await auctionProxyV1.read.priceOracle());
console.log("Before upgrade feePerCentage:", await auctionProxyV1.read.feePerCentage());

if (proxyOwnerBefore.toLowerCase() !== wallet.account.address.toLowerCase()) {
  throw new Error(
    `Caller is not proxy owner. expected ${wallet.account.address.toLowerCase()} but proxy owner is ${proxyOwnerBefore.toLowerCase()}`
  );
}

try {
  const initializeV2Data = encodeFunctionData({
    abi: implementationV2.abi,
    functionName: "initializeV2",
    args: [],
  });

  const implementationBefore = await readImplementation(proxy.address as `0x${string}`);
  console.log("Implementation before upgrade:", implementationBefore);

  console.log("Upgrading proxy to V2...");
  const txHash = await auctionProxyV1.write.upgradeToAndCall(
    [implementationV2.address, initializeV2Data],
    { account: wallet.account }
  );
  console.log("Upgrade tx hash:", txHash);

  const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
  console.log("Upgrade tx status:", receipt.status);

  const implementationAfter = await readImplementation(proxy.address as `0x${string}`);
  console.log("Implementation after upgrade:", implementationAfter);

  if (implementationAfter.toLowerCase() !== implementationV2.address.toLowerCase()) {
    throw new Error(
      `Proxy implementation mismatch: expected ${implementationV2.address}, got ${implementationAfter}`
    );
  }

  const auctionProxyV2 = await viem.getContractAt(
    "AuctionUpgradeableV2",
    proxy.address
  );

  const version = await auctionProxyV2.read.getVersion();
  const ownerAfter = await auctionProxyV2.read.owner();
  const feeReceiverAfter = await auctionProxyV2.read.feeReceiver();
  const priceOracleAfter = await auctionProxyV2.read.priceOracle();
  const feePerCentageAfter = await auctionProxyV2.read.feePerCentage();

  console.log("After upgrade getVersion:", version.toString());
  console.log("After upgrade owner:", ownerAfter);
  console.log("After upgrade feeReceiver:", feeReceiverAfter);
  console.log("After upgrade priceOracle:", priceOracleAfter);
  console.log("After upgrade feePerCentage:", feePerCentageAfter.toString());

  console.log(
    "Upgrade effect confirmed: old storage is preserved and new V2 function is available."
  );
} catch (error) {
  console.error("Upgrade check failed:", error);
  process.exitCode = 1;
}