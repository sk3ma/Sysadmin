#!/usr/bin/env bash

# Declaring script variables.
AWS_CMD="aws"
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
BLUE='\e[1;34m'
RED='\e[1;31m'
GREEN='\e[1;32m'
NORMAL='\e[0m'

# Display menu banner.
banner() {
    echo -e "${GREEN}"
    cat << "STOP"
    ___      _____  ___ _    ___ 
   /_\ \    / / __|/ __| |  |_ _|
  / _ \ \/\/ /\__ \ (__| |__ | | 
 /_/ \_\_/\_/ |___/\___|____|___|
                                                
STOP
    echo -e "${NORMAL}"
}

# Prompt AWS profile.
setup_aws() {
  echo -ne "${YELLOW}Enter AWS profile: ${NORMAL}"
  read aws_profile
  echo -ne "${YELLOW}Enter AWS region: ${NORMAL}"
  read aws_region
}

# Create pause function.
pause() {
  echo -ne "${CYAN}Press [Enter] to continue...${NORMAL}"
  read
}

# Show main menu.
menu() {
  clear
  echo -e "${YELLOW}###############"
  echo "# AWSCLI MENU #"
  echo -e "###############${NORMAL}"
  echo
  echo "[1] EC2     - List instances"
  echo "[2] IAM     - List users/roles"
  echo "[3] S3      - List buckets"
  echo "[4] EKS     - List clusters"
  echo "[5] Secrets - View secrets"
  echo "[6] Route53 - List DNS zones"
  echo "[7] Lambda  - View functions"
  echo "[8] Billing - View cost usage"
  echo "[9] VPC     - View networking"
  echo "[10] ECR    - View containers"
  echo "[11] SES    - Email settings"
  echo "[0] Exit menu"
  echo
}

# AWS services funcions.
run_choice() {
  case $1 in
    1)
      echo -e "${YELLOW}[EC2 Instances]${NORMAL}"
      ${AWS_CMD} ec2 describe-instances --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    2)
      echo -e "${YELLOW}[IAM Users and Roles]${NORMAL}"
      ${AWS_CMD} iam list-users --profile "$aws_profile" | jq .
      ${AWS_CMD} iam list-roles --profile "$aws_profile" | jq .
      ;;
    3)
      echo -e "${YELLOW}[S3 Buckets]${NORMAL}"
      ${AWS_CMD} s3api list-buckets --query "Buckets[].Name" --output json --profile "$aws_profile" | jq .
      ;;
    4)
      echo -e "${YELLOW}[EKS Clusters]${NC}"
      ${AWS_CMD} eks list-clusters --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    5)
      echo -e "${YELLOW}[Secrets Manager]${NORMAL}"
      ${AWS_CMD} secretsmanager list-secrets --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    6)
      echo -e "${YELLOW}[Route53 Hosted Zones]${NORMAL}"
      ${AWS_CMD} route53 list-hosted-zones --profile "$aws_profile" | jq .
      ;;
    7)
      echo -e "${YELLOW}[Lambda Functions]${NORMAL}"
      ${AWS_CMD} lambda list-functions --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    8)
      echo -e "${YELLOW}[Billing - Last 30 Days]${NORMAL}"
      ${AWS_CMD} ce get-cost-and-usage \
        --time-period Start=$(date -d '30 days ago' +%F),End=$(date +%F) \
        --granularity MONTHLY \
        --metrics "AmortizedCost" \
        --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    9)
      echo -e "${YELLOW}[VPC Details]${NORMAL}"
      ${AWS_CMD} ec2 describe-vpcs --profile "$aws_profile" --region "$aws_region" | jq .
      ${AWS_CMD} ec2 describe-subnets --profile "$aws_profile" --region "$aws_region" | jq .
      ${AWS_CMD} ec2 describe-route-tables --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    10)
      echo -e "${YELLOW}[ECR Repositories]${NORMAL}"
      ${AWS_CMD} ecr describe-repositories --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    11)
      echo -e "${YELLOW}[SES - Email Status]${NORMAL}"
      ${AWS_CMD} ses list-identities --profile "$aws_profile" --region "$aws_region" | jq .
      ${AWS_CMD} ses get-send-quota --profile "$aws_profile" --region "$aws_region" | jq .
      ;;
    0)
      echo -e "${GREEN}Exiting menu.${NORMAL}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option. Try again.${NORMAL}"
      ;;
  esac
  pause
}

# Display banner first
banner
setup_aws

# Introduce infinite loop.
while true; do
  menu
  echo -ne "${BLUE}Choose an option [0-11]: ${NORMAL}"
  read opt
  run_choice "$opt"
done
