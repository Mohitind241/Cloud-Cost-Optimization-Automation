"""
Cloud Cost Optimization with Automation
========================================
Lambda function: cost_analyser.py

What it does every day (triggered by CloudWatch Events):
  1. Pulls last-7-day AWS spend from Cost Explorer
  2. Detects idle EC2 instances (CPU < 2% for threshold days)
  3. Detects unattached EBS volumes
  4. Detects unassociated Elastic IP addresses
  5. Publishes a cost-summary report to SNS
  6. Pushes custom CloudWatch metrics for dashboards

Tools used: AWS Cost Explorer, EC2 describe APIs, SNS, CloudWatch
"""

import boto3
import json
import os
import logging
from datetime import datetime, timedelta, timezone

# ─── Logging ──────────────────────────────────────────────────
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ─── Environment variables ────────────────────────────────────
SNS_TOPIC_ARN         = os.environ["SNS_TOPIC_ARN"]
ENVIRONMENT           = os.environ.get("ENVIRONMENT", "dev")
IDLE_THRESHOLD_DAYS   = int(os.environ.get("IDLE_THRESHOLD_DAYS", "7"))
AWS_REGION            = os.environ.get("AWS_ACCOUNT_REGION", "us-east-1")

# ─── AWS Clients ──────────────────────────────────────────────
ce_client  = boto3.client("ce",         region_name="us-east-1")   # Cost Explorer is global
ec2_client = boto3.client("ec2",        region_name=AWS_REGION)
cw_client  = boto3.client("cloudwatch", region_name=AWS_REGION)
sns_client = boto3.client("sns",        region_name=AWS_REGION)


# ══════════════════════════════════════════════════════════════
# 1. COST EXPLORER — Last 7 days spend
# ══════════════════════════════════════════════════════════════
def get_cost_last_7_days() -> dict:
    """Return total cost for the last 7 days grouped by service."""
    end   = datetime.now(timezone.utc).date()
    start = end - timedelta(days=7)

    response = ce_client.get_cost_and_usage(
        TimePeriod={"Start": str(start), "End": str(end)},
        Granularity="DAILY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )

    service_costs: dict[str, float] = {}
    total_cost = 0.0

    for result in response["ResultsByTime"]:
        for group in result["Groups"]:
            service = group["Keys"][0]
            amount  = float(group["Metrics"]["UnblendedCost"]["Amount"])
            service_costs[service] = service_costs.get(service, 0.0) + amount
            total_cost += amount

    # Sort descending
    sorted_services = dict(
        sorted(service_costs.items(), key=lambda x: x[1], reverse=True)
    )
    return {"total_usd": round(total_cost, 4), "by_service": sorted_services}


# ══════════════════════════════════════════════════════════════
# 2. IDLE RESOURCE DETECTION
# ══════════════════════════════════════════════════════════════
def detect_idle_ec2_instances() -> list[dict]:
    """Find running EC2 instances with very low CPU utilisation."""
    idle_instances = []

    response  = ec2_client.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )

    end_time   = datetime.now(timezone.utc)
    start_time = end_time - timedelta(days=IDLE_THRESHOLD_DAYS)

    for reservation in response.get("Reservations", []):
        for instance in reservation.get("Instances", []):
            instance_id = instance["InstanceId"]
            instance_type = instance.get("InstanceType", "unknown")

            # Get average CPU utilisation over the threshold period
            cpu_metrics = cw_client.get_metric_statistics(
                Namespace="AWS/EC2",
                MetricName="CPUUtilization",
                Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
                StartTime=start_time,
                EndTime=end_time,
                Period=86400,          # daily granularity
                Statistics=["Average"],
            )

            if not cpu_metrics["Datapoints"]:
                avg_cpu = 0.0
            else:
                avg_cpu = round(
                    sum(dp["Average"] for dp in cpu_metrics["Datapoints"])
                    / len(cpu_metrics["Datapoints"]),
                    2,
                )

            if avg_cpu < 2.0:          # < 2% CPU → considered idle
                name_tag = next(
                    (t["Value"] for t in instance.get("Tags", []) if t["Key"] == "Name"),
                    "Unnamed",
                )
                idle_instances.append({
                    "instance_id":   instance_id,
                    "instance_type": instance_type,
                    "name":          name_tag,
                    "avg_cpu_pct":   avg_cpu,
                    "launch_time":   str(instance.get("LaunchTime", "")),
                })

    return idle_instances


def detect_unattached_volumes() -> list[dict]:
    """Return EBS volumes that are not attached to any instance."""
    response = ec2_client.describe_volumes(
        Filters=[{"Name": "status", "Values": ["available"]}]
    )
    volumes = []
    for vol in response.get("Volumes", []):
        name_tag = next(
            (t["Value"] for t in vol.get("Tags", []) if t["Key"] == "Name"), "Unnamed"
        )
        volumes.append({
            "volume_id":   vol["VolumeId"],
            "size_gb":     vol["Size"],
            "volume_type": vol["VolumeType"],
            "name":        name_tag,
            "create_time": str(vol.get("CreateTime", "")),
        })
    return volumes


def detect_unassociated_eips() -> list[dict]:
    """Return Elastic IP addresses with no associated instance."""
    response = ec2_client.describe_addresses()
    eips = []
    for addr in response.get("Addresses", []):
        if "AssociationId" not in addr:
            eips.append({
                "allocation_id": addr.get("AllocationId", "N/A"),
                "public_ip":     addr.get("PublicIp", "N/A"),
            })
    return eips


