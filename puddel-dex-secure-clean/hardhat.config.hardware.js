require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test", 
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    fuji: {
      url: process.env.FUJI_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      // NO PRIVATE KEYS - Use hardware wallet + MetaMask/Frame
      // accounts: [], // Empty - use external signer
      gas: 8000000,
      gasPrice: 25000000000,
      timeout: 120000
    },
    avalanche: {
      url: process.env.AVALANCHE_RPC_URL || "https://api.avax.network/ext/bc/C/rpc", 
      chainId: 43114,
      // NO PRIVATE KEYS - Use hardware wallet + MetaMask/Frame
      // accounts: [], // Empty - use external signer
      gas: 8000000,
      gasPrice: 25000000000,
      timeout: 120000
    }
  },
  etherscan: {
    apiKey: {
      avalanche: process.env.SNOWTRACE_API_KEY || "",
      fuji: process.env.SNOWTRACE_API_KEY || ""
    },
    customChains: [
      {
        network: "fuji",
        chainId: 43113,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/43113/etherscan",
          browserURL: "https://testnet.snowtrace.io"
        }
      }
    ]
  }
};