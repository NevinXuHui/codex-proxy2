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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
  echo "Error: Node.js is not installed"
  echo "Please install Node.js first: https://nodejs.org/"
  exit 1
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

# Build the project
echo "Building project..."
cd "$SCRIPT_DIR"

# Build frontend
echo "Building frontend..."
cd web
sudo -u "$REAL_USER" npm run build
cd ..

# Build backend
echo "Building backend..."
sudo -u "$REAL_USER" npx tsc

echo "Build completed."
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
ExecStart=$(which node) $SCRIPT_DIR/dist/cli.js
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
