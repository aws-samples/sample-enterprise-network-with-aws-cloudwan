# Security

## Reporting a Vulnerability

If you discover a potential security issue in this project, we ask that you notify AWS Security via our
[vulnerability reporting page](https://aws.amazon.com/security/vulnerability-reporting/). Please do **not**
create a public GitHub issue.

## Security Considerations

This repository is a reference architecture intended for learning and adaptation. Review the following
before deploying to any environment.

### Credential Management

- All sensitive values (passwords, keys, tokens) must be provided via Terraform variables at deploy time
  or retrieved from AWS Secrets Manager. No credentials are stored in source control.
- CheckPoint firewall credentials (`checkpoint_password`, `checkpoint_sic_key`) are marked `sensitive`
  and have no default values. Supply them via `terraform.tfvars` (excluded from version control),
  environment variables, or a secrets manager integration.
- The `db_password` variable in `deployments/workload-production` has no default value and must be
  explicitly provided.

### Encryption

- All SSM parameters are encrypted with customer-managed KMS keys (CMKs) with automatic key rotation enabled.
- AWS Network Firewall rule groups and policies use CMK encryption.
- S3 buckets for access logs use server-side encryption (AES-256).
- CloudWatch Log Groups use KMS encryption where configured.

### Network Security

- CloudWAN segment isolation enforces east-west traffic inspection through centralized Network Firewall.
- All EC2 instances enforce IMDSv2 (`http_tokens = "required"`).
- S3 public access is blocked on all buckets.
- VPC Flow Logs are enabled across all VPCs.
- ALB listeners default to TLS 1.2+ (`ELBSecurityPolicy-TLS-1-2-2017-01`).
- Load balancer access logging is enabled for ALB, NLB, and GWLB resources.

### IAM

- IAM policies are scoped to specific resource ARNs where possible.
- Cross-account access uses `sts:AssumeRole` with Organization ID conditions.
- EC2 instance profiles use least-privilege policies (SSM managed instance core).

## Accepted Security Debt

The following items have been reviewed and accepted for this reference architecture:

| Item | Rationale |
|------|-----------|
| VPC endpoint policies with `Resource: "*"` | Scoped by `aws:PrincipalVpc` condition; standard pattern for VPC endpoints |
| Security group egress `0.0.0.0/0` | Controlled at the Network Firewall layer, not at individual security groups |
| CloudWatch Log Groups without KMS CMK | AWS-managed encryption is enabled by default |
| KMS keys using default key policy | Acceptable for sample/reference code |
| Internal ALB on HTTP | TLS terminates at CloudFront; internal traffic stays within VPC |
| GitHub Actions using stored AWS credentials | OIDC federation is recommended for production but not required for reference code |
| S3 log buckets without lifecycle policies | Cost management concern, not a security risk |
| NLB without deletion protection | Required for clean teardown of sample deployments |

## Production Hardening Recommendations

Before using this architecture in a production environment, consider the following:

1. Enable AWS Config rules for continuous compliance monitoring.
2. Implement OIDC federation for GitHub Actions instead of stored credentials.
3. Add lifecycle policies to S3 log buckets to manage storage costs.
4. Enable deletion protection on all load balancers.
5. Integrate with AWS Secrets Manager for all credential management.
6. Enable AWS CloudTrail for API-level audit logging.
7. Implement AWS GuardDuty for threat detection.
8. Review and tighten security group rules for your specific use case.
9. Add KMS CMK encryption to CloudWatch Log Groups.
10. Implement automated security scanning in CI/CD pipelines.
