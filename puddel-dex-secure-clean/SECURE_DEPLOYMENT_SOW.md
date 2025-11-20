# SECURE DEPLOYMENT SOW
## Statement of Work: Production-Ready Secure PUDDeL Deployment

**Document Version**: 1.0  
**Date**: August 2, 2025  
**Classification**: SECURITY CRITICAL

---

## 🎯 **OBJECTIVE**

Deploy PUDDeL DEX ecosystem with ZERO private key exposure to Claude or git history, ensuring institutional-grade security for public launch.

## 🚨 **SECURITY REQUIREMENTS**

### **NON-NEGOTIABLE RULES**
1. ❌ **Claude NEVER sees actual private keys**
2. ❌ **No keys EVER committed to git** 
3. ❌ **No keys in environment files**
4. ✅ **Hardware wallet usage strongly recommended**
5. ✅ **Encrypted storage for backup keys only**
6. ✅ **Multi-signature for production contracts**

---

## 📋 **PHASE 1: SECURE KEY GENERATION**

### **Step 1.1: Generate Primary Deployment Keys**
```bash
# You do this OFFLINE, Claude does NOT see the output
openssl rand -hex 32  # Generates new private key
# Save this key securely - DO NOT share with Claude
```

**Your Actions:**
- [ ] Generate new private key offline
- [ ] Write down key on paper (backup)
- [ ] Store in hardware wallet if available
- [ ] Create secure address from key
- [ ] Fund address with test AVAX for deployment

**Claude Actions:**
- [ ] Create deployment scripts that read from environment
- [ ] Test scripts with placeholder keys
- [ ] Verify all scripts use process.env.PRIVATE_KEY

### **Step 1.2: Environment Setup**
```bash
# You create this file locally - Claude NEVER sees it
touch .env.production.local

# Add your real key (you type this, not Claude):
echo "PRIVATE_KEY=your_actual_key_here" >> .env.production.local
echo "DEPLOYER_ADDRESS=your_address_here" >> .env.production.local
```

**Security Check:**
- [ ] Verify .env.production.local is in .gitignore
- [ ] Confirm git status shows file as ignored
- [ ] Test that pre-commit hook blocks if accidentally staged

---

## 📋 **PHASE 2: SECURE DEPLOYMENT SCRIPTS**

### **Step 2.1: Create Encrypted Deployment System**

**Claude Will:**
- [ ] Create deployment scripts that read from environment only
- [ ] Build verification system for contract deployment
- [ ] Create rollback procedures for failed deployments
- [ ] Add comprehensive logging (no keys logged)

**You Will:**
- [ ] Review all scripts for security before running
- [ ] Confirm no hardcoded values in any files
- [ ] Run deployment in secure environment

### **Step 2.2: Contract Deployment Order**
1. **PeL Token** (ERC-20 with proper tokenomics)
2. **Factory** (Uniswap V2 fork with security enhancements)  
3. **Router** (Trading interface with slippage protection)
4. **Governance** (DAO with voting escrow system)
5. **Verification** (All contracts on Snowtrace)

---

## 📋 **PHASE 3: DEPLOYMENT EXECUTION**

### **Step 3.1: Pre-Deployment Security Check**
```bash
# Security verification before deployment
npm run security-check     # Claude creates this
npm run test               # Run all tests
npm run compile            # Verify compilation
```

**Checklist:**
- [ ] All tests pass
- [ ] Security hooks active
- [ ] Environment variables set
- [ ] Git status clean (no uncommitted changes)
- [ ] Pre-commit hook tested and working

### **Step 3.2: Deployment Process**

**Your Terminal Session:**
```bash
# You run these commands - Claude guides but doesn't see output
cd puddel-dex-secure
npm install
npm run deploy:production  # Claude creates this script
```

**Security Protocol:**
- [ ] Run deployment in separate terminal Claude can't see
- [ ] Copy only contract addresses to share with Claude
- [ ] Never share transaction hashes or other details
- [ ] Verify deployment success independently

### **Step 3.3: Contract Verification**
```bash
# Verify contracts on Snowtrace (automated)
npm run verify:all         # Claude creates this
```

