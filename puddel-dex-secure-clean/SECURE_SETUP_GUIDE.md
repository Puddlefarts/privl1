# 🔒 Secure File Structure Setup Guide

This guide shows how to set up a secure file structure that protects sensitive data with filesystem permissions.

## 🛡️ Security Architecture

The secure setup creates a `secure-private/` directory that:
- Is owned by root with 700 permissions (only root can access)
- Contains all sensitive files (.env, keys, deployment records)
- Is completely blocked from git commits
- Requires sudo access to read/write

## 📋 Setup Instructions

### Step 1: Create Secure Directory Structure

```bash
# Create the secure directory tree
sudo mkdir -p secure-private/{keys,env,deployments,backups}

# Set root ownership
sudo chown -R root:root secure-private/

# Set strict permissions (700 = owner read/write/execute only)
sudo chmod -R 700 secure-private/
```

### Step 2: Create Secure Environment File

```bash
# Create production environment file
sudo nano secure-private/env/.env.production
```

**Add this content (with your real values):**
```env
# CRITICAL: Never commit this file or share these values
PRIVATE_KEY=your_new_64_character_private_key_without_0x_prefix
DEPLOYER_ADDRESS=0xYourNewWalletAddressFromThePrivateKey
SNOWTRACE_API_KEY=your_snowtrace_api_key_for_contract_verification
RPC_URL=https://api.avax.network/ext/bc/C/rpc
VERIFY_CONTRACTS=true
```

### Step 3: Set File Permissions

```bash
# Secure the environment file
sudo chmod 600 secure-private/env/.env.production

# Verify permissions
ls -la secure-private/env/
# Should show: -rw------- 1 root root
```

### Step 4: Test Access

```bash
# This should work (you have sudo)
sudo cat secure-private/env/.env.production

# This should fail (regular user access blocked)
cat secure-private/env/.env.production
```

## 🚀 Deployment Usage

### Secure Deployment Command

```bash
# Run deployment with secure environment
sudo node scripts/deploy-with-secure-env.js --network avalanche
```

The secure deployment script will:
1. ✅ Validate file permissions
2. ✅ Load environment variables securely
3. ✅ Run deployment without logging sensitive data
4. ✅ Clean up environment variables after completion

## 📁 Directory Structure

```
puddel-dex-secure/
├── secure-private/           # 🔒 ROOT ONLY ACCESS
│   ├── env/
│   │   └── .env.production   # 🔑 Production secrets
│   ├── keys/
│   │   └── backup-keys.json  # 🔑 Encrypted key backups
│   ├── deployments/
│   │   └── *.json           # 📋 Deployment records
│   └── backups/
│       └── *.backup         # 💾 Secure backups
├── scripts/                  # ✅ Public deployment scripts
├── contracts/               # ✅ Public smart contracts
└── src/                     # ✅ Public frontend code
```

## 🔐 Access Control

| User/Process | secure-private/ | Regular Files |
|--------------|----------------|---------------|
| You (sudo)   | ✅ Full Access | ✅ Full Access |
| You (normal) | ❌ No Access   | ✅ Full Access |
| Claude Code  | ❌ No Access   | ✅ Read Only   |
| Git          | ❌ Blocked     | ✅ Tracks     |
| Deployment   | ✅ Sudo Access | ✅ Read Access |

## 🚨 Security Benefits

1. **Physical Security**: Even if someone gets your laptop, they need your sudo password
2. **Process Isolation**: Development tools can't accidentally access sensitive files  
3. **Git Safety**: Impossible to commit sensitive files
4. **Audit Trail**: All secure file access requires sudo (logged)
5. **Compartmentalization**: Secrets are completely separate from code

## 🆘 Emergency Procedures

### If Files Are Compromised
```bash
# Immediately change permissions to lock down
sudo chmod 000 secure-private/

# Generate new keys and update files
sudo nano secure-private/env/.env.production

# Restore access when ready
sudo chmod -R 700 secure-private/
```

### Backup Secure Files
```bash
# Create encrypted backup
sudo tar -czf secure-backup-$(date +%Y%m%d).tar.gz secure-private/
sudo gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
    secure-backup-$(date +%Y%m%d).tar.gz

# Store encrypted backup safely
sudo rm secure-backup-$(date +%Y%m%d).tar.gz
```

## ✅ Verification

Run this to verify your setup:
```bash
# Should succeed (with sudo)
sudo ls -la secure-private/env/

# Should fail (without sudo)  
ls secure-private/env/

# Should show proper git ignore
git status # secure-private/ should not appear
```

---

**🛡️ This setup ensures your private keys remain completely secure while allowing safe public repository sharing.**