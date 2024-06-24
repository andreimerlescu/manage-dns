#!/bin/bash

# Paths for temporary files and directories
TMP_DIR="/tmp/test_manage_dns"
CORE_FILE="$TMP_DIR/Corefile"
LOCK_FILE="$TMP_DIR/manage-dns.lock"
LOG_FILE="$TMP_DIR/dns_management.log"

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
        echo "Test failed. Expected content not found in Corefile."
        echo "Expected: $expected_content"
        echo "Actual: $actual_content"
        exit 1
    else
        echo "Test passed."
    fi
}

# Test 1 - Add a new domain example.com with an A record called www pointing to 192.168.128.17
echo "Running Test 1..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action create --type A --name www --value 192.168.128.17 --sudo
assert_corefile "example.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A www 192.168.128.17
}"

# Test 2 - Add a new domain google.com with an A record called andrei pointing to 192.168.128.18
echo "Running Test 2..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action create --type A --name andrei --value 192.168.128.18 --sudo
assert_corefile "google.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A andrei 192.168.128.18
}"

# Test 3 - Remove domain google.com
echo "Running Test 3..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action remove --type A --name andrei --timeout 1 --sudo <<< "y"
assert_corefile "# Removed A andrei"

# Test 4 - Update domain example.com and change A record called www to point to 8.8.8.8
echo "Running Test 4..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action replace --type A --name www --value 8.8.8.8 --sudo
assert_corefile "A www 8.8.8.8"

# Test 5 - List all domains
echo "Running Test 5..."
output=$(sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --action list-all --sudo)
echo "$output" | grep -q "DOMAIN: example.com"
if [ $? -ne 0 ]; then
    echo "Test failed. Domain example.com not found in the list."
    exit 1
else
    echo "Test passed."
fi

# Test 6 - List only google.com (no result expected)
echo "Running Test 6..."
output=$(sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action list --sudo)
if [[ "$output" != *"No records found for domain google.com."* ]]; then
    echo "Test failed. Expected no records for google.com."
    exit 1
else
    echo "Test passed."
fi

# Test 7 - Remove from domain example.com A record called www
echo "Running Test 7..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action remove --type A --name www --timeout 1 --sudo <<< "y"
assert_corefile "# Removed A www"

# Test 8 - List only example.com
echo "Running Test 8..."
output=$(sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action list --sudo)
if [[ "$output" != *"No records found for domain example.com."* ]]; then
    echo "Test failed. Expected no records for example.com."
    exit 1
else
    echo "Test passed."
fi

# Test 9 - Remove example.com
echo "Running Test 9..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action remove --type A --name www --timeout 1 --sudo <<< "y"
assert_corefile ""

# Test 10 - Update forwarders for all domains
echo "Running Test 10..."
sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain all --action update-forward --forward "192.168.128.1 10.0.0.1" --sudo
assert_corefile "forward . 192.168.128.1 10.0.0.1"

# Test 11 - List all domains with JSON output
echo "Running Test 11..."
output=$(sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --action list-all --sudo --json)
echo "$output" | grep -q "\"domain\":\"example.com\""
if [ $? -ne 0 ]; then
    echo "Test failed. JSON output for domain example.com not found."
    exit 1
else
    echo "Test passed."
fi

# Test 12 - List all domains with JSON output and jq query
if command -v jq &>/dev/null; then
    echo "Running Test 12..."
    output=$(sudo ./manage-dns.sh --debug --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --action list-all --sudo --json --jq '.[] | select(.domain=="example.com")')
    echo "$output" | grep -q "\"domain\":\"example.com\""
    if [ $? -ne 0 ]; then
        echo "Test failed. jq query output for domain example.com not found."
        exit 1
    else
        echo "Test passed."
    fi
else
    echo "Skipping Test 12. jq not found."
fi

# Clean up
rm -rf "$TMP_DIR"

echo "All tests passed."
