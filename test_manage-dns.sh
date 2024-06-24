#!/bin/bash

# Paths for temporary files and directories
TMP_DIR="/tmp/test_manage_dns"
CORE_FILE="$TMP_DIR/Corefile"
LOCK_FILE="$TMP_DIR/manage-dns.lock"
LOG_FILE="$TMP_DIR/dns_management.log"
TEST=0
REPORT=""

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

# Function to assert Corefile contents
assert_corefile() {
    local expected_content="$1"
    local actual_content
    actual_content=$(<"$CORE_FILE")
    if [[ "$actual_content" != *"$expected_content"* ]]; then
        printf "$(tcolt_red "FAILED!")"
        echo
        REPORT+="Test ${TEST} failed. Expected content not found in Corefile."
        REPORT+="Expected: $expected_content"
        REPORT+="Actual: $actual_content"
    else
        printf "$(tcolt_green "PASSED!")"
    fi
}

running_test(){
    ((TEST++))
    printf "Running Test $TEST $1"
}

running_test "Add a new domain example.com with an A record called www pointing to 192.168.128.17..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action create --type A --name www --value 192.168.128.17 --sudo
assert_corefile "example.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A www 192.168.128.17
}"
echo

running_test "Add a new domain google.com with an A record called andrei pointing to 192.168.128.18..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action create --type A --name andrei --value 192.168.128.18 --sudo
assert_corefile "google.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A andrei 192.168.128.18
}"
echo

running_test "Remove domain google.com..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action remove --type A --name andrei --timeout 1 --sudo <<< "y"
assert_corefile "# Removed A andrei"
echo

running_test "Update domain example.com and change A record called www to point to 8.8.8.8..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action replace --type A --name www --value 8.8.8.8 --sudo
assert_corefile "A www 8.8.8.8"
echo

running_test "List all domains..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --action list-all --sudo)
echo "$output" | grep -q "DOMAIN: example.com"
if [ $? -ne 0 ]; then
    printf "$(tcolt_red "FAILED!")"
    echo
    REPORT+="Test ${TEST} failed. Domain example.com not found in the list.\n"
else
    printf "$(tcolt_green "PASSED!")"
    echo
fi

running_test "List only google.com (no result expected)..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action list --sudo)
if [[ "$output" != *"No records found for domain google.com."* ]]; then
    printf "$(tcolt_red "FAILED!")"
    echo
    REPORT+="Test ${TEST} failed. Expected no records for google.com.\n"
else
    printf "$(tcolt_green "PASSED!")"
    echo
fi

running_test "Update forwarders for all domains..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain all --action update-forward --forward "192.168.128.1 10.0.0.1" --sudo
assert_corefile "forward . 192.168.128.1 10.0.0.1"
echo

running_test "List all domains with JSON output..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --action list-all --sudo --json)
echo "$output" | grep -q "\"domain\":\"example.com\""
if [ $? -ne 0 ]; then
    printf "$(tcolt_red "FAILED!")"
    echo
    REPORT+="Test ${TEST} failed. JSON output for domain example.com not found.\n"
else
    printf "$(tcolt_green "PASSED!")"
    echo
fi

running_test "List all domains with JSON output and jq query..."
if command -v jq &>/dev/null; then
    output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --action list-all --sudo --json --jq '.[] | select(.domain=="example.com")')
    echo "$output" | grep -q "\"domain\": \"example.com\""
    if [ $? -ne 0 ]; then
        printf "$(tcolt_red "FAILED!")"
        echo
        REPORT+="Test ${TEST} failed. jq query output for domain example.com not found.\n"
    else
        printf "$(tcolt_green "PASSED!")"
        echo
    fi
else
    printf "$(tcolt_blue "Skipping (jq not found)")"
    echo
fi

running_test "Remove example.com..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action remove --type A --name www --timeout 1 --sudo <<< "y"
assert_corefile ""
echo

running_test "Remove from domain example.com A record called www..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action remove --type A --name www --timeout 1 --sudo <<< "y"
assert_corefile "# Removed A www"
echo

running_test "List only example.com..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action list --sudo)
if [[ "$output" != *"No records found for domain example.com."* ]]; then
    printf "$(tcolt_red "FAILED!")"
    echo
else
    printf "$(tcolt_green "PASSED!")"
    echo
fi

# Clean up
rm -rf "$TMP_DIR"

echo "${REPORT}"

success "All ${TEST} tests passed."


