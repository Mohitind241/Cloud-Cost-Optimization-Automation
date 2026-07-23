<<<<<<< HEAD
# ☁️ Cloud Cost Optimization with Automation

> **Automated cloud cost monitoring, idle resource detection, and budget alerting on AWS — fully provisioned with Terraform and deployed via GitLab CI/CD.**

---

## 🎯 Problem This Project Solves

AWS bills can silently balloon. Teams often have:
- EC2 instances running 24/7 with near-zero usage
- EBS volumes detached and forgotten
- Elastic IPs sitting idle (charged even when unused)
- No visibility into which service is eating the budget

This project **automates the detection and alerting of all the above**, runs daily, and sends you a cost report — so you always know where your money is going and what to turn off.

---

## 🛠️ Tech Stack

| Tool | Purpose |
|---|---|
| **AWS Cost Explorer** | Query 7-day spend broken down by service |
| **AWS Lambda (Python 3.12)** | Runs the cost analyser daily |
| **CloudWatch Events** | Triggers Lambda on a daily schedule |
| **CloudWatch Metrics & Dashboard** | Visualise cost trends and idle resource counts |
| **AWS SNS** | Sends email cost-optimisation report |
| **AWS Budgets** | Hard monthly budget cap with % alerts |
| **Terraform** | Infrastructure-as-Code for all AWS resources |
| **GitLab CI/CD** | Automates Terraform validate → plan → apply |

---

## 📂 Project Structure

```
cloud-cost-optimization-automation/
├── main.tf                        # Root module — wires networking + cost_automation
├── provider.tf                    # AWS provider configuration
├── variables.tf                   # All input variables with defaults
├── outputs.tf                     # Root-level outputs
├── backend.tf                     # S3 remote state backend (empty block)
├── tfstate.config                 # Backend config injected at init time
├── .gitignore                     # Terraform, Python, Lambda zip excludes
├── .gitlab-ci.yml                 # 4-stage CI/CD pipeline
│
├── modules/
│   ├── networking/                # VPC, subnets, security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── cost_automation/           # Lambda, SNS, Budgets, CloudWatch
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── lambda/
    └── cost_analyser.py           # Python Lambda — the core automation brain
```

---

## 📋 Prerequisites

Before you begin, make sure you have:

