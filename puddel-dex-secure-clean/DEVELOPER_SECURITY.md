# Developer Security Guidelines

## 🚨 **NEVER COMMIT THESE**

### ❌ **Absolutely Forbidden**
```javascript
// NEVER DO THIS - Private keys in code
const privateKey = "0x1234...abcd"; // Example - never put real keys here
const wallet = new ethers.Wallet(privateKey, provider);

// NEVER DO THIS - Secrets in environment files
PRIVATE_KEY=actual_private_key_here
MNEMONIC=actual twelve word mnemonic here
```

### ✅ **Always Do This Instead**
```javascript
// CORRECT - Use environment variables
const privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
    throw new Error("PRIVATE_KEY environment variable not set");
}
const wallet = new ethers.Wallet(privateKey, provider);

// CORRECT - Use encrypted storage for production
const encryptedWallet = await getEncryptedWallet();
```

## 🛡️ **Security Rules**

### **1. Environment Variables**
- ✅ Use `.env.local` for development (never committed)
- ✅ Use `.env.example` with placeholder values
- ❌ Never commit actual `.env` files

### **2. Private Keys**
- ✅ Store in environment variables only
- ✅ Use encrypted wallets for production
- ✅ Use hardware wallets when possible
- ❌ Never hardcode in any file

### **3. Debug Scripts**
- ✅ Always use `process.env.PRIVATE_KEY`
- ✅ Name them `debug-*.js` (auto-ignored)
- ✅ Delete after debugging
- ❌ Never commit debug scripts with keys

### **4. Testing**
```javascript
// CORRECT - Test setup
const testPrivateKey = process.env.TEST_PRIVATE_KEY || "0x" + "0".repeat(64);

// CORRECT - Use test mnemonics from environment
const testMnemonic = process.env.TEST_MNEMONIC || "test test test test test test test test test test test junk";
```

## 🔒 **Automated Protection**

This repository has automated protection:

### **Pre-commit Hooks**
- Scans for private key patterns
- Blocks 64-character hex strings
- Prevents .env file commits
- Shows clear error messages

### **Enhanced .gitignore**
- Blocks files with "private", "key", "secret" in name
- Ignores wallet files and keystores
- Blocks debug scripts
- Protects encrypted storage directories

### **Testing Protection**
```bash
# Test the protection (should fail)
echo "const privateKey = '1234...64chars...abcd';" > test-private-key.js // Example key pattern
git add test-private-key.js
git commit -m "test" # This will be BLOCKED
```

## 📋 **Secure Development Checklist**

Before any commit:
- [ ] No private keys in any files
- [ ] Environment variables used correctly
- [ ] No .env files being committed
- [ ] Debug scripts deleted or using env vars
- [ ] Pre-commit hook passes
- [ ] Code review by another developer

## 🚨 **If You Accidentally Commit Keys**

**STOP IMMEDIATELY:**
1. Do NOT push to remote
2. Generate new private keys
3. Reset git history: `git reset --hard HEAD~1`
4. Update all references to use new keys
5. If already pushed, create new repository (like we did)

## 💡 **Best Practices**

### **Development Environment**
```bash
# Setup development environment
cp .env.example .env.local
# Edit .env.local with your development keys
echo ".env.local" >> .gitignore  # Extra safety
```

### **Production Deployment**
```bash
# Use encrypted storage
node scripts/setup-encrypted-wallet.js
# Deploy with encrypted keys
node scripts/deploy-production.js --encrypted
```

### **Team Collaboration**
- Share placeholder .env.example files
- Use different keys for each developer
- Rotate keys regularly
- Use separate keys for test/prod

---

**Remember**: Once a private key is committed to git, it's compromised forever. The only solution is to generate new keys and abandon the old ones.