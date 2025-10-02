# AWS EC2 Deployment Guide

This guide walks you through deploying `mcp-server-joeleesuh` to AWS EC2 using AWS CloudShell.

## Overview

This deployment will:
- Launch an EC2 instance (t3.micro - Free Tier eligible)
- Auto-install Node.js 20.x with Express and WebSocket support
- Clone and build the MCP server from GitHub
- Set up the server as a systemd service running in HTTP mode on port 3000
- Configure security group to allow inbound HTTP/WebSocket traffic on port 3000
- Configure AWS Session Manager for secure access (no SSH keys required)

## Server Modes

The MCP server supports two modes:
- **stdio mode**: For local development and traditional MCP client connections
- **HTTP mode** (default on EC2): Exposes HTTP REST API and WebSocket endpoints on port 3000

The EC2 deployment uses HTTP mode by default, allowing you to interact with the server via:
- HTTP REST endpoints for health checks and server info
- WebSocket connections for MCP protocol communication

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI access via CloudShell
- GitHub repository: https://github.com/joeleesuh/mcp-simple-server

## Deployment Steps

### Option 1: Quick Deploy via CloudShell (Recommended)

1. **Open AWS CloudShell** in your AWS Console

2. **Clone this repository** (or copy the deployment script):
   ```bash
   curl -O https://raw.githubusercontent.com/joeleesuh/mcp-simple-server/main/scripts/deploy-to-ec2.sh
   chmod +x deploy-to-ec2.sh
   ```

3. **Run the deployment script**:
   ```bash
   ./deploy-to-ec2.sh
   ```

4. **Note the Instance ID** from the output for future reference

### Option 2: Manual Deployment

#### Step 1: Prepare User Data Script

Create a file named `user-data.sh` with the EC2 initialization script (see `scripts/user-data.sh` in this repository).

#### Step 2: Create Security Group

```bash
# Create security group
SG_ID=$(aws ec2 create-security-group \
  --group-name mcp-server-joeleesuh-sg \
  --description "Security group for MCP Server with HTTP/WebSocket on port 3000" \
  --query 'GroupId' \
  --output text)

echo "Security Group ID: $SG_ID"

# Tag the security group
aws ec2 create-tags \
  --resources $SG_ID \
  --tags Key=Name,Value=mcp-server-joeleesuh-sg

# Add inbound rule for port 3000 (HTTP/WebSocket)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0 \
  --group-rule-description "MCP Server HTTP/WebSocket"
```

#### Step 3: Launch EC2 Instance

```bash
# Launch EC2 instance with user data
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t3.micro \
  --security-group-ids $SG_ID \
  --iam-instance-profile Name=AmazonSSMManagedInstanceCore \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=mcp-server-joeleesuh}]' \
  --metadata-options HttpTokens=required \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
```

**Note**: If you don't have an IAM instance profile named `AmazonSSMManagedInstanceCore`, see the "Setup IAM Role" section below.

#### Step 4: Wait for Instance to be Ready

```bash
# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance is running!"

# Wait for status checks
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_ID
echo "Instance is ready!"
```

#### Step 5: Verify Installation

```bash
# Connect via Session Manager
aws ssm start-session --target $INSTANCE_ID

# Once connected, check the service status
sudo systemctl status mcp-server-joeleesuh

# View logs
sudo journalctl -u mcp-server-joeleesuh -f
```

## Setup IAM Role (If Not Already Created)

If you need to create an IAM instance profile for SSM access:

```bash
# Create IAM role
aws iam create-role \
  --role-name EC2-SSM-Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach SSM policy
aws iam attach-role-policy \
  --role-name EC2-SSM-Role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name AmazonSSMManagedInstanceCore

# Add role to instance profile
aws iam add-role-to-instance-profile \
  --instance-profile-name AmazonSSMManagedInstanceCore \
  --role-name EC2-SSM-Role

# Wait a moment for the profile to propagate
sleep 10
```

## Post-Deployment

### Access the Instance

```bash
# Connect via AWS Systems Manager Session Manager
aws ssm start-session --target $INSTANCE_ID
```

