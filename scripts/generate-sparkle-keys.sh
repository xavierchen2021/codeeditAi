#!/bin/bash
set -e

# Script to generate EdDSA signing keys for Sparkle updates
# This should be run once during initial setup

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_DIR="$PROJECT_ROOT/.sparkle-keys"

echo "Generating Sparkle EdDSA signing keys..."
echo ""

# Find generate_keys tool from Sparkle SPM
GENERATE_KEYS=$(find ~/Library/Developer/Xcode/DerivedData -path "*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys" 2>/dev/null | head -1)

if [ -z "$GENERATE_KEYS" ]; then
    echo "❌ Error: Sparkle's generate_keys tool not found."
    echo ""
    echo "The tool should be automatically downloaded when you add Sparkle via SPM."
    echo "Please build your Xcode project first to download Sparkle dependencies."
    echo ""
    echo "Expected location: ~/Library/Developer/Xcode/DerivedData/.../SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"
    exit 1
fi

echo "Found generate_keys at: $GENERATE_KEYS"
echo ""

# Create keys directory if it doesn't exist
mkdir -p "$KEYS_DIR"

# Check if keys already exist
if [ -f "$KEYS_DIR/eddsa_priv.pem" ] || [ -f "$KEYS_DIR/eddsa_pub.pem" ]; then
    echo "⚠️  Keys already exist in $KEYS_DIR"
    echo ""
    read -p "Do you want to regenerate them? This will overwrite existing keys. (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing keys."
        exit 0
    fi
fi

# Run generate_keys tool
cd "$KEYS_DIR"
"$GENERATE_KEYS"

echo ""
echo "Exporting private key from Keychain..."
"$GENERATE_KEYS" -x "$KEYS_DIR/eddsa_priv.pem"

if [ -f "$KEYS_DIR/eddsa_priv.pem" ]; then
    echo "✅ Private key exported to $KEYS_DIR/eddsa_priv.pem"
else
    echo "❌ Failed to export private key"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo ""
echo "1. Copy PRIVATE key to clipboard for GitHub Secrets:"
echo "   cat $KEYS_DIR/eddsa_priv.pem | pbcopy"
echo ""
echo "2. Add the SUPublicEDKey shown above to your Info.plist in project.pbxproj"
echo ""
echo "⚠️  IMPORTANT: Never commit the private key to git!"
echo "   (Already protected by .gitignore)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
