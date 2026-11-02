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
Meslo Nerd Font, Azure CLI / VPN Client, Aspire CLI, Discord,
Office, Edge Beta, WSL containers with Ubuntu, taskbar preferences, and Elgato
Control Center / Stream Deck / Camera Hub. Signal and Slack are selected too;
Discord remains selected.
fnm with Node.js LTS and Terminal configuration are also selected by default.
**Docker Desktop and Azure Developer CLI (`azd`) are initially unchecked.**
Azure CLI (`az`) remains selected. Aspire CLI is
installed through WinGet (`Microsoft.Aspire`), not its standalone install script.
Existing installed apps are not bulk-upgraded.

Oh My Posh styles the prompt; Nerd Fonts supply the icons. The Oh My Posh
selection installs both the prompt tool and Meslo Nerd Font and configures the
custom prompt from this repository's
[`terminal/madtheme.omp.json`](../terminal/madtheme.omp.json), not the old
ohmyposh-config repository. It includes contextual Aspire AppHost/running status
and the active Node version in Node projects. With Terminal configuration
selected, the font is applied to the PowerShell 7 profile automatically.

## Terminal settings

The selected-by-default Terminal configuration step makes PowerShell 7 the
default profile. If Oh My Posh/Meslo is also selected, it sets that profile's
font to `MesloLGM Nerd Font`; otherwise it leaves the font unchanged.
PowerShell 7 and Windows Terminal must be installed or selected.

Existing stable packaged or unpackaged Terminal settings are updated; a fresh
install is configured before its first launch. Other profiles and settings
are preserved, and an existing PowerShell dynamic profile is reused when
available. Each existing settings file gets a uniquely named
`settings.json.setup-backup-*` copy before writing. JSON comments and formatting
are normalized when the settings are saved; invalid settings stop setup rather
than being replaced. Terminal Preview is not modified.

The **OS default terminal application** is separate from the default shell
profile. Select Windows Terminal under Terminal > Settings > Startup for that
OS setting; setup does not use unsupported CLI flags or hardcoded delegation
registry values.

## Node versions with fnm

Setup installs [fnm](https://github.com/Schniz/fnm) through WinGet (`Schniz.fnm`),
then installs the current Node.js LTS and makes it the default. It does not
install a second standalone Node.js package. fnm is useful for switching
between projects without replacing one machine-wide Node installation.

The PowerShell 7 profile gets:

```powershell
fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
```

Open a new PowerShell 7 window after setup. `.node-version` and `.nvmrc` files
select the project version automatically as you change directories. Install
each project's required version first:

```powershell
fnm install 22
fnm use 22
# Or, from a project containing .node-version / .nvmrc:
fnm install
fnm use
node --version
npm --version
```

Do not install standalone Node or configure another version manager alongside
fnm unless you intentionally manage their PATH precedence. This configures
Windows PowerShell 7, not Ubuntu's shell.

## GitHub organization access

The **GitHub browser sign-in + HTTPS Git credentials** menu item is opt-in.
It requires Git and GitHub CLI (both selected by default), opens browser/device
authentication, configures Git to use `gh` as its HTTPS credential helper for
github.com, and checks login status. It does not create SSH keys or ask you to
paste tokens into this script. You can also run it later:

```powershell
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git --hostname github.com
gh auth status --hostname github.com
```

Installing software or logging in does **not** grant organization membership.
Finish these steps as required by your organization:

- Accept invitations and enable the required 2FA/passkey.
- Visit `https://github.com/orgs/YOUR-ORG/sso` and sign in through the identity
  provider. Authorize GitHub CLI's OAuth access to the organization; request
  administrator approval if the organization restricts OAuth apps.
- Verify actual private-repository access with
  `gh repo view YOUR-ORG/PRIVATE-REPO`. Login status alone does not verify SSO.
  If authorization is missing, establish the browser SSO session and rerun
  `gh auth login --hostname github.com --git-protocol https --web`.
- Complete any company device enrollment, VPN/IP allowlist, and conditional
  access requirements using your organization's instructions. There is no
  universal GitHub organization-access app to install.

Git for Windows and `gh` cover the HTTPS workflow; no separate SSH setup is
needed unless you prefer SSH. Set your Git commit name/email separately using
your approved identity. Copilot CLI/app sign-in and organization Copilot policies
are separate. For GitHub Enterprise hosts, use the actual hostname instead of
`github.com` in the commands above.

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

In Windows Terminal's settings, choose the OS default terminal application.
PowerShell 7 and Meslo are configured by the Terminal setup selection.
The custom prompt and fnm initialization are added to the actual PowerShell 7
current-user/all-hosts profile without duplicating them on reruns.
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
