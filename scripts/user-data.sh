#!/bin/bash
set -e

# EC2 User Data Script for mcp-server-joeleesuh
# This script runs on first boot to set up the MCP server

echo "=== Starting MCP Server Setup ==="
date

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install Node.js 20.x
echo "Installing Node.js 20.x..."
dnf install -y nodejs npm git

# Verify installation
node --version
npm --version
git --version

# Create application directory
echo "Creating application directory..."
mkdir -p /opt/mcp-server-joeleesuh
cd /opt/mcp-server-joeleesuh

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/joeleesuh/mcp-simple-server.git .

# Install dependencies
echo "Installing dependencies..."
npm install

# Build the project
echo "Building project..."
npm run build

# Verify build
if [ ! -f "dist/index.js" ]; then
    echo "ERROR: Build failed - dist/index.js not found"
    exit 1
fi

echo "Build successful!"

# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/mcp-server-joeleesuh.service <<'EOF'
[Unit]
Description=MCP Server - joeleesuh
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mcp-server-joeleesuh
ExecStart=/usr/bin/node /opt/mcp-server-joeleesuh/dist/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mcp-server-joeleesuh

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start service
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable mcp-server-joeleesuh
systemctl start mcp-server-joeleesuh

# Wait a moment for service to start
sleep 5

# Check service status
echo "Checking service status..."
systemctl status mcp-server-joeleesuh --no-pager || true

# Output service logs
echo "Recent service logs:"
journalctl -u mcp-server-joeleesuh --no-pager -n 20 || true

echo "=== MCP Server Setup Complete ==="
echo "Instance is ready!"
echo "Connect via: aws ssm start-session --target $(ec2-metadata --instance-id | cut -d ' ' -f 2)"
date
