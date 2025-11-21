#!/usr/bin/env bash
# SELIS export command implementation

cmd_export() {
    ########################
    # ARGUMENT / USAGE
    ########################

    if [ "$#" -ne 2 ]; then
        echo "Usage: selis export <ProjectFolderName> <IngameScriptName>"
        echo "  Example: selis export MyScript MyScript"
        echo "           selis export MyCoolProject MyCoolPBScript"
        exit 1
    fi

    PROJECT_NAME="$1"
    INGAME_SCRIPT_NAME="$2"

    ########################
    # CONFIGURATION
    ########################

    # Read config from [common]
    STEAM_ROOT="$(conf_get common steam_root)"
    if [ -z "${STEAM_ROOT}" ]; then
        error "steam_root is not set in ${CONFIG_FILE} under [common]."
    fi

    SE_APPDATA="$(conf_get common se_appdata)"
    if [ -z "${SE_APPDATA}" ]; then
        error "se_appdata is not set in ${CONFIG_FILE} under [common]."
    fi

    MAIN_FILE="$(conf_get common main_file)"
    if [ -z "${MAIN_FILE}" ]; then MAIN_FILE="Program.cs"; fi

    RUN_BUILD="$(conf_get common run_build)"
    if [ -z "${RUN_BUILD}" ]; then RUN_BUILD="true"; fi

    RUN_VALIDATE="$(conf_get common run_validate)"
    if [ -z "${RUN_VALIDATE}" ]; then RUN_VALIDATE="true"; fi

    # Project root is always the directory this script is executed from
    PROJECT_ROOT="$(pwd)"

    ########################
    # SCRIPT START
    ########################

    PROJECT_DIR="${PROJECT_ROOT}/${PROJECT_NAME}"

    # Ensure the project folder exists
    if [ ! -d "${PROJECT_DIR}" ]; then
        error "Project folder '${PROJECT_NAME}' does not exist in: ${PROJECT_ROOT}"
    fi

    CSPROJ_FILE="${PROJECT_DIR}/${PROJECT_NAME}.csproj"

    INGAME_SCRIPTS_ROOT="${SE_APPDATA}/IngameScripts/local"
    DEST_DIR="${INGAME_SCRIPTS_ROOT}/${INGAME_SCRIPT_NAME}"
    DEST_FILE="${DEST_DIR}/script.cs"

    echo "Project folder: ${PROJECT_DIR}"
    echo "Export name:    ${INGAME_SCRIPT_NAME}"

    # Count .cs files in project
    CS_FILE_COUNT=$(find "${PROJECT_DIR}" -maxdepth 1 -name "*.cs" -type f | wc -l)
    if [ "${CS_FILE_COUNT}" -eq 0 ]; then
        error "No .cs files found in project directory: ${PROJECT_DIR}"
    fi
    echo "Source files:   ${CS_FILE_COUNT} .cs file(s) found"

    if [ ! -d "${INGAME_SCRIPTS_ROOT}" ]; then
        error "Ingame scripts root folder not found: ${INGAME_SCRIPTS_ROOT}
Have you launched Space Engineers at least once?"
    fi

    mkdir -p "${DEST_DIR}"

    ########################################
    # Optional whitelist validation
    ########################################

    if [ "${RUN_VALIDATE}" = "true" ]; then
        echo "Running whitelist validation..."
        source "${SCRIPT_DIR}/lib/validate.sh"
        if ! cmd_validate "${PROJECT_NAME}"; then
            error "Whitelist validation failed. Aborting export."
        fi
        echo
    fi

    ########################################
    # Optional build to validate the code
    ########################################

    if [ "${RUN_BUILD}" = "true" ]; then
        if [ ! -f "${CSPROJ_FILE}" ]; then
            warn "RUN_BUILD=true but no csproj found at: ${CSPROJ_FILE}
Skipping build."
        else
            if command -v dotnet >/dev/null 2>&1; then
                echo "Running dotnet build for validation..."
                if ! dotnet build "${CSPROJ_FILE}" -c Release; then
                    error "Build failed. Aborting export."
                fi
                echo "Build succeeded."
            elif command -v msbuild >/dev/null 2>&1; then
                echo "Running msbuild for validation..."
                if ! msbuild "${CSPROJ_FILE}" /p:Configuration=Release; then
                    error "Build failed. Aborting export."
                fi
                echo "Build succeeded."
            else
                warn "RUN_BUILD=true but neither 'dotnet' nor 'msbuild' was found.
Skipping build; export will proceed without validation."
            fi
        fi
    fi

    ########################################
    # Bundle sources + minify + export
    ########################################

    echo "Bundling .cs files, stripping wrappers, minifying and exporting..."

    "${SCRIPT_DIR}/lib/bundle.sh" "${PROJECT_DIR}" | "${SCRIPT_DIR}/lib/minify.sh" > "${DEST_FILE}"

    echo "-------------------------------------------------------"
    echo "Exported processed script to:"
    echo "  ${DEST_FILE}"
    echo
    echo "In Space Engineers:"
    echo "  - Open a world"
    echo "  - Programmable Block > Edit"
    echo "  - Load your script from the local scripts list (name: ${INGAME_SCRIPT_NAME})."
}
