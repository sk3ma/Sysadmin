#!/usr/bin/env bash

# Define color variables.
GREEN="\033[0;32m"
RED="\033[0;31m"
NORMAL="\033[0m"
YELLOW="\033[0;33m"

# Define script variables.
users_to_remove=("osadmin" "jpublic" "ranybody")
users_to_keep=("cadel" "ktrap")
groups_to_remove=("osadmin" "jpublic" "ranybody")

# Sanity checking.
if [[ "${EUID}" -ne "0" ]]; then
    echo
    echo "███████╗██████╗ ██████╗  ██████╗ ██████╗ "
    echo "██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔══██╗"
    echo "█████╗  ██████╔╝██████╔╝██║   ██║██████╔╝"
    echo "██╔══╝  ██╔══██╗██╔══██╗██║   ██║██╔══██╗"
    echo "███████╗██║  ██║██║  ██║╚██████╔╝██║  ██║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
    echo
    echo -e "${RED}[🔴] You must be root, exiting.${NORMAL}"
    exit 1
fi

# Remove unwanted users.
for user in "${users_to_remove[@]}"; do
  if id "${user}" &>/dev/null; then
    echo -e "${NORMAL}Removing user: ${user}${NORMAL}"
    userdel -r "${user}" && echo -e "${GREEN}User ${user} removed successfully.${NORMAL}" || echo -e "${RED}Failed to remove user ${user}.${NORMAL}"
  else
    echo -e "${RED}User ${user} not found, skipping...${NORMAL}"
  fi
done

# Remove unwanted groups.
for group in "${groups_to_remove[@]}"; do
  if getent group "${group}" &>/dev/null; then
    echo -e "${GREEN}Removing group: ${group}${NORMAL}"
    groupdel "${group}" && echo -e "${GREEN}Group ${group} removed successfully.${NORMAL}" || echo -e "${RED}Failed to remove group ${group}.${NORMAL}"
  else
    echo -e "${RED}Group ${group} not found, skipping...${NORMAL}"
  fi
done

# Keep wanted users.
for user in "${users_to_keep[@]}"; do
  if ! id "${user}" &>/dev/null; then
    echo -e "${GREEN}Creating user: ${user}${NORMAL}"
    useradd -ms /bin/bash "${user}" && echo -e "${GREEN}User ${user} created successfully.${NORMAL}" || echo -e "${RED}Failed to create user ${user}.${NORMAL}"
  else
    echo -e "${YELLOW}User ${user} already exists, skipping...${NORMAL}"
  fi
done

# Quit root session.
if [[ ${-} == *i* ]]; then
    echo -e "${YELLOW}Logging out from root session...${NORMAL}"
    exit 0
fi
