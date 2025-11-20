#!/usr/bin/env bash
# SELIS bundle utility
# Bundles multiple .cs files by stripping partial class Program wrappers
# Input: Project directory path as argument
# Output: Bundled source code to stdout

set -euo pipefail

# Get script directory for sourcing common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [ "$#" -ne 1 ]; then
    error "Usage: bundle.sh <project_directory>"
fi

PROJECT_DIR="$1"

if [ ! -d "${PROJECT_DIR}" ]; then
    error "Project directory does not exist: ${PROJECT_DIR}"
fi

# Find all .cs files in project directory (depth 1), sort alphabetically
CS_FILES=$(find "${PROJECT_DIR}" -maxdepth 1 -name "*.cs" -type f | sort)

if [ -z "${CS_FILES}" ]; then
    error "No .cs files found in project directory: ${PROJECT_DIR}"
fi

# Process each .cs file with wrapper stripping logic
for file in ${CS_FILES}; do
    # Extract content between 'partial class Program' and closing braces
    # 1. awk: Find 'partial class Program' line and capture everything after
    # 2. tail -n +2: Skip first line (opening brace after partial class declaration)
    # 3. sed '$d' (first): Remove last line (closing brace of Program class)
    # 4. sed '$d' (second): Remove second-to-last line (closing brace of namespace)
    awk 'BEGIN {prog=0} /partial class Program/ {prog=1; next} prog {print}' "${file}" \
        | tail -n +2 \
        | sed '$d' \
        | sed '$d'

    # Add blank line between files (will be collapsed during minification)
    echo ""
done
