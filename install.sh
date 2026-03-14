#!/bin/bash
set -e

# Codex Proxy Systemd Service Installer
# This script installs and configures the systemd service for Codex Proxy

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="codex-proxy"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PORT=9100

echo "=== Codex Proxy Systemd Service Installer ==="
echo ""

# Check if this is a re-run from sudo (via BUILD_DONE marker)
if [ "$EUID" -eq 0 ] && [ -z "$BUILD_DONE" ]; then
  # Running as root, check if we have SUDO_USER (meaning run via sudo)
  if [ -n "$SUDO_USER" ]; then
    echo "Error: Please run this script without sudo first"
    echo "Usage: ./install.sh"
    echo ""
    echo "The script will:"
    echo "  1. Build the project (as current user)"
    echo "  2. Install systemd service (automatically with sudo)"
    exit 1
  else
    # Running as root user directly (not via sudo)
    echo "Running as root user. Building and installing..."
    echo ""
  fi
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Step 1: Building project (as current user)..."
  echo ""

  # Check if Node.js is installed
  if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed"
    echo "Please install Node.js first: https://nodejs.org/"
    exit 1
  fi

  cd "$SCRIPT_DIR"

  # Build frontend
  echo "Building frontend..."
  cd web
  npm run build
  cd ..

  # Build backend
  echo "Building backend..."
  npx tsc

  echo ""
  echo "Build completed. Now running installation with sudo..."
  echo ""

  # Re-run this script with sudo, passing BUILD_DONE marker
  exec sudo BUILD_DONE=1 "$0" "$@"
fi

# If we're here, we're running as root (either directly or via sudo after build)
if [ -z "$BUILD_DONE" ]; then
  # Running as root directly, need to build first
  echo "Step 1: Building project..."
  echo ""

  # Check if Node.js is installed
  if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed"
    echo "Please install Node.js first: https://nodejs.org/"
    exit 1
  fi

  cd "$SCRIPT_DIR"

  # Build frontend
  echo "Building frontend..."
  cd web
  npm run build
  cd ..

  # Build backend
  echo "Building backend..."
  npx tsc

  echo ""
  echo "Build completed."
  echo ""
fi

echo "Step 2: Installing systemd service..."
echo ""

# Check if Node.js is installed (for systemd service path)
NODE_PATH=$(which node 2>/dev/null || echo "/usr/bin/node")
if [ ! -f "$NODE_PATH" ]; then
  # Try common nvm location
  if [ -f "/root/.nvm/versions/node/v22.22.0/bin/node" ]; then
    NODE_PATH="/root/.nvm/versions/node/v22.22.0/bin/node"
  else
    echo "Warning: Could not find node binary, using /usr/bin/node"
    NODE_PATH="/usr/bin/node"
  fi
fi

# Get current user (the one who invoked sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo ~$REAL_USER)

echo "Installation directory: $SCRIPT_DIR"
echo "Running as user: $REAL_USER"
echo "Port: $PORT"
echo ""

# Kill processes using the port
echo "Checking for processes using port $PORT..."
PIDS=$(lsof -ti:$PORT 2>/dev/null || true)
if [ -n "$PIDS" ]; then
  echo "Found processes using port $PORT: $PIDS"
  echo "Killing processes..."
  kill -9 $PIDS 2>/dev/null || true
  sleep 1
  echo "Processes killed."
else
  echo "No processes found using port $PORT."
fi
echo ""

# Verify build artifacts exist
if [ ! -d "$SCRIPT_DIR/dist" ]; then
  echo "Error: dist directory not found. Please build the project first."
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/dist/index.js" ]; then
  echo "Error: dist/index.js not found. Please build the project first."
  exit 1
fi

echo "Build artifacts verified."
echo ""

# Create systemd service file
echo "Creating systemd service file..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Codex Proxy Server
After=network.target

[Service]
Type=simple
User=$REAL_USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$NODE_PATH $SCRIPT_DIR/dist/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

# Environment
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "Service file created at: $SERVICE_FILE"
echo ""

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable service
echo "Enabling service to start on boot..."
systemctl enable "$SERVICE_NAME"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Service commands:"
echo "  Start:   sudo systemctl start $SERVICE_NAME"
echo "  Stop:    sudo systemctl stop $SERVICE_NAME"
echo "  Restart: sudo systemctl restart $SERVICE_NAME"
echo "  Status:  sudo systemctl status $SERVICE_NAME"
echo "  Logs:    sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "The service is enabled and will start automatically on boot."
echo "To start it now, run: sudo systemctl start $SERVICE_NAME"
