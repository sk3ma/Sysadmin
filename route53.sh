#!/usr/bin/env bash

set -euo pipefail

# Settings variables.
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RED="\033[1;31m"
CYAN="\033[1;36m"
PURPLE="\033[1;95m"
RESET="\033[0m"
PROFILE="${AWS_PROFILE:-robanybody}"
OUTDIR="inventory_raw/route53_records"
ZONES_FILE="inventory_raw/Route53_Zones.json"

# Inventory directory.
mkdir -p "${OUTDIR}"

# Signal trap.
trap 'echo -e "\n${RED}Caught interrupt, exiting...${RESET}"; exit 1' INT

# Script banner.
header() {
  echo
  echo -e "${CYAN}===========================${RESET}"
  echo -e "${CYAN}# Route53 Management Tool #${RESET}"
  echo -e "${CYAN}===========================${RESET}"
  echo
}

# Pause function.
pause() { read -rp "Press Enter to continue..."; }

# Store records.
export_records() {
  if [[ ! -f "${ZONES_FILE}" ]]; then
    echo -e "${RED}Missing ${ZONES_FILE}. Run aws_inv.sh first.${RESET}"
    pause; return
  fi

  echo -e "${PURPLE}Exporting record sets for all hosted zones...${RESET}"

  while read -r id; do
    zone_id=$(basename "${id}")
    outfile="${OUTDIR}/${zone_id}_records.json"

    if [[ -f "${outfile}" ]]; then
      echo -e "  ${GREEN}=>${RESET} Skipping zone ${YELLOW}${zone_id}${RESET} (already exists)"
      continue
    fi

    echo -e "  ${GREEN}=>${RESET} ${YELLOW}${zone_id}${RESET}"

    aws --profile "${PROFILE}" route53 list-resource-record-sets \
      --hosted-zone-id "${zone_id}" \
      --output json > "${outfile}" || {
        echo -e "  ${RED}Error fetching ${zone_id}${RESET}"
        rm -f "${outfile}"
      }
  done < <(jq -r '.HostedZones[].Id' "${ZONES_FILE}")

  echo
  echo -e "${GREEN}Exports complete.${RESET}"
  echo -e "Files stored in ${BLUE}${OUTDIR}${RESET}"
  pause
}

# Query records.
view_records() {
  while true; do
    clear; header
    echo -e "${GREEN}Available hosted zones:${RESET}"
    
    jq -r '.HostedZones[] | "\(.Name) \(.Id)"' "${ZONES_FILE}" | nl | while read -r line; do
      zone_name=$(echo "${line}" | awk '{print $2}')
      zone_id=$(echo "${line}" | awk '{print $3}' | awk -F/ '{print $3}')
      printf " %3s\t%s ${YELLOW}/hostedzone/%s${RESET}\n" "$(echo "${line}" | awk '{print $1}')" "${zone_name}" "${zone_id}"
    done

    echo
    read -rp "$(echo -e "${BLUE}Enter a number or 'b' to go back: ${RESET}")" zid_input

    if [[ "${zid_input,,}" == "b" ]]; then
      break
    fi

    if [[ "${zid_input}" =~ ^[0-9]+$ ]]; then
      zid=$(jq -r --argjson n "${zid_input}" '.HostedZones[$n-1].Id' "${ZONES_FILE}" | awk -F/ '{print $3}')
    else
      zid="${zid_input}"
    fi

    local zfile="${OUTDIR}/${zid}_records.json"

    if [[ -f "${zfile}" ]]; then
      echo
      {
        trap - INT
        jq '.' "${zfile}" | less
        trap 'echo -e "\n${RED}Caught interrupt, exiting...${RESET}"; exit 1' INT
      } || true
      echo
      pause
    else
      echo -e "${RED}No records exported for ${zid}. Run option 1 first.${RESET}"
      pause
    fi
  done
}

