#!/usr/bin/env bash

# Define function variable.
ANSIBLE_CMD="ansible all -i inventory -u ansible -b -m"

# Creating pause function.
pause() {
  read -p "Press [Enter] key to proceed..." fackEnterKey
}

# Show main menu.
menu() {
  clear
  echo "===================="
  echo " M A I N - M E N U"
  echo "===================="
  echo "1. Ping all hosts"
  echo "2. Run uptime command"
  echo "3. Run df command"
  echo "4. Run free command"
  echo "5. Exit main menu"
}

# Show user options.
options() {
  local choice
  read -p "Select choice [1 - 5] " choice
  case ${choice} in
    1) $ANSIBLE_CMD ping ;;
    2) $ANSIBLE_CMD command -a uptime ;;
    3) $ANSIBLE_CMD command -a df ;;
    4) $ANSIBLE_CMD command -a free ;;
    5) exit 0 ;;
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
