# Quick Push to GitHub - Instructions

## Step 1: Create the Repo on GitHub.com

1. Go to: **https://github.com/new**
2. Fill in:
   - **Repository name**: `privl1`
   - **Description**: `Trustless zero-knowledge privacy Layer-1 blockchain | Privacy by default, programmable via zkVM, native DEX`
   - **Visibility**: ✓ Public
   - **DO NOT** check any "Initialize with..." boxes
3. Click **"Create repository"**

## Step 2: Push Your Code

Back in your terminal, run these commands:

```bash
cd /home/sakas/projects/privl1

# Add GitHub as remote
git remote add origin https://github.com/puddlefarts/privl1.git

# Push everything
git push -u origin main
```

## Authentication

When it asks for credentials:
- **Username**: `puddlefarts`
- **Password**: Use a [Personal Access Token](https://github.com/settings/tokens/new)
  - If you don't have one:
    1. Go to: https://github.com/settings/tokens/new
    2. Give it a name: "PRIVL1 Development"
    3. Expiration: 90 days (or No expiration if you're living dangerously)
    4. Check: `repo` (Full control of private repositories)
    5. Click "Generate token"
    6. **COPY THE TOKEN** (you won't see it again!)
    7. Use this as your password when pushing

## That's It!

Your repo will be live at: **https://github.com/puddlefarts/privl1**

---

**Then we fix the crypto and start recruiting devs!** 🚀
