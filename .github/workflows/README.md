# GitHub Actions Workflows

## Terraform Network Deployment Workflow

This workflow provides a simple, folder-based deployment approach for the network infrastructure.

### Features

- Deploy any deployment folder independently
- State files stored in core AWS account
- No environment promotion (dev→stg→prd)
- Read configuration from terraform.tfvars in each deployment folder
- Manual approval for apply and destroy actions

### Configuration

#### 1. Update Core Account ID

Edit `.github/workflows/terraform-deploy.yml` and replace:

```yaml
CORE_ACCOUNT_ID: "YOUR_CORE_ACCOUNT_ID"
```

With your actual core/network-services account ID.

#### 2. Setup GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `AWS_ACCESS_KEY_ID` - AWS access key for the account with permissions
- `AWS_SECRET_ACCESS_KEY` - AWS secret access key
- `AWS_SESSION_TOKEN` - (Optional) AWS session token if using temporary credentials

#### 3. Setup GitHub Environments (Optional but Recommended)

For manual approval on apply/destroy, create these environments in your repository (Settings → Environments):

**For Apply Actions:**
- `network-core`
- `network-egress`
- `network-inspection`
- `network-ingress`
- `workload-production`
- `workload-development`

**For Destroy Actions:**
- `destroy-network-core`
- `destroy-network-egress`
- `destroy-network-inspection`
- `destroy-network-ingress`
- `destroy-workload-production`
- `destroy-workload-development`

For each environment, add required reviewers to enforce manual approval.

### Usage

#### Running a Deployment

1. Go to **Actions** tab in GitHub
2. Select **Terraform Network Deployment** workflow
3. Click **Run workflow**
4. Select:
   - **Deployment folder**: Choose which deployment to run
   - **Action**: Choose `plan`, `apply`, or `destroy`
   - **Auto-approve**: Leave unchecked for safety (requires GitHub environment approval)

#### Workflow Actions

**Plan**
- Runs `terraform plan` to show what changes will be made
- No infrastructure changes
- Safe to run anytime

**Apply**
- Runs `terraform plan` first
- If changes detected, runs `terraform apply`
- Requires manual approval if GitHub environment is configured
- Creates/updates infrastructure

**Destroy**
- Destroys all infrastructure in the selected deployment folder
- Requires manual approval if GitHub environment is configured
- PERMANENT - cannot be undone

### State File Management

State files are stored in S3 bucket in the core account:

```
s3://terraform-state-network-{CORE_ACCOUNT_ID}/
├── network-core/terraform.tfstate
├── network-egress/terraform.tfstate
├── network-inspection/terraform.tfstate
├── network-ingress/terraform.tfstate
├── workload-production/terraform.tfstate
└── workload-development/terraform.tfstate
```

Each deployment folder has its own state file, allowing independent deployments.

### Deployment Order

For initial deployment, follow this order:

1. **network-core** - Creates CloudWAN, IPAM, DNS
2. **network-inspection** - Creates inspection VPC and security services
3. **network-egress** - Creates egress VPC and NAT/firewall
4. **network-ingress** - Creates ingress VPC and ALB/WAF
5. **workload-production** - Creates production workload VPC
6. **workload-development** - Creates development workload VPC

### Troubleshooting

**Backend Configuration**

If you see backend errors, the workflow automatically creates:
- S3 bucket: `terraform-state-network-{CORE_ACCOUNT_ID}`
- DynamoDB table: `terraform-state-locks`

Both are created in the core account specified in the workflow.

**Permission Issues**

Ensure your AWS credentials have permissions to:
- Create/manage S3 buckets and DynamoDB tables in core account
- Assume roles in target accounts (if using cross-account deployment)
- Create network resources (VPCs, subnets, CloudWAN, etc.)

**State Lock Issues**

If a deployment fails and leaves a state lock:

```bash
# From your local machine
cd deployments/{folder}
terraform force-unlock {LOCK_ID}
```

### Local Development

To use the same backend configuration locally:

```bash
cd deployments/network-core

# Create backend.tf (same as workflow creates)
cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "terraform-state-network-{CORE_ACCOUNT_ID}"
    key            = "network-core/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
EOF

# Initialize and work normally
terraform init
terraform plan
terraform apply
```

### Security Best Practices

1. **Never enable auto-approve for production deployments**
2. **Always use GitHub environment protection with required reviewers**
3. **Review terraform plan output before approving apply**
4. **Use least-privilege IAM roles for GitHub Actions**
5. **Enable CloudTrail logging for all AWS accounts**
6. **Regularly review state file access logs**

### Differences from Original Workflow

The new workflow is simplified:

- **No environment promotion** - Each deployment is independent
- **No workspace management** - Each folder has its own state file
- **No complex account switching** - Uses single AWS credential set
- **No tfvars file selection** - Uses terraform.tfvars in each folder
- **Simpler backend setup** - Single S3 bucket with folder-based keys
- **Manual trigger only** - No automatic deployments on push

This approach is better suited for network infrastructure where:
- Deployments are infrequent
- Each component is independent
- Manual review is required
- No environment progression is needed