---

## 📋 **PHASE 4: POST-DEPLOYMENT SECURITY**

### **Step 4.1: Secure the Deployment**
- [ ] Transfer contract ownership to multisig (if applicable)
- [ ] Remove deployment keys from active use
- [ ] Store backup keys in encrypted cold storage
- [ ] Document all contract addresses

### **Step 4.2: Update Frontend**
```bash
# You provide only contract addresses to Claude
# Example format (you fill in real addresses):
FACTORY=0x1234567890123456789012345678901234567890
ROUTER=0x2345678901234567890123456789012345678901
TOKEN=0x3456789012345678901234567890123456789012
GOVERNANCE=0x4567890123456789012345678901234567890123
```

**Claude Will:**
- [ ] Update src/contracts/addresses.ts with your addresses
- [ ] Test frontend integration
- [ ] Verify all functionality works
- [ ] Update documentation

---

## 📋 **PHASE 5: SECURITY VALIDATION**

### **Step 5.1: Final Security Audit**
- [ ] Verify no keys in git history: `git log -p --all | grep -i private`
- [ ] Confirm all environment files are ignored
- [ ] Test pre-commit hooks work
- [ ] Verify contract ownership is correct

### **Step 5.2: Documentation Update**
- [ ] Update README with new contract addresses
- [ ] Document deployment process
- [ ] Create investor security report
- [ ] Prepare public launch materials

---

## 🔒 **SECURITY PROTOCOLS**

### **Information Sharing Rules**

**YOU SHARE WITH CLAUDE:**
- ✅ Contract addresses (after deployment)
- ✅ Transaction success/failure status
- ✅ Error messages (without sensitive data)
- ✅ Gas costs and deployment metrics

**YOU NEVER SHARE WITH CLAUDE:**
- ❌ Private keys or mnemonics
- ❌ Transaction hashes
- ❌ Wallet balances or specific amounts
- ❌ Environment file contents
- ❌ Any hexadecimal strings that could be keys

### **Emergency Procedures**

**If Deployment Fails:**
1. STOP immediately
2. Do NOT share error details containing keys
3. Generate new keys if compromise suspected
4. Start deployment process over

**If Keys Accidentally Exposed:**
1. Generate new keys immediately
2. Transfer all funds to new address
3. Restart entire deployment process
4. Never use exposed keys again

---

## 📊 **SUCCESS CRITERIA**

### **Technical Requirements**
- [ ] All contracts deployed successfully
- [ ] Frontend connects to new contracts
- [ ] All tests pass with new deployment
- [ ] Contracts verified on Snowtrace
- [ ] No security vulnerabilities detected

### **Security Requirements**
- [ ] Zero private key exposure to Claude or git
- [ ] All deployment keys stored securely
- [ ] Pre-commit hooks prevent future exposure
- [ ] Clean git history maintained
- [ ] Professional security documentation

### **Business Requirements**
- [ ] Investor-ready deployment
- [ ] Professional documentation
- [ ] Clean contract addresses
- [ ] Audit-ready codebase
- [ ] Public launch ready

---

## ⚡ **NEXT IMMEDIATE ACTIONS**

### **FOR YOU (RIGHT NOW):**
1. Generate new private key offline
2. Fund new address with test AVAX
3. Create .env.production.local file (local only)
4. Confirm Claude cannot see your environment

### **FOR CLAUDE (NEXT):**
1. Create secure deployment scripts
2. Build verification system
3. Test with placeholder keys
4. Prepare step-by-step deployment guide

---

## 🤝 **ROLES & RESPONSIBILITIES**

### **YOUR RESPONSIBILITIES:**
- Generate and secure private keys
- Execute deployment commands
- Verify contract addresses
- Maintain key security
- Make go/no-go decisions

### **CLAUDE'S RESPONSIBILITIES:**
- Create secure deployment scripts
- Provide technical guidance
- Update frontend with addresses you provide
- Ensure no security vulnerabilities
- Document the process

---

**🔐 REMEMBER: Security is more important than speed. If anything feels unsafe, STOP and reassess.**

Are you ready to proceed with Phase 1: Secure Key Generation?