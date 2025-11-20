require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  "ts-node": {
    transpileOnly: true,
    compilerOptions: {
      module: "commonjs"
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          viaIR: true
        }
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ],
    overrides: {
      "@openzeppelin/contracts/**/*.sol": {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  networks: {
    // RECOMMENDED: Frame + Ledger for secure deployment (no private keys in files)
    // Install Frame.sh, connect your Ledger, then use: --network testnet
    testnet: {
      url: "http://127.0.0.1:1248", // Frame RPC (WSL -> Windows host)
      chainId: 43113, // Fuji testnet (set in Frame)
      timeout: 120000,
      // No 'accounts' - Frame + Ledger handle signing
    },
    mainnet: {
      url: "http://127.0.0.1:1248", // Frame RPC (WSL can reach Windows localhost)
      chainId: 43114, // Avalanche mainnet (set in Frame)
      timeout: 120000,
      // No 'accounts' - Frame + Ledger handle signing
    },

    // LEGACY: Direct RPC with private key (less secure, for testing only)
    fuji: {
      url: process.env.FUJI_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gas: 8000000,
      gasPrice: 25000000000,
      timeout: 120000
    },
    avalanche: {
      url: process.env.AVALANCHE_RPC_URL || "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      gas: 8000000,
      gasPrice: 25000000000,
      timeout: 120000
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
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
