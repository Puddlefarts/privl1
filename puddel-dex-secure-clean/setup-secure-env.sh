#!/bin/bash
# Secure environment setup using sudo

echo "🔐 Secure Environment Setup"
echo "This script will:"
echo "1. Create a root-owned secure keys file"
echo "2. Copy keys to .env.local when you need to run the app"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo ./setup-secure-env.sh"
    exit 1
fi

# Create secure keys file
SECURE_FILE=".env.secure"

if [ ! -f "$SECURE_FILE" ]; then
    echo "Creating secure keys file..."
    cat > "$SECURE_FILE" << 'EOF'
# Secure API Keys - Protected by root
# Edit with: sudo nano .env.secure
HUGGINGFACE_API_KEY=your_secure_key_here
EOF
    
    # Lock it down
    chown root:root "$SECURE_FILE"
    chmod 600 "$SECURE_FILE"
    echo "✅ Created $SECURE_FILE (root-only access)"
else
    echo "✅ $SECURE_FILE already exists"
fi

echo ""
echo "To add your keys:"
echo "  sudo nano $SECURE_FILE"
echo ""
echo "To load keys for development:"
echo "  sudo cat $SECURE_FILE > .env.local"
echo ""
echo "The AI assistant cannot read $SECURE_FILE without your password!"