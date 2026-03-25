# Security Scanning with Checkov

This repository uses [Checkov](https://www.checkov.io/) to scan Terraform code for security and compliance issues.

## Overview

Security scanning is automatically integrated into the CI/CD pipeline and runs:
- On every push to `main` or `develop` branches
- On every pull request
- Before every Terraform deployment
- On-demand via workflow dispatch

## Pipeline Behavior

### Automatic Scanning on Push/PR
- Scans all Terraform files in the repository
- Fails the pipeline if **CRITICAL** or **HIGH** severity issues are found
- Generates detailed reports available in workflow artifacts
- Posts results as PR comments for easy review

### Pre-Deployment Scanning
- Runs before every Terraform plan/apply/destroy
- Scans only the specific deployment folder being deployed
- **Blocks deployment** if CRITICAL or HIGH severity issues are detected
- Ensures only secure infrastructure is deployed

## Severity Levels

Checkov categorizes issues by severity:

- **🔴 CRITICAL**: Immediate security risks that must be fixed
- **🟠 HIGH**: Significant security issues that should be addressed
- **🟡 MEDIUM**: Important security improvements recommended
- **🟢 LOW**: Minor security enhancements suggested

## Running Scans Locally

### Prerequisites
Install Checkov:
```bash
# Using pip
pip install checkov

# Using Homebrew (macOS)
brew install checkov

# Using Docker
docker pull bridgecrew/checkov
```

### Quick Scan
```bash
# Scan entire repository
./scripts/run-security-scan.sh

# Scan specific deployment
./scripts/run-security-scan.sh deployments/network-core

# Scan with specific severity threshold
./scripts/run-security-scan.sh deployments/network-core HIGH
```

### Manual Checkov Commands
```bash
# Scan a specific directory
checkov --directory deployments/network-core --framework terraform

# Scan with specific severity threshold
checkov --directory . --framework terraform --check CKV_AWS_*

# Generate JSON report
checkov --directory . --framework terraform --output json --output-file-path console,report.json

# Skip specific checks
checkov --directory . --framework terraform --skip-check CKV_AWS_260,CKV_AWS_338
```

## Configuration

### Checkov Configuration File
The `.checkov.yml` file contains global configuration:
- Frameworks to scan (terraform, secrets)
- Directories to skip (.terraform, .git)
- Checks to skip with justifications
- Output formats and settings

### Skipping Checks

If a check is a false positive or not applicable, you can skip it:

#### 1. In Configuration File (Recommended)
Add to `.checkov.yml`:
```yaml
skip-check:
  - CKV_AWS_123  # Brief justification why this is skipped
```

#### 2. Inline in Terraform Code
```hcl
resource "aws_s3_bucket" "example" {
  #checkov:skip=CKV_AWS_18:Justification for skipping this check
  bucket = "my-bucket"
}
```

#### 3. At Resource Level
```hcl
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
  
  #checkov:skip=CKV_AWS_18
  #checkov:skip=CKV_AWS_19
}
```

## Common Security Issues and Fixes

### 1. Unencrypted Resources
**Issue**: CKV_AWS_18 - S3 bucket not encrypted
```hcl
# ❌ Bad
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

# ✅ Good
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### 2. Public Access
**Issue**: CKV_AWS_20 - S3 bucket allows public access
```hcl
# ✅ Good
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### 3. Missing Logging
**Issue**: CKV_AWS_23 - Security group missing description
```hcl
# ❌ Bad
resource "aws_security_group_rule" "example" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# ✅ Good
resource "aws_security_group_rule" "example" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTPS traffic from internet"
}
```

## GitHub Actions Workflows

### Security Scan Workflow
**File**: `.github/workflows/security-scan.yml`

Runs comprehensive security scans on push/PR events.

**Manual Trigger**:
1. Go to Actions tab
2. Select "Security Scan with Checkov"
3. Click "Run workflow"
4. Choose scan path and severity threshold

### Terraform Deploy Workflow
**File**: `.github/workflows/terraform-deploy.yml`

Includes pre-deployment security scan that:
1. Scans the deployment folder
2. Blocks deployment if CRITICAL/HIGH issues found
3. Proceeds with deployment only if scan passes

## Viewing Results

### In GitHub Actions
1. Go to the Actions tab
2. Click on the workflow run
3. View the "Security Scan" job
4. Check the summary for quick overview
5. Download artifacts for detailed reports

### Report Formats
- **CLI Output**: Human-readable console output
- **JSON**: Machine-readable format for automation
- **SARIF**: GitHub Security tab integration
- **JUnit XML**: Test result format

### GitHub Security Tab
SARIF results are automatically uploaded to the Security tab:
1. Go to Security tab
2. Click "Code scanning alerts"
3. View Checkov findings with file locations

## Best Practices

1. **Run scans locally** before pushing code
2. **Fix CRITICAL and HIGH** severity issues immediately
3. **Document skip reasons** when skipping checks
4. **Review scan results** in PR comments
5. **Keep Checkov updated** to get latest security checks
6. **Use inline suppressions** sparingly and with justification
7. **Monitor security trends** over time

## Troubleshooting

### Scan Fails with False Positives
- Review the specific check documentation
- Add to skip-check in `.checkov.yml` with justification
- Use inline suppressions for specific resources

### Pipeline Blocked by Security Issues
1. Review the failed checks in the workflow summary
2. Fix the issues in your Terraform code
3. Test locally with `./scripts/run-security-scan.sh`
4. Push the fixes to re-run the scan

### Need to Deploy Urgently
If you must deploy despite security issues (not recommended):
1. Document the security debt
2. Create a ticket to fix the issues
3. Temporarily add checks to skip-check list
4. Remove the skip after fixing

## Resources

- [Checkov Documentation](https://www.checkov.io/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

## Support

For questions or issues with security scanning:
1. Check this documentation
2. Review Checkov documentation
3. Contact the security team
4. Create an issue in the repository