# ══════════════════════════════════════════════════════════════
# 3. CLOUDWATCH CUSTOM METRICS
# ══════════════════════════════════════════════════════════════
def publish_custom_metrics(total_cost: float, idle_count: int, unattached_vols: int):
    """Push key cost metrics to a custom CloudWatch namespace."""
    cw_client.put_metric_data(
        Namespace="CloudCostOptimization",
        MetricData=[
            {
                "MetricName": "WeeklyTotalCostUSD",
                "Value":      total_cost,
                "Unit":       "None",
                "Dimensions": [{"Name": "Environment", "Value": ENVIRONMENT}],
            },
            {
                "MetricName": "IdleEC2InstanceCount",
                "Value":      float(idle_count),
                "Unit":       "Count",
                "Dimensions": [{"Name": "Environment", "Value": ENVIRONMENT}],
            },
            {
                "MetricName": "UnattachedEBSVolumeCount",
                "Value":      float(unattached_vols),
                "Unit":       "Count",
                "Dimensions": [{"Name": "Environment", "Value": ENVIRONMENT}],
            },
        ],
    )


# ══════════════════════════════════════════════════════════════
# 4. SNS REPORT PUBLISHER
# ══════════════════════════════════════════════════════════════
def publish_sns_report(
    cost_data: dict,
    idle_instances: list,
    unattached_volumes: list,
    unassociated_eips: list,
):
    """Format and publish a cost-optimisation report to SNS."""
    lines = [
        f"☁️  Cloud Cost Optimization Report — {ENVIRONMENT.upper()}",
        f"📅  Period : Last 7 days  |  Date : {datetime.now(timezone.utc).strftime('%Y-%m-%d')}",
        "=" * 60,
        "",
        f"💰 TOTAL AWS SPEND (last 7 days): ${cost_data['total_usd']:.2f}",
        "",
        "📊 TOP SERVICES BY COST:",
    ]

    for i, (service, amount) in enumerate(cost_data["by_service"].items()):
        if i >= 5:
            break
        lines.append(f"   {i+1}. {service}: ${amount:.4f}")

    lines += [
        "",
        f"⚠️  IDLE EC2 INSTANCES ({len(idle_instances)} found):",
    ]
    if idle_instances:
        for inst in idle_instances:
            lines.append(
                f"   - {inst['instance_id']} ({inst['instance_type']}) "
                f"| Name: {inst['name']} | Avg CPU: {inst['avg_cpu_pct']}%"
            )
    else:
        lines.append("   ✅ No idle instances detected.")

    lines += [
        "",
        f"💾 UNATTACHED EBS VOLUMES ({len(unattached_volumes)} found):",
    ]
    if unattached_volumes:
        for vol in unattached_volumes:
            lines.append(
                f"   - {vol['volume_id']} | {vol['size_gb']} GB | Type: {vol['volume_type']}"
            )
    else:
        lines.append("   ✅ No unattached volumes found.")

    lines += [
        "",
        f"🌐 UNASSOCIATED ELASTIC IPs ({len(unassociated_eips)} found):",
    ]
    if unassociated_eips:
        for eip in unassociated_eips:
            lines.append(f"   - {eip['public_ip']} (Allocation: {eip['allocation_id']})")
    else:
        lines.append("   ✅ No unassociated Elastic IPs found.")

    lines += [
        "",
        "=" * 60,
        "💡 ACTION ITEMS:",
        "   • Stop or rightsize any idle EC2 instances.",
        "   • Delete unattached EBS volumes if no longer needed.",
        "   • Release unused Elastic IPs to avoid charges.",
        "   • Review top-spend services for reserved-instance opportunities.",
        "",
        "This report was generated automatically by the",
        "Cloud Cost Optimization Lambda — powered by Terraform & AWS.",
    ]

    message = "\n".join(lines)

    sns_client.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f"[{ENVIRONMENT.upper()}] AWS Cost Optimization Report",
        Message=message,
    )
    logger.info("Cost report published to SNS.")


# ══════════════════════════════════════════════════════════════
# 5. LAMBDA HANDLER
# ══════════════════════════════════════════════════════════════
def lambda_handler(event, context):
    """
    Entry point — orchestrates cost analysis and alerting.

    Flow:
      get_cost_last_7_days()
        → detect idle EC2 instances
        → detect unattached EBS volumes
        → detect unassociated Elastic IPs
        → publish CloudWatch metrics
        → publish SNS report
    """
    logger.info("Starting Cloud Cost Optimisation Analysis...")

    try:
        # 1. Pull cost data
        cost_data = get_cost_last_7_days()
        logger.info(f"Total 7-day cost: ${cost_data['total_usd']:.2f}")

        # 2. Detect idle / wasteful resources
        idle_instances    = detect_idle_ec2_instances()
        unattached_vols   = detect_unattached_volumes()
        unassociated_eips = detect_unassociated_eips()

        logger.info(
            f"Found {len(idle_instances)} idle EC2, "
            f"{len(unattached_vols)} unattached EBS, "
            f"{len(unassociated_eips)} loose EIPs."
        )

        # 3. Push metrics to CloudWatch
        publish_custom_metrics(
            total_cost    = cost_data["total_usd"],
            idle_count    = len(idle_instances),
            unattached_vols = len(unattached_vols),
        )

        # 4. Publish report via SNS
        publish_sns_report(
            cost_data          = cost_data,
            idle_instances     = idle_instances,
            unattached_volumes = unattached_vols,
            unassociated_eips  = unassociated_eips,
        )

        return {
            "statusCode":        200,
            "total_cost_usd":    cost_data["total_usd"],
            "idle_instances":    len(idle_instances),
            "unattached_vols":   len(unattached_vols),
            "unassociated_eips": len(unassociated_eips),
        }

    except Exception as exc:
        logger.exception(f"Cost analyser failed: {exc}")
        raise
