# ============================================================
# Remote State Backend — S3 + DynamoDB Lock
# Project: Cloud Cost Optimization with Automation
# ============================================================

terraform {
  backend "s3" {
    # Populated at init time via -backend-config="tfstate.config"
    # so no hard-coded values here.
  }
}
