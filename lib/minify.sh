#!/usr/bin/env bash
# SELIS minify utility
# Minifies C# source code by stripping comments and collapsing whitespace
# Input: Source code from stdin
# Output: Minified code to stdout

set -euo pipefail

# Strip C++ style comments, remove carriage returns, collapse whitespace
sed -E 's://.*$::' \
  | tr -d '\r' \
  | awk 'NF {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); gsub(/[[:space:]]+/, " "); printf "%s ", $0} END {print ""}'
