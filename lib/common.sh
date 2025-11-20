#!/usr/bin/env bash
# Common functions shared across all SELIS commands

########################
# Configuration Management
########################

# Simple INI getter: conf_get <section> <key>
conf_get() {
    awk -v section="$1" -v key="$2" '
      function trim(str) {
        sub(/^[ \t\r\n]+/, "", str)
        sub(/[ \t\r\n]+$/, "", str)
        return str
      }
      BEGIN { in_section = 0 }
      /^\s*\[.*\]\s*$/ {
        s = $0
        gsub(/^[ \t]*|[ \t]*$/, "", s)
        sub(/^\[/, "", s)
        sub(/\]$/, "", s)
        if (tolower(s) == tolower(section)) in_section = 1
        else in_section = 0
        next
      }
      in_section && $0 ~ "=" {
        line = $0
        sub(/[;#].*$/, "", line)
        n = index(line, "=")
        if (n > 0) {
          k = trim(substr(line, 1, n-1))
          v = trim(substr(line, n+1))
          if (tolower(k) == tolower(key)) { print v; exit }
        }
      }
    ' "${CONFIG_FILE}"
}

########################
# Path Detection
########################

# Detect selis.conf location
find_config() {
    local script_dir="$1"
    if [ -f "${script_dir}/selis.conf" ]; then
        echo "${script_dir}/selis.conf"
    elif [ -f "/mnt/storage/www/selis/selis.conf" ]; then
        echo "/mnt/storage/www/selis/selis.conf"
    else
        echo ""
    fi
}

########################
# Error Handling
########################

error() {
    echo "ERROR: $*" >&2
    exit 1
}

warn() {
    echo "WARN: $*" >&2
}

info() {
    echo "$*"
}
