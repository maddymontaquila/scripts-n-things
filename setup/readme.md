# Windows setup

Run in an **elevated PowerShell window using your own Windows account**, not a
different administrator account. User profiles and settings belong to the account
running the script. Windows 11 and a working WinGet (Microsoft Store's App
Installer) are expected.

```powershell
irm https://raw.githubusercontent.com/maddymontaquila/scripts-n-things/main/setup/windows.ps1 | iex
```

This runs the version published on `main`. To use a local checkout instead:

```powershell
.\setup\windows.ps1
```

## Choose what gets installed

The menu shows the selected defaults before making changes:

- Enter numbers separated by commas or spaces to toggle items.
- Enter `all` or `none` to select or clear everything.
- Enter `add` to add an exact WinGet package ID, such as `Microsoft.PowerToys`.
  Use `winget search <name>` to find IDs. Added packages can be toggled too.
- Press Enter to review the selection count and confirm, or `q` to quit.

Deselecting an item **skips it**; it never uninstalls existing software. Custom
packages come from the `winget` source. The script stops on installation errors;
fix the reported issue and rerun, deselecting steps you no longer want.

Defaults include PowerShell 7, .NET 10 via dotnetup, Git, GitHub CLI, GitHub
Copilot CLI (`GitHub.Copilot`), the GitHub Copilot app (`GitHub.CopilotApp`),
Windows Terminal, VS Code Insiders, Oh My Posh with the custom theme and
Meslo Nerd Font, Azure CLI / VPN Client / Developer CLI, Aspire CLI, Discord,
Office, Edge Beta, WSL containers with Ubuntu, taskbar preferences, and Elgato
Control Center / Stream Deck / Camera Hub.
**Docker Desktop and Node.js LTS are initially unchecked.** Aspire CLI is
installed through WinGet (`Microsoft.Aspire`), not its standalone install script.
Existing installed apps are not bulk-upgraded.

Oh My Posh styles the prompt; Nerd Fonts supply the icons. The Oh My Posh
selection installs both the prompt tool and Meslo Nerd Font and configures the
custom prompt. You still need to choose the font in Terminal settings.

## WSL containers

[`wslc` ships with WSL 2.9.3 or newer](https://learn.microsoft.com/en-us/windows/wsl/wsl-container?tabs=csharp).
The WSL selection installs/updates `Microsoft.WSL` through WinGet, runs
`wsl --install --no-distribution` to enable Windows features, runs `wsl --update`,
checks the minimum WSL version and `wslc --help`, and installs Ubuntu if it is
missing. If enabling Windows features requires a restart, setup stops with an
explicit restart/rerun instruction rather than trying to use WSL immediately.
Docker Desktop is not required for `wslc`.

This does not configure Aspire to use `wslc` or guarantee compatibility with
tools that require a Docker-compatible API. Docker Desktop remains an optional
selection for those workflows.

## .NET through dotnetup

[dotnetup is in public preview](https://devblogs.microsoft.com/dotnet/introducing-dotnetup/).
The script downloads its official PowerShell installer into a temporary file,
installs the executable in `$HOME\.dotnetup`, then runs:

```powershell
dotnetup sdk install 10 --interactive false
dotnetup env set shell --shell pwsh
dotnetup dotnet -- --list-sdks
```

This tracks the latest stable SDK within **.NET 10**, rather than following
future major versions. It uses PowerShell 7 **shell mode**, avoiding changes to
the machine-wide .NET installation and PATH. Select PowerShell 7 in the menu if
it is not already installed. Open a new PowerShell 7 window to load the
environment configuration. Other shells, services, and independently launched
apps are not automatically configured; see
[dotnetup environment configuration](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnetup/reference/dotnetup-env-set).
Use `dotnetup update` to update tracked SDKs later.

## Finish after installation

Restart Windows if requested, then launch Ubuntu to create your Linux user.
If you selected Docker Desktop, launch it to complete its first-run setup.
Installing Windows tools does not also provision their equivalents inside Ubuntu.

In Windows Terminal's settings, choose the default terminal application, the
PowerShell 7 default profile, and the installed Meslo Nerd Font. The custom
prompt is added to the actual PowerShell 7 current-user/all-hosts profile.
Taskbar changes take effect after signing out or restarting; Explorer is not
forcibly restarted.

Office licensing, Azure/GitHub authentication, VPN configuration, Git identity,
editor extensions/settings sync, development certificates, Windows updates, and
OEM drivers still need their normal setup.

Launch `copilot` in PowerShell 7 and open the GitHub Copilot app to finish their
authentication/onboarding. These are separate from GitHub CLI (`gh`); the CLI
is the standalone Copilot CLI, not the retired `gh copilot` extension.

## Script checks

Run the platform-independent, mocked checks without installing any apps:

```powershell
pwsh -NoProfile -File ./setup/windows.Tests.ps1
```
