# PowerShell prompt

`madtheme.omp.json` is the theme used by the Windows setup script. It keeps the
purple path/time, Git status, .NET SDK, and command-status segments and adds:

- **Aspire:** the detected AppHost name and a check mark when it is running.
  Oh My Posh uses `aspire extension get-apphosts` to locate the AppHost and
  `aspire ps --format json` for running status. The segment is hidden when no
  AppHost is found.
- **Node:** the active Node version in directories with Node/JavaScript/
  TypeScript project files, including `.node-version` and `.nvmrc`. With fnm
  initialized, this follows the version selected for the project. It is hidden
  outside matching project directories or when Node is unavailable.

Use a current Oh My Posh release with Aspire segment support, the Aspire CLI,
and Node via fnm. Meslo Nerd Font supplies the prompt icons.

Setup downloads the theme from **this repository** into
`$HOME\.mytheme.omp.json`, so existing PowerShell profile initialization continues
to work. After the changes are merged to `main`, refresh an existing installation
without running the full setup:

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/maddymontaquila/scripts-n-things/main/terminal/madtheme.omp.json' -OutFile "$HOME\.mytheme.omp.json"
```

The next prompt uses the updated theme. To try the theme from a local checkout
in the current PowerShell session instead:

```powershell
oh-my-posh init pwsh --config "$PWD\terminal\madtheme.omp.json" | Invoke-Expression
```
