#!/bin/bash
thisscript="x13-me/armbian-config"

BASH_MIN_MAJOR="4" # Minimum MAJOR version of Bash, currently 4
BASH_MIN_MINOR="0" # Minimum MINOR version of Bash, 0 if unneeded

CONFIG_MIN_MAJOR="25" # Minimum version of armbian-config
CONFIG_MIN_MINOR="2"  # Both major AND minor required.

CONFIG_FILE_LOCATIONS=( # REVERSE priority, list is iterated over
    "~/.config"
    "/mnt/.config"
    "/boot/armbianInit.txt"
)

CONFIG_VARS=(
    [hostname]=""
    [locale]=""
    [timezone]=""
    [rootpw]=""
    [rootkey]=""
    [netplan]=""
    [netplandir]=""
    [loadremoteconfig]=""
    [remoteconfigpath]=""
)

printout() { # "str" ["char"]    # Output Fillerchar
    # Prints string but formatted
    # Takes string, optional char
    local fillerchar="#"
    if [ $# -gt 1 ]; then fillerchar="$2"; fi
    while IFS= read -r line; do
        local outchars="$fillerchar$line"
        for ((i = ${#line}; i < 78; i++)); do
            outchars+="$fillerchar"
        done
        echo "$outchars"
    done <<<$1
}

testcallingargs() { # "$#"  # Specialvar
    # Tests args script is called with
    # Takes special $# (number of args), exits on fail
    if [ $1 -ne 0 ]; then
        printout " $0 " ":"
        printout " $thisscript " ":"
        printout " armbian-init is not designed to be called manually! " ":"
        printout " it is called automatically on first boot. " ":"
        printout " it *should* automatically disable itself. " ":"
        exit 64
    fi
    printout "$thisscript called without args, running!"
}

testbashversion() { # "int" "int"   # Major Minor
    # Tests bash version
    # Takes two ints, exits on fail
    # Initialise variables
    local bashver="$(bash --version)" #Assign bash version to string
    # Regular expression
    local regexp='^GNU bash.*version ([0-9]+)\.([0-9]+)\.([0-9]+).*'
    local BASH_VER1="1"
    local BASH_VER2="0"
    if [[ $bashver =~ $regexp ]]; then
        BASH_VER1="${BASH_REMATCH[1]}"
        BASH_VER2="${BASH_REMATCH[2]}"
        if [ $BASH_VER1 -lt $1 ] || [ $BASH_VER1 -eq $1 -a $BASH_VER2 -lt $2 ]; then
            printout "[ERROR] Did not detect a GNU bash version $1.$2 or greater"
            printout "        This error should NOT occur on Armbian, if it does:"
            printout "        * Please open an issue against $thisscript on GitHub."
            printout "        * Include EVERYTHING between these lines."
            printout "          - Incorrectly opened issues will be closed."
            printout "#" "~"
            printout "$thisscript" ":"
            printout "#" ":"
            printout "bash --version" ":"
            printout "$bashver" ":"
            printout "#" "~"
            exit 72
        else
            printout "Bash V$1.$2+ ($BASH_VER1.$BASH_VER2) detected"
        fi
    fi
    return 0
}
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
testarraysupport() { #
    # Tests bash array support
    # Takes nothing, exits on fail
    declare -A foo >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        printout "[ERROR] This version of Bash does not appear to support arrays!"
        printout "        Something is VERY broken"
        printout "        Please fix your /bin/bash"
        exit 71
    else
        printout "Bash supports arrays!"
    fi
    return 0
}

testarmbianconfig() { # "int" "int" # Major Minor
    # Tests armbian config
    # Takes two ints, exits on fail
    configver="$(dpkg-query -W armbian-config)"
    regexp='^armbian-config\s*([0-9]+)\.([0-9]+)\.[0-9]+.*' # Regular expression
    if [[ $configver =~ $regexp ]]; then
        CONFIG_VER1="${BASH_REMATCH[1]}"
        CONFIG_VER2="${BASH_REMATCH[2]}"
        if [[ $CONFIG_VER1 -lt $1 ]]; then echo "1LT1"; fi
        if [[ ($CONFIG_VER1 -lt $1) || (($CONFIG_VER1 -eq $1) && ($CONFIG_VER2 -lt $2)) ]]; then
            printout "[ERROR] armbian-configng version insufficient"
            printout "        You have:"
            printout "        $configver"
            printout "        You need:"
            printout "        $1.$2"
            exit 72
        else
            printout "armbian-config V$CONFIG_VER1.$CONFIG_VER2 detected"
        fi
    fi
    return 0
}

loadremoteconfig() { #
    if [ -f /boot/armbianRemoteInit.cfg ]; then
        remoteconfigpath="$(cat /boot/armbianRemoteInit.cfg)"
        printout "/boot/armbianRemoteInit.cfg exists!"
        printout "it contains:"
        printout "$remoteconfigpath"
        local filepath="/tmp/armbianRemoteInit$(dbus-uuidgen).cfg"
        touch $filepath
        curl -o $filepath $remoteconfigpath
        CONFIG_FILE_LOCATIONS+=("$filepath")
    else
        printout "No remote config provided"
    fi
    printout "Will check:"
    for i in ${CONFIG_FILE_LOCATIONS[@]}; do
        printout "$i"
    done
    return 0
}

handleconfigs() { # "str" # ingest | purge
    for filelocation in ${CONFIG_FILE_LOCATIONS[@]}; do
        printout "filelocation: $filelocation"
        if [[ $1 == "ingest" ]]; then
            while IFS= read -r line; do
                local regexp='^([A-z]+)(?>[\s]*[=:\s][\s]*)["]?([^\n"]+)'
                if [[ $line =~ $regexp ]]; then
                    CONFIG_VARS[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
                    printout "${BASH_REMATCH[1]}"
                    printout "$CONFIG_VARS[${BASH_REMATCH[1]}]"
                fi
            done <<<$filelocation
        elif [[ $1 == "purge" ]]; then
            rm "$filelocation"
        fi
    done
}

get_ip_info() { # Takes no args, returns nothing, stores in $ipinfo[]
    declare -A ipinfo
    ipinfo=(
        [ip]=""
        [hostname]=""
        # [city]=""
        # [region]=""
        [country]=""
        # [loc]=""
        # [org]=""
        # [postal]=""
        [timezone]=""
        # [readme]=""
        # Commented values will NOT be stored
    )
    local ipjson=$(curl -s --connect-timeout 5 -m 10 "https://ipinfo.io/json")
    local count=0
    while [[ -z $ipjson && $count -lt 3 ]]; do
        ipjson=$(curl --connect-timeout 15 -m 30 -s "https://ipinfo.io/json")
        ((count++))
    done
    if [[ -n $ipjson ]]; then
        for i in "${!ipinfo[@]}"; do
            ipinfo[$i]=$(jq -r --arg i $i '.[$i] | select (.!=null)' <<<$ipjson)
            ipjson=""
        done
        return 0
    elif [[ -z $ipjson ]]; then
        printout "\rFailed to get IP info after $count tries!"
        return 1
    fi
}

testcallingargs "$#"
testbashversion "$BASH_MIN_MAJOR" "$BASH_MIN_MINOR" "$BASH_MIN_PATCH"
testarraysupport
testarmbianconfig "$CONFIG_MIN_MAJOR" "$CONFIG_MIN_MINOR"
handleconfigs ingest
