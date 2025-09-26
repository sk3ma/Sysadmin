#!/usr/bin/env bash

set -euo pipefail

YELLOW="\033[1;33m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
NORMAL="\033[0m"
PROFILE="robanybody"

echo -e "${YELLOW}[🟡] Listing IAM Secrets${NORMAL}"
secrets=$(aws secretsmanager list-secrets \
  --profile "${PROFILE}" \
  --query "SecretList[].Name" \
  --output text)

printf "${CYAN}%s${NORMAL}\n" ${secrets}

read -rp "Enter a secret name to query (press Enter for first): " secret_name
secret_name=${secret_name:-$(echo "${secrets}" | awk '{print $1}')}
if [[ -n "${secret_name}" ]]; then
  echo -e "${YELLOW}[🟡] Getting secret: ${GREEN}${secret_name}${NORMAL}"
  aws secretsmanager describe-secret \
    --secret-id "${secret_name}" \
    --profile "${PROFILE}" \
    --output json | jq -C .
fi

echo -e "${YELLOW}[🟡] Listing IAM Users${NORMAL}"
users=$(aws iam list-users \
  --profile "${PROFILE}" \
  --query "Users[].UserName" \
  --output text)

printf "${CYAN}%s${NORMAL}\n" ${users}

read -rp "Enter a user name to query (press Enter for first): " user_name
user_name=${user_name:-$(echo "${users}" | awk '{print $1}')}
if [[ -n "${user_name}" ]]; then
  echo -e "${YELLOW}[🟡] Getting user: ${GREEN}${user_name}${NORMAL}"
  aws iam get-user \
    --user-name "${user_name}" \
    --profile "${PROFILE}" \
    --output json | jq -C .
fi

echo -e "${YELLOW}[🟡] Listing IAM Groups${NORMAL}"
groups=$(aws iam list-groups \
  --profile "${PROFILE}" \
  --query "Groups[].GroupName" \
  --output text)

printf "${CYAN}%s${NORMAL}\n" ${groups}

read -rp "Enter a group name to query (press Enter for first): " group_name
group_name=${group_name:-$(echo "${groups}" | awk '{print $1}')}
if [[ -n "${group_name}" ]]; then
  echo -e "${YELLOW}[🟡] Getting group: ${GREEN}${group_name}${NORMAL}"
  aws iam get-group \
    --group-name "${group_name}" \
    --profile "${PROFILE}" \
    --output json | jq -C .
fi

echo -e "${YELLOW}[🟡] Listing Lambda Functions${NORMAL}"
lambdas=$(aws lambda list-functions \
  --profile "${PROFILE}" \
  --query "Functions[].FunctionName" \
  --output text)

printf "${CYAN}%s${NORMAL}\n" ${lambdas}

read -rp "Enter a Lambda function name to query (press Enter for first): " lambda_name
lambda_name=${lambda_name:-$(echo "${lambdas}" | awk '{print $1}')}
if [[ -n "${lambda_name}" ]]; then
  echo -e "${YELLOW}[🟡] Getting Lambda: ${GREEN}${lambda_name}${NORMAL}"
  aws lambda get-function \
    --function-name "${lambda_name}" \
    --profile "${PROFILE}" \
    --output json | jq -C .
fi
