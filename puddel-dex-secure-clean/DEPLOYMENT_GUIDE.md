# 🔒 SECURE DEPLOYMENT GUIDE

**CRITICAL**: Follow this guide exactly to deploy PUDDeL contracts securely without exposing private keys.

## 📋 **PREREQUISITES**

### **1. Environment Setup**
```bash
# Clone and enter secure repository
cd puddel-dex-secure

# Install dependencies
npm install

# Verify security systems work
npm run check-security
```

### **2. Generate Secure Private Key**
```bash
# Generate new private key (do this OFFLINE)
openssl rand -hex 32

# Example output: a1b2c3d4e5f6789...
# NEVER share this key with anyone (including Claude)
```

### **3. Fund Deployment Address**
- Import private key into MetaMask (temporarily)
- Get your address from MetaMask
- Send 5+ AVAX to address for deployment costs
- Remove private key from MetaMask after funding

## 🔐 **SECURE DEPLOYMENT PROCESS**

### **Step 1: Create Environment File**
```bash
# Create production environment file (LOCAL ONLY)
touch .env.production.local

# Add your private key (YOU type this, not Claude):
echo "PRIVATE_KEY=YOUR_ACTUAL_PRIVATE_KEY_HERE" >> .env.production.local
echo "DEPLOYER_ADDRESS=0xYOUR_ADDRESS_HERE" >> .env.production.local
echo "SNOWTRACE_API_KEY=YOUR_API_KEY_HERE" >> .env.production.local
echo "VERIFY_CONTRACTS=true" >> .env.production.local
```

**SECURITY CHECK:**
```bash
# Verify file is ignored by git
git status
# Should NOT show .env.production.local

# Test pre-commit hook
echo "test" > temp.txt
git add temp.txt
git commit -m "test"  # Should work

# Test security protection
echo "const privateKey = '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';" > test-key.js
git add test-key.js
git commit -m "test"  # Should FAIL with security alert
rm test-key.js
```

### **Step 2: Pre-Deployment Validation**
```bash
# Run all security checks
npm run security-check

# Expected output:
# ✅ Lint passed
# ✅ Compilation successful  
# ✅ All tests passed
```

### **Step 3: Deploy to Fuji Testnet**
```bash
# Load your environment (you type the values)
export $(cat .env.production.local | xargs)

# Deploy to Fuji testnet
npm run deploy:fuji

# Expected output:
# 🔒 SECURE PRODUCTION DEPLOYMENT STARTING
# ✅ Security validation passed
# ✅ Deployer Address: 0xYOUR_ADDRESS
# 💰 Initial Balance: X.XXX AVAX
# 1️⃣ DEPLOYING PeL TOKEN
# ✅ PeL Token deployed: 0x1234...
# 2️⃣ DEPLOYING FACTORY  
# ✅ Factory deployed: 0x5678...
# 3️⃣ DEPLOYING ROUTER
# ✅ Router deployed: 0x9abc...
# 4️⃣ DEPLOYING GOVERNANCE
# ✅ Governance deployed: 0xdef0...
# 5️⃣ CONTRACT VERIFICATION
# ✅ All contracts verified
# 🎉 SECURE DEPLOYMENT COMPLETED SUCCESSFULLY!
```

### **Step 4: Validate Deployment**
```bash
# Validate all contracts deployed correctly
npm run validate-deployment

# Expected output:
# 🔍 VALIDATING DEPLOYMENT
# ✅ PEL Token: 0x1234...
# ✅ Factory: 0x5678...
# ✅ Router: 0x9abc...
# ✅ Governance: 0xdef0...
# ✅ ALL CONTRACTS VALIDATED SUCCESSFULLY
```

### **Step 5: Share Contract Addresses with Claude**
**ONLY share the contract addresses (NOT private keys or transaction details):**

```
Factory: 0x1234567890123456789012345678901234567890
Router: 0x2345678901234567890123456789012345678901  
PeL Token: 0x3456789012345678901234567890123456789012
Governance: 0x4567890123456789012345678901234567890123
```

Claude will then update the frontend with these addresses.

## 🚨 **SECURITY RULES**

### **✅ SAFE TO SHARE WITH CLAUDE:**
- Contract addresses (after deployment)
- "Deployment successful" or "Deployment failed" status
- Gas costs or deployment times
- Error messages (without sensitive data)

### **❌ NEVER SHARE WITH CLAUDE:**
- Private keys or mnemonics
- Transaction hashes  
- Wallet balances
- Environment file contents
- Any 64-character hex strings

## 🔄 **MAINNET DEPLOYMENT**

Once Fuji deployment is tested and working:

### **Step 1: Create Mainnet Environment**
```bash
# Create mainnet environment file
touch .env.mainnet.local

# Add mainnet configuration
echo "PRIVATE_KEY=YOUR_MAINNET_PRIVATE_KEY" >> .env.mainnet.local
echo "DEPLOYER_ADDRESS=0xYOUR_MAINNET_ADDRESS" >> .env.mainnet.local
echo "SNOWTRACE_API_KEY=YOUR_API_KEY" >> .env.mainnet.local
echo "VERIFY_CONTRACTS=true" >> .env.mainnet.local
```

### **Step 2: Deploy to Mainnet**
```bash
# Load mainnet environment
export $(cat .env.mainnet.local | xargs)

# Deploy to Avalanche mainnet
npm run deploy:mainnet
```

## 🛡️ **POST-DEPLOYMENT SECURITY**

### **Immediate Actions:**
1. **Remove private keys from environment files**
2. **Transfer contract ownership** to multisig (recommended)
3. **Store backup keys** in encrypted cold storage
4. **Delete deployment keys** from hot wallets
5. **Document all addresses** in secure location

### **Long-term Security:**
1. **Use hardware wallets** for contract administration
2. **Enable multisig** for critical operations
3. **Rotate API keys** regularly
4. **Monitor contracts** for unusual activity
5. **Keep emergency procedures** documented and tested

## 🚨 **EMERGENCY PROCEDURES**

### **If Deployment Fails:**
1. Check error message (don't share sensitive details)
2. Verify environment variables are set correctly
3. Check AVAX balance is sufficient
4. Try deployment again with same environment

### **If Private Key Exposed:**
1. **STOP IMMEDIATELY** - don't continue deployment
2. **Generate new private key**
3. **Transfer all funds** to new address  
4. **Start deployment process over** with new key
5. **Never use exposed key again**

### **If Transaction Stuck:**
1. Check network status (Avalanche/Fuji)
2. Increase gas price if needed
3. Wait for network congestion to clear
4. Contact support if issue persists

---

**🔒 REMEMBER: Security is more important than speed. If anything feels unsafe, STOP and get help.**