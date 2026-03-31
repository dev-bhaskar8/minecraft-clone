require("@nomicfoundation/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

const {
  PRIVATE_KEY,
  BASE_RPC_URL,
  BASE_SEPOLIA_RPC_URL,
  ETHERSCAN_API_KEY,
} = process.env;

function net(url, chainId) {
  if (!url || !PRIVATE_KEY) return undefined;
  return { url, chainId, accounts: [PRIVATE_KEY] };
}

const networks = {};
const baseNet = net(BASE_RPC_URL, 8453);
if (baseNet) networks.base = baseNet;
const baseSepoliaNet = net(BASE_SEPOLIA_RPC_URL, 84532);
if (baseSepoliaNet) networks.baseSepolia = baseSepoliaNet;

/** @type {import('hardhat/config').HardhatUserConfig} */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  networks,
  // Optional; only used if you add @nomicfoundation/hardhat-verify later.
  etherscan: {
    apiKey: {
      base: ETHERSCAN_API_KEY || "",
      baseSepolia: ETHERSCAN_API_KEY || "",
    },
  },
};
