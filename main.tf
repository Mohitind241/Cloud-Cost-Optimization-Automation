# ============================================================
# Root module — Cloud Cost Optimization with Automation
# Wires together: VPC networking + Lambda cost-analyser
# ============================================================

# ─── VPC / Networking module ──────────────────────────────────
module "networking" {
  source = "./modules/networking"

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
  environment         = var.environment
}

# ─── Cost Automation module ───────────────────────────────────
module "cost_automation" {
  source = "./modules/cost_automation"

  environment                  = var.environment
  public_subnet_id             = module.networking.public_subnet_id
  private_subnet_id            = module.networking.private_subnet_id
  vpc_id                       = module.networking.vpc_id
  lambda_sg_id                 = module.networking.lambda_sg_id
  cost_alert_email             = var.cost_alert_email
  monthly_budget_limit         = var.monthly_budget_limit
  lambda_schedule_expression   = var.lambda_schedule_expression
  idle_resource_threshold_days = var.idle_resource_threshold_days
  aws_region                   = var.aws_region
}
