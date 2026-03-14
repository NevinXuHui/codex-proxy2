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
echo "Step 3: Downloading Windows curl-impersonate..."
echo ""

# Create bin directory if not exists
mkdir -p bin

# Download curl-impersonate for Windows
CURL_VERSION="v0.7.2"
CURL_WIN_URL="https://github.com/lwthiker/curl-impersonate/releases/download/${CURL_VERSION}/curl-impersonate-${CURL_VERSION}.x86_64-pc-windows-msvc.zip"
CURL_WIN_ZIP="bin/curl-impersonate-windows.zip"

if [ ! -f "bin/curl-impersonate.exe" ]; then
  echo "Downloading curl-impersonate for Windows..."
  curl -L -o "$CURL_WIN_ZIP" "$CURL_WIN_URL"

  echo "Extracting..."
  unzip -o "$CURL_WIN_ZIP" -d bin/

  # Find and rename the curl executable
  find bin/ -name "curl-impersonate-chrome*.exe" -exec mv {} bin/curl-impersonate.exe \;

  # Clean up
  rm -f "$CURL_WIN_ZIP"

  echo "curl-impersonate.exe installed successfully"
else
  echo "curl-impersonate.exe already exists, skipping download"
fi

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
