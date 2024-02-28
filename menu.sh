#!/bin/bash

show_menu() {
    echo "======================"
    echo "      MAIN MENU       "
    echo "======================"
}

display_menu() {
    echo "Choose an option:"
    echo
    echo "1. System Load"
    echo "2. Disk Usage"
    echo "3. Memory Usage"
    echo "4. Swap Usage"
    echo "5. Running Processes"
    echo "6. Users Logged In"
    echo "7. IP Address"
}

execute_command() {
    case $1 in
        1)
            uptime
            ;;
        2)
            df -h /
            ;;
        3)
            free -m
            ;;
        4)
            swapon --show
            ;;
        5)
            ps aux | wc -l
            ;;
        6)
            who | wc -l
            ;;
        7)
            hostname -I
            ;;
        *)
            echo "Invalid choice. Please enter a valid number."
            ;;
    esac
}

trap 'echo "Exiting..."; exit 1' INT

while true; do
    show_menu
    display_menu
    read -p "Enter your choice (or 'q' to quit): " choice

    if [[ "$choice" == "q" ]]; then
        echo "Exiting..."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[1-7]$ ]]; then
        echo "Invalid choice. Please enter a valid number."
        continue
    fi

    execute_command "$choice"
done
