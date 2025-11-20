#!/usr/bin/env bash
# SELIS create command implementation

cmd_create() {
    ########################
    # ARGUMENT / USAGE
    ########################

    if [ "$#" -ne 1 ]; then
        echo "Usage: selis create <ProjectName>"
        echo "  Example: selis create MyScript"
        exit 1
    fi

    PROJECT_NAME="$1"

    ########################
    # CONFIGURATION
    ########################

    # Read config from [common]
    STEAM_ROOT="$(conf_get common steam_root)"
    if [ -z "${STEAM_ROOT}" ]; then
        error "steam_root is not set in ${CONFIG_FILE} under [common]."
    fi

    SE_BIN="$(conf_get common se_bin)"
    if [ -z "${SE_BIN}" ]; then
        # Fallback: derive from steam_root
        SE_BIN="${STEAM_ROOT}/common/SpaceEngineers/Bin64"
    fi

    MAIN_FILE="$(conf_get common main_file)"
    if [ -z "${MAIN_FILE}" ]; then MAIN_FILE="Program.cs"; fi

    # Project root is the directory this script is EXECUTED FROM
    PROJECT_ROOT="$(pwd)"

    # Template directory
    TEMPLATE_DIR="${SCRIPT_DIR}/lib/templates"

    ########################
    # SCRIPT START
    ########################

    PROJECT_DIR="${PROJECT_ROOT}/${PROJECT_NAME}"

    echo "Target project directory:"
    echo "  ${PROJECT_DIR}"

    # Do not overwrite an existing project
    if [ -d "${PROJECT_DIR}" ]; then
        error "Directory already exists: ${PROJECT_DIR}
Refusing to overwrite. Choose a different project name or remove the folder."
    fi

    mkdir -p "${PROJECT_DIR}"

    ########################
    # Create Program.cs from template
    ########################

    if [ ! -f "${TEMPLATE_DIR}/Program.cs.template" ]; then
        error "Template file not found: ${TEMPLATE_DIR}/Program.cs.template"
    fi

    sed "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
        "${TEMPLATE_DIR}/Program.cs.template" > "${PROJECT_DIR}/${MAIN_FILE}"

    ########################
    # Create .csproj from template
    ########################

    CS_PROJ="${PROJECT_DIR}/${PROJECT_NAME}.csproj"

    if [ ! -f "${TEMPLATE_DIR}/project.csproj.template" ]; then
        error "Template file not found: ${TEMPLATE_DIR}/project.csproj.template"
    fi

    sed -e "s|__PROJECT_NAME__|${PROJECT_NAME}|g" \
        -e "s|__SE_BIN__|${SE_BIN}|g" \
        "${TEMPLATE_DIR}/project.csproj.template" > "${CS_PROJ}"

    ########################
    # Restore dependencies for IntelliSense
    ########################

    echo "-------------------------------------------------------"
    echo "Project created:"
    echo "  ${CS_PROJ}"
    echo

    if command -v dotnet >/dev/null 2>&1; then
        echo "Restoring NuGet packages for IntelliSense..."
        if dotnet restore "${CS_PROJ}"; then
            echo "Restore succeeded. IntelliSense should now work in your IDE."
        else
            warn "Restore failed. IntelliSense may not work until you manually run:
  cd ${PROJECT_DIR} && dotnet restore"
        fi
        echo
    else
        warn "'dotnet' command not found. Run this to enable IntelliSense:
  cd ${PROJECT_DIR} && dotnet restore"
        echo
    fi

    ########################
    # Add project to solution file
    ########################

    SOLUTION_FILE="${PROJECT_ROOT}/selis.sln"

    if [ -f "${SOLUTION_FILE}" ]; then
        echo "Adding project to solution file..."

        # Check if project already exists in solution
        if grep -q "\"${PROJECT_NAME}\"" "${SOLUTION_FILE}"; then
            warn "Project '${PROJECT_NAME}' already exists in solution. Skipping."
        else
            if command -v dotnet >/dev/null 2>&1; then
                # Use dotnet sln to add the project
                if dotnet sln "${SOLUTION_FILE}" add "${CS_PROJ}"; then
                    echo "Successfully added ${PROJECT_NAME} to solution."
                else
                    warn "Failed to add project to solution. You may need to add it manually."
                fi
            else
                warn "'dotnet' not found. Could not add project to solution.
  Add manually with: dotnet sln selis.sln add ${CS_PROJ}"
            fi
        fi
        echo
    fi

    echo "Open this folder in VS Code:"
    echo "  ${PROJECT_DIR}"
    echo "Then export with:"
    echo "  ./selis export ${PROJECT_NAME} ${PROJECT_NAME}"
}
