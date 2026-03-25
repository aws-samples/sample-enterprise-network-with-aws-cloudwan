#!/bin/bash

# CheckPoint CloudGuard Network Security User Data Script
# This script configures the CheckPoint instance for AWS GWLB deployment with GENEVE support

# Set region and basic variables
export AWS_DEFAULT_REGION=${region}
export CHECKPOINT_PASSWORD="${checkpoint_password}"
export SIC_KEY="${sic_key}"

# Wait for instance to be ready
sleep 30

# CheckPoint CloudGuard specific configuration
# Configure first time wizard settings
clish -c "set user admin shell /bin/bash" -s
clish -c "set user admin password-hash ${checkpoint_password_hash}" -s

# Configure GENEVE support for GWLB
clish -c "set interface eth0 state on" -s
clish -c "set interface eth0 ipv4-address dhcp" -s
clish -c "set interface eth0 auto-negotiation on" -s

# Enable GENEVE protocol support (port 6081)
clish -c "set geneve interface geneve-1 state on" -s
clish -c "set geneve interface geneve-1 vni 1" -s
clish -c "set geneve interface geneve-1 remote-ip any" -s
clish -c "set geneve interface geneve-1 local-ip eth0" -s

# Configure security policy for GWLB traffic
clish -c "set security-policy rule 1 name 'Allow GWLB Traffic'" -s
clish -c "set security-policy rule 1 source any" -s
clish -c "set security-policy rule 1 destination any" -s
clish -c "set security-policy rule 1 service any" -s
clish -c "set security-policy rule 1 action accept" -s
clish -c "set security-policy rule 1 track log" -s

# Configure threat prevention
clish -c "set threat-prevention policy standard" -s
clish -c "set threat-prevention ips enable" -s
clish -c "set threat-prevention anti-virus enable" -s
clish -c "set threat-prevention anti-bot enable" -s

# Configure logging
clish -c "set log-server 169.254.169.254 protocol syslog" -s
clish -c "set logging enable" -s

# Save configuration
clish -c "save config" -s

# Configure CloudWatch agent for monitoring
yum update -y
yum install -y awscli

# Download and install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch agent configuration for CheckPoint
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "CheckPoint/Security",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait", 
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "net": {
                "measurement": [
                    "bytes_sent",
                    "bytes_recv",
                    "packets_sent",
                    "packets_recv"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/checkpoint/system",
                        "log_stream_name": "{instance_id}/messages"
                    },
                    {
                        "file_path": "/var/log/CPsuite-R81/fw1/log/fw.log",
                        "log_group_name": "/aws/ec2/checkpoint/firewall",
                        "log_stream_name": "{instance_id}/firewall"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Configure health check endpoint for GWLB
cat > /tmp/health_check.sh << 'EOF'
#!/bin/bash
# Simple health check script for GWLB
while true; do
    # Check if CheckPoint services are running
    if pgrep -f "fwd" > /dev/null && pgrep -f "cpd" > /dev/null; then
        # Services are running, respond to health checks
        echo "CheckPoint services healthy" | logger -t health_check
    else
        echo "CheckPoint services unhealthy" | logger -t health_check
    fi
    sleep 30
done
EOF

chmod +x /tmp/health_check.sh
nohup /tmp/health_check.sh &

# Signal completion
echo "CheckPoint CloudGuard instance configuration completed with GENEVE support" | logger -t userdata
echo "Instance ready for GWLB traffic inspection" | logger -t userdata