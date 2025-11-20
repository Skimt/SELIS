#!/usr/bin/env bash
# SELIS remove command implementation

cmd_remove() {
    ########################
    # ARGUMENT / USAGE
    ########################

    if [ "$#" -ne 1 ]; then
        echo "Usage: selis remove <ProjectName>"
        echo "  Example: selis remove MyScript"
        exit 1
    fi

    PROJECT_NAME="$1"

    # Project root is the directory this script is executed from
    PROJECT_ROOT="$(pwd)"

    ########################
    # SCRIPT START
    ########################

    PROJECT_DIR="${PROJECT_ROOT}/${PROJECT_NAME}"
    CS_PROJ="${PROJECT_DIR}/${PROJECT_NAME}.csproj"
    SOLUTION_FILE="${PROJECT_ROOT}/selis.sln"

    echo "-------------------------------------------------------"
    echo "Project removal:"
    echo "  Project: ${PROJECT_NAME}"
    echo "  Path:    ${PROJECT_DIR}"
    echo "-------------------------------------------------------"

    # Check what exists
    PROJECT_DIR_EXISTS=false
    IN_SOLUTION=false

    if [ -d "${PROJECT_DIR}" ]; then
        PROJECT_DIR_EXISTS=true
    fi

    if [ -f "${SOLUTION_FILE}" ] && grep -q "\"${PROJECT_NAME}\"" "${SOLUTION_FILE}"; then
        IN_SOLUTION=true
    fi

    # If nothing exists, warn and exit
    if [ "$PROJECT_DIR_EXISTS" = false ] && [ "$IN_SOLUTION" = false ]; then
        error "Project '${PROJECT_NAME}' not found:
  - No project folder at: ${PROJECT_DIR}
  - Not found in solution file: ${SOLUTION_FILE}"
    fi

    # Confirmation prompt
    echo
    echo "WARNING: This will permanently delete:"
    if [ "$PROJECT_DIR_EXISTS" = true ]; then
        echo "  - Project folder: ${PROJECT_DIR}"
        echo "  - All files inside it"
    fi
    if [ "$IN_SOLUTION" = true ]; then
        echo "  - Entry from solution file: ${SOLUTION_FILE}"
    fi
    if [ "$PROJECT_DIR_EXISTS" = false ]; then
        echo
        echo "NOTE: Project folder does not exist, will only remove from solution."
    fi
    echo
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted. No changes were made."
        exit 0
    fi

    ########################################
    # Remove from solution file
    ########################################

    if [ -f "${SOLUTION_FILE}" ]; then
        echo
        echo "Removing project from solution file..."

        if command -v dotnet >/dev/null 2>&1; then
            # Use dotnet sln to remove the project
            if [ -f "${CS_PROJ}" ]; then
                if dotnet sln "${SOLUTION_FILE}" remove "${CS_PROJ}" 2>/dev/null; then
                    echo "Successfully removed ${PROJECT_NAME} from solution."
                else
                    warn "Project may not be in solution or removal failed."
                fi
            else
                warn ".csproj file not found. Attempting manual removal from solution..."
                # Fallback: try to remove manually by editing the solution file
                if grep -q "\"${PROJECT_NAME}\"" "${SOLUTION_FILE}"; then
                    warn "Found project reference in solution, but dotnet sln remove failed.
      You may need to manually edit: ${SOLUTION_FILE}"
                fi
            fi
        else
            warn "'dotnet' command not found. Cannot automatically remove from solution.
      Please manually remove ${PROJECT_NAME} from: ${SOLUTION_FILE}"
        fi
    fi

    ########################################
    # Delete project directory
    ########################################

    if [ "$PROJECT_DIR_EXISTS" = true ]; then
        echo
        echo "Deleting project directory..."

        if rm -rf "${PROJECT_DIR}"; then
            echo "Successfully deleted: ${PROJECT_DIR}"
        else
            error "Failed to delete project directory."
        fi
    fi

    echo
    echo "-------------------------------------------------------"
    echo "Project '${PROJECT_NAME}' has been removed."
    echo "-------------------------------------------------------"
}
