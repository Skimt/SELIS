#!/usr/bin/env bash
# SELIS validate command implementation
# Validates C# code against the Space Engineers whitelist

cmd_validate() {
    ########################
    # ARGUMENT / USAGE
    ########################

    if [ "$#" -lt 1 ]; then
        echo "Usage: selis validate <ProjectFolderName>"
        echo "  Example: selis validate MyScript"
        echo
        echo "Validates that the project only uses APIs available in Space Engineers"
        echo "programmable blocks (checks against the whitelist)."
        exit 1
    fi

    PROJECT_NAME="$1"
    PROJECT_ROOT="$(pwd)"
    PROJECT_DIR="${PROJECT_ROOT}/${PROJECT_NAME}"
    WHITELIST_FILE="${SCRIPT_DIR}/lib/whitelist.json"

    # Ensure the project folder exists
    if [ ! -d "${PROJECT_DIR}" ]; then
        error "Project folder '${PROJECT_NAME}' does not exist in: ${PROJECT_ROOT}"
    fi

    # Ensure whitelist exists
    if [ ! -f "${WHITELIST_FILE}" ]; then
        error "Whitelist file not found: ${WHITELIST_FILE}"
    fi

    echo "Validating project: ${PROJECT_NAME}"
    echo "Checking against Space Engineers API whitelist..."
    echo

    # Find all .cs files
    CS_FILES=$(find "${PROJECT_DIR}" -maxdepth 1 -name "*.cs" -type f)
    if [ -z "${CS_FILES}" ]; then
        error "No .cs files found in project directory: ${PROJECT_DIR}"
    fi

    VIOLATIONS_FOUND=0
    WARNINGS_FOUND=0

    # Check each .cs file
    for CS_FILE in ${CS_FILES}; do
        FILENAME=$(basename "${CS_FILE}")

        # Check for banned namespace usings
        check_banned_usings "${CS_FILE}" "${FILENAME}"

        # Check for common banned patterns in code
        check_banned_patterns "${CS_FILE}" "${FILENAME}"
    done

    echo
    echo "-------------------------------------------------------"

    if [ "$VIOLATIONS_FOUND" -gt 0 ]; then
        echo "FAILED: Found ${VIOLATIONS_FOUND} whitelist violation(s)"
        echo
        echo "These APIs are not available in Space Engineers programmable blocks."
        echo "Your script will crash at runtime if you use them."
        return 1
    elif [ "$WARNINGS_FOUND" -gt 0 ]; then
        echo "PASSED with ${WARNINGS_FOUND} warning(s)"
        return 0
    else
        echo "PASSED: No whitelist violations detected"
        return 0
    fi
}

check_banned_usings() {
    local FILE="$1"
    local FILENAME="$2"

    # Banned namespace patterns - these are NOT allowed (with some exceptions)
    local BANNED_PATTERNS=(
        '^System\.IO$'
        '^System\.Net'
        '^System\.Threading'
        '^System\.Diagnostics'
        '^System\.Runtime\.InteropServices'
        '^System\.Security'
        '^System\.Reflection$'
    )

    # Exceptions that ARE allowed even though they match banned patterns
    local EXCEPTIONS=(
        'System.IO.BinaryReader'
        'System.IO.BinaryWriter'
        'System.IO.Path'
        'System.IO.FileNotFoundException'
    )

    # Extract using statements (exclude "using (" which is using statement syntax)
    local USINGS
    USINGS=$(grep -n "^[[:space:]]*using[[:space:]]" "${FILE}" 2>/dev/null | grep -v "using[[:space:]]*(" || true)

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        local LINE_NUM
        LINE_NUM=$(echo "$line" | cut -d: -f1)
        local USING_STMT
        USING_STMT=$(echo "$line" | cut -d: -f2-)

        # Extract namespace from using statement
        local NAMESPACE
        NAMESPACE=$(echo "$USING_STMT" | sed -E 's/^[[:space:]]*using[[:space:]]+//; s/[[:space:]]*;[[:space:]]*$//')

        # Skip static usings and aliases
        if [[ "$NAMESPACE" == static* ]] || [[ "$NAMESPACE" == *=* ]]; then
            continue
        fi

        # Check against banned patterns
        for BANNED in "${BANNED_PATTERNS[@]}"; do
            if echo "$NAMESPACE" | grep -qE "$BANNED"; then
                # Check if it's an allowed exception
                local IS_EXCEPTION=0
                for EXCEPTION in "${EXCEPTIONS[@]}"; do
                    if [[ "$NAMESPACE" == "$EXCEPTION" ]]; then
                        IS_EXCEPTION=1
                        break
                    fi
                done

                if [ "$IS_EXCEPTION" -eq 0 ]; then
                    echo "VIOLATION: ${FILENAME}:${LINE_NUM}: Banned namespace '${NAMESPACE}'"
                    echo "  ${USING_STMT}"
                    ((VIOLATIONS_FOUND++)) || true
                fi
            fi
        done
    done <<< "$USINGS"
}

