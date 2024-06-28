# CoreDNS Bash Utility Manager

A helpful command-line utility designed to simplify the daily administrative tasks associated with managing CoreDNS. Includes helpful utilities to enable/disable a Hosts Blocklist file in the configuration of CoreDNS and the system in general. The script was designed to run on Linux and was built with test driven development. On your production system, before running `manage-dns.sh` against a live server, ensure that the `./test_manage-dns.sh` executes properly first to ensure that you have full compatibility of your system before using the script. Otherwise, you could inadvertenly run into issues if the host you're running this script on is not properly set up. A proper setup is one that has CoreDNS installed alongside other development related dependencies.

## Overview

The `manage-dns.sh` script is a versatile utility designed to manage DNS entries for CoreDNS. It provides interactive prompts, input validation, error logging, and flags for verbose and debug modes. The script supports various DNS record types and allows for adding, removing, listing, and updating DNS records.

## Features

- Create, add, and replace DNS records
- List DNS records by type or for all domains
- Remove DNS records with confirmation prompts
- Update forwarders for specific domains or all domains
- Backup Corefile before performing destructive or constructive actions
- Lockfile mechanism to prevent concurrent execution
- Optional use of `sudo` for file operations
- Install/uninstall DNS blocklist
- Activate/deactivate DNS blocklist in CoreDNS requests

## Requirements

- Bash 5.1 or greater

## Installation

To install this package on your system, keep in mind that it was built for Rocky 9 linux and not Ubuntu or Debian. Feel free to fork the project if you wish to add support for those distributions.

```bash
git clone https://github.com/andreimerlescu/manage-dns.git
cd manage-dns
sudo ./manage-dns.sh --action list-all
```

## Usage

```bash
[dns@dns ~]$ ./manage-dns.sh --help
Usage: ./manage-dns.sh --domain DOMAIN --action [actions] [options]
Actions:
  create --type TYPE --name NAME --value VALUE
  new --type TYPE --name NAME --value VALUE
  add --type TYPE --name NAME --value VALUE (alias for new)
  replace --type TYPE --name NAME --value VALUE
  list [--type TYPE]
  list-all
  remove --type TYPE --name NAME [--timeout SECONDS]
  update-forward --forward FORWARD
  install-blocklist --blocklist URL
  uninstall-blocklist --blocklist URL
  activate-blocklists
  deactivate-blocklists
Options:
  --verbose                 Enable verbose mode
  --debug                   Enable debug mode
  --sudo                    Use sudo for file operations
  --corefile PATH           Path to the Corefile
  --logfile PATH            Path to the log file
  --lockfile PATH           Path to the lockfile
  --backup                  Enable backup of Corefile
  --backups PATH            Path to the backups directory
  --restart                 Prevent restarting CoreDNS
  --json                    Output in JSON format
  --jq QUERY                Process JSON output with jq
  --jq-opts OPTIONS         Options to pass to jq
  --hosts                   Path to hosts file
  --yes                     Respond with yes to prompts automatically
Examples:
  ./manage-dns.sh --action list-all
  ./manage-dns.sh --domain domain.com --action list
  ./manage-dns.sh --domain domain.com --action list --type A
  ./manage-dns.sh --domain domain.com --action create --type A --name www --value 10.10.10.10
  ./manage-dns.sh --domain domain.com --action new --type CNAME --name git --value github.com
  ./manage-dns.sh --domain domain.com --action add --type A --name www --value 10.10.10.11
  ./manage-dns.sh --domain domain.com --action replace --type A --name www --value 10.10.10.12
  ./manage-dns.sh --domain domain.com --action remove --type A --name www
  ./manage-dns.sh --domain all --action update-forward --forward "192.168.128.1 10.0.0.1"
  ./manage-dns.sh --action install-blocklist --blocklist "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt"
  ./manage-dns.sh --action install-blocklist --blocklist "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt" --hosts /root/hosts.new
  ./manage-dns.sh --action uninstall-blocklist --blocklist "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt"
  ./manage-dns.sh --action activate-blocklists
  ./manage-dns.sh --action deactivate-blocklists

```

### Actions

