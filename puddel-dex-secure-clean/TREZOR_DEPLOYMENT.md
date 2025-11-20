# 🔐 PUDDeL DEX - Trezor Deployment Guide

**Zero-knowledge, hardware wallet-secured deployment system.**

Your private keys never leave your Trezor device. All sensitive addresses are prompted at runtime and never stored in files.

---

## 🛡️ Security Guarantees

✅ **Private keys:** Stored in Trezor hardware, never exposed
✅ **Wallet addresses:** Prompted at runtime, never in git
✅ **Contract addresses:** You record them manually
✅ **Configuration:** No sensitive data in committed files

---

## 📋 Prerequisites

### 1. Hardware

- **Trezor device** (Model One or Model T)
- USB connection to your computer
- Trezor firmware up to date

### 2. Software

```bash
# Install Hardhat Ledger plugin (works with Trezor too)
npm install --save-dev @nomicfoundation/hardhat-ledger

# Or use Hardhat's Trezor integration
npm install --save-dev @trezor/connect-web
```

### 3. Testnet AVAX

- Fund your Trezor address with testnet AVAX for gas
- Get testnet AVAX from: https://faucet.avax.network/

---

## ⚙️ Hardhat Configuration

### Option A: Using `@nomicfoundation/hardhat-ledger` (Recommended)

**hardhat.config.ts:**
```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ledger";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    testnet: {
      url: process.env.RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
      ledgerAccounts: [
        // Derivation path for first account: m/44'/60'/0'/0/0
        "0x0",
      ],
    },
    mainnet: {
      url: process.env.RPC_URL || "https://api.avax.network/ext/bc/C/rpc",
      ledgerAccounts: ["0x0"],
    },
  },
};

export default config;
```

### Option B: Using Frame (Easiest)

1. **Install Frame:** https://frame.sh
2. **Connect Trezor** to Frame
3. **Configure Hardhat:**

```typescript
networks: {
  testnet: {
    url: "http://127.0.0.1:1248", // Frame's local RPC
  }
}
```

Frame automatically handles Trezor signing!

---

## 🚀 Deployment Steps

### Step 0: Test Trezor Connection

```bash
npx hardhat run scripts/00_setup_trezor.ts --network testnet
```

**Expected output:**
```
🔐 PUDDeL DEX - Trezor Setup
==================================================

✅ Trezor Connected Successfully!
──────────────────────────────────────────────────
Deployer Address: 0xYourTrezorAddress...
Balance: 10.5 AVAX
Network: testnet (Chain ID: 43113)
```

⚠️ **Make sure you have sufficient AVAX balance!**

---

### Step 1: Deploy Core (PeL Token)

```bash
npx hardhat run scripts/01_deploy_core.ts --network testnet
```

**What happens:**
1. Script connects to your Trezor
2. Prompts you for:
   - Admin address (default: your Trezor address)
   - Initial PeL supply
3. **You approve transaction on Trezor device**
4. PeL token deploys
5. **Script displays address - WRITE IT DOWN!**

**Example interaction:**
```
🔐 Deployer (Trezor): 0xABCD...1234
💰 Balance: 10.5 AVAX

📝 Configuration:
Enter Admin/Multisig address (default: 0xABCD...1234): [press Enter or type address]
Initial PeL supply (default: 1000000): [press Enter or type amount]

⚠️  Please approve the transaction on your Trezor device...
✅ PeL Token deployed!
   Address: 0x5678...ABCD

📋 DEPLOYMENT SUMMARY - WRITE THESE DOWN!
PeL Token: 0x5678...ABCD
```

---

### Step 2: Deploy ve(3,3) System

```bash
npx hardhat run scripts/02_deploy_ve_gauges.ts --network testnet
```

**Prompts:**
- PeL token address (from Step 1)
- Admin address
- Epoch length (default: 604800 = 7 days)
- Initial emission per epoch

**Deploys:**
- VotingEscrow (veNFT)
- Voter (gauge weights)
- Minter (emissions)

**Grants:**
- MINTER_ROLE to Minter contract

---

### Step 3: Deploy Revenue System

```bash
npx hardhat run scripts/03_deploy_revenue.ts --network testnet
```

**Prompts:**
- PeL token address
- Treasury address
- Emergency fund address
- veRewards address (optional)
- Factory address

**Deploys:**
- FeeDistributor

**Configures:**
- Factory.feeTo → FeeDistributor

---

### Step 4: Add Gauges for LP Pairs

```bash
npx hardhat run scripts/04_add_gauges.ts --network testnet
```

