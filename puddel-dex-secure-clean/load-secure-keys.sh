#!/bin/bash
# Load secure keys for development (requires sudo)

echo "🔐 Loading secure API keys..."
echo "This requires your sudo password."
echo ""

# Check if secure file exists
if [ ! -f ".env.secure" ]; then
    echo "❌ .env.secure not found!"
    echo "Run: sudo ./setup-secure-env.sh first"
    exit 1
fi

# Copy secure keys to .env.local (requires password)
sudo cat .env.secure > .env.local

if [ $? -eq 0 ]; then
    echo "✅ Secure keys loaded into .env.local"
    echo "🚀 You can now run: npm run dev"
    echo ""
    echo "Note: The AI assistant can now read .env.local"
    echo "      Clear it when done: echo '# Cleared' > .env.local"
else
    echo "❌ Failed to load keys (incorrect password?)"
fi