#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting deployment at $(date) ==="

# Update and install packages
yum update -y
yum install -y httpd curl jq

# Start Apache
systemctl start httpd
systemctl enable httpd

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || echo "")
if [ -n "$TOKEN" ]; then
    INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
    AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
    PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "unknown")
    REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "unknown")
else
    INSTANCE_ID="unknown"
    AZ="unknown"
    PRIVATE_IP="unknown"
    REGION="unknown"
fi

# Create main page
cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Cloud Architecture</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: rgba(255,255,255,0.95); border-radius: 20px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .status { display: inline-block; background: #00ff88; color: #1a1a2e; padding: 8px 20px; border-radius: 20px; font-weight: bold; margin-top: 10px; }
        .content { padding: 40px; }
        .section { margin-bottom: 30px; padding: 25px; background: #f8f9fa; border-radius: 10px; border-left: 4px solid #667eea; }
        .section h2 { color: #667eea; margin-bottom: 15px; }
        .diagram { background: #1a1a2e; color: #00ff88; padding: 20px; border-radius: 10px; font-family: monospace; font-size: 0.9em; line-height: 1.8; overflow-x: auto; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-top: 20px; }
        .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .card h3 { color: #667eea; margin-bottom: 10px; }
        .tags { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 15px; }
        .tag { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 8px 16px; border-radius: 20px; font-size: 0.85em; }
        .metadata { background: #1a1a2e; color: #00ff88; padding: 20px; border-radius: 10px; font-family: monospace; margin-top: 20px; }
        .meta-item { display: flex; padding: 8px 0; border-bottom: 1px solid rgba(0,255,136,0.2); }
        .meta-label { color: #888; min-width: 180px; }
        .meta-value { color: #00ff88; font-weight: bold; }
        .footer { background: #1a1a2e; color: white; text-align: center; padding: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Enterprise Cloud Architecture</h1>
            <p style="font-size: 1.2em; margin-top: 10px;">AWS CloudWAN + CloudFront VPC Origins</p>
            <div class="status">SYSTEM OPERATIONAL</div>
        </div>
        <div class="content">
            <div class="section">
                <h2>Architecture Overview</h2>
                <div class="diagram">
Internet → CloudFront (Global CDN)
    ↓
VPC Origin (Cross-Account)
    ↓
Internal Application Load Balancer
    ↓
EC2 Instances (Multi-AZ)
    ↓
CloudWAN (Production Segment)
    ↓
Egress VPC → NAT Gateway → Internet
                </div>
            </div>
            <div class="section">
                <h2>Key Features</h2>
                <div class="tags">
                    <span class="tag">CloudFront VPC Origins</span>
                    <span class="tag">Internal ALB</span>
                    <span class="tag">CloudWAN</span>
                    <span class="tag">Multi-AZ</span>
                    <span class="tag">Auto Scaling</span>
                    <span class="tag">Centralized Egress</span>
                </div>
            </div>
            <div class="section">
                <h2>Infrastructure Components</h2>
                <div class="grid">
                    <div class="card"><h3>Network</h3><p>CloudWAN provides centralized routing across accounts with segment isolation.</p></div>
                    <div class="card"><h3>Application</h3><p>Internal ALB distributes traffic to EC2 instances across AZs.</p></div>
                    <div class="card"><h3>CDN</h3><p>CloudFront with VPC Origins for global content delivery.</p></div>
                    <div class="card"><h3>Security</h3><p>Multi-layer security with SGs, NACLs, and centralized egress.</p></div>
                </div>
            </div>
            <div class="section">
                <h2>Server Metadata</h2>
                <div class="metadata">
                    <div class="meta-item"><span class="meta-label">Instance ID:</span><span class="meta-value">INSTANCE_ID</span></div>
                    <div class="meta-item"><span class="meta-label">Availability Zone:</span><span class="meta-value">AZ</span></div>
                    <div class="meta-item"><span class="meta-label">Private IP:</span><span class="meta-value">PRIVATE_IP</span></div>
                    <div class="meta-item"><span class="meta-label">Region:</span><span class="meta-value">REGION</span></div>
                </div>
            </div>
        </div>
        <div class="footer">
            <p>Enterprise Cloud Architecture Demo | Powered by AWS CloudWAN</p>
        </div>
    </div>
</body>
</html>
EOF

# Replace metadata placeholders
sed -i "s/INSTANCE_ID/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ/$AZ/g" /var/www/html/index.html
sed -i "s/PRIVATE_IP/$PRIVATE_IP/g" /var/www/html/index.html
sed -i "s/REGION/$REGION/g" /var/www/html/index.html

# Create health endpoint
echo "OK" > /var/www/html/health.html

# Create info endpoint
cat > /var/www/html/info <<EOF
{"status":"healthy","instance_id":"$INSTANCE_ID","az":"$AZ","private_ip":"$PRIVATE_IP","region":"$REGION"}
EOF

# Set permissions
chmod 644 /var/www/html/*
chown apache:apache /var/www/html/*

# Configure Apache
cat > /etc/httpd/conf.d/app.conf <<'EOF'
ServerTokens Prod
ServerSignature Off
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/css application/javascript application/json
</IfModule>
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "DENY"
</IfModule>
EOF

# Restart Apache
systemctl restart httpd

# Verify
sleep 2
curl -s http://localhost/health.html > /dev/null && echo "SUCCESS: Health check OK" || echo "WARNING: Health check failed"

echo "=== Deployment completed at $(date) ==="
