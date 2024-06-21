# manage-dns

CoreDNS Bash Utility Manager

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

## Requirements

- Bash 5.1 or greater

## Installation

To install this package on your system, keep in mind that it was built for Rocky 9 linux and not Ubuntu or Debian. Feel free to fork the project if you wish to add support for those distributions.

```bash
git clone https://github.com/andreimerlescu/manage-dns.git
cd manage-dns
sudo ./manage-dns.sh --domain all --action list-all
```

## Usage

```bash
[dns@dns ~]$ ./manage-dns.sh --help
Usage: ./manage-dns.sh --domain DOMAIN --action ACTION [options]
Actions:
  create --type TYPE --name NAME --value VALUE
  new --type TYPE --name NAME --value VALUE
  add --type TYPE --name NAME --value VALUE (alias for new)
  replace --type TYPE --name NAME --value VALUE
  list [--type TYPE]
  list-all
  remove --type TYPE --name NAME [--timeout SECONDS]
  update-forward --forward FORWARD
Options:
  --verbose                 Enable verbose mode
  --debug                   Enable debug mode
  --sudo                    Use sudo for file operations
  --corefile PATH           Path to the Corefile
  --logfile PATH            Path to the log file
  --lockfile PATH           Path to the lockfile
  --backups PATH            Path to the backups directory
Examples:
  ./manage-dns.sh --domain domain.com --action create --type A --name www --value 10.10.10.10
  ./manage-dns.sh --domain domain.com --action new --type CNAME --name git --value github.com
  ./manage-dns.sh --domain domain.com --action add --type A --name www --value 10.10.10.11
  ./manage-dns.sh --domain domain.com --action replace --type A --name www --value 10.10.10.12
  ./manage-dns.sh --domain domain.com --action list
  ./manage-dns.sh --domain domain.com --action list --type A
  ./manage-dns.sh --domain domain.com --action list-all
  ./manage-dns.sh --domain domain.com --action remove --type A --name www
  ./manage-dns.sh --domain all --action update-forward --forward "192.168.128.1 10.0.0.1"
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

### Options

- `--verbose`                 Enable verbose mode
- `--debug`                   Enable debug mode
- `--sudo`                    Use sudo for file operations
- `--corefile PATH`           Path to the Corefile
- `--logfile PATH`            Path to the log file
- `--lockfile PATH`           Path to the lockfile
- `--backups PATH`            Path to the backups directory
- `--nobackup`                Enable no backup creation
- `--norestart`               Prevent restarting CoreDNS

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

## Contributing

Feel free to submit issues, fork the repository and send pull requests.

## Acknowledgments

Special thanks to Andrei and the community for their contributions to this project.

