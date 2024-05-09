#!/usr/bin/env bash

# Define function variable.
ANSIBLE_CMD="ansible all -i inventory -u ansible -b -m"

# Creating pause function.
pause() {
  read -p "Press [Enter] key to proceed..." fackEnterKey
}

# Prompt for action.
prompt_cmd_and_grp() {
  read -p "Enter the ad-hoc command: " adhoc_command
  read -p "Enter the host group: " host_group
}

# Show main menu.
menu() {
  clear
  echo "===================="
  echo " M A I N - M E N U"
  echo "===================="
  echo "1. Run Ansible command"
  echo "2. Exit the script"
}

# Show user options.
options() {
  local choice
  read -p "Select choice [1 - 2] " choice
  case ${choice} in
    1) prompt_cmd_and_grp && ${ANSIBLE_CMD} command -a "${adhoc_command}" -e "${host_group}" ;;
    2) exit 0 ;;
    *) echo "Invalid selection..." && sleep 2 ;;
  esac
  pause
}

# Introduce trapping signal.
trap - SIGINT SIGTERM SIGHUP

# Introduce infinite loop.
while true; do
  menu
  options
done
