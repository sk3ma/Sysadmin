#!/usr/bin/env bash

####################################################
# Bash script to lint Ansible playbooks and roles. #
# Runs `ansible-lint` only if `yamllint` passes.   #
####################################################

# Define colour variables.
GREEN="\033[32m"
NORMAL="\033[0m"

# Ubuntu Linu function.
install_ubuntu() {
    sudo apt update
    sudo apt install  yamllint ansible-lint -y
}

# Rocky Linux function.
install_rocky() {
    sudo dnf install yamllint ansible-lint-y
}

# Confirm Linux distribution.
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=${NAME}
else
    echo -e "\e[31;1;3;5m[❌] Unsupported OS, exiting.\e[m"
    exit 1
fi

# Check yamllint presence.
if ! command -v yamllint &> /dev/null; then
    echo -e "\e[36;1;3m[INFO] yamllint not installed, install it? (y/n).\e[m"
    read -r install_choice
    if [ "${install_choice}" == "y" ]; then
        if [[ "${OS_NAME}" == "Ubuntu" || "${OS_NAME}" == "Debian" ]]; then
            install_ubuntu
        elif [[ "${OS_NAME}" == "Rocky Linux" || "${OS_NAME}" == "CentOS" || "${OS_NAME}" == "Fedora" ]]; then
            install_rocky
        else
            echo -e "\e[31;1;3m[❌] Unsupported OS for installation, exiting.\e[m"
            exit 1
        fi
        if [ ${?} -ne 0 ]; then
            echo -e "\e[31;1;3m[❌] Failed to install yamllint, exiting.\e[m"
            exit 1
        fi
    else
        echo -e "\e[33;1;3;5m[INFO] yamllint is required, exiting.\e[m"
        exit 1
    fi
fi

# Check ansible-lint presence.
if ! command -v ansible-lint &> /dev/null; then
    echo -e "\e[36;1;3m[INFO] ansible-lint not installed, install it? (y/n).\e[m"
    read -r install_choice
    if [ "${install_choice}" == "y" ]; then
        if [[ "${OS_NAME}" == "Ubuntu" || "${OS_NAME}" == "Debian" ]]; then
            install_ubuntu
        elif [[ "${OS_NAME}" == "Rocky Linux" || "${OS_NAME}" == "CentOS" || "${OS_NAME}" == "Fedora" ]]; then
            install_rocky
        else
            echo -e "\e[31;1;3m[❌] Unsupported OS for installation, exiting.\e[m"
            exit 1
        fi
        if [ ${?} -ne 0 ]; then
            echo -e "\e[31;1;3m[❌] Failed to install ansible-lint, exiting.\e[m"
            exit 1
        fi
    else
        echo -e "\e[33;1;3;5m[INFO] ansible-lint is required, exiting.\e[m"
        exit 1
    fi
fi

# Specify working directory.
echo -e "\e[38;5;208;1;3;5m[OK] Starting functional testing...\e[m"
echo -e "${GREEN}"
cat << "STOP"
    ___               _ __    __        __    _       __           
   /   |  ____  _____(_) /_  / /__     / /   (_)___  / /____  _____
  / /| | / __ \/ ___/ / __ \/ / _ \   / /   / / __ \/ __/ _ \/ ___/
 / ___ |/ / / (__  ) / /_/ / /  __/  / /___/ / / / / /_/  __/ /    
/_/  |_/_/ /_/____/_/_.___/_/\___/  /_____/_/_/ /_/\__/\___/_/     
                                                                        
STOP
echo -e "${NORMAL}"
echo -e "\e[33;1;3m[INFO] Enter the Ansible directory:\e[m" # The directory in question.
read -r working_dir

# Check directory existence.
if [[ ! -d "${working_dir}" ]]; then
    echo -e "\e[31;1;3;5m[❌] Directory ${working_dir} doesn't exist, exiting.\e[m"
    exit 1
fi

# Specify Ansible playbook.
echo -e "\e[33;1;3m[INFO] Enter the Ansible playbook:\e[m" # The playbook or role.
read -r yaml_file

# Full playbook path.
file_path="${working_dir}/${yaml_file}"

# Check Ansible existence.
if [[ ! -f "${file_path}" ]]; then
    echo -e "\e[31;1;3;5m[❌] File ${file_path} doesn't exist, exiting.\e[m"
    exit 1
fi

# Run YAML linter.
echo -e "\e[35;1;3m[INFO] Running yamllint on ${file_path}...\e[m"
yamllint "${file_path}"

# Check for success.
if [ ${?} -eq 0 ]; then
    echo -e "\e[32;1;3;5m[✅] yamllint completed successfully.\e[m"
    echo
    
    # Execute ansible-lint binary.
    echo -e "\e[35;1;3m[INFO] Running ansible-lint on ${file_path}...\e[m"
    ansible-lint "${file_path}"

    # Check for success.
    if [ ${?} -eq 0 ]; then
        echo -e "\e[32;1;3;5m[✅] ansible-lint completed successfully.\e[m"
    else
        echo -e "\e[31;1;3;5m[❌] ansible-lint encountered errors, exiting.\e[m"
    fi
else
    echo -e "\e[31;1;3;5m[❌] yamllint encountered errors, exiting.\e[m"
fi

exit 0