**Interactive loop:**
```
Add a gauge for a liquidity pair? (y/n): y
Enter Liquidity Pair address: 0x...
Pair name (e.g., PeL-AVAX): PeL-AVAX

📦 Deploying Gauge...
⚠️  Approve on Trezor...
✅ Gauge deployed

📦 Deploying Bribe...
✅ Bribe deployed

Add another gauge? (y/n): n
```

**For each pair, deploys:**
- Gauge (LP staking)
- Bribe (voter incentives)

**Configures:**
- Registers gauge in Voter
- Grants MINTER_ROLE to Minter

---

### Step 5: Start Emissions

```bash
npx hardhat run scripts/start_emissions.ts --network testnet
```

**What it does:**
- Calls `Minter.updateEpoch()` for the first time
- Starts weekly emission distribution
- After this, anyone can call `updateEpoch()` permissionlessly

---

## 📝 Recording Deployed Addresses

### Option 1: Manual Record (Most Secure)

Create a file **outside this repository** (e.g., in a password manager):

```
PUDDeL DEX Testnet Deployment - 2025-01-XX

PeL Token: 0x...
VotingEscrow: 0x...
Voter: 0x...
Minter: 0x...
FeeDistributor: 0x...

Gauges:
- PeL-AVAX: Gauge 0x..., Bribe 0x...
- USDC-AVAX: Gauge 0x..., Bribe 0x...
```

### Option 2: Local Config File (Gitignored)

Create `deployment-config.json` (already in `.gitignore`):

```json
{
  "network": "testnet",
  "deployedAt": "2025-01-XX",
  "contracts": {
    "PeL": "0x...",
    "VotingEscrow": "0x...",
    "Voter": "0x...",
    "Minter": "0x...",
    "FeeDistributor": "0x..."
  },
  "gauges": [
    {
      "pair": "PeL-AVAX",
      "gauge": "0x...",
      "bribe": "0x..."
    }
  ]
}
```

**Verify it's gitignored:**
```bash
git status deployment-config.json
# Should output: "Untracked files" or "pathspec did not match"
```

---

## 🔍 Verification

### Verify No Secrets in Git

```bash
# Check .env is gitignored
git check-ignore -v .env
# Output: .gitignore:23:.env    .env

# Check no secrets in tracked files
git grep -E "(0x[a-fA-F0-9]{64}|privateKey)" -- '*.ts' '*.js'
# Should return nothing

# Check deployment config is gitignored
git ls-files | grep -E "(deployment-config|deployed-addresses|\.secret)"
# Should return nothing
```

### Verify Contract Deployment

```bash
# Check contract on Snowtrace (testnet)
open "https://testnet.snowtrace.io/address/0xYourContractAddress"

# Or use Hardhat
npx hardhat verify --network testnet 0xYourContractAddress "constructor" "args"
```

---

## 🛠️ Troubleshooting

### "Trezor not connected"

1. Make sure Trezor is plugged in via USB
2. Unlock your Trezor device
3. Enable "Ethereum" in Trezor Suite if prompted
4. Try reconnecting: unplug and plug back in

### "Insufficient funds for gas"

- Your Trezor address needs testnet AVAX
- Get from faucet: https://faucet.avax.network/
- Check balance: `npx hardhat run scripts/00_setup_trezor.ts --network testnet`

### "Transaction rejected on Trezor"

- You must approve each transaction on the device
- Double-check the transaction details on screen
- If values look wrong, cancel and restart deployment

### "Ledger accounts not found"

- Check `hardhat.config.ts` has `ledgerAccounts` configured
- Ensure `@nomicfoundation/hardhat-ledger` is installed
- Try using Frame instead (easier setup)

---

## 🎉 Post-Deployment

### Mainnet Deployment

**When ready for mainnet:**

1. ✅ Thoroughly test on testnet first
2. ✅ Get contracts audited
3. ✅ Use a **fresh Trezor** or **multisig** for mainnet admin
4. ✅ Change network to `mainnet` in commands:
   ```bash
   npx hardhat run scripts/01_deploy_core.ts --network mainnet
   ```

### Ongoing Operations

**Weekly epoch rolls:**
```bash
# Anyone can call (permissionless)
npx hardhat run scripts/start_emissions.ts --network testnet
```

**Or automate with a cron/keeper:**
```bash
# Every Monday at 00:00 UTC
0 0 * * 1 npx hardhat run scripts/start_emissions.ts --network mainnet
```

---

## 📞 Support

If you encounter issues:
1. Check Trezor Suite is up to date
2. Verify Hardhat config matches this guide
3. Ensure sufficient AVAX for gas
4. Review error messages carefully

---

**Security Note:** This guide ensures your private keys never leave your Trezor device. All deployment scripts prompt for addresses at runtime and never store sensitive data in files that could be committed to git.
