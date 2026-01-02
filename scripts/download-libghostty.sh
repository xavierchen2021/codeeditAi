#!/bin/bash
set -euo pipefail

# Download libghostty from R2
# Usage: ./scripts/download-libghostty.sh
# Requires: R2_PUBLIC_URL environment variable (or uses default)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="${ROOT_DIR}/Vendor/libghostty"

R2_PUBLIC_URL="${R2_PUBLIC_URL:-https://cdn.aizen.app}"
DOWNLOAD_URL="${R2_PUBLIC_URL}/libghostty.tar.gz"

echo "Downloading libghostty from R2..."
echo "URL: ${DOWNLOAD_URL}"

curl -fsSL "${DOWNLOAD_URL}" -o "${ROOT_DIR}/libghostty.tar.gz"

echo "Extracting to ${VENDOR_DIR}..."
mkdir -p "${VENDOR_DIR}"
tar -xzf "${ROOT_DIR}/libghostty.tar.gz" -C "${VENDOR_DIR}"
rm "${ROOT_DIR}/libghostty.tar.gz"

echo "Done: $(lipo -info "${VENDOR_DIR}/lib/libghostty.a" 2>/dev/null || echo "libghostty.a extracted")"
