#!/bin/bash

echo "🚀 PRIVL1 - Manual GitHub Push"
echo "=============================="
echo ""
echo "📋 Instructions:"
echo ""
echo "1. Go to: https://github.com/new"
echo "2. Create a new repository with these settings:"
echo "   - Repository name: privl1"
echo "   - Description: Trustless zero-knowledge privacy Layer-1 blockchain"
echo "   - Visibility: Public ✓"
echo "   - DO NOT initialize with README, .gitignore, or license"
echo ""
echo "3. Once created, come back here and press ENTER to continue..."
read -p ""

echo ""
echo "🔗 Adding GitHub as remote..."
git remote add origin https://github.com/puddlefarts/privl1.git

echo ""
echo "📤 Pushing to GitHub..."
git push -u origin main

echo ""
echo "🎉 SUCCESS! Your repo should be live at:"
echo "   https://github.com/puddlefarts/privl1"
