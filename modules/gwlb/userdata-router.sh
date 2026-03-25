#!/bin/bash
set -e

# Simple Linux Router for GWLB
# This script configures a Linux instance as a pass-through router
# It enables IP forwarding and accepts all traffic without inspection

echo "=========================================="
echo "Configuring Linux Router for GWLB"
echo "=========================================="

# Update system
yum update -y

# Install required packages
yum install -y iptables-services tcpdump net-tools

# Enable IP forwarding permanently
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sysctl -p

# Disable source/destination check (will be done via AWS API)
# This is critical for routing to work

# Configure iptables to accept all traffic
# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Set default policies to ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Allow all forwarding (pass-through mode)
iptables -A FORWARD -j ACCEPT

# Save iptables rules
service iptables save
systemctl enable iptables

# Configure for GWLB GENEVE traffic
# GWLB uses GENEVE protocol (UDP port 6081)
modprobe geneve
echo "geneve" >> /etc/modules-load.d/geneve.conf

# Disable reverse path filtering (required for asymmetric routing)
echo "net.ipv4.conf.all.rp_filter = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.eth0.rp_filter = 0" >> /etc/sysctl.conf
sysctl -p

# Install CloudWatch agent for monitoring (optional)
wget https://s3.${region}.amazonaws.com/amazoncloudwatch-agent-${region}/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create a simple health check script
cat > /usr/local/bin/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check - return 0 if system is healthy
exit 0
EOF
chmod +x /usr/local/bin/health-check.sh

# Log configuration completion
echo "Router configuration completed at $(date)" >> /var/log/router-setup.log
echo "IP forwarding enabled: $(sysctl net.ipv4.ip_forward)" >> /var/log/router-setup.log
echo "Routing table:" >> /var/log/router-setup.log
ip route >> /var/log/router-setup.log

echo "=========================================="
echo "Router Configuration Complete"
echo "=========================================="
