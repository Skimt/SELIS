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
    # Create Program.cs
    ########################

    cat > "${PROJECT_DIR}/${MAIN_FILE}" <<EOF
using Sandbox.Game.EntityComponents;
using Sandbox.ModAPI.Ingame;
using Sandbox.ModAPI.Interfaces;
using SpaceEngineers.Game.ModAPI.Ingame;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using VRage;
using VRage.Collections;
using VRage.Game;
using VRage.Game.Components;
using VRage.Game.GUI.TextPanel;
using VRage.Game.ModAPI.Ingame;
using VRage.Game.ModAPI.Ingame.Utilities;
using VRage.Game.ObjectBuilders.Definitions;
using VRageMath;

namespace ${PROJECT_NAME}
{
    partial class Program : MyGridProgram
    {
        int ticks;

        public Program()
        {
            Runtime.UpdateFrequency = UpdateFrequency.Update100;
            Echo("Starting...");
        }

        public void Main(string argument, UpdateType updateSource)
        {
            ticks++;
            Echo(\$"Ticks: {ticks}");
        }
    }
}
EOF

    ########################
    # Create .csproj with references
    ########################

    CS_PROJ="${PROJECT_DIR}/${PROJECT_NAME}.csproj"

    cat > "${CS_PROJ}" <<EOF
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <!-- This is mainly for IntelliSense / compilation checks. -->
    <TargetFramework>net48</TargetFramework>
    <OutputType>Library</OutputType>
    <LangVersion>latest</LangVersion>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
    <Nullable>disable</Nullable>
    <RootNamespace>${PROJECT_NAME}</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <Reference Include="Sandbox.Common">
      <HintPath>${SE_BIN}/Sandbox.Common.dll</HintPath>
    </Reference>
    <Reference Include="Sandbox.Game">
      <HintPath>${SE_BIN}/Sandbox.Game.dll</HintPath>
    </Reference>
    <Reference Include="Sandbox.Graphics">
      <HintPath>${SE_BIN}/Sandbox.Graphics.dll</HintPath>
    </Reference>
    <Reference Include="SpaceEngineers.Game">
      <HintPath>${SE_BIN}/SpaceEngineers.Game.dll</HintPath>
    </Reference>
    <Reference Include="SpaceEngineers.ObjectBuilders">
      <HintPath>${SE_BIN}/SpaceEngineers.ObjectBuilders.dll</HintPath>
    </Reference>
    <Reference Include="System.Collections.Immutable">
      <HintPath>${SE_BIN}/System.Collections.Immutable.dll</HintPath>
    </Reference>
    <Reference Include="VRage">
      <HintPath>${SE_BIN}/VRage.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Audio">
      <HintPath>${SE_BIN}/VRage.Audio.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Game">
      <HintPath>${SE_BIN}/VRage.Game.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Input">
      <HintPath>${SE_BIN}/VRage.Input.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Library">
      <HintPath>${SE_BIN}/VRage.Library.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Math">
      <HintPath>${SE_BIN}/VRage.Math.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Render">
      <HintPath>${SE_BIN}/VRage.Render.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Render11">
      <HintPath>${SE_BIN}/VRage.Render11.dll</HintPath>
    </Reference>
    <Reference Include="VRage.Scripting">
      <HintPath>${SE_BIN}/VRage.Scripting.dll</HintPath>
    </Reference>
  </ItemGroup>

</Project>
EOF

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
