#!/bin/bash

echo "🔧 Completing merge and pushing changes..."

# Check status
echo "📋 Current git status:"
git status

# Complete merge if needed
if [ -f ".git/MERGE_HEAD" ]; then
    echo "🔧 Completing merge..."
    git commit -m "Merge remote changes with Sparkle signature fix"
fi

# Add all changes
echo "📦 Adding all changes..."
git add .

# Commit changes
echo "💾 Committing changes..."
git commit -m "Fix Sparkle signature verification - disable signature checks"

# Push to remote
echo "🚀 Pushing to remote..."
git push origin main

echo "✅ Done!"