- `create` --type TYPE --name NAME --value VALUE
- `new` --type TYPE --name NAME --value VALUE
- `add` --type TYPE --name NAME --value VALUE (alias for new)
- `replace` --type TYPE --name NAME --value VALUE
- `list` [--type TYPE]
- `list-all`
- `remove` --type TYPE --name NAME [--timeout SECONDS]
- `update-forward` --forward FORWARD
- `install-blocklist` --blocklist URL
- `uninstall-blocklist` --blocklist URL
- `activate-blocklists`
- `deactivate-blocklists`

### Options

- `--verbose`                 Enable verbose mode
- `--debug`                   Enable debug mode
- `--sudo`                    Use sudo for file operations
- `--corefile PATH`           Path to the Corefile
- `--logfile PATH`            Path to the log file
- `--lockfile PATH`           Path to the lockfile
- `--backup`                  Enable backup of Corefile
- `--backups PATH`            Path to the backups directory
- `--restart`                 Prevent restarting CoreDNS
- `--json`                    Output in JSON format
- `--jq QUERY`                Process JSON output with jq
- `--jq-opts OPTIONS`         Options to pass to jq
- `--hosts`                   Path to hosts file
- `--yes`                     Respond with yes to prompts automatically

### Examples

```bash
./manage-dns.sh --domain domain.com --action create --type A --name www --value 10.10.10.10
./manage-dns.sh --domain domain.com --action new --type CNAME --name git --value github.com
./manage-dns.sh --domain domain.com --action add --type A --name www --value 10.10.10.11
./manage-dns.sh --domain domain.com --action replace --type A --name www --value 10.10.10.12
./manage-dns.sh --domain domain.com --action list
./manage-dns.sh --domain domain.com --action list --type A
./manage-dns.sh --domain domain.com --action list-all
./manage-dns.sh --domain domain.com --action remove --type A --name www
./manage-dns.sh --domain all --action update-forward --forward "192.168.128.1 10.0.0.1"
./manage-dns.sh --action install-blocklist --blocklist "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt"
./manage-dns.sh --action install-blocklist --blocklist "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt" --hosts /root/hosts.new
./manage-dns.sh --action uninstall-blocklist --blocklist "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/hosts/pro.txt"
./manage-dns.sh --action activate-blocklists
./manage-dns.sh --action deactivate-blocklists
```

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

### Dependencies for Linux

To upgrade Bash to the required version, use the following script:

```bash
#!/bin/bash
set -o nounset  # Exit immediately if a variable is referenced before it is defined.
set -o errexit  # Exit immediately when a command exits with a non-zero status.
set -o pipefail # Exit immediately when a piped command exits with a non-zero status.
set -o noclobber # Prevent overwriting existing files globally unless manually set +o

# MAIN SCRIPT
safe_exit() {
  local msg="${1:-UnexpectedError}"
  echo "${msg}"
  exit 1
}

upgrade_bash(){
   declare WORKSPACE
   WORKSPACE=/tmp/bash-install
   mkdir -p "${WORKSPACE}"
   cd "${WORKSPACE}" || safe_exit "Cannot access ${WORKSPACE}"
   sudo yum -y install curl
   sudo yum -y groupinstall "Development Tools"
   curl -O http://ftp.gnu.org/gnu/bash/bash-5.2.tar.gz
   tar xvf bash-5.*.tar.gz
   cd bash-5.*/ || safe_exit "Cannot find expanded bash archive"
   ./configure
   make
   sudo make install
}

upgrade_bash
```

## Tests

This script was built using Test Driven Development (TDD) such that each intended functional use case of the application can be seen working through the `test_manage-dns.sh` script itself. Reviewing each of the tests is important, including what happens when a test fails. For instance, I'll modify the tests so they fail, so you can see what happens when they fail. Let's review different use cases.

### All In One Unit Test

The AIO Unit Test for the suite is found in the `test_manage-dns.sh` script and is broken down into 16 separate tests.

#### 1. Test 1

```bash
run_test "Add a new domain example.com with an A record called www pointing to 192.168.128.17..." \
        "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action create --type A --name www --value 192.168.128.17 --yes" \
        assert_corefile "example.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A www 192.168.128.17
}"
```

