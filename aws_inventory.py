#!/usr/bin/env python3

# Imp[ort Python libraries.
import os
import sys
import boto3
import json
import signal
from datetime import datetime, date
from rich.console import Console
from rich.table import Table
from rich.progress import Progress
from pathlib import Path

console = Console()

# Assign script variables.
OUTDIR = Path("inventory_raw")
OUTDIR.mkdir(exist_ok=True)
PROFILE = os.getenv("AWS_PROFILE", "robanybody")
REGION = os.getenv("AWS_REGION", "eu-west-1")

# Register signal trap.
def handle_interrupt(sig, frame):
    console.print("\n[red]Caught interrupt signal, exiting...[/]\n")
    sys.exit(0)

signal.signal(signal.SIGINT, handle_interrupt)

# Add JSON encoder.
def safe_json_dumps(data):
    """Safely dump JSON with datetime/date support."""
    def default(o):
        if isinstance(o, (datetime, date)):
            return o.isoformat()
        return str(o)
    return json.dumps(data, indent=2, default=default)


# Load AWS session.
def aws_session():
    return boto3.Session(profile_name=PROFILE, region_name=REGION)


# AWS fetch wrapper.
def fetch_service(service_name, client, method_name, key, **kwargs):
    """Try to fetch and save JSON output for a specific AWS service."""
    try:
        func = getattr(client, method_name)
        data = func(**kwargs)
        items = data.get(key, []) if isinstance(data, dict) else []
        if items:
            console.print(f"[green]+[/] {service_name}: [green]{len(items)} found[/]")
            with open(OUTDIR / f"{service_name.replace(' ', '_').lower()}.json", "w") as f:
                f.write(safe_json_dumps(data))
        else:
            console.print(f"[yellow]-[/] {service_name}: none detected")
    except Exception as e:
        console.print(f"[red]![/] {service_name}: {e}")


# Audit AWS account.
def scrape_inventory():
    console.rule("[bold cyan]AWS Inventory Tool")
    session = aws_session()
    console.print(
        f"[green]Gathering inventory for profile:[/] [blue]{PROFILE}[/]\n"
        f"[yellow]Results will be stored in:[/] [blue]{OUTDIR}[/]\n"
    )
    services = [
        ("IAM Users", "iam", "list_users", "Users"),
        ("IAM Roles", "iam", "list_roles", "Roles"),
        ("IAM Policies", "iam", "list_policies", "Policies", {"Scope": "Local"}),
        ("EC2 Instances", "ec2", "describe_instances", "Reservations"),
        ("Auto Scaling Groups", "autoscaling", "describe_auto_scaling_groups", "AutoScalingGroups"),
        ("Load Balancers", "elbv2", "describe_load_balancers", "LoadBalancers"),
        ("EKS Clusters", "eks", "list_clusters", "clusters"),
        ("ECS Clusters", "ecs", "list_clusters", "clusterArns"),
        ("ECR Repositories", "ecr", "describe_repositories", "repositories"),
        ("Lambda Functions", "lambda", "list_functions", "Functions"),
        ("API Gateway v2", "apigatewayv2", "get_apis", "Items"),
        ("S3 Buckets", "s3", "list_buckets", "Buckets"),
        ("RDS Instances", "rds", "describe_db_instances", "DBInstances"),
        ("DynamoDB Tables", "dynamodb", "list_tables", "TableNames"),
        ("ElastiCache Clusters", "elasticache", "describe_cache_clusters", "CacheClusters"),
        ("EFS Filesystems", "efs", "describe_file_systems", "FileSystems"),
        ("FSx Filesystems", "fsx", "describe_file_systems", "FileSystems"),
        ("OpenSearch Domains", "opensearch", "list_domain_names", "DomainNames"),
        ("VPCs", "ec2", "describe_vpcs", "Vpcs"),
        ("Subnets", "ec2", "describe_subnets", "Subnets"),
        ("Security Groups", "ec2", "describe_security_groups", "SecurityGroups"),
        ("Route53 Zones", "route53", "list_hosted_zones", "HostedZones"),
        ("NAT Gateways", "ec2", "describe_nat_gateways", "NatGateways"),
        ("SQS Queues", "sqs", "list_queues", "QueueUrls"),
        ("SNS Topics", "sns", "list_topics", "Topics"),
        ("Kinesis Streams", "kinesis", "list_streams", "StreamNames"),
        ("CloudWatch Alarms", "cloudwatch", "describe_alarms", "MetricAlarms"),
        ("Log Groups", "logs", "describe_log_groups", "logGroups"),
        ("KMS Keys", "kms", "list_keys", "Keys"),
        ("Secrets Manager", "secretsmanager", "list_secrets", "SecretList"),
        ("ACM Certificates", "acm", "list_certificates", "CertificateSummaryList"),
        ("SSM Managed Instances", "ssm", "describe_instance_information", "InstanceInformationList"),
        ("Step Functions", "stepfunctions", "list_state_machines", "stateMachines"),
        ("CodePipeline", "codepipeline", "list_pipelines", "pipelines"),
        ("CodeBuild Projects", "codebuild", "list_projects", "projects"),
    ]

    try:
        with Progress() as progress:
            task = progress.add_task("[cyan]Gathering AWS inventory...", total=len(services))
            for svc in services:
                name, client_name, method_name, key, *opt = svc
                kwargs = opt[0] if opt else {}
                client = session.client(client_name)
                fetch_service(name, client, method_name, key, **kwargs)
                progress.advance(task)
    except KeyboardInterrupt:
        console.print("\n[red]Scan interrupted by user. Partial data saved.[/]\n")
        return

    console.print("\n[yellow]Inventory gathering complete![/]\n")

# Scrape AWS inventory.
def view_inventory():
    files = list(OUTDIR.glob("*.json"))
    if not files:
        console.print("[red]No inventory files found. Run scrape first.[/]")
        return

    table = Table(title="Available Inventory Files")
    table.add_column("ID", justify="right")
    table.add_column("Service", justify="left")

    for i, f in enumerate(files, 1):
        table.add_row(str(i), f.stem.replace("_", " ").title())
    console.print(table)

    try:
        choice = console.input("[yellow]Select file number to view (or press Enter to cancel): [/]")
        if not choice.isdigit():
            return
        file = files[int(choice)-1]

        console.print(f"[green]Showing contents of:[/] {file}")
        with open(file) as f:
            console.print_json(f.read())
    except KeyboardInterrupt:
        console.print("\n[red]Cancelled by user.[/]\n")
    except Exception as e:
        console.print(f"[red]Error displaying JSON: {e}[/]")


# Define main menu.
def main():
    while True:
        console.rule("[bold magenta]Main Menu")
        console.print("[green]1) Scrape AWS inventory [/]")
        console.print("[yellow]2) View inventory[/] ")
        console.print("[red]3) Exit [/]\n")

        try:
            opt = console.input("[cyan]Choose an option:[/] ")
        except KeyboardInterrupt:
            console.print("\n[red]Interrupted. Exiting...[/]\n")
            break

        if opt == "1":
            scrape_inventory()
        elif opt == "2":
            view_inventory()
        elif opt == "3":
            console.print("[green]Exiting...[/]")
            break
        else:
            console.print("[red]Invalid choice[/]")

# Call main function.
if __name__ == "__main__":
    main()
