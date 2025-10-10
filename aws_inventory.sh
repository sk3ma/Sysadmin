#!/usr/bin/env bash

set -euo pipefail

# Declaring variables.
OUTDIR="inventory_raw"
mkdir -p "${OUTDIR}"
PROFILE="${AWS_PROFILE:-robanybody}"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Interrupt signal.
cleanup() {
  echo
  echo -e "${RED}Caught interrupt signal, exiting...${RESET}"
  echo
  exit 1
}
trap cleanup INT

# Script header.
header() {
  echo
  echo -e "${CYAN}======================${RESET}"
  echo -e "${CYAN}# AWS Inventory Tool #${RESET}"
  echo -e "${CYAN}======================${RESET}"
  echo
}

# Pause function.
pause() {
  read -rp "Press Enter to continue..."
}

# AWS profile.
check_service() {
  local name="${1}"
  shift
  if output=$(aws --profile "${PROFILE}" "$@" --output json 2>/dev/null); then
    local nonempty
    nonempty=$(echo "${output}" | jq 'if type=="object" then (length>0) else (length>0) end' 2>/dev/null || echo false)
    if [[ "${nonempty}" == "true" ]]; then
      echo -e "[${GREEN}+${RESET}] ${name} ${GREEN}IN USE${RESET}"
      echo "${output}" > "${OUTDIR}/${name// /_}.json"
    else
      echo -e "[${YELLOW}-${RESET}] ${name} ${YELLOW}none detected${RESET}"
    fi
  else
    echo -e "[${RED}!${RESET}] ${name} ${RED}error or insufficient permissions${RESET}"
  fi
}

# Audit inventory.
scrape_inventory() {
  echo -e "${GREEN}Gathering inventory for profile:${RESET} ${BLUE}${PROFILE}${RESET}"
  echo -e "${YELLOW}Results will be stored in:${RESET} ${BLUE}${OUTDIR}${RESET}"
  echo

  check_service "IAM Users" iam list-users
  check_service "IAM Roles" iam list-roles
  check_service "IAM Policies" iam list-policies --scope Local
  check_service "EC2 Instances" ec2 describe-instances
  check_service "Auto Scaling" autoscaling describe-auto-scaling-groups
  check_service "Load Balancers" elbv2 describe-load-balancers
  check_service "EKS Clusters" eks list-clusters
  check_service "ECS Clusters" ecs list-clusters
  check_service "ECR Repositories" ecr describe-repositories
  check_service "Lambda Functions" lambda list-functions
  check_service "API Gateway v2" apigatewayv2 get-apis
  check_service "S3 Buckets" s3api list-buckets
  check_service "RDS Instances" rds describe-db-instances
  check_service "DynamoDB Tables" dynamodb list-tables
  check_service "ElastiCache Clusters" elasticache describe-cache-clusters
  check_service "EFS Filesystems" efs describe-file-systems
  check_service "FSx Filesystems" fsx describe-file-systems
  check_service "OpenSearch Domains" opensearch list-domain-names
  check_service "VPCs" ec2 describe-vpcs
  check_service "Subnets" ec2 describe-subnets
  check_service "Security Groups" ec2 describe-security-groups
  check_service "Route53 Zones" route53 list-hosted-zones
  check_service "NAT Gateways" ec2 describe-nat-gateways
  check_service "SQS Queues" sqs list-queues
  check_service "SNS Topics" sns list-topics
  check_service "Kinesis Streams" kinesis list-streams
  check_service "CloudWatch Alarms" cloudwatch describe-alarms
  check_service "Log Groups" logs describe-log-groups
  check_service "KMS Keys" kms list-keys
  check_service "Secrets Manager" secretsmanager list-secrets
  check_service "ACM Certificates" acm list-certificates
  check_service "SSM Managed Instances" ssm describe-instance-information
  check_service "Step Functions" stepfunctions list-state-machines
  check_service "CodePipeline" codepipeline list-pipelines
  check_service "CodeBuild" codebuild list-projects

  echo
  echo -e "${YELLOW}Inventory gathering complete!${RESET}"
  pause
}

# View findings.
view_inventory() {
  while true; do
    clear
    header
    echo -e "${YELLOW}Available services in:${RESET} ${BLUE}${OUTDIR}${RESET}"
    echo

    shopt -s nullglob
    files=("${OUTDIR}"/*.json)

    if [[ ${#files[@]} -eq 0 ]]; then
      echo -e "${RED}No inventory files found.${RESET} Choose option 1 first."
      pause
      return
    fi

    declare -A services
    idx=1
    for f in "${files[@]}"; do
      base=$(basename "${f}" .json | sed 's/_/ /g')
      services[${idx}]="${f}"
      echo "${idx}) ${base}"
      ((idx++))
    done

    echo
    read -rp "$(echo -e "${BLUE}Select a service to view (number, or 'b' to go back): ${RESET}")" choice

    if [[ "${choice}" =~ ^[Bb]$ ]]; then
      break
    fi

    if [[ -n "${services[${choice}]:-}" ]]; then
      echo
      {
        trap - INT
        jq '.' "${services[${choice}]}" | less
        trap cleanup INT
      } || true
    else
      echo -e "${RED}Invalid selection, try again.${RESET}"
      sleep 1
    fi
  done
}

# Script menu.
menu() {
  clear
  header
  while true; do
    echo -e "${GREEN}1) Scrape AWS inventory${RESET}"
    echo -e "${YELLOW}2) View inventory findings${RESET}"
    echo -e "${RED}3) Exit the script${RESET}"
    echo
    read -rp "$(echo -e "${BLUE}Choose an option: ${RESET}")" opt

    case ${opt} in
      1) scrape_inventory ;;
      2) view_inventory ;;
      3) echo -e "${GREEN}Exiting...${RESET}"; exit 0 ;;
      *) echo -e "${RED}Invalid choice, try again.${RESET}"; sleep 1 ;;
    esac
    clear
    header
  done
}

# Calling function.
menu