### Check Server Status

```bash
# Check if service is running
sudo systemctl status mcp-server-joeleesuh

# View real-time logs
sudo journalctl -u mcp-server-joeleesuh -f

# Restart the service
sudo systemctl restart mcp-server-joeleesuh
```

### Update the Server

```bash
# SSH into the instance
aws ssm start-session --target $INSTANCE_ID

# Pull latest changes
cd /opt/mcp-server-joeleesuh
sudo git pull origin main

# Rebuild
sudo npm install
sudo npm run build

# Restart service
sudo systemctl restart mcp-server-joeleesuh
```

## Usage with MCP Clients

The EC2 deployment runs in HTTP mode, exposing both HTTP REST endpoints and WebSocket connections.

### HTTP Endpoints

Once deployed, you can interact with the server via HTTP:

```bash
# Get public IP from deployment output, then:

# Health check
curl http://<PUBLIC_IP>:3000/health

# Server info and available tools
curl http://<PUBLIC_IP>:3000/

# Example response:
# {
#   "name": "mcp-server-joeleesuh",
#   "version": "1.0.0",
#   "description": "MCP server with echo, add, and timestamp tools",
#   "websocket": "ws://<PUBLIC_IP>:3000/",
#   "tools": [...]
# }
```

### WebSocket Connection

Connect MCP clients to the WebSocket endpoint:

```
ws://<PUBLIC_IP>:3000/
```

### Local stdio Mode

To run the server locally in stdio mode:

```bash
# Connect to instance via SSM
aws ssm start-session --target $INSTANCE_ID

# Stop the HTTP service
sudo systemctl stop mcp-server-joeleesuh

# Run in stdio mode
MCP_MODE=stdio node /opt/mcp-server-joeleesuh/dist/index.js
```

### Testing WebSocket with wscat

```bash
# Install wscat if needed
npm install -g wscat

# Connect to the WebSocket endpoint
wscat -c ws://<PUBLIC_IP>:3000/
```

## Cost Optimization

- **Instance Type**: t3.micro (Free Tier eligible - 750 hours/month free for 12 months)
- **Storage**: 8 GB gp3 (Free Tier eligible - 30 GB/month free for 12 months)
- **Data Transfer**: Minimal for this use case
- **Estimated Cost**: $0/month (within Free Tier) or ~$7.50/month after Free Tier

### Stop Instance When Not in Use

```bash
# Stop instance
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# Start instance
aws ec2 start-instances --instance-ids $INSTANCE_ID
```

## Cleanup

To remove all resources:

```bash
# Terminate instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Wait for termination
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID

# Delete security group
aws ec2 delete-security-group --group-id $SG_ID
```

## Troubleshooting

### Service Not Starting

```bash
# Check service status
sudo systemctl status mcp-server-joeleesuh

# View detailed logs
sudo journalctl -u mcp-server-joeleesuh -xe

# Check if Node.js is installed
node --version
npm --version

# Verify files exist
ls -la /opt/mcp-server-joeleesuh
```

### Can't Connect via SSM

1. Ensure the IAM instance profile is attached
2. Wait a few minutes for SSM agent to register
3. Check instance has internet connectivity (for SSM endpoints)

```bash
# Check SSM agent status on instance
sudo systemctl status amazon-ssm-agent
```

### Build Failures

```bash
# Check build logs
cat /var/log/cloud-init-output.log

# Manually rebuild
cd /opt/mcp-server-joeleesuh
sudo npm install
sudo npm run build
```

## Security Best Practices

1. **No SSH Access**: Uses AWS Session Manager (SSM) instead of SSH keys
2. **No Inbound Ports**: Security group has no inbound rules (SSM uses outbound HTTPS)
3. **IMDSv2**: Instance metadata uses IMDSv2 for enhanced security
4. **Regular Updates**: Keep the instance and packages updated

## Alternative: Docker Deployment

For a containerized approach, see the `Dockerfile` in the repository. You can:

1. Build the Docker image on the EC2 instance
2. Run it as a container with Docker or Podman
3. Use ECS/Fargate for a fully managed container deployment

## References

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
