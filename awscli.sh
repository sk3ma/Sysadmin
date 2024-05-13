#!/usr/bin/env bash

# Define function variable.
AWS_CMD="aws"

# Creating pause function.
pause() {
  read -p "Press [Enter] key to proceed..." fackEnterKey
}

# Prompt for AWS profile and region.
command() {
  read -p "Enter AWS profile: " aws_profile
  read -p "Enter AWS region: " aws_region
}

# Show main menu.
menu() {
  clear
  echo "#####################"
  echo "# M A I N - M E N U #"
  echo "#####################"
  echo
  echo "1. Run CLI command"
  echo "2. Exit the script"
  echo
}

# Show user options.
options() {
  local choice
  read -p "Select choice [1 - 2] " choice
  case ${choice} in
    1) command && ${AWS_CMD} ec2 describe-instances --profile ${aws_profile} --region ${aws_region} ;;
    2) exit 0 ;;
    *) echo "Invalid selection..." && sleep 2 ;;
  esac
  pause
}

# Ignore SIGINT signal.
sigterm() {
  echo "Ctrl+C is disabled, execute option 2 to exit."
}

# Introduce trapping signal.
trap sigterm SIGINT

# Introduce infinite loop.
while true; do
  menu
  options
done
