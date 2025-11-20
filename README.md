# SELIS

**Space Engineers Linux Ingame Scripting**

A development environment for writing and deploying Space Engineers programmable block scripts on Linux systems running the game via Proton/Steam.

> **Note:** This project is inspired by [Malware's MDK-SE](https://github.com/malware-dev/MDK-SE) (now [MDK2](https://github.com/malforge/mdk2)), which provides a Visual Studio extension for Space Engineers scripting on Windows. SELIS offers a lightweight, bash-based alternative optimized for Linux/Proton environments. For MDK's Linux setup guide, see [Running MDK on Linux](https://github.com/malforge/mdk2/wiki/Running-MDK-on-Linux-%28functional%2C-but-unsupported%29).

## Features

- **Full IntelliSense Support** - Write scripts with complete IDE support by referencing Space Engineers DLLs
- **Build Validation** - Optional compilation checks before export to catch errors early
- **Automated Processing** - Automatic namespace/class wrapper stripping and code minification
- **Seamless Integration** - Direct export to Space Engineers' IngameScripts folder
- **Project Scaffolding** - Quick project creation with all necessary boilerplate

## Prerequisites

- **Space Engineers** installed via Steam on Linux (running under Proton)
- **.NET SDK** (for build validation) - `dotnet` command available
- **Bash** shell environment

## Installation

1. Clone this repository:
   ```bash
   git clone <your-repo-url>
   cd selis
   ```

2. Create your configuration file:
   ```bash
   cp selis.conf.example selis.conf
   ```

3. Edit `selis.conf` with your system paths:
   ```bash
   # Update these paths for your system
   steam_root = /home/youruser/.steam/debian-installation/steamapps
   se_appdata = /home/youruser/.steam/debian-installation/steamapps/compatdata/244850/pfx/drive_c/users/steamuser/AppData/Roaming/SpaceEngineers
   se_bin = /home/youruser/.steam/debian-installation/steamapps/common/SpaceEngineers/Bin64
   ```

4. Make scripts executable:
   ```bash
   chmod +x selis create export remove
   ```

## Quick Start

### Create a New Script Project

```bash
./selis create MyNewScript
```

Or using the legacy wrapper:
```bash
./create MyNewScript
```

This creates a new folder with:
- `Program.cs` - Script source with development wrapper
- `MyNewScript.csproj` - Project file with SE DLL references

### Write Your Script

Open the project in your IDE and edit `Program.cs`:

```csharp
namespace MyNewScript
{
  partial class Program : MyGridProgram
  {
    // Your code here
    public void Main(string argument, UpdateType updateSource)
    {
      Echo("Hello, Space Engineers!");
    }
  }
}
```

### Export to Game

```bash
./selis export MyNewScript MyNewScript
```

Or using the legacy wrapper:
```bash
./export MyNewScript MyNewScript
```

This will:
1. Validate your code with `dotnet build` (optional, configured in `selis.conf`)
2. Strip the namespace/class wrapper
3. Minify the code
4. Copy to Space Engineers' IngameScripts folder

### Load in Space Engineers

1. Launch Space Engineers
2. Open a world
3. Access a Programmable Block
4. Click "Edit"
5. Select your script from the local scripts list

### Remove a Project

```bash
./selis remove ProjectName
```

Or using the legacy wrapper:
```bash
./remove ProjectName
```

This will:
1. Prompt for confirmation (requires typing "yes")
2. Remove the project from the solution file
3. Permanently delete the project folder and all its contents

**Warning:** This action cannot be undone!

## How It Works

### Development Wrapper Pattern

Scripts are written with a C# wrapper for IDE support:

```csharp
namespace MyScript
{
  partial class Program : MyGridProgram
  {
    // Your actual game code goes here
  }
}
```

The `export` script automatically:
- Removes the namespace and class wrapper
- Strips comments
- Minifies whitespace
- Exports only the inner code to Space Engineers

### Project Structure

```
selis/
├── MyScript/              # Example project
│   ├── Program.cs         # Script source
│   └── MyScript.csproj    # Project file with SE DLL refs
├── selis.conf             # Configuration file
├── create                 # Project creation script
├── export                 # Export/deployment script
├── remove                 # Project removal script
├── selis.sln              # Visual Studio solution file
└── README.md
```

## Configuration

Edit `selis.conf` to customize behavior:

- `steam_root` - Path to Steam installation
- `se_appdata` - Space Engineers AppData folder (in Proton prefix)
- `se_bin` - Space Engineers Bin64 folder (contains DLLs)
- `main_file` - Source filename (default: `Program.cs`)
- `run_build` - Validate with build before export (`true`/`false`)

## Development Workflow

1. Create project: `./selis create ProjectName`
2. Write code in `ProjectName/Program.cs`
3. Test build: `cd ProjectName && dotnet build -c Release`
4. Export: `./selis export ProjectName ScriptName`
5. Test in-game
6. Iterate: modify code → export → test
7. Remove project when done: `./selis remove ProjectName` (optional)

**Note:** Legacy wrappers (`./create`, `./export`, `./remove`) are still supported for backwards compatibility.

## Important Notes

### Class Name Requirement

⚠️ **The class inside your namespace MUST be named `Program`**. The export script looks for `partial class Program` to strip the wrapper. The namespace can be named anything, but the class must be `Program`.

### Linux/Proton Paths

All paths in `selis.conf` and `.csproj` files are Linux paths that point into:
- Steam's Debian installation layout
- Proton's Windows compatibility prefix (`drive_c` structure)

The game runs under Proton but expects scripts in Windows-style AppData locations within the prefix.

### Space Engineers API Constraints

Space Engineers scripts run in a sandboxed environment:
- Limited API access (only `VRage.*`, `Sandbox.*`, `SpaceEngineers.Game.*`)
- No file I/O, networking, or reflection
- Execution time limits per tick (~0.5ms per frame)

## Contributing

Contributions are welcome! Please ensure:
- Scripts remain compatible with the Space Engineers sandboxed environment
- The wrapper pattern is preserved
- Configuration remains centralized in `selis.conf`