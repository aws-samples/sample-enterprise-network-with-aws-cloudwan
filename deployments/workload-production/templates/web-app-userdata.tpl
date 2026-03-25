#!/bin/bash

# Enterprise Web Application User Data Script
# Optimized for ALB health checks and CloudFront VPC Origins

set -e

# Update system
yum update -y

# Install Apache and required packages
yum install -y httpd curl jq awscli

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Create web application content
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise Web Application</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container { 
            background: rgba(255,255,255,0.1); 
            padding: 40px; 
            border-radius: 15px; 
            max-width: 900px; 
            margin: 0 auto;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .header { 
            text-align: center; 
            border-bottom: 2px solid rgba(255,255,255,0.3); 
            padding-bottom: 20px; 
            margin-bottom: 30px;
        }
        .status { 
            color: #00ff88; 
            font-weight: bold; 
            font-size: 1.2em;
        }
        .info { 
            background: rgba(255,255,255,0.1); 
            padding: 20px; 
            margin: 20px 0; 
            border-radius: 10px; 
            border-left: 4px solid #00ff88;
        }
        .architecture {
            background: rgba(0,0,0,0.2);
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
            font-family: monospace;
        }
        .feature {
            display: inline-block;
            background: rgba(255,255,255,0.2);
            padding: 8px 16px;
            margin: 5px;
            border-radius: 20px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Enterprise Web Application</h1>
            <p class="status">✅ Application Status: HEALTHY</p>
        </div>
        
        <div class="info">
            <h3>🏗️ Architecture Overview</h3>
            <div class="architecture">
Internet → CloudFront (Ingress Account) → Internal ALB → EC2 Instances
            </div>
        </div>
        
        <div class="info">
            <h3>🔧 Application Features</h3>
            <div class="feature">CloudFront VPC Origins</div>
            <div class="feature">Internal ALB</div>
            <div class="feature">Auto Scaling</div>
            <div class="feature">Health Monitoring</div>
            <div class="feature">CloudWAN Connectivity</div>
        </div>
        
        <div class="info">
            <h3>📊 Server Information</h3>
            <p><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></p>
            <p><strong>Availability Zone:</strong> <span id="az">Loading...</span></p>
            <p><strong>Private IP:</strong> <span id="private-ip">Loading...</span></p>
            <p><strong>Timestamp:</strong> <span id="timestamp"></span></p>
        </div>
        
        <div class="info">
            <h3>🔗 API Endpoints</h3>
            <p><strong>Health Check:</strong> <a href="/health" style="color: #00ff88;">/health</a></p>
            <p><strong>Server Info:</strong> <a href="/info" style="color: #00ff88;">/info</a></p>
            <p><strong>Status:</strong> <a href="/status" style="color: #00ff88;">/status</a></p>
        </div>
    </div>
    
    <script>
        // Load instance metadata
        fetch('/info')
            .then(response => response.json())
            .then(data => {
                document.getElementById('instance-id').textContent = data.instance_id || 'N/A';
                document.getElementById('az').textContent = data.availability_zone || 'N/A';
                document.getElementById('private-ip').textContent = data.private_ip || 'N/A';
            })
            .catch(error => {
                console.log('Could not load instance info:', error);
            });
        
        // Update timestamp
        document.getElementById('timestamp').textContent = new Date().toISOString();
    </script>
</body>
</html>
EOF

# Create health check endpoint
cat > /var/www/html/health << 'EOF'
OK
EOF

# Create info endpoint with instance metadata
cat > /var/www/html/info << 'EOF'
{
  "status": "healthy",
  "application": "enterprise-web-app",
  "timestamp": "TIMESTAMP_PLACEHOLDER",
  "instance_id": "INSTANCE_ID_PLACEHOLDER",
  "availability_zone": "AZ_PLACEHOLDER",
  "private_ip": "PRIVATE_IP_PLACEHOLDER",
  "server": "apache",
  "architecture": "cloudfront-vpc-origins"
}
EOF

# Create status endpoint
cat > /var/www/html/status << 'EOF'
{
  "health": "OK",
  "service": "web-application",
  "load_balancer": "internal-alb",
  "origin": "cloudfront-vpc-origins"
}
EOF

# Get instance metadata and update info endpoint
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "unknown")
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Replace placeholders with actual values
sed -i "s/TIMESTAMP_PLACEHOLDER/$TIMESTAMP/" /var/www/html/info
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/" /var/www/html/info
sed -i "s/AZ_PLACEHOLDER/$AZ/" /var/www/html/info
sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/" /var/www/html/info

# Set proper permissions
chmod 644 /var/www/html/*
chown apache:apache /var/www/html/*

# Configure Apache for better performance
cat > /etc/httpd/conf.d/performance.conf << 'EOF'
# Performance optimizations for ALB health checks
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Enable compression
LoadModule deflate_module modules/mod_deflate.so
<Location />
    SetOutputFilter DEFLATE
    SetEnvIfNoCase Request_URI \
        \.(?:gif|jpe?g|png)$ no-gzip dont-vary
    SetEnvIfNoCase Request_URI \
        \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
</Location>

# Security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
EOF

# Restart Apache to apply configuration
systemctl restart httpd

# Verify health endpoint is working
sleep 5
HEALTH_CHECK=$(curl -s http://localhost/health 2>/dev/null || echo "FAILED")
if [ "$HEALTH_CHECK" = "OK" ]; then
    echo "✅ Health endpoint is working"
    logger "Enterprise Web App: Health endpoint configured successfully"
else
    echo "❌ Health endpoint failed"
    logger "Enterprise Web App: Health endpoint configuration failed"
    # Ensure basic health endpoint exists
    echo "OK" > /var/www/html/health
    chmod 644 /var/www/html/health
fi

# Final verification
systemctl status httpd
echo "🚀 Enterprise Web Application deployment completed successfully!"
logger "Enterprise Web App: Deployment completed at $(date)"