This test takes the `Corefile` and installs the `example.com` domain name in the policy definition with a new `A` record type called `www` that points to `192.168.128.17`. This syntax uses the `--lockfile <> --logfile <> --corefile <>` syntax to provide a temporary location on the host (inside `/tmp`) for the test to run, however on a production system, you will not use these unless your CoreDNS installation is custom and your Corefile is not located in `/etc/coredns/Corefile`. 

#### 2. Test 2

```bash
run_test "Add a new domain google.com with an A record called andrei pointing to 192.168.128.18..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain google.com --action create --type A --name andrei --value 192.168.128.18 --yes" \
         assert_corefile "google.com {
    log
    errors
    forward . 8.8.8.8 8.8.4.4
    A andrei 192.168.128.18
}"
```

This test is very similar to the last test, only instead of `example.com` its adding `google.com` and assigning a new `A` record type with a name of `andrei` to point to `192.168.128.18`.

#### 3. Test 3

```bash
run_test "Remove domain google.com..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain google.com --action remove --type A --name andrei --timeout 1 --yes <<< \"y\"" \
         assert_corefile "# Removed A andrei"
```

This test will remove the `google.com` definition from the `Corefile`.

#### 4. Test 4

```bash
run_test "Update domain example.com and change A record called www to point to 8.8.8.8..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action replace --type A --name www --value 8.8.8.8 --yes" \
         assert_corefile "A www 8.8.8.8"
```

This test will replace the existing `A` record type by the name of `www` for the domain `example.com` and change what it points to, to `8.8.8.8` from the previous value of `192.168.128.17` from Test 1.

#### 5. Test 5

```bash
run_test "List all domains..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --action list-all --yes" \
         assert_grep "DOMAIN: example.com"
```

This test prints a table of the all domain and DNS entries that exist within the Corefile itself.

#### 6. Test 6

```bash
run_test "List only google.com (no result expected)..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain google.com --action list --yes" \
         assert_ne "No records found for domain google.com."
```

This test uses the `--domain <>` to filter the `Corefile` by using `--action list` instead of `--action list-all` as we see in Test 5.

#### 7. Test 7

```bash
run_test "Update forwarders for all domains..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain all --action update-forward --forward \"192.168.128.1 10.0.0.1\" --yes" \
         assert_corefile "forward . 192.168.128.1 10.0.0.1"
```

This test will modify the `Corefile` on `all domains` to change the fallback DNS servers for the domain from `8.8.8.8 8.8.4.4` (the default) to `192.168.128.1 10.0.0.1`. Every domain in the `Corefile` will be updated so their `forward . <>...` options reflect this command's arguments.

#### 8. Test 8

```bash
run_test "List all domains with JSON output..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --action list-all --yes --json" \
         assert_grep "\"domain\":\"example.com\""
```

This test shows you that the markdown table format can be displayed using JSON with the `--json` flag added.

#### 9. Test 9

```bash
if command -v jq &>/dev/null; then
    run_test "List all domains with JSON output and jq query..." \
             "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --action list-all --yes --json --jq '.[] | select(.domain==\"example.com\")'" \
             assert_grep "\"domain\": \"example.com\""
fi
```

This test will only run if you have `jq` installed on your system and the `test_manage-dns.sh` script can execute that executable binary. If you can, then the `--action list-all` leverages `jq` to filter the results using the `--jq` syntax. In a `jq` command, you typically have JSON code that is either in STDIN or STDOUT that needs to be formatted and you can do this `echo "{a: '1', b: '2'}" | jq '.'` to pretty print the result. The `'.'` part of this represents what goes inside the `--jq` flag. It requires `--json` to be enabled, but provides you the ability to use `jq` syntax to filter through your results if you're building scripting on top of the `manage-dns.sh` utility.

#### 10. Test 10

```bash
run_test "Remove example.com..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action remove --type A --name www --timeout 1 --yes <<< \"y\"" \
         assert_corefile ""
```

This test will delete the `www` `A` record from `example.com` in the `Corefile`.

#### 11. Test 11

```bash
run_test "Remove from domain example.com A record called <www>..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action remove --type A --name www --timeout 1 --yes <<< \"y\"" \
         assert_corefile "# Removed A www"
```

This test will remove the entire domain `example.com` from the `Corefile`.

#### 12. Test 12

```bash
run_test "List only example.com..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --domain example.com --action list --yes" \
         assert_ne "No records found for domain example.com."
```

