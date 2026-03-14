#!/usr/bin/env bash
set -euo pipefail

echo "Building project..."

# Build frontend
cd web
npm run build
cd ..

# Build backend
npx tsc

echo "Starting server..."
npm start