1. **AWS Account** — [Create here](https://signin.aws.amazon.com/signup?request_type=register)
2. **AWS CLI installed & configured**
3. **Terraform ≥ 1.3** — [Install here](https://developer.hashicorp.com/terraform/install)
4. **GitLab account** — [gitlab.com](https://gitlab.com)
5. **VS Code** (or any editor) — [Download here](https://code.visualstudio.com/download)

---

## 🚀 Step-by-Step Setup

### Part 1 — AWS Setup

#### Step 1: Create an IAM User for Terraform

1. Go to **AWS Console → IAM → Users → Add users**
2. Enter a username (e.g. `terraform-cost-bot`)
3. Attach policy: **AdministratorAccess** (or a custom least-privilege policy)
4. Create the user → go to **Security credentials → Create access key**
5. Choose **CLI** → download the `.csv`

#### Step 2: Configure AWS CLI

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output (json)

aws iam list-users   # verify it works
```

#### Step 3: Create the S3 State Bucket + DynamoDB Lock Table

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket cloud-cost-opt-tfstate \
  --region us-east-1

# Enable versioning (important for state safety)
aws s3api put-bucket-versioning \
  --bucket cloud-cost-opt-tfstate \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket cloud-cost-opt-tfstate \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name cloud-cost-opt-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

### Part 2 — GitLab Repository Setup

#### Step 4: Create a New GitLab Repository

1. Log in to [gitlab.com](https://gitlab.com)
2. Click **New project → Create blank project**
3. **Project name**: `cloud-cost-optimization-automation`
4. Visibility: **Private**
5. Click **Create project**

#### Step 5: Add AWS Credentials as GitLab CI/CD Variables

1. Go to your project → **Settings → CI/CD → Variables → Add variable**
2. Add these two variables (mark as **Masked** and **Protected**):

| Key | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your IAM access key |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret key |

---

### Part 3 — Configure the Project

#### Step 6: Update `tfstate.config`

Edit `tfstate.config` and replace with your actual bucket name:

```hcl
bucket         = "cloud-cost-opt-tfstate"   # your bucket name
key            = "terraform/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "cloud-cost-opt-tf-lock"   # your DynamoDB table
encrypt        = true
```

#### Step 7: Update `variables.tf` — set your email

In `variables.tf`, change:
```hcl
variable "cost_alert_email" {
  default = "your-email@example.com"   # ← put your real email here
}
```

---

### Part 4 — Manual Terraform Run (Local Test)

#### Step 8: Initialize, Plan, Apply

```bash
# From the project root:
terraform init -backend-config="tfstate.config"

terraform fmt -recursive      # format code
terraform validate            # check syntax

terraform plan                # preview what will be created
terraform apply               # create all resources
```

After apply, **check your email** — you'll get an SNS confirmation; click **Confirm subscription**.

---

### Part 5 — Automated CI/CD via GitLab

#### Step 9: Push to GitLab

```bash
git init
git remote add origin https://gitlab.com/<your-username>/cloud-cost-optimization-automation.git
git add .
git commit -m "feat: initial cloud cost optimization automation setup"
git push -u origin main
```

#### Step 10: Watch the Pipeline

1. Go to your GitLab project → **CI/CD → Pipelines**
2. You'll see the pipeline run: **validate → plan → apply (manual)**
3. Click the ▶️ button on `tf:apply` to approve the deployment

---

## 🔄 How It Works (End-to-End Flow)

```
CloudWatch Events (daily)
        ↓
   Lambda (cost_analyser.py)
        ↓
   ┌─────────────────────────────────┐
   │  1. Query Cost Explorer (7 days) │
   │  2. Find idle EC2 instances      │
   │  3. Find unattached EBS volumes  │
   │  4. Find loose Elastic IPs       │
   └─────────────────────────────────┘
        ↓                    ↓
  CloudWatch Metrics     SNS Email Report
  (custom dashboard)    (daily to your inbox)
        ↓
  AWS Budgets (alert at 80% & 100% of monthly limit)
```

---

## 💡 What the Daily Report Looks Like

```
☁️  Cloud Cost Optimization Report — DEV
📅  Period : Last 7 days  |  Date : 2026-07-23
════════════════════════════════════════════════════════════

💰 TOTAL AWS SPEND (last 7 days): $12.48

📊 TOP SERVICES BY COST:
   1. Amazon EC2: $7.20
   2. Amazon S3: $2.10
   3. AWS Lambda: $0.80
   ...

⚠️  IDLE EC2 INSTANCES (2 found):
   - i-0abc123def (t2.micro) | Name: old-test | Avg CPU: 0.3%
   - i-0xyz789ghi (t3.small) | Name: staging  | Avg CPU: 1.1%

💾 UNATTACHED EBS VOLUMES (1 found):
   - vol-0abcdef12 | 50 GB | Type: gp2

🌐 UNASSOCIATED ELASTIC IPs (1 found):
   - 3.84.12.200 (Allocation: eipalloc-0abc...)

💡 ACTION ITEMS:
   • Stop or rightsize idle EC2 instances → saves ~$X/month
   • Delete unattached EBS volumes → saves ~$Y/month
   • Release unused Elastic IPs → saves $0.005/hr each
```

---

## 📊 CloudWatch Dashboard

After deploying, visit your CloudWatch dashboard to see:
- **Weekly total spend** trend chart
- **Idle EC2 count** over time
- **Unattached EBS volume count** over time
- **Lambda invocation / error** counts

---

## 🗑️ Clean Up

To destroy all created resources:

```bash
terraform destroy
```

Or trigger the **tf:destroy** manual step in the GitLab pipeline.

---

## 🔐 Security Notes

- **Never commit** `tfstate.config` with real bucket names to a public repo
- **Never commit** `.tfvars` files with sensitive values
- Always mark GitLab CI variables as **Masked** and **Protected**
- The `.gitignore` in this project already excludes all state files and secrets

---

## 📚 References

- [AWS Cost Explorer API](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-api.html)
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [AWS Budgets](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitLab CI/CD Docs](https://docs.gitlab.com/ee/ci/)
=======
# Cloud-Cost-Optimization-Automation
Automated cloud cost monitoring using AWS Lambda, Cost Explorer, CloudWatch, Terraform
>>>>>>> 4b8cc5050ec656eeb7b79ed2beda388d85fe26a6
