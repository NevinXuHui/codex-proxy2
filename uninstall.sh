#!/bin/bash
set -e

# Codex Proxy Systemd Service Uninstaller

SERVICE_NAME="codex-proxy"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "=== Codex Proxy Systemd Service Uninstaller ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check if service exists
if [ ! -f "$SERVICE_FILE" ]; then
  echo "Service is not installed."
  exit 0
fi

# Stop service
echo "Stopping service..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true

# Disable service
echo "Disabling service..."
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

# Remove service file
echo "Removing service file..."
rm -f "$SERVICE_FILE"

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo ""
echo "=== Uninstallation Complete ==="
echo "Service has been removed successfully."
