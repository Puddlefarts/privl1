# 🖼️ Frame + Trezor Setup Guide

**The easiest, most secure way to deploy with a Trezor hardware wallet.**

Frame handles all the complexity of Trezor integration - your private keys never leave the device.

---

## 🚀 Quick Start (5 minutes)

### 1. Install Frame

Download from: **https://frame.sh**

- **macOS**: Download .dmg and install
- **Linux**: Download AppImage or use `snap install frame-wallet`
- **Windows**: Download .exe installer

### 2. Launch Frame

Frame runs in your menu bar/system tray. Click the icon to open.

### 3. Connect Trezor

1. **Plug in your Trezor** via USB
2. **Unlock your Trezor** (enter PIN on device)
3. In Frame, click **"Add Account"**
4. Select **"Trezor"**
5. Choose your account (usually first one: `m/44'/60'/0'/0/0`)

You should now see your Trezor address in Frame!

### 4. Add Avalanche Fuji Network

1. In Frame, click **"Settings" → "Chains"**
2. Click **"Add Chain"**
3. Enter Fuji details:

```
Name: Avalanche Fuji
Chain ID: 43113
RPC URL: https://api.avax-test.network/ext/bc/C/rpc
Explorer: https://testnet.snowtrace.io
Symbol: AVAX
```

4. **Set Fuji as active network**

### 5. Fund Your Trezor Address

1. **Copy your Trezor address** from Frame
2. Get testnet AVAX from: **https://faucet.avax.network/**
3. Paste your address and request AVAX
4. Wait ~30 seconds for confirmation
5. **Check balance in Frame** - you should see AVAX appear

---

## ✅ Verify Setup

Test that Hardhat can connect to Frame:

```bash
# Start Hardhat console
npx hardhat console --network testnet

# Get your Trezor address
> (await ethers.getSigners())[0].address
'0xYourTrezorAddress...'

# Check balance
> await ethers.provider.getBalance('0xYourTrezorAddress')
BigNumber { value: "10000000000000000000" }  # 10 AVAX
```

If you see your address and balance, **you're ready to deploy!** 🎉

---

## 🚀 Deploy with Frame + Trezor

All deployment commands use `--network testnet`:

```bash
# Step 0: Test connection
npx hardhat run scripts/00_setup_trezor.ts --network testnet

# Step 1: Deploy PeL token
npx hardhat run scripts/01_deploy_core.ts --network testnet

# Step 2: Deploy ve(3,3) system
npx hardhat run scripts/02_deploy_ve_gauges.ts --network testnet

# Step 3: Deploy revenue system
npx hardhat run scripts/03_deploy_revenue.ts --network testnet

# Step 4: Add gauges
npx hardhat run scripts/04_add_gauges.ts --network testnet

# Step 5: Start emissions
npx hardhat run scripts/start_emissions.ts --network testnet
```

**What happens:**
1. Script prepares transaction
2. **Frame pops up** asking you to review
3. **Check transaction details in Frame**
4. **Approve on your Trezor device** (press button)
5. Transaction signs and broadcasts
6. Frame shows confirmation

---

## 🔒 Security Benefits

✅ **Private keys never leave Trezor** - physically impossible to extract
✅ **No keys in files** - Hardhat config has NO private keys
✅ **Visual confirmation** - Frame shows every transaction before signing
✅ **Hardware approval** - You physically press Trezor button for each tx
✅ **Works with any dApp** - Frame is a universal hardware wallet interface

---

## 🛠️ Troubleshooting

### "Frame not responding" or "Connection timeout"

1. **Make sure Frame is running** - check menu bar/system tray
2. **Restart Frame** - quit and relaunch
3. **Check Frame settings** - ensure local RPC is enabled (`http://127.0.0.1:1248`)
4. **Try different USB port** for Trezor

### "Trezor not detected in Frame"

1. **Unplug and replug** Trezor
2. **Update Trezor firmware** via Trezor Suite
3. **Enable Ethereum app** in Trezor Suite settings
4. **Try Trezor Bridge** - install from trezor.io if needed

### "Wrong network" or "Chain ID mismatch"

1. **In Frame, select Fuji network** (Chain ID 43113)
2. **Check hardhat.config.js** - `testnet` network should have `chainId: 43113`
3. **Restart Frame** after changing networks

### "Insufficient funds"

1. **Check balance in Frame** - click your account
2. **Request more from faucet** if needed
3. **Wait for faucet transaction** to confirm (~30 seconds)

### Transaction stuck or pending

1. **Don't close Frame** while tx is pending
2. **Check Snowtrace** - paste your tx hash at testnet.snowtrace.io
3. **Speed up** - Frame lets you increase gas price if stuck
4. **Cancel if needed** - Frame can submit a cancel transaction

---

## 📱 Frame Mobile (Optional)

Frame also works with **WalletConnect** for mobile Trezor use:

1. Install Frame mobile app
2. Connect Trezor via WalletConnect
3. Scan QR code from desktop Frame

---

## 🎯 Mainnet Deployment

When ready for production:

1. ✅ **Test thoroughly on Fuji first**
2. ✅ **Get contracts audited**
3. ✅ **Fund Trezor with mainnet AVAX** (for gas)
4. ✅ **In Frame, switch to Avalanche Mainnet** (Chain ID 43114)
5. ✅ **Use `--network mainnet` in all commands**

Example:
```bash
npx hardhat run scripts/01_deploy_core.ts --network mainnet
```

Frame will show **"Avalanche Mainnet"** and amounts in real AVAX. Double-check everything!

---

## 💡 Pro Tips

### Save Deployed Addresses Securely

After each deployment, Frame shows the contract address. **Write it down immediately** in:

- **Password manager** (1Password, Bitwarden, etc.)
- **Local notes** outside this repo
- **Encrypted file** (like deployment-config.json, which is gitignored)

### Use Frame for All Crypto Operations

Frame works with:
- Any Hardhat/Ethers script
- MetaMask-compatible dApps
- Hardware wallet signing for any EVM chain

### Multiple Trezor Accounts

Frame supports multiple accounts from same Trezor:
- `m/44'/60'/0'/0/0` - First account
- `m/44'/60'/0'/0/1` - Second account
- etc.

Use different accounts for deployer vs. treasury vs. emergency.

---

## 📚 Resources

- **Frame Docs**: https://docs.frame.sh
- **Trezor Support**: https://trezor.io/support
- **Avalanche Testnet Explorer**: https://testnet.snowtrace.io
- **Fuji Faucet**: https://faucet.avax.network

---

**You're all set!** Frame + Trezor is the gold standard for secure deployment. Your keys never leave the hardware device, and you get visual confirmation of every transaction.

🚀 **Ready to deploy? Run: `npx hardhat run scripts/00_setup_trezor.ts --network testnet`**
