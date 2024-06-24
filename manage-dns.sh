#!/bin/bash

# Variables
VERBOSE=false
DEBUG=false
LOGFILE="dns_management.log"
LOCKFILE="./manage-dns.lock"
BACKUP_DIR="./backups"
CORE_FILE="/etc/coredns/Corefile"
TIMEOUT=30
USE_SUDO=""
BACKUP=false
RESTART=false
OUTPUT_JSON=false
JQ_QUERY="."
JQ_OPTS=""

# Early parsing of debug flag
for arg in "$@"; do
  case $arg in
    --debug)
      DEBUG=true
      set -x
      ;;
  esac
done

# Functions
log() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
    echo "$(date): $1" >> "$LOGFILE"
}

error_log() {
    echo "$(date): ERROR: $1" >> "$LOGFILE"
}

usage() {
    echo "Usage: $0 --domain DOMAIN --action [actions] [options]"
    echo "Actions:"
    echo "  create --type TYPE --name NAME --value VALUE"
    echo "  new --type TYPE --name NAME --value VALUE"
    echo "  add --type TYPE --name NAME --value VALUE (alias for new)"
    echo "  replace --type TYPE --name NAME --value VALUE"
    echo "  list [--type TYPE]"
    echo "  list-all"
    echo "  remove --type TYPE --name NAME [--timeout SECONDS]"
    echo "  update-forward --forward FORWARD"
    echo "Options:"
    echo "  --verbose                 Enable verbose mode"
    echo "  --debug                   Enable debug mode"
    echo "  --sudo                    Use sudo for file operations"
    echo "  --corefile PATH           Path to the Corefile"
    echo "  --logfile PATH            Path to the log file"
    echo "  --lockfile PATH           Path to the lockfile"
    echo "  --backup                  Enable backup of Corefile"
    echo "  --backups PATH            Path to the backups directory"
    echo "  --restart                 Prevent restarting CoreDNS"
    echo "  --json                    Output in JSON format"
    echo "  --jq QUERY                Process JSON output with jq"
    echo "  --jq-opts OPTIONS         Options to pass to jq"
    echo "Examples:"
    echo "  $0 --action list-all"
    echo "  $0 --domain domain.com --action list"
    echo "  $0 --domain domain.com --action list --type A"
    echo "  $0 --domain domain.com --action create --type A --name www --value 10.10.10.10"
    echo "  $0 --domain domain.com --action new --type CNAME --name git --value github.com"
    echo "  $0 --domain domain.com --action add --type A --name www --value 10.10.10.11"
    echo "  $0 --domain domain.com --action replace --type A --name www --value 10.10.10.12"
    echo "  $0 --domain domain.com --action remove --type A --name www"
    echo "  $0 --domain all --action update-forward --forward \"192.168.128.1 10.0.0.1\""
    exit 1
}

pad() {
    local str="$1"
    local length="$2"
    printf "%-${length}s" "$str"
}

repeat() {
  local char=$1
  local count=$2
  printf "%${count}s" | tr ' ' "$char"
}

backup_corefile() {
    if ! $BACKUP; then
        log "No backup created."
        return
    fi
    local timestamp=$(date -u +"%Y_%m_%d_%H_%M_%S")
    local backup_file="${BACKUP_DIR}/Corefile_${timestamp}.bak"
    if $USE_SUDO cp "$CORE_FILE" "$backup_file"; then
        log "Backup of Corefile created at $backup_file"
    else
        error_log "Failed to create backup of Corefile"
        exit 1
    fi
}

create_lockfile() {
    if [ -f "$LOCKFILE" ]; then
        error_log "Lockfile exists. Another instance of the script is running."
        exit 1
    fi
    $USE_SUDO touch "$LOCKFILE"
}

remove_lockfile() {
    if [ -f "$LOCKFILE" ]; then
        $USE_SUDO rm "$LOCKFILE"
    fi
}

restart_coredns() {
    if ! $RESTART; then
        log "Not restarting CoreDNS service"
        return
    fi
    log "Restarting CoreDNS service"
    if $USE_SUDO systemctl restart coredns.service; then
        log "CoreDNS service restarted successfully"
    else
        error_log "Failed to restart CoreDNS service"
        exit 1
    fi
}

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

