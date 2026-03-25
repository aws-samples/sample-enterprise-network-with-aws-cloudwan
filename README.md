# AWS Enterprise Network Architecture with CloudWAN Service Insertion

[![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.5.0-blue)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-CloudWAN-orange)](https://aws.amazon.com/cloud-wan/)
[![License](https://img.shields.io/badge/license-MIT--0-green)](LICENSE)

## Overview

A modular Terraform reference architecture for deploying AWS enterprise network architecture with CloudWAN Service Insertion and AWS Network Firewall. This architecture provides comprehensive traffic inspection for both internet egress (north-south) and inter-segment (east-west) traffic flows.

**Architecture**: CloudWAN Service Insertion with AWS Network Firewall  
**Version**: 1.0  
**Status**: Reference Architecture

---

## Key Features

- **CloudWAN Service Insertion**: Automatic traffic routing through inspection VPCs using Network Function Groups (NFGs)
- **Modular Design**: Reusable Terraform modules for all components
- **Multi-Segment Architecture**: Support for 8+ segments (production, development, staging, sandbox, etc.)
- **Multi-Account Support**: Segregated accounts for security, networking, and applications
- **High Availability**: Multi-AZ deployment across all components
- **IPAM Integration**: Automated CIDR allocation and conflict prevention
- **Flexible Firewall Rules**: Support for custom rules, AWS Managed Rules, and test rules
- **Comprehensive Logging**: CloudWatch integration for all traffic flows

---

## Architecture Diagrams

### Core Network Architecture
![Core Network](architecture-diagrams/core-network.png)
*CloudWAN core network with service insertion, segments, and network function groups*

### North-South Traffic Flow (Internet Egress)
![North-South Traffic](architecture-diagrams/north-south-traffic.png)
*Internet-bound traffic inspection through Egress VPC Network Firewall*

### East-West Traffic Flow (Inter-Segment)
![East-West Traffic](architecture-diagrams/east-west-traffic.png)
*Inter-segment traffic inspection through Inspection VPC Network Firewall*

---

## Repository Structure

```
.
├── deployments/                    # Deployment configurations (environment-specific)
│   ├── network-core/              # CloudWAN, IPAM, DNS, Core VPC
│   ├── network-egress/            # Egress VPC with Network Firewall
│   ├── network-inspection/        # Inspection VPC with Network Firewall
│   ├── workload-production/       # Production workload VPC
│   └── workload-development/      # Development workload VPC
│
├── modules/                        # Reusable Terraform modules
│   ├── alb/                       # Application Load Balancer
│   ├── cloudwan/                  # CloudWAN Core Network
│   ├── direct-connect/            # Direct Connect integration
│   ├── dns/                       # Route 53 Resolver
│   ├── endpoints/                 # VPC Endpoints
│   ├── gwlb/                      # Gateway Load Balancer
│   ├── ipam/                      # IP Address Management
│   ├── network-firewall/          # AWS Network Firewall
│   ├── vpc/                       # VPC with CloudWAN integration
│   └── workload-application/      # Application workload
│
└── config/                        # Configuration templates
    └── deployment-values.template.sh
```

---

## 📚 Documentation

### Getting Started

1. **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Step-by-step deployment instructions
2. **[COMPLETE_SOLUTION_OVERVIEW.md](COMPLETE_SOLUTION_OVERVIEW.md)** - Comprehensive architecture details
3. **[ROUTING_GUIDE.md](ROUTING_GUIDE.md)** - Routing configuration and traffic flows

### Operations & Management

4. **[OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md)** - Day-to-day operations and management
5. **[CLOUDWAN_POLICY_EXPLAINED.md](CLOUDWAN_POLICY_EXPLAINED.md)** - CloudWAN policy and segments

### Testing & Validation

6. **[TRAFFIC_FLOW_VERIFICATION.md](TRAFFIC_FLOW_VERIFICATION.md)** - Verify traffic flows
7. **[FIREWALL_TESTING_GUIDE.md](FIREWALL_TESTING_GUIDE.md)** - Test firewall rules

---

## Quick Start

### Prerequisites

- **Terraform**: >= 1.5.0
- **AWS CLI**: Version 2.x configured with appropriate profiles
- **AWS Organizations**: Multi-account setup (recommended)
- **IAM Permissions**: Administrator access or equivalent for:
  - VPC, EC2, Network Manager (CloudWAN)
  - IPAM, Route 53, Network Firewall
  - IAM, RAM, CloudWatch

### For New Deployments

1. **Review Architecture**: Read this README and `COMPLETE_SOLUTION_OVERVIEW.md`
2. **Plan Deployment**: Review `DEPLOYMENT_GUIDE.md` for deployment steps
3. **Deploy Infrastructure**:
   ```bash
   # Deploy core network
   cd deployments/network-core
   terraform init && terraform apply
   
   # Deploy egress VPC
   cd ../network-egress
   terraform init && terraform apply
   
   # Deploy workload VPCs
   cd ../workload-production
   terraform init && terraform apply
   ```
4. **Verify**: Use `TRAFFIC_FLOW_VERIFICATION.md` to validate

---

## Deployment Scenarios

### Scenario 1: Internet Egress Only (Minimal)
**Use Case**: Basic internet connectivity with inspection

**Deploy**:
1. `deployments/network-core` (CloudWAN + IPAM)
2. `deployments/network-egress` (NAT + Network Firewall)
3. `deployments/workload-production` (Workload VPC)

---

### Scenario 2: Full Inspection (Recommended)
**Use Case**: Complete security with both internet and inter-segment inspection

**Deploy**:
1. `deployments/network-core` (CloudWAN + IPAM)
2. `deployments/network-egress` (NAT + Network Firewall)
3. `deployments/network-inspection` (Network Firewall for east-west)
4. `deployments/workload-production` (Production VPC)
5. `deployments/workload-development` (Dev VPC)

---

## Core Modules

### Infrastructure Modules

- **[modules/cloudwan](modules/cloudwan/)** - CloudWAN Core Network with Service Insertion
- **[modules/vpc](modules/vpc/)** - VPC with CloudWAN integration and automatic routing
- **[modules/ipam](modules/ipam/)** - IP Address Management for CIDR allocation
- **[modules/network-firewall](modules/network-firewall/)** - AWS Network Firewall with custom rules
- **[modules/dns](modules/dns/)** - Route 53 Resolver for centralized DNS

### Application Modules

- **[modules/alb](modules/alb/)** - Application Load Balancer with advanced routing
- **[modules/workload-application](modules/workload-application/)** - EC2 workload deployment
- **[modules/endpoints](modules/endpoints/)** - VPC Endpoints for AWS services

### Network Modules

- **[modules/gwlb](modules/gwlb/)** - Gateway Load Balancer for appliance insertion
- **[modules/direct-connect](modules/direct-connect/)** - Direct Connect integration

---

## Architecture Patterns

### North-South Traffic (Internet Egress)
```
Workload VPC → CloudWAN → Egress VPC → Network Firewall → NAT Gateway → Internet
```

### East-West Traffic (Inter-Segment)
```
Dev VPC → CloudWAN → Inspection VPC → Network Firewall → CloudWAN → Production VPC
```

### Intranet Traffic (Segment Sharing)
```
Workload VPC → CloudWAN → Shared Services VPC (direct, no inspection)
```

---

## Security Scanning

This repository implements automated security scanning using [Checkov](https://www.checkov.io/) to ensure infrastructure code meets security and compliance standards.

### Local Testing

Run security scans locally before pushing:
```bash
# Scan entire repository
checkov -d .

# Scan specific deployment
checkov -d deployments/network-core
```

---

## Cleanup / Teardown

To destroy all deployed resources, run `terraform destroy` in each deployment folder in reverse order of creation. The recommended teardown sequence:

```bash
# 1. Workload accounts first
cd deployments/workload-development && terraform destroy -auto-approve
cd deployments/workload-production  && terraform destroy -auto-approve

# 2. Egress and inspection VPCs
cd deployments/network-egress      && terraform destroy -auto-approve
cd deployments/network-inspection  && terraform destroy -auto-approve

# 3. Core network last (CloudWAN, IPAM, DNS)
cd deployments/network-core        && terraform destroy -auto-approve
```

> **Note:** Some resources (e.g., KMS keys with deletion windows, S3 buckets with versioning) may require manual cleanup or a waiting period before full removal.

---

## Support & Contributions

For questions, issues, or contributions, please refer to the documentation or open an issue in the repository.

---

## License

This project is licensed under the MIT-0 License - see the [LICENSE](LICENSE) file for details.

---

**Last Updated**: 2026