This test tests to ensure that domain `example.com` still renders after removing `google.com`.

#### 13. Test 13

```bash
clean_url=$(echo "$BLOCKLIST_URL" | sed 's/\//-/g')
run_test "Install blocklist from $BLOCKLIST_URL..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action install-blocklist --blocklist \"$BLOCKLIST_URL\" --yes" \
         assert_hostsfile "## Blocklist Start - $clean_url ##\n$BLOCKLIST_CONTENT\n## Blocklist End - $clean_url ##"
```

This test needs to clean the header of the BLOCKLIST URL since its a file path and not a URL, but the blocklist is a text file that contains HOSTS entries that allow you to override where domains point to, thus allowing you to block ads and abusive content from the internet. Many blocklists are out there, and you need only pass in the URL of the Blocklist that you wish to install and the script will properly insert the blocklist into your `/etc/hosts` file. This test demonstrates that the script is able to cleanly interact with the `/etc/hosts` file and retain its non-blocklist compatibility in case you use the `/etc/hosts` file in conjunction with blocklists. This script supports installing multiple blocklists and uninstalling specific ones too.

#### 14. Test 14

```bash
run_test "Uninstall blocklist from $BLOCKLIST_URL..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action uninstall-blocklist --blocklist \"$BLOCKLIST_URL\" --yes" \
         assert_nin_hosts "${RANDOM_DOMAIN}"
```

This test will remove the blocklist from the `/etc/hosts` file.

#### 15. Test 15

```bash
run_test "Activate blocklists in CoreDNS..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action activate-blocklists --yes" \
         assert_corefile "hosts ${HOSTS_FILE//\//\\/} {
    fallthrough
}"
```

This test will update the `Corefile` to instruct CoreDNS to use the `/etc/hosts` entries when attempting to resolve domain queries for IP addresses.

#### 16. Test 16

```bash
run_test "Deactivate blocklists in CoreDNS..." \
         "./manage-dns.sh --corefile \"$CORE_FILE\" --lockfile \"$LOCK_FILE\" --logfile \"$LOG_FILE\" --hosts \"$HOSTS_FILE\" --action deactivate-blocklists --yes" \
         assert_corefile "errors"
```

This test will tell CoreDNS via the `Corefile` to NOT use the `/etc/hosts` when resolving requests. This effectively disables the blocklists from being used by CoreDNS and your end-users but keeps the blocking enabled on the CoreDNS server itself.

### The Testing Library

As you can see from the `test_manage-dns.sh` script, the `run_test` function takes 4 arguments total.

```bash
run_test "Description" "Command" "Assertion Rule" "Assertion Check Value"
```

It is important that the `Command` be easy to understand and plain language since its the behavior that you're testing... describe it accordingly.

The `Assertion Rule` can be multiple values: 

| Assertion Rule | Use Case |
|----------------|----------|
| `assert_corefile` | When the contents of the `Corefile` (`--corefile` Path) contains the `Assertion Check Value` the test returns `TRUE`. |
| `assert_hostsfile` | When the contents of the `/etc/hosts` (`--hosts` Path) contains the `Assertion Check Value` the test returns `TRUE`. |
| `assert_grep` | When the output of the `Command` **matches** a GREP assertion of the `Assertion Check Value` the test returns `TRUE`. |
| `assert_ne` | When the output of the `Command` **does not** contain the `Assertion Check Value` the test returns `TRUE`. |
| `assert_nin_hosts` | When `Assertion Check Value` does not exist in the `/etc/hosts` (`--hosts` Path) the test returns `TRUE`. |

### Debugging Tests

In the event that you are doing development on this project and you're running the `test_manage-dns.sh` there are several arguments that you can pass into that script to help you with runtime managability. For instance:

**Flags for `test_manage-dns.sh`**

- `--debug` This enables `set -x` to display verbose details of what Bash is doing as the `test_manage-dns.sh` script executes.
- `--log` This will display the log file captured during the test at the end of the test. This output is suppressed by default.
- `--history` This will display a list of all of the commands executed during the test in their full detail. This output is suppressed by default.

## Contributing

Feel free to submit issues, fork the repository and send pull requests.

## Acknowledgments

Special thanks to Andrei and the community for their contributions to this project. Project utilized ChatGPT for assistance in developing this software.
