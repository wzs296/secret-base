import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";
import "dotenv/config";
import "@nomicfoundation/hardhat-verify";

const sepoliaRpcUrl = (process.env.SEPOLIA_RPC_URL ?? "").trim();
const sepoliaPrivateKey = (process.env.SEPOLIA_PRIVATE_KEY ?? "").trim();

export default defineConfig({
  plugins: [hardhatToolboxViemPlugin],
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  solidity: {
    profiles: {
      default: {
        version: "0.8.34",
      },
      production: {
        version: "0.8.34",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    sepolia: {
      type: "http",
      chainType: "l1",
      url: sepoliaRpcUrl,
      accounts: [sepoliaPrivateKey],
    },
  },
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY"),
    },
  },
} as any);