check_banned_patterns() {
    local FILE="$1"
    local FILENAME="$2"

    # Pattern checks for common violations
    # Format: "pattern@@description" (using @@ as delimiter to avoid conflicts with regex |)
    local PATTERNS=(
        'System\.IO\.(File|Directory|FileStream|MemoryStream|StreamReader|StreamWriter)@@File/Directory I/O is not allowed'
        'System\.Net\.@@Networking (System.Net) is not allowed'
        'System\.Threading\.(Thread|Parallel[^Q])@@Threading is not allowed'
        'System\.Diagnostics\.(Debug|Trace|Process|Stopwatch)@@Diagnostics namespace is not allowed'
        'System\.Reflection\.(Assembly|MethodInfo|PropertyInfo|FieldInfo)@@Reflection is heavily restricted'
        '(HttpClient|WebClient|HttpWebRequest)@@Network requests are not allowed'
        'Process\.Start@@Starting processes is not allowed'
        'Environment\.(GetEnvironmentVariable|SetEnvironmentVariable|Exit|FailFast)@@Most Environment members are banned'
        'Console\.Write@@Console I/O is not allowed (use Echo() instead)'
        'Console\.Read@@Console I/O is not allowed (use Echo() instead)'
        'Marshal\.@@Interop/Marshal is not allowed'
        'unsafe[[:space:]]+\{@@Unsafe code blocks are not allowed'
        'fixed[[:space:]]*\(@@Fixed pointers are not allowed'
        '\[DllImport@@P/Invoke is not allowed'
    )

    for PATTERN_DESC in "${PATTERNS[@]}"; do
        local PATTERN
        PATTERN="${PATTERN_DESC%%@@*}"
        local DESC
        DESC="${PATTERN_DESC##*@@}"

        # Search for pattern
        local MATCHES
        MATCHES=$(grep -nE "$PATTERN" "$FILE" 2>/dev/null || true)

        while IFS= read -r match; do
            [ -z "$match" ] && continue
            local LINE_NUM
            LINE_NUM=$(echo "$match" | cut -d: -f1)
            local LINE_CONTENT
            LINE_CONTENT=$(echo "$match" | cut -d: -f2-)

            # Skip if line is a comment
            if echo "$LINE_CONTENT" | grep -qE '^[[:space:]]*//' ; then
                continue
            fi
            # Skip if in a block comment (simple check)
            if echo "$LINE_CONTENT" | grep -qE '^[[:space:]]*\*' ; then
                continue
            fi

            echo "VIOLATION: ${FILENAME}:${LINE_NUM}: ${DESC}"
            echo "  $(echo "$LINE_CONTENT" | sed 's/^[[:space:]]*//')"
            ((VIOLATIONS_FOUND++)) || true
        done <<< "$MATCHES"
    done
}
