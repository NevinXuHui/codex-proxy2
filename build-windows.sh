#!/bin/bash
set -e

# Codex Proxy Windows Build Script
# This script builds the project for Windows platform

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Codex Proxy Windows Build Script ==="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
  echo "Error: Node.js is not installed"
  echo "Please install Node.js first: https://nodejs.org/"
  exit 1
fi

cd "$SCRIPT_DIR"

echo "Step 1: Building frontend..."
echo ""
cd web
npm run build
cd ..

echo ""
echo "Step 2: Building backend..."
echo ""
npx tsc

echo ""
echo "Step 3: Setting up curl-impersonate..."
echo ""

# Use the setup script to download curl-impersonate
npm run setup || {
  echo "Warning: curl-impersonate setup failed, but build can continue"
  echo "You may need to run 'npm run setup' manually later"
}

echo ""
echo "=== Build Complete ==="
echo ""
echo "Build artifacts:"
echo "  - dist/           (Backend compiled files)"
echo "  - web/dist/       (Frontend compiled files)"
echo "  - bin/curl-impersonate.exe (Windows TLS tool)"
echo ""
echo "To run on Windows:"
echo "  1. Copy the entire project directory to Windows"
echo "  2. Install Node.js on Windows"
echo "  3. Run: node dist/index.js"
echo ""
echo "Or use the provided run.bat script"
echo ""
