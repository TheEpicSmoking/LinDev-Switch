#!/bin/bash
cd "$(dirname "$0")"

CONFIG_FILE="./config.ini"
# Function to read from config.ini
read_config() { #Check [devices]
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[settings]" > "$CONFIG_FILE"
        echo "frame=true" >> "$CONFIG_FILE"
        echo "colors=true" >> "$CONFIG_FILE"
        echo "" >> "$CONFIG_FILE"
        echo "[devices]" >> "$CONFIG_FILE"
        else
        if ! grep -q "\[devices\]" "$CONFIG_FILE"; then
            echo "" >> "$CONFIG_FILE"
            echo "[devices]" >> "$CONFIG_FILE"
        fi
    fi
    local section=""
    while IFS='=' read -r key value; do #Starts reading
        if [[ $key =~ ^\[.*\]$ ]]; then
            section=$key
        else
            case "$section" in
                "[settings]")
                    case "$key" in
                        "frame") frame="$value" ;;
                        "colors") colors="$value" ;;
                    esac
                    ;;
                "[devices]")
                    local device_id=$(xinput list --id-only "${value//\"/}")
                    device_names+=("$key")
                    device_ids+=("$device_id")
                    device_rnames+=("${value//\"/}")
                    ;;
            esac
        fi
    done < $CONFIG_FILE
}

# Variables
device_rnames=()
device_names=()
device_ids=()
frame=false
colors=false
lines=9
current_page=1
items_per_page=9
selected_device_index=-1

# Read the config.ini
read_config


# Adjust window
if $frame; then
    offset=1
else
    offset=0