confirm_action() {
    local prompt="$1"
    local timeout=${2:-$TIMEOUT}
    read -t $timeout -p "$prompt (yYtT1 to confirm): " response
    if [[ "$response" =~ ^[yYtT1]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Parse flags
while [[ "$1" != "" ]]; do
    case $1 in
        --domain) shift; DOMAIN=$1 ;;
        --action) shift; ACTION=$1 ;;
        --type) shift; TYPE=$1 ;;
        --name) shift; NAME=$1 ;;
        --value) shift; VALUE=$1 ;;
        --forward) shift; VALUE=$1 ;;
        --verbose) VERBOSE=true ;;
        --debug) ;; # Handled earlier
        --timeout) shift; TIMEOUT=$1 ;;
        --sudo) USE_SUDO="sudo" ;;
        --corefile) shift; CORE_FILE=$1 ;;
        --lockfile) shift; LOCKFILE=$1 ;;
        --logfile) shift; LOGFILE=$1 ;;
        --backups) shift; BACKUP_DIR=$1 ;;
        --backup) BACKUP=true ;;
        --restart) RESTART=true ;;
        --json) OUTPUT_JSON=true ;;
        --jq) shift; JQ_QUERY=$1 ;;
        --jq-opts) shift; JQ_OPTS=$1 ;;
        *) usage ;;
    esac
    shift
done

if $BACKUP; then
    $USE_SUDO mkdir -p "${BACKUP_DIR}"
fi

# Ensure the domain and IP are valid if needed
if [[ "${DOMAIN}" != "all" ]] && ! validate_domain "$DOMAIN"; then
    error_log "Invalid domain: $DOMAIN"
    exit 1
fi

# Validate input
if [ -z "$ACTION" ]; then
    usage
fi

if [ "$ACTION" != "list" ] && [ "$ACTION" != "list-all" ] && [ "$ACTION" != "remove" ]; then
    if [ "$TYPE" == "A" ] || [ "$TYPE" == "AAAA" ]; then
        if ! validate_ip "$VALUE"; then
            error_log "Invalid IP address: $VALUE"
            exit 1
        fi
    fi
fi

