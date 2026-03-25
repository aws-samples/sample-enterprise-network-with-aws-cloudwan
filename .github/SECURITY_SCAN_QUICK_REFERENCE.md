# Security Scan Quick Reference

## 🚨 Pipeline Behavior

### ✅ Scan Passes
- **CRITICAL/HIGH issues**: 0
- **Action**: Deployment proceeds automatically

### ❌ Scan Fails  
- **CRITICAL/HIGH issues**: > 0
- **Action**: Pipeline fails, deployment blocked
- **Fix**: Address security issues and push again

## 📊 Severity Thresholds

| Severity | Symbol | Pipeline Action |
|----------|--------|-----------------|
| CRITICAL | 🔴 | **BLOCKS** deployment |
| HIGH | 🟠 | **BLOCKS** deployment |
| MEDIUM | 🟡 | Warning only |
| LOW | 🟢 | Info only |

## 🔧 Quick Commands

```bash
# Scan entire repo
./scripts/run-security-scan.sh

# Scan specific deployment
./scripts/run-security-scan.sh deployments/network-core

# Scan with Checkov directly
checkov -d deployments/network-core --framework terraform

# View results
cat security-reports/checkov-results.json | jq '.summary'
```

## 🛠️ Quick Fixes

### Skip a Check (with justification)
```yaml
# In .checkov.yml
skip-check:
  - CKV_AWS_123  # Reason: Not applicable because...
```

### Inline Suppression
```hcl
resource "aws_s3_bucket" "example" {
  #checkov:skip=CKV_AWS_18:Encryption handled by bucket policy
  bucket = "my-bucket"
}
```

## 📍 Where Scans Run

1. **Every Push** to main/develop → Full repo scan
2. **Every PR** → Full repo scan + PR comment
3. **Before Deployment** → Specific deployment folder scan
4. **Manual Trigger** → Custom path scan

## 🔍 View Results

- **GitHub Actions**: Actions tab → Workflow run → Security Scan job
- **Artifacts**: Download from workflow run
- **Security Tab**: Security → Code scanning alerts
- **PR Comments**: Automatic comment on pull requests

## ⚡ Emergency Override

**NOT RECOMMENDED** - Only for critical situations:

1. Add check to `.checkov.yml` skip-check
2. Document reason and create fix ticket
3. Push changes
4. Remove skip after fixing

## 📚 Full Documentation

See [SECURITY_SCANNING.md](../SECURITY_SCANNING.md) for complete guide.