fi
total_pages=$(( (${#device_names[@]} + $items_per_page - 1) / $items_per_page ))
echo -ne "\033]0;LinDev-Switch\007"
window(){
    columns=$(tput cols)
    max_name_length=$((columns - 15))
    lines=$(( ${#device_names[@]} + 3 ))
    [[ $frame == true ]] && lines=$((lines + 2))
    (( lines <= 4 )) && lines=5
    (( columns <= 15 )) && columns=16
}
window

# ANSI Escape Sequences for colors
ESC=$(echo -e "\033")
if [[ $colors == true ]]; then
    GREEN="${ESC}[32m"
    GRAY="${ESC}[90m"
    RESET="${ESC}[0m"
    RED="${ESC}[31m"
    YELLOW="${ESC}[33m"
else
    GREEN=""
    GRAY=""
    RESET=""
    RED=""
    YELLOW=""
fi

get_device_status() {
    local device_id=$1
    local enabled=$(xinput list-props "$device_id" | grep "Device Enabled" | grep -o "[01]$")
    if [[ $enabled == 1 ]]; then
        echo "Enabled"
    else
        echo "Disabled"
    fi
}

#Print the entire GUI
initial_display() {
    clear
    if [[ $frame == true ]]; then
        titleline
    fi
    display_page
    tput cup $(($offset+${#device_names[@]}+1)) 0
    if [[ $frame == true ]]; then
        bottomline
    fi
    if (($total_pages > 1)); then
        local text="[←/→ Browse pages]"
    fi
    echo -e "\n$text[↑/↓ Select Device][w Toggle][h Help]"
}

#cleaner for multipage mess
page_clear()
{
    local line=""
    if [[ $repeat != 0 ]]; then
        for (( i = 0; i < $repeat; i++ )); do
            for (( j = 0; j < columns; j++ )); do
            line+=" "
            done
            echo -e "$line"
        done
    fi
}

#Print the page
display_page() {
    local start_index=$(( (current_page - 1) * items_per_page ))
    repeat=0
    local end_index=$(( start_index + items_per_page - 1 ))
    end_index=$(( end_index < ${#device_names[@]} ? end_index : ${#device_names[@]} - 1 ))
    for i in $(seq $start_index $end_index); do
        local name="${device_names[$i]}"
        [[ ${#name} -gt $max_name_length ]] && name="${name:0:max_name_length}"
        local status=$(get_device_status "${device_ids[$i]}")
        local display_number=$((i - start_index + 1))
        if [[ $i -eq $selected_device_index ]]; then
            local selection="${YELLOW}"
        else
            local selection=" "
        fi
        if [[ $i -eq $end_index ]] && [[ $current_page -eq $total_pages ]] && [[ $total_pages > 1 ]]; then
            local repeat=$((items_per_page - display_number))

        fi
        if [[ $status == "Enabled" ]]; then
            tput cup $(($offset+$display_number)) 0
            echo -e "$selection$display_number. $name:${RESET} ${GREEN}$status${RESET}                                      "
            page_clear
        else
            tput cup $(($offset+$display_number)) 0 
            echo -e "$selection$display_number. $name:${RESET} ${RED}$status${RESET}                                        "
            page_clear
        fi
    done
    if (($total_pages > 1)); then
        tput cup $(($offset+$items_per_page+1)) 0
        echo -e "\n${YELLOW}Page $current_page of $total_pages${RESET}"
        if [[ $repeat != 0 ]] && [[ $frame == true ]]; then
            tput cup $(($offset+$items_per_page+3)) 0
            bottomline
        fi
    fi
}

update_device_status() {
    local index=$1
    local name="${device_names[$index]}"
    [[ ${#name} -gt $max_name_length ]] && name="${name:0:max_name_length}"
    local status=$(get_device_status "${device_ids[$index]}")
    local row=$((index % items_per_page + 1))
    [[ $frame == true ]] && row=$((row + 1))
    tput cup $((row)) 0
    local display_number=$((index % items_per_page + 1))
    if [[ $index -eq $selected_device_index ]]; then
        echo -n "${YELLOW}"
    else
        echo -n " "
    fi
    if [[ $status == "Enabled" ]]; then
        echo -ne "$display_number. $name: ${GREEN}$status${RESET}   "
    else
        echo -ne "$display_number. $name: ${RED}$status${RESET}   "
    fi
}

# Frame TOP
titleline() {
    local line=""
    local TitleSpacer=$((columns - 15))
    local mod=$((columns % 2))
    local hcolumns=$((TitleSpacer / 2))
    local TitleText=" LinDev  Switch "
    (( mod != 0 )) && TitleText="= LinDev Switch "
    for (( i = 0; i < TitleSpacer; i++ )); do
        if (( i == hcolumns )); then
            line+="$TitleText"
        else
            line+="="
        fi
    done
    echo -e "$line\n"
}

# Frame BOT
bottomline() {
    local line="\n"
    for (( i = 0; i < columns; i++ )); do
        line+="="
    done
    echo -e "$line"
}

# Function to enable all devices
enableAllDevices() {
    for device_name in "${device_ids[@]}"; do
        local device_id=$(xinput list --id-only "$device_name")
        xinput enable "$device_id"
    done
}

# Function to disable all devices
disableAllDevices() {
    for device_name in "${device_ids[@]}"; do
        local device_id=$(xinput list --id-only "$device_name")
        xinput disable "$device_id"
    done
}

# Help
helper() {
    clear
    if [[ $frame == true ]]; then
        titleline
    fi
    echo -e "[1-9]  ${YELLOW}|${RESET} Toggle Device."
    echo -e "←/→    ${YELLOW}|${RESET} Previous/Next Page."
    echo -e "↑/↓    ${YELLOW}|${RESET} Navigate Devices."
    echo -e "w      ${YELLOW}|${RESET} Toggle Selected Device."
    echo -e "e      ${YELLOW}|${RESET} Enable all Devices."
    echo -e "d      ${YELLOW}|${RESET} Disable all Devices."
    echo -e "a      ${YELLOW}|${RESET} Add a Device."
    echo -e "s      ${YELLOW}|${RESET} Remove a Device."
    echo -e "r      ${YELLOW}|${RESET} Refresh."
    echo -e "q      ${YELLOW}|${RESET} Quit."
    if [[ $frame == true ]]; then
        bottomline
    fi
    echo -e "\nPress a button to return..."
    stty -echo
    read -rsn 1 x
    if [[ $x == $'\x1b' ]]; then
        read -sn 2
    fi
    initial_display
}

add_device() {
    local devices_list
    devices_list=$(xinput list --name-only)
    local devices=()
    local index=0
    local existing_devices=("${device_rnames[@]}")

    while IFS= read -r device; do
        devices+=("$device")
    done <<< "$devices_list"

    local selected_index=$1

    while true; do
        clear
        if [[ $frame == true ]]; then
            titleline
        fi
        echo "Add a device:"
        for i in "${!devices[@]}"; do
            if [[ "${devices[i]}" == "∼ "* ]]; then
                devices[i]="${devices[i]:2}"
            fi
            if [[ " ${existing_devices[@]} " =~ " ${devices[i]} " ]]; then
                if [[ $i -eq $selected_index ]]; then
                    ((selected_index++))
                fi
                for j in ${!existing_devices[@]}; do
                    if [[ " ${existing_devices[j]} " =~ " ${devices[i]} " ]];  then
                        echo "${GRAY}  ${devices[i]} (${device_names[j]})${RESET}"
                    fi
                done
                
            else
                if [[ $i -eq $selected_index ]]; then
                    echo " ${YELLOW}${devices[i]}${RESET}"
                else
                    echo "  ${devices[i]}"
                fi
            fi
        done
        if [[ $frame == true ]]; then
            bottomline
        fi
        echo -e "\n[← Back][↑/↓ Navigate][→ Select]\n"
        


        read -rsn1 key
        case "$key" in
            $'\x1B') read -rsn2 key
                if [[ $key == "[A" ]]; then # Up
                    ((selected_index--))
                    while [[ $selected_index -lt 0 ]] || [[ " ${existing_devices[@]} " =~ " ${devices[selected_index]} " ]]; do
                        ((selected_index--))
                        if [[ $selected_index -lt 0 ]]; then
                            selected_index=$(( ${#devices[@]} - 1 ))
                        fi
                    done
                elif [[ $key == "[B" ]]; then # Down
                    ((selected_index++))
                    while [[ $selected_index -ge ${#devices[@]} ]] || [[ " ${existing_devices[@]} " =~ " ${devices[selected_index]} " ]]; do
                        ((selected_index++))
                        if [[ $selected_index -ge ${#devices[@]} ]]; then
                            selected_index=0
                        fi
                    done
                elif [[ $key == "[D" ]]; then # Left
                    exec "$0"
                elif [[ $key == "[C" ]]; then # Right
                    break
                fi
                ;;
            'r') exec "$0" ;;
            'q') exit ;;
        esac
    done

    local selected_device="${devices[selected_index]}"
    tput cup $((${#devices[@]} + 5)) 0
    local text="\nEnter a name for $selected_device:"
    echo -e "$text                                  "
    tput cup $((${#devices[@]} + 7)) 0
    echo -e "\n[← Back][→ Confirm]"
    local device_name=""
    local x=0
    while true; do
        read -rsn1 char
        case "$char" in
            $'\x1B') read -rsn2 key
                if [[ $key == "[D" ]]; then # Left
                    add_device $selected_index
                    return
                elif [[ $key == "[C" ]]; then # Right
                    break
                fi
                ;;
            $'\x7F') device_name="${device_name%?}" # Backspace
                tput cup $((${#devices[@]} + 5)) 0
                echo -e "$text $device_name "
                ;; 
            *) device_name+="$char" 
                tput cup $((${#devices[@]} + 5)) 0
                echo -e "$text $device_name"
            ;;
        esac
    done
    echo "$device_name=\"$selected_device\"" >> $CONFIG_FILE
    exec "$0"
}

remove_device() {
    local selected_index=0

    while true; do
        clear
        if [[ $frame == true ]]; then
            titleline
        fi
        echo "Remove a device:"
        for i in "${!device_names[@]}"; do
            if [[ $i -eq $selected_index ]]; then
                echo " ${YELLOW}${device_names[i]}${RESET}"
            else
                echo "  ${device_names[i]}"
            fi
        done
        if [[ $frame == true ]]; then
            bottomline
        fi
        echo -e "\n[← Back][↑/↓ Navigate][→ Select]\n"
        read -rsn1 key
            case "$key" in
            $'\x1B') read -rsn2 key
                 if [[ $key == "[A" ]]; then # Up
                    ((selected_index--))
                    if [[ $selected_index -lt 0 ]]; then
                        selected_index=$(( ${#device_names[@]} - 1 ))
                    fi
                elif [[ $key == "[B" ]]; then # Down
                    ((selected_index++))
                    if [[ $selected_index -ge ${#device_names[@]} ]]; then
                        selected_index=0
                    fi
                elif [[ $key == "[D" ]]; then # Left
                    exec "$0"
                elif [[ $key == "[C" ]]; then # Right
                    break
                fi
                ;;
            'r') exec "$0" ;;
            'q') exit ;;


            
        esac
    done

    local selected_device="${device_names[selected_index]}"
    sed -i "/^\[$selected_device\]/d" $CONFIG_FILE
    sed -i "/^$selected_device=/d" $CONFIG_FILE
    exec "$0"
}

#Signal handlers
handle_sigwinch() {
    window
    initial_display
}

handle_exit() {
    tput cnorm
}

# Main menu loop
tput civis
if [[ ${#device_names[@]} < 1 ]]; then
    add_device 0
fi
initial_display
while true; do
    trap handle_sigwinch WINCH
    trap handle_exit EXIT
    tput cup $((lines))
    stty -echo
    read -sn 1 choice
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= items_per_page )); then
        index=$(( (current_page - 1) * items_per_page + choice - 1 ))
        if [[ $index -lt ${#device_names[@]} ]]; then
            device_id="${device_ids[$index]}"
            enabled=$(get_device_status "$device_id")
            if [[ $enabled == "Enabled" ]]; then
                xinput disable "$device_id"
            else
                xinput enable "$device_id"
            fi
            update_device_status $index
        fi
    elif [[ $choice == "e" ]]; then
        enableAllDevices
        for i in "${!device_names[@]}"; do
            update_device_status $i
        done
    elif [[ $choice == "d" ]]; then
        disableAllDevices
        for i in "${!device_names[@]}"; do
            update_device_status $i
        done
    elif [[ $choice == "h" ]]; then
        helper
    elif [[ $choice == "a" ]]; then
        add_device 0
    elif [[ $choice == "s" ]]; then
        remove_device
    elif [[ $choice == "r" ]]; then
        exec "$0" 
    elif [[ $choice == "q" ]]; then
        exit 0
    elif [[ $choice == $'\x1b' ]]; then
        read -sn 2 arrow 
        if [[ $arrow == "[A" ]]; then  # Up
            if [[ $selected_device_index -eq -1 ]]; then
                selected_device_index=$(( (${#device_names[@]} + $items_per_page - 1) % $items_per_page ))
            else
                ((selected_device_index--))
                if [[ $selected_device_index -lt 0 ]]; then
                    selected_device_index=$(( ${#device_names[@]} - 1 ))
                fi
            fi
            display_page
        elif [[ $arrow == "[B" ]]; then  # Down
            if [[ $selected_device_index -eq -1 ]]; then
                selected_device_index=0
            else
                ((selected_device_index++))
                if [[ $selected_device_index -ge ${#device_names[@]} ]]; then
                    selected_device_index=0
                fi
            fi
            display_page
        elif [[ $arrow == "[D" ]] && (( current_page > 1 )); then  # Left
            (( current_page > 1 )) && (( current_page-- ))
            display_page
        elif [[ $arrow == "[C" ]] && (( current_page < total_pages )); then  # Right
            (( current_page < total_pages )) && (( current_page++ ))
            display_page
        fi
    elif [[ $choice == "w" ]]; then
        if [[ $selected_device_index -ge 0 ]]; then
            index=$(( (current_page - 1) * items_per_page + selected_device_index ))
            if [[ $index -lt ${#device_names[@]} ]]; then
                device_id="${device_ids[$index]}"
                enabled=$(get_device_status "$device_id")
                if [[ $enabled == "Enabled" ]]; then
                    xinput disable "$device_id"
                else
                    xinput enable "$device_id"
                fi
                update_device_status $index
            fi
        fi
    else
        echo -e "${RED}Invalid Choice.${RESET} Type '${YELLOW}h${RESET}' for help."
    fi
done