#!/bin/bash

SHOW_LOGS=false
SHOW_HISTORY=false

# Early parsing of debug flag
for arg in "$@"; do
  case $arg in
    --debug) DEBUG=true; set -x ;;
    --log) SHOW_LOGS=true ;;
    --history) SHOW_HISTORY=true ;;
  esac
done

# Paths for temporary files and directories
TMP_DIR="$(mktemp -q -d)"
CORE_FILE="$TMP_DIR/Corefile"
touch $CORE_FILE
LOCK_FILE="$TMP_DIR/manage-dns.lock"
LOG_FILE="$TMP_DIR/dns_management.log"
touch $LOG_FILE
HOSTS_FILE="$TMP_DIR/hosts"
touch $HOSTS_FILE
BLOCKLIST_URL="$TMP_DIR/blocklist.txt"
TEST=0
SUCCESSES=0
FAILURES=0
declare -A history=()
declare -A outputs=()
declare -A RESULTS=()

# Helpers
function banner_warning() { printf "\033[%d;%dm%s\033[0m\n" 37 43 "${1}"; }
function banner_info() { printf "\033[%d;%dm%s\033[0m\n" 31 47 "${1}"; }
function banner_error() { printf "\033[%d;%dm%s\033[0m\n" 37 49 "${1}"; }
function error(){ tcolt_red "[ERROR] ${1}"; }
function warning(){ tcolt_orange "[WARNING] ${1}"; }
function info(){ tcolt_yellow "[INFO] ${1}"; }
function debug(){ [[ -z "${DEBUG:-}" ]] && tcolt_pink "[DEBUG] ${1}"; }
function success(){ tcolt_green "[SUCCESS] ${1}"; }
function rerror(){ replace "$(tcolt_red "[ERROR] ${1}";)"; }
function rwarning(){ replace "$(tcolt_orange "[WARNING] ${1}";)"; }
function rinfo(){ replace "$(tcolt_yellow "[INFO] ${1}";)"; }
function rdebug(){ [[ -z "${DEBUG:-}" ]] && replace "$(tcolt_pink "[DEBUG] ${1}";)"; }
function rsuccess(){ replace "$(tcolt_green "[SUCCESS] ${1}";)"; }
function tcolt_red() { echo -e "\033[1;31m${1}\033[0m"; }
function tcolt_blue() { echo -e "\033[0;34m${1}\033[0m"; }
function tcolt_green() { echo -e "\033[1;32m${1}\033[0m"; }
function tcolt_purple() { echo -e "\033[0;35m${1}\033[0m"; }
function tcolt_gold() { echo -e "\033[0;33m${1}\033[0m"; }
function tcolt_silver() { echo -e "\033[0;37m${1}\033[0m"; }
function tcolt_yellow() { echo -e "\033[0;33m${1}\033[0m"; }
function tcolt_orange() { echo -e "\033[0;33m${1}\033[0m"; }
function tcolt_pink() { echo -e "\033[0;36m${1}\033[0m"; }
function tcolt_magenta() { echo -e "\033[0;35m${1}\033[0m"; }
function safe_exit() { local msg="${1:-UnexpectedError}"; echo "${msg}"; exit 1; }
function pad() { printf "%-${1}s\n" "${2}"; }
function append() { pad "${1}" "${2}"; }
function prepend() { printf "%*s\n" $2 "${1}"; }
function replace(){ printf "\r%s%s" "${1}" "$(printf "%-$(( $(tput cols) - ${#1} ))s")"; }

# Ensure the temporary directory is clean
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Copy the initial Corefile if needed
echo ". {
  forward . 8.8.8.8 8.8.4.4
  log
  errors
}" > "$CORE_FILE"

# Initial Hosts file content
HOSTS_CONTENT="127.0.0.1\tlocalhost\n::1\tlocalhost"
echo -e "${HOSTS_CONTENT}" > "$HOSTS_FILE"

RANDOM_DOMAIN="000dn.com"

BLOCKLIST_CONTENT="0.0.0.0 0.org
0.0.0.0 0.to
0.0.0.0 ellas2.0.org
0.0.0.0 www.0.org
0.0.0.0 www.0.to
0.0.0.0 0--4.com
0.0.0.0 www.0--4.com
0.0.0.0 0--d.com
0.0.0.0 www.0--d.com
0.0.0.0 0-0-0checkmate.com
0.0.0.0 www.0-0-0checkmate.com
0.0.0.0 0-02.net
0.0.0.0 0.0-02.net
0.0.0.0 www.0-02.net
0.0.0.0 0-architecture.com
0.0.0.0 www.0-architecture.com
0.0.0.0 00.org
0.0.0.0 www.00.org
0.0.0.0 0008d6ba2e.com
0.0.0.0 26b1d20dfe.0008d6ba2e.com
0.0.0.0 www.0008d6ba2e.com
0.0.0.0 ${RANDOM_DOMAIN}
0.0.0.0 www.000dn.com
0.0.0.0 000free.us
0.0.0.0 www.000free.us
0.0.0.0 000juwrq36.ru"

echo "${BLOCKLIST_CONTENT}" > "$BLOCKLIST_URL"

# Function to assert Corefile contents
assert_corefile() {
    local expected_content="$1"
    local actual_content
    actual_content=$(<"$CORE_FILE")
    if echo "${actual_content}" | grep -qF "$expected_content"; then
        printf "$(tcolt_green "PASSED!")"
    else
        if echo "$actual_content" | awk -v RS='' -v pattern="$expected_content" 'BEGIN { found = 0 } { gsub(/\n/, ""); if ($0 ~ pattern) { found = 1 } } END { exit !found }'; then
            printf "$(tcolt_green "PASSED!")"
        else
            if grep -q "${expected_content}" "$CORE_FILE"; then
                printf "$(tcolt_green "PASSED!")"
            else
                echo "Test ${TEST} failed. Expected content not found in Corefile.\nExpected: $expected_content\nActual: $actual_content" | tee -a $LOG_FILE > /dev/null
                printf "$(tcolt_red "FAILED!")"
            fi
        fi
    fi
}

assert_hostsfile() {
    local expected_content="$1"
    local actual_content
    actual_content=$(<"$HOSTS_FILE")
    if echo "$actual_content" | awk -v RS='' -v pattern="$expected_content" 'BEGIN { found = 0 } { gsub(/\n/, ""); if ($0 ~ pattern) { found = 1 } } END { exit !found }'; then
        printf "$(tcolt_green "PASSED!")"
    else
        if grep -q "${expected_content}" "$HOSTS_FILE"; then
            printf "$(tcolt_green "PASSED!")"
        else
            echo "Test ${TEST} failed. Expected content not found in Hosts file.\nExpected: $expected_content\nActual: $actual_content" | tee -a $LOG_FILE > /dev/null
            printf "$(tcolt_red "FAILED!")"
        fi
    fi
}

function add_command() {
  local host=$1
  local cmd=$2

  if (( ${#cmd} < 3 )); then
    return
  fi

  if [[ -z "${history["$host"]}" ]]; then
    history["$host"]="$cmd"
  else
    history["$host"]="${history["$host"]}|$cmd"
  fi
}

function print_history() {
  for host in "${!history[@]}"; do
    banner_info "Execution History: $host"
    echo "Execution History: $host" | sudo tee -a "$LOG_FILE" > /dev/null
    local -i i=0
    IFS='|' read -r -a commands <<< "${history[$host]}"
    for cmd in "${commands[@]}"; do
      if (( ${#cmd} < 3 )); then
        continue
      fi
      ((i++))
      echo "$(prepend $i 3): $cmd"
      echo "$(prepend $i 3): $cmd" | sudo tee -a "$LOG_FILE" > /dev/null
    done
  done
}


run_test() {
    local id=$1
    ((TEST++))
    printf "Running Test $TEST $id"
    local cmd=$2
    local assert=$3
    local what=$4
    local output
    
    cmd="${cmd/ --debug/}"
    cmd="${cmd/ --verbose/}"

    add_command "localhost" "$cmd"

    output=$(bash -c "$cmd" 2>&1)
    outputs["test-$TEST"]="$output"

    if [[ "$assert" == "assert_corefile" ]]; then
        local a=$(assert_corefile "$what")
        if [[ "${a}" == "$(tcolt_red "FAILED!")" ]]; then
            ((FAILURES++))
            RESULTS[$TEST]=false
            # Re-run the command with debug and verbose flags and capture the output
            local debug_cmd="${cmd/ --corefile/ --debug --verbose --corefile}"
            output=$(bash -c "$debug_cmd" 2>&1)
            outputs["test-$TEST"]="$output"
        else
            ((SUCCESSES++))
            RESULTS[$TEST]=true
        fi
        printf "%s" "$a"
    elif [[ "$assert" == "assert_hostsfile" ]]; then
        local a=$(assert_hostsfile "$what")
        if [[ "${a}" == "$(tcolt_red "FAILED!")" ]]; then
            ((FAILURES++))
            RESULTS[$TEST]=false
            # Re-run the command with debug and verbose flags and capture the output
            local debug_cmd="${cmd/ --corefile/ --debug --verbose --corefile}"
            output=$(bash -c "$debug_cmd" 2>&1)
            outputs["test-$TEST"]="$output"
        else
            ((SUCCESSES++))
            RESULTS[$TEST]=true
        fi
        printf "%s" "$a"
    elif [[ "$assert" == "assert_grep" ]]; then
        echo "$output" | grep -q "$what"
        if [ $? -ne 0 ]; then
            echo "Test ${TEST} failed. [$assert] Couldn't find: ${what}\n" | tee -a $LOG_FILE > /dev/null
            ((FAILURES++))
            RESULTS[$TEST]=false
            # Re-run the command with debug and verbose flags and capture the output
            local debug_cmd="${cmd/ --corefile/ --debug --verbose --corefile}"
            output=$(bash -c "$debug_cmd" 2>&1)
            outputs["test-$TEST"]="$output"
            printf "$(tcolt_red "FAILED!")"
        else
            ((SUCCESSES++))
            RESULTS[$TEST]=true
            printf "$(tcolt_green "PASSED!")"
        fi
    elif [[ "$assert" == "assert_ne" ]]; then
        if [[ "$output" != *"$what"* ]]; then
            echo "Test ${TEST} failed. [$assert] Expected to not find: $what\n" | tee -a $LOG_FILE > /dev/null
            ((FAILURES++))
            RESULTS[$TEST]=false
            # Re-run the command with debug and verbose flags and capture the output
            local debug_cmd="${cmd/ --corefile/ --debug --verbose --corefile}"
            output=$(bash -c "$debug_cmd" 2>&1)
            outputs["test-$TEST"]="$output"
            printf "$(tcolt_red "FAILED!")"
        else
            ((SUCCESSES++))
            RESULTS[$TEST]=true
            printf "$(tcolt_green "PASSED!")"
        fi
    elif [[ "${assert}" == "assert_nin_hosts" ]]; then
        if ! grep -q "${what}" "$HOSTS_FILE"; then
            ((SUCCESSES++))
            RESULTS[$TEST]=true
            printf "$(tcolt_green "PASSED!")"
        else
            echo "Test ${TEST} failed. [$assert] Expected to not find: $what\n" | tee -a $LOG_FILE > /dev/null
            ((FAILURES++))
            RESULTS[$TEST]=false
            # Re-run the command with debug and verbose flags and capture the output
            local debug_cmd="${cmd/ --corefile/ --debug --verbose --corefile}"
            output=$(bash -c "$debug_cmd" 2>&1)
            outputs["test-$TEST"]="$output"
            printf "$(tcolt_red "FAILED!")"
        fi
    else
        banner_warning "Invalid assert argument 2 passed into run_test"
        exit 1
    fi
    echo
}

run_test "Add a new domain example.com with an A record called www pointing to 192.168.128.17..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action create --type A --name www --value 192.168.128.17 --yes" \
         assert_corefile "example.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A www 192.168.128.17
}"

run_test "Add a new domain google.com with an A record called andrei pointing to 192.168.128.18..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain google.com --action create --type A --name andrei --value 192.168.128.18 --yes" \
         assert_corefile "google.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A andrei 192.168.128.18
}"

run_test "Remove domain google.com..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain google.com --action remove --type A --name andrei --timeout 1 --yes <<< \"y\"" \
         assert_corefile "# Removed A andrei"

run_test "Update domain example.com and change A record called www to point to 8.8.8.8..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action replace --type A --name www --value 8.8.8.8 --yes" \
         assert_corefile "A www 8.8.8.8"

run_test "List all domains..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --action list-all --yes" \
         assert_grep "DOMAIN: example.com"

run_test "List only google.com (no result expected)..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain google.com --action list --yes" \
         assert_ne "No records found for domain google.com."

run_test "Update forwarders for all domains..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain all --action update-forward --forward \"192.168.128.1 10.0.0.1\" --yes" \
         assert_corefile "forward . 192.168.128.1 10.0.0.1"

run_test "List all domains with JSON output..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --action list-all --yes --json" \
         assert_grep "\"domain\":\"example.com\""

if command -v jq &>/dev/null; then
    run_test "List all domains with JSON output and jq query..." \
             "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --action list-all --yes --json --jq '.[] | select(.domain==\"example.com\")'" \
             assert_grep "\"domain\": \"example.com\""
fi

run_test "Remove example.com..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action remove --type A --name www --timeout 1 --yes <<< \"y\"" \
         assert_corefile ""

run_test "Remove from domain example.com A record called www..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action remove --type A --name www --timeout 1 --yes <<< \"y\"" \
         assert_corefile "# Removed A www"

run_test "List only example.com..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action list --yes" \
         assert_ne "No records found for domain example.com."

clean_url=$(echo "$BLOCKLIST_URL" | sed 's/\//-/g')
run_test "Install blocklist from $BLOCKLIST_URL..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action install-blocklist --blocklist \"$BLOCKLIST_URL\" --yes" \
         assert_hostsfile "## Blocklist Start - $clean_url ##\n$BLOCKLIST_CONTENT\n## Blocklist End - $clean_url ##"

run_test "Uninstall blocklist from $BLOCKLIST_URL..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action uninstall-blocklist --blocklist \"$BLOCKLIST_URL\" --yes" \
         assert_nin_hosts "${RANDOM_DOMAIN}"

run_test "Activate blocklists in CoreDNS..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action activate-blocklists --yes" \
         assert_corefile "hosts ${HOSTS_FILE//\//\\/} {
    fallthrough
}"

run_test "Deactivate blocklists in CoreDNS..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action deactivate-blocklists --yes" \
         assert_corefile "errors"

# Clean up
rm -rf "$TMP_DIR"

if $SHOW_HISTORY; then
    print_history
fi

banner_info "OUTPUTS"
for key in "${!outputs[@]}"; do
    test="${key/test-}"
    result="${RESULTS[$test]}"
    if [[ "${result}" != "true" ]]; then
        banner_warning "Output for $key"
        printf "%s\n" "${outputs[$key]}"
        echo
    fi
done

success "${SUCCESSES} tests passed."
error "${FAILURES} tests failed."

if $SHOW_LOGS; then
    echo
    cat $LOG_FILE
fi

echo

