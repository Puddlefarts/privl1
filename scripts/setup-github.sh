#!/bin/bash
set -e

echo "🚀 PRIVL1 - GitHub Setup Script"
echo "================================"
echo ""

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo "📦 Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install gh -y
    echo "✅ GitHub CLI installed!"
else
    echo "✅ GitHub CLI already installed"
fi

echo ""
echo "🔐 Authenticating with GitHub..."
gh auth login

echo ""
echo "📦 Creating repository on GitHub..."
gh repo create privl1 \
    --public \
    --description "Trustless zero-knowledge privacy Layer-1 blockchain | Privacy by default, programmable via zkVM, native DEX" \
    --source=. \
    --remote=origin \
    --push

echo ""
echo "🎉 SUCCESS! Your repo is live at:"
echo "   https://github.com/$(gh api user -q .login)/privl1"
echo ""
echo "✅ All done! PRIVL1 is now on GitHub."