# Function to handle DNS actions
manage_dns() {
    if [ ! -f "$CORE_FILE" ]; then
        error_log "Corefile does not exist at $CORE_FILE"
        exit 1
    fi

    if ! [ -w "$CORE_FILE" ]; then
        error_log "Corefile is not writable"
        exit 1
    fi

    case $ACTION in
        create | new | add | replace | remove)
            # Backup Corefile
            backup_corefile
            ;;
    esac

    case $ACTION in
        create)
            log "Creating root domain $DOMAIN with $TYPE record for $NAME pointing to $VALUE"
            # Check if domain already exists
            if grep -q "$DOMAIN {" "$CORE_FILE"; then
                # Domain exists, add record within the block
                $USE_SUDO sed -i "/$DOMAIN {/,/}/ s/}/    $TYPE $NAME $VALUE\n}/" "$CORE_FILE"
            else
                # Domain does not exist, create a new block
                $USE_SUDO bash -c "echo \"$DOMAIN {\" >> \"$CORE_FILE\""
                $USE_SUDO bash -c "echo \"    log\" >> \"$CORE_FILE\""
                $USE_SUDO bash -c "echo \"    errors\" >> \"$CORE_FILE\""
                $USE_SUDO bash -c "echo \"    forward . 8.8.8.8 8.8.4.4\" >> \"$CORE_FILE\""
                $USE_SUDO bash -c "echo \"    $TYPE $NAME $VALUE\" >> \"$CORE_FILE\""
                $USE_SUDO bash -c "echo \"}\" >> \"$CORE_FILE\""
            fi
            log "Successfully created domain $DOMAIN with $TYPE record $NAME pointing to $VALUE"
            ;;
        new | add)
            log "Adding new $TYPE record in $DOMAIN: $NAME pointing to $VALUE"
            # Add the new DNS entry
            if grep -q "$DOMAIN {" "$CORE_FILE"; then
                # Domain exists, add new record
                if grep -q "$DOMAIN {/,/}/ s/    $TYPE $NAME $VALUE" "$CORE_FILE"; then
                    log "Record already exists, skipping add"
                else
                    $USE_SUDO sed -i "/$DOMAIN {/,/}/ s/}/    $TYPE $NAME $VALUE\n}/" "$CORE_FILE"
                    log "Successfully added $TYPE record $NAME pointing to $VALUE in domain $DOMAIN"
                fi
            else
                # Domain does not exist, log error
                error_log "Domain $DOMAIN does not exist in Corefile"
                exit 1
            fi
            ;;
        replace)
            log "Replacing $TYPE record in $DOMAIN: $NAME pointing to $VALUE"
            # Replace the DNS entry
            if grep -q "$DOMAIN {" "$CORE_FILE"; then
                # Domain exists, replace record
                if grep -q "    $TYPE $NAME" "$CORE_FILE"; then
                    $USE_SUDO sed -i "/$DOMAIN {/,/}/ s/    $TYPE $NAME .*/    $TYPE $NAME $VALUE/" "$CORE_FILE"
                    log "Successfully replaced $TYPE record $NAME pointing to $VALUE in domain $DOMAIN"
                else
                    error_log "Record $NAME does not exist in domain $DOMAIN"
                    exit 1
                fi
            else
                # Domain does not exist, log error
                error_log "Domain $DOMAIN does not exist in Corefile"
                exit 1
            fi
            ;;
        list)
            log "Listing records for $DOMAIN"
            local records
            records=$(grep -A 100 "$DOMAIN {" "$CORE_FILE" | awk '/}/ {exit} {print}' | grep -E "^\s+[A-Z]+")
            if [ -n "$TYPE" ]; then
                records=$(echo "$records" | grep -E "^\s+$TYPE\s")
            fi
            if [ -z "$records" ]; then
                echo "No records found for domain $DOMAIN."
            else
                if $OUTPUT_JSON; then
                    local json_records=()
                    while read -r line; do
                        local record_type=$(echo "$line" | awk '{print $1}')
                        local record_name=$(echo "$line" | awk '{print $2}')
                        local record_value=$(echo "$line" | awk '{print $3}')
                        json_records+=("{\"$record_name\":\"$record_value\"}")
                    done <<< "$records"
                    echo "{\"domain\":\"$DOMAIN\",\"records\":{\"$TYPE\":[${json_records[*]}]}}"
                else
                    local types=()
                    local names=()
                    local values=()
                    while read -r line; do
                        types+=("$(echo "$line" | awk '{print $1}')")
                        names+=("$(echo "$line" | awk '{print $2}')")
                        values+=("$(echo "$line" | awk '{print $3}')")
                    done <<< "$records"
                    local max_type_len=4
                    local max_name_len=4
                    local max_value_len=5
                    for i in "${!types[@]}"; do
                        [ ${#types[i]} -gt $max_type_len ] && max_type_len=${#types[i]}
                        [ ${#names[i]} -gt $max_name_len ] && max_name_len=${#names[i]}
                        [ ${#values[i]} -gt $max_value_len ] && max_value_len=${#values[i]}
                    done
                    echo "DOMAIN: $DOMAIN"
                    echo "| $(pad "Type" $max_type_len) | $(pad "Name" $max_name_len) | $(pad "Value" $max_value_len) |"
                    echo "| $(repeat "-" $max_type_len) | $(repeat "-" $max_name_len) | $(repeat "-" $max_value_len) |"
                    for i in "${!types[@]}"; do
                        echo "| $(pad "${types[i]}" $max_type_len) | $(pad "${names[i]}" $max_name_len) | $(pad "${values[i]}" $max_value_len) |"
                    done
                fi
            fi
            ;;
        list-all)
            log "Listing all domains"
            local domains
            domains=$(grep -oP '^[a-zA-Z0-9.-]+ {' "$CORE_FILE" | awk '{print $1}')
            if $OUTPUT_JSON; then
                local json_output="["
                local first=true
                for domain in $domains; do
                    if [ "$first" = false ]; then
                        json_output+=","
                    else
                        first=false
                    fi
                    local records
                    records=$(grep -A 100 "$domain {" "$CORE_FILE" | awk '/}/ {exit} {print}' | grep -E "^\s+[A-Z]+")
                    if [ -z "$records" ]; then
                        continue
                    else
                        local types=()
                        local names=()
                        local values=()
                        while read -r line; do
                            types+=("$(echo "$line" | awk '{print $1}')")
                            names+=("$(echo "$line" | awk '{print $2}')")
                            values+=("$(echo "$line" | awk '{print $3}')")
                        done <<< "$records"
                        local domain_json="{\"domain\":\"$domain\",\"records\":{"
                        local record_types=($(echo "${types[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
                        for record_type in "${record_types[@]}"; do
                            domain_json+="\"$record_type\":["
                            local first_record=true
                            for i in "${!types[@]}"; do
                                if [ "${types[i]}" == "$record_type" ]; then
                                    if [ "$first_record" = false ]; then
                                        domain_json+=","
                                    else
                                        first_record=false
                                    fi
                                    domain_json+="{\"${names[i]}\":\"${values[i]}\"}"
                                fi
                            done
                            domain_json+="],"
                        done
                        domain_json="${domain_json%,}}"
                        json_output+="$domain_json"
                    fi
                done
                json_output+="]"
                if [ -n "$JQ_QUERY" ] && command -v jq &>/dev/null; then
                    echo "$json_output" | jq $JQ_OPTS "$JQ_QUERY"
                else
                    echo "$json_output"
                fi
            else
                for domain in $domains; do
                    local records
                    records=$(grep -A 100 "$domain {" "$CORE_FILE" | awk '/}/ {exit} {print}' | grep -E "^\s+[A-Z]+")
                    if [ -z "$records" ]; then
                        continue
                    else
                        local types=()
                        local names=()
                        local values=()
                        while read -r line; do
                            types+=("$(echo "$line" | awk '{print $1}')")
                            names+=("$(echo "$line" | awk '{print $2}')")
                            values+=("$(echo "$line" | awk '{print $3}')")
                        done <<< "$records"
                        local max_type_len=4
                        local max_name_len=4
                        local max_value_len=5
                        for i in "${!types[@]}"; do
                            [ ${#types[i]} -gt $max_type_len ] && max_type_len=${#types[i]}
                            [ ${#names[i]} -gt $max_name_len ] && max_name_len=${#names[i]}
                            [ ${#values[i]} -gt $max_value_len ] && max_value_len=${#values[i]}
                        done
                        echo "DOMAIN: $domain"
                        echo "| $(pad "Type" $max_type_len) | $(pad "Name" $max_name_len) | $(pad "Value" $max_value_len) |"
                        echo "| $(repeat "-" $max_type_len) | $(repeat "-" $max_name_len) | $(repeat "-" $max_value_len) |"
                        for i in "${!types[@]}"; do
                            echo "| $(pad "${types[i]}" $max_type_len) | $(pad "${names[i]}" $max_name_len) | $(pad "${values[i]}" $max_value_len) |"
                        done
                    fi
                done
            fi
            ;;
        remove)
            log "Removing $TYPE record $NAME from $DOMAIN"
            if confirm_action "Are you sure you want to remove $TYPE record $NAME from $DOMAIN?" "$TIMEOUT"; then
                if grep -q "$DOMAIN {" "$CORE_FILE"; then
                    if grep -q "    $TYPE $NAME" "$CORE_FILE"; then
                        $USE_SUDO sed -i "/$DOMAIN {/,/}/ s/    $TYPE $NAME .*/    # Removed $TYPE $NAME $VALUE/" "$CORE_FILE"
                        log "Successfully removed $TYPE record $NAME from domain $DOMAIN"
                    else
                        error_log "Record $NAME does not exist in domain $DOMAIN"
                        exit 1
                    fi
                else
                    error_log "Domain $DOMAIN does not exist in Corefile"
                    exit 1
                fi
            else
                log "Action cancelled by user."
                exit 0
            fi
            ;;
        update-forward)
            log "Updating forwarders for $DOMAIN to $VALUE"
            if [ "$DOMAIN" = "all" ]; then
                $USE_SUDO sed -i "/forward .*/c\    forward . $VALUE" "$CORE_FILE"
                log "Successfully updated forwarders for all domains to $VALUE"
            else
                if grep -q "$DOMAIN {" "$CORE_FILE"; then
                    $USE_SUDO sed -i "/$DOMAIN {/,/}/ s/    forward .*/    forward . $VALUE/" "$CORE_FILE"
                    log "Successfully updated forwarders for $DOMAIN to $VALUE"
                else
                    error_log "Domain $DOMAIN does not exist in Corefile"
                    exit 1
                fi
            fi
            ;;
        *)
            usage
            ;;
    esac
    restart_coredns
}

# Create lockfile
create_lockfile

# Trap to remove lockfile on exit
trap 'remove_lockfile; exit' INT TERM EXIT

# Execute DNS management function
manage_dns

# Remove lockfile
remove_lockfile

# Remove trap
trap - INT TERM EXIT
