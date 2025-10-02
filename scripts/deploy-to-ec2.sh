#!/bin/bash
set -e

# Deploy mcp-server-joeleesuh to AWS EC2
# Run this script from AWS CloudShell

echo "========================================"
echo "MCP Server - AWS EC2 Deployment"
echo "========================================"
echo ""

# Configuration
INSTANCE_TYPE="t3.micro"
SG_NAME="mcp-server-joeleesuh-sg"
INSTANCE_NAME="mcp-server-joeleesuh"
IAM_PROFILE="AmazonSSMManagedInstanceCore"
REPO_URL="https://raw.githubusercontent.com/joeleesuh/mcp-simple-server/main/scripts/user-data.sh"

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI is not installed"
    exit 1
fi

# Get current region
REGION=$(aws configure get region)
if [ -z "$REGION" ]; then
    echo "ERROR: AWS region not configured"
    echo "Run: aws configure"
    exit 1
fi

echo "Deploying to region: $REGION"
echo ""

# Step 1: Download user data script
echo "[1/6] Downloading user data script..."
if ! curl -sf "$REPO_URL" -o /tmp/user-data.sh; then
    echo "ERROR: Failed to download user data script"
    echo "Creating user data script from inline content..."

    cat > /tmp/user-data.sh <<'USERDATA'
#!/bin/bash
set -e
echo "=== Starting MCP Server Setup ==="
date
dnf update -y
dnf install -y nodejs npm git
node --version
npm --version
mkdir -p /opt/mcp-server-joeleesuh
cd /opt/mcp-server-joeleesuh
git clone https://github.com/joeleesuh/mcp-simple-server.git .
npm install
npm run build
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
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable mcp-server-joeleesuh
systemctl start mcp-server-joeleesuh
echo "=== Setup Complete ==="
USERDATA
fi

# Step 2: Create or get security group
echo "[2/6] Setting up security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating new security group: $SG_NAME"
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "Security group for MCP Server - no inbound ports (uses SSM)" \
        --query 'GroupId' \
        --output text)

    aws ec2 create-tags \
        --resources "$SG_ID" \
        --tags Key=Name,Value="$SG_NAME"

    echo "Created security group: $SG_ID"
else
    echo "Using existing security group: $SG_ID"
fi

# Step 3: Verify IAM instance profile exists
echo "[3/6] Checking IAM instance profile..."
if ! aws iam get-instance-profile --instance-profile-name "$IAM_PROFILE" &>/dev/null; then
    echo "WARNING: IAM instance profile '$IAM_PROFILE' not found"
    echo "Creating IAM role and instance profile..."

    # Create role
    aws iam create-role \
        --role-name EC2-SSM-Role \
        --assume-role-policy-document '{
          "Version": "2012-10-17",
          "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
          }]
        }' >/dev/null 2>&1 || true

    # Attach policy
    aws iam attach-role-policy \
        --role-name EC2-SSM-Role \
        --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore 2>&1 || true

    # Create instance profile
    aws iam create-instance-profile \
        --instance-profile-name "$IAM_PROFILE" >/dev/null 2>&1 || true

    # Add role to profile
    aws iam add-role-to-instance-profile \
        --instance-profile-name "$IAM_PROFILE" \
        --role-name EC2-SSM-Role 2>&1 || true

    echo "Waiting for IAM resources to propagate..."
    sleep 15
fi

# Step 4: Get latest Amazon Linux 2023 AMI
echo "[4/6] Getting latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameter.Value' \
    --output text)

echo "Using AMI: $AMI_ID"

# Step 5: Launch EC2 instance
echo "[5/6] Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile "Name=$IAM_PROFILE" \
    --user-data file:///tmp/user-data.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --metadata-options HttpTokens=required \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp3"}}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launched: $INSTANCE_ID"

# Step 6: Wait for instance to be ready
echo "[6/6] Waiting for instance to be ready..."
echo "This may take 2-3 minutes..."

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "✓ Instance is running"

aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
echo "✓ Instance status checks passed"

# Get instance details
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

# Summary
echo ""
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo ""
echo "Instance ID:     $INSTANCE_ID"
echo "Instance Type:   $INSTANCE_TYPE"
echo "Public IP:       $PUBLIC_IP"
echo "Private IP:      $PRIVATE_IP"
echo "Security Group:  $SG_ID"
echo "Region:          $REGION"
echo ""
echo "Next Steps:"
echo "------------"
echo "1. Wait 2-3 minutes for the server to finish installing"
echo ""
echo "2. Connect to the instance:"
echo "   aws ssm start-session --target $INSTANCE_ID"
echo ""
echo "3. Check service status:"
echo "   sudo systemctl status mcp-server-joeleesuh"
echo ""
echo "4. View logs:"
echo "   sudo journalctl -u mcp-server-joeleesuh -f"
echo ""
echo "5. View installation logs:"
echo "   sudo cat /var/log/cloud-init-output.log"
echo ""
echo "To stop the instance (save costs):"
echo "   aws ec2 stop-instances --instance-ids $INSTANCE_ID"
echo ""
echo "To terminate the instance:"
echo "   aws ec2 terminate-instances --instance-ids $INSTANCE_ID"
echo ""
echo "========================================"
