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
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action create --type A --name www --value 192.168.128.17 --sudo --norestart
assert_corefile "example.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A www 192.168.128.17
}"

# Test 2 - Add a new domain google.com with an A record called andrei pointing to 192.168.128.18
echo "Running Test 2..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action create --type A --name andrei --value 192.168.128.18 --sudo --norestart
assert_corefile "google.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A andrei 192.168.128.18
}"

# Test 3 - Remove domain google.com
echo "Running Test 3..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action remove --type A --name andrei --timeout 1 --sudo --norestart <<< "y"
assert_corefile "# Removed A andrei"

# Test 4 - Update domain example.com and change A record called www to point to 8.8.8.8
echo "Running Test 4..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action replace --type A --name www --value 8.8.8.8 --sudo --norestart
assert_corefile "A www 8.8.8.8"

# Test 5 - List all domains
echo "Running Test 5..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain all --action list-all --sudo --norestart)
echo "$output" | grep -q "DOMAIN: example.com"
if [ $? -ne 0 ]; then
    echo "Test failed. Domain example.com not found in the list."
    exit 1
else
    echo "Test passed."
fi

# Test 6 - List only google.com (no result expected)
echo "Running Test 6..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain google.com --action list --sudo --norestart)
if [[ "$output" != *"No records found for domain google.com."* ]]; then
    echo "Test failed. Expected no records for google.com."
    exit 1
else
    echo "Test passed."
fi

# Test 7 - Remove from domain example.com A record called www
echo "Running Test 7..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action remove --type A --name www --timeout 1 --sudo --norestart <<< "y"
assert_corefile "# Removed A www"

# Test 8 - List only example.com
echo "Running Test 8..."
output=$(sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action list --sudo --norestart)
if [[ "$output" != *"No records found for domain example.com."* ]]; then
    echo "Test failed. Expected no records for example.com."
    exit 1
else
    echo "Test passed."
fi

# Test 9 - Remove example.com
echo "Running Test 9..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain example.com --action remove --type A --name www --timeout 1 --sudo --norestart <<< "y"
assert_corefile ""

# Test 10 - Update forwarders for all domains
echo "Running Test 10..."
sudo ./manage-dns.sh --corefile "$CORE_FILE" --lockfile "$LOCK_FILE" --logfile "$LOG_FILE" --domain all --action update-forward --forward "192.168.128.1 10.0.0.1" --sudo --norestart
assert_corefile "forward . 192.168.128.1 10.0.0.1"

# Clean up
rm -rf "$TMP_DIR"

echo "All tests passed."
