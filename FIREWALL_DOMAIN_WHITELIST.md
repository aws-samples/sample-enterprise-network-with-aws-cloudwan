# Network Firewall Domain Whitelist Configuration

## Current Mode: WHITELIST (Strict)

With `enable_drop_established = true` and `enable_alert_established = false`, the firewall operates in **strict whitelist mode**:
- Only explicitly allowed domains can access the internet
- Explicitly blocked domains are dropped with alerts
- All other domains are blocked by default (dropped silently)

**Important**: When `alert_established` is enabled together with `drop_established`, AWS Network Firewall logs alerts but does NOT enforce the drop action properly. Use ONLY `drop_established` for proper whitelist enforcement.

## Allowed Domains (Internet Access Permitted)

### Google Services
- `google.com` - Main Google domain
- `.google.com` - All Google subdomains (www.google.com, mail.google.com, etc.)
- `.googleapis.com` - Google APIs

### GitHub Services
- `github.com` - Main GitHub domain
- `.github.com` - All GitHub subdomains
- `.githubusercontent.com` - GitHub raw content

### HashiCorp/Terraform Services
- `terraform.io` - Terraform main site
- `.terraform.io` - Terraform subdomains
- `hashicorp.com` - HashiCorp main site
- `.hashicorp.com` - HashiCorp subdomains
- `.registry.terraform.io` - Terraform Registry
- `.releases.hashicorp.com` - HashiCorp releases

### AWS Services
- `amazon.com` - Amazon main site
- `.amazon.com` - Amazon subdomains
- `amazonaws.com` - AWS main domain
- `.amazonaws.com` - All AWS service endpoints

### Infrastructure Services (Always Allowed)
- DNS queries (UDP/TCP port 53)
- NTP (UDP port 123)
- ICMP (ping, traceroute)

## Blocked Domains (Explicitly Denied)

### Social Media (Test Blocks)
- `facebook.com` - Facebook main domain
- `.facebook.com` - All Facebook subdomains
- `twitter.com` - Twitter main domain
- `.twitter.com` - All Twitter subdomains
- `instagram.com` - Instagram main domain
- `.instagram.com` - All Instagram subdomains

## All Other Domains

**Status**: BLOCKED by default (drop_established action)

Any domain not in the allowed list will be blocked, including:
- Other social media sites
- News sites
- Entertainment sites
- Any other internet domains

## Rule Processing Order (STRICT_ORDER)

1. **Priority 5**: Check blocked domains → DROP with ALERT
2. **Priority 100**: Check allowed domains → PASS with FLOW log
3. **Default Action**: drop_established → DROP (silently, no alert)

**Note**: `alert_established` is intentionally DISABLED because when combined with `drop_established`, it prevents the drop action from working properly. With only `drop_established`, non-matching traffic is properly blocked.

## How to Add More Allowed Domains

Edit `deployments/network-egress/network-firewall.tf`:

```terraform
locals {
  allowed_domains = [
    # Existing domains...
    
    # Add new domains (both formats recommended):
    "example.com",      # Exact match
    ".example.com",     # All subdomains
  ]
}
```

Then apply:
```bash
cd deployments/network-egress
terraform apply
```

## Testing Access

### Test Allowed Domain (Should Work)
```bash
curl -I http://google.com
curl -I https://github.com
curl -I https://registry.terraform.io
```

### Test Blocked Domain (Should Timeout/Hang)
```bash
# Will hang until timeout - this is expected behavior for DROP action
curl --max-time 5 http://facebook.com
curl --max-time 5 http://twitter.com

# Expected output: "curl: (28) Operation timed out after 5000 milliseconds"
```

### Test Unlisted Domain (Should Timeout/Hang - Default Deny)
```bash
curl --max-time 5 http://cnn.com
curl --max-time 5 http://reddit.com

# Expected output: "curl: (28) Operation timed out after 5000 milliseconds"
```

**Note**: The hang/timeout behavior is **correct and expected** when traffic is blocked with DROP action. This is more secure than sending a TCP RST because it doesn't reveal the firewall's presence to potential attackers.

## Viewing Logs

### See Allowed Traffic
```bash
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_EGRESS] \
  --follow \
  --filter-pattern "flow" \
  --profile [PROFILE_NAME]
```

### See Blocked Traffic
```bash
aws logs tail /aws/network-firewall/[FIREWALL_LOG_GROUP_EGRESS] \
  --follow \
  --filter-pattern "alert" \
  --profile [PROFILE_NAME]
```

## Security Posture

**Current Configuration**: High Security (Whitelist Mode)
- ✅ Only approved domains accessible
- ✅ Explicit blocks for known bad domains
- ✅ Default deny for everything else
- ✅ Comprehensive logging of all traffic
- ✅ DNS, NTP, and ICMP allowed for infrastructure

This is the recommended configuration for production environments where you want strict control over internet access.