# Remove records.
delete_record() {
  clear; header
  echo -e "${GREEN}Available hosted zones:${RESET}"

  jq -r '.HostedZones[] | "\(.Name) \(.Id)"' "${ZONES_FILE}" | nl | while read -r line; do
    zone_name=$(echo "${line}" | awk '{print $2}')
    zone_id=$(echo "${line}" | awk '{print $3}' | awk -F/ '{print $3}')
    printf " %3s\t%s ${YELLOW}/hostedzone/%s${RESET}\n" "$(echo "${line}" | awk '{print $1}')" "${zone_name}" "${zone_id}"
  done

  echo
  read -rp "$(echo -e "${BLUE}Enter a number or 'b' to go back: ${RESET}")" zid_input
  if [[ "${zid_input,,}" == "b" ]]; then
    return
  fi

  if [[ "${zid_input}" =~ ^[0-9]+$ ]]; then
    zid=$(jq -r --argjson n "${zid_input}" '.HostedZones[$n-1].Id' "${ZONES_FILE}" | awk -F/ '{print $3}')
  else
    zid="${zid_input}"
  fi

  local zfile="${OUTDIR}/${zid}_records.json"
  if [[ ! -f "${zfile}" ]]; then
    echo -e "${RED}No exported records found for this zone. Run option 1 first.${RESET}"
    pause; return
  fi

  echo
  read -rp "$(echo -e "${PURPLE}Enter record name with trailing dot: ${RESET}")" rname

  record_json=$(jq -r --arg name "$rname" '.ResourceRecordSets[] | select(.Name==$name)' "${zfile}")

  if [[ -z "${record_json}" ]]; then
    echo -e "${RED}Record ${rname} not found in exported data.${RESET}"
    pause; return
  fi

  rtype=$(echo "${record_json}" | jq -r '.Type')
  ttl=$(echo "${record_json}" | jq -r '.TTL')
  rval=$(echo "${record_json}" | jq -r '.ResourceRecords[0].Value')

  echo
  echo -e "${YELLOW}Found record:${RESET}"
  echo -e "  Name:  ${BLUE}${rname}${RESET}"
  echo -e "  Type:  ${BLUE}${rtype}${RESET}"
  echo -e "  TTL:   ${BLUE}${ttl}${RESET}"
  echo -e "  Value: ${BLUE}${rval}${RESET}"
  echo
  read -rp "$(echo -e "${RED}Confirm DELETE this record? [y/N]: ${RESET}")" confirm

  if [[ "${confirm,,}" == "y" ]]; then
    echo -e "${YELLOW}Deleting record...${RESET}"
    aws --profile "${PROFILE}" route53 change-resource-record-sets \
      --hosted-zone-id "${zid}" \
      --change-batch "{
        \"Changes\": [{
          \"Action\": \"DELETE\",
          \"ResourceRecordSet\": {
            \"Name\": \"${rname}\",
            \"Type\": \"${rtype}\",
            \"TTL\": ${ttl},
            \"ResourceRecords\": [{\"Value\": \"${rval}\"}]
          }
        }]
      }" \
    && echo -e "${GREEN}Record deleted successfully.${RESET}" \
    || echo -e "${RED}Error deleting record.${RESET}"
  else
    echo -e "${YELLOW}Deletion cancelled.${RESET}"
  fi

  pause
}

# Compare results.
compare_files() {
  echo
  read -rp "$(echo -e "${BLUE}Enter hosted zone ID: ${RESET}")" zid
  local zfile="${OUTDIR}/${zid}_records.json"
  if [[ ! -f "${zfile}" ]]; then
    echo -e "${RED}No export found for zone ${zid}. Run option 1 first.${RESET}"
    pause; return
  fi

  read -rp "$(echo -e "${BLUE}Enter path to route53.auto.tfvars: ${RESET}")" tfvars
  if [[ ! -f "${tfvars}" ]]; then
    echo -e "${RED}TF vars file not found.${RESET}"
    pause; return
  fi

  jq -r '.ResourceRecordSets[].Name' "${zfile}" | sort > /tmp/aws_records.txt
  grep -Eo 'name\s*=\s*".*"' "${tfvars}" | cut -d'"' -f2 | sort > /tmp/tf_records.txt

  echo -e "${YELLOW}Records present in AWS but missing in Terraform:${RESET}"
  comm -23 /tmp/aws_records.txt /tmp/tf_records.txt || true
  echo
  echo -e "${YELLOW}Records managed in Terraform but missing in AWS:${RESET}"
  comm -13 /tmp/aws_records.txt /tmp/tf_records.txt || true
  pause
}

# User menu.
menu() {
  clear; header
  while true; do
    echo -e "${GREEN}1) Export all record sets${RESET}"
    echo -e "${YELLOW}2) View records for a zone${RESET}"
    echo -e "${PURPLE}3) Compare manual vs automated records${RESET}"
    echo -e "${RED}4) Delete a specific record${RESET}"
    echo -e "${BLUE}5) Exit the script${RESET}"
    echo
    read -rp "$(echo -e "${CYAN}Choose an option: ${RESET}")" opt
    case ${opt} in
      1) export_records ;;
      2) view_records ;;
      3) compare_files ;;
      4) delete_record ;;
      5) echo -e "${GREEN}Exiting...${RESET}"; exit 0 ;;
      *) echo -e "${RED}Invalid choice.${RESET}"; sleep 1 ;;
    esac
    clear; header
  done
}

# Calling function.
menu
