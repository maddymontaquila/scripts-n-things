# Run in an elevated PowerShell window using your own Windows account.
$ErrorActionPreference = 'Stop'

function Read-YesNo {
    param([string] $Prompt, [bool] $Default = $true)

    $hint = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $answer = (Read-Host "$Prompt [$hint]").Trim()
        if ($answer -eq '') { return $Default }
        if ($answer -match '^(y|yes)$') { return $true }
        if ($answer -match '^(n|no)$') { return $false }
        Write-Warning 'Enter y or n.'
    }
}

function Invoke-Checked {
    param(
        [string] $Command,
        [string[]] $Arguments = @(),
        [int[]] $SuccessCodes = @(0),
        [switch] $StopForReboot
    )

    $PSNativeCommandUseErrorActionPreference = $false
    & $Command @Arguments | Out-Host
    $code = $LASTEXITCODE
    if ($code -in @(3010, 1641, -1978334967, -1978334965)) {
        $script:rebootRequired = $true
        Write-Warning "$Command requires a Windows restart."
        if ($StopForReboot) { throw 'Restart Windows and rerun setup to finish configuring WSL containers and Ubuntu.' }
    } elseif ($code -notin $SuccessCodes) {
        throw "$Command failed with exit code $code. Setup stopped; fix the error and rerun."
    }
}

function Update-SessionPath {
    $env:PATH = @(
        [Environment]::GetEnvironmentVariable('PATH', 'Machine')
        [Environment]::GetEnvironmentVariable('PATH', 'User')
        $env:PATH
    ) -join ';'
}

function Install-WinGetPackage {
    param([string] $Id)

    Write-Host "Installing $Id..." -ForegroundColor Green
    # WinGet also returns UPDATE_NOT_APPLICABLE when the requested app is current.
    Invoke-Checked -Command 'winget' -Arguments @(
        'install', '--id', $Id, '--exact', '--source', 'winget', '--silent',
        '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'
    ) -SuccessCodes @(0, -1978335189)
    Update-SessionPath
}

function Install-DotNet10 {
    Write-Host 'Installing .NET 10 with dotnetup (public preview)...' -ForegroundColor Cyan
    $dotnetupDirectory = Join-Path $HOME '.dotnetup'
    $dotnetup = Join-Path $dotnetupDirectory 'dotnetup.exe'

    if (!(Test-Path $dotnetup)) {
        $installer = Join-Path ([IO.Path]::GetTempPath()) ("get-dotnetup-{0}.ps1" -f [guid]::NewGuid())
        try {
            Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/dotnetup/get-dotnetup.ps1' -OutFile $installer
            # Isolate installer exit statements from the rest of this setup.
            Invoke-Checked -Command (Get-Process -Id $PID).Path -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-InstallDir', $dotnetupDirectory
            )
        } finally {
            if (Test-Path $installer) { Remove-Item -LiteralPath $installer }
        }
    }
    if (!(Test-Path $dotnetup)) { throw "dotnetup was not installed at $dotnetup." }

    Invoke-Checked -Command $dotnetup -Arguments @('sdk', 'install', '10', '--interactive', 'false')
    Invoke-Checked -Command $dotnetup -Arguments @('env', 'set', 'shell', '--shell', 'pwsh')
    $env:PATH = "$dotnetupDirectory;$env:PATH"
    $sdks = & $dotnetup dotnet -- --list-sdks
    if ($LASTEXITCODE -ne 0) { throw 'Could not list dotnetup-managed SDKs.' }
    $sdks | Out-Host
    if (!($sdks -match '^10\.\d+\.\d+\s')) { throw 'dotnetup did not report an installed .NET 10 SDK.' }
}

function Install-WslContainers {
    Install-WinGetPackage -Id 'Microsoft.WSL'
    Invoke-Checked -Command 'wsl' -Arguments @('--install', '--no-distribution') -StopForReboot
    Invoke-Checked -Command 'wsl' -Arguments @('--update')
    $versionOutput = & wsl --version
    if ($LASTEXITCODE -ne 0) { throw 'Could not check the WSL version. Restart Windows and rerun setup.' }
    $versionText = ($versionOutput | Out-String).Replace("`0", '')
    $versionMatch = [regex]::Match($versionText, '\d+\.\d+\.\d+(?:\.\d+)?')
    if (!$versionMatch.Success -or [version] $versionMatch.Value -lt [version] '2.9.3') {
        throw "WSL containers require WSL 2.9.3 or newer. Reported version: $versionText"
    }
    Update-SessionPath
    Invoke-Checked -Command 'wslc' -Arguments @('--help')

    $distributions = & wsl --list --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Could not list WSL distributions. Restart Windows and rerun setup.' }
    $distributionNames = @($distributions | ForEach-Object { $_.Replace("`0", '').Trim() })
    if ('Ubuntu' -notin $distributionNames) {
        Invoke-Checked -Command 'wsl' -Arguments @('--install', '-d', 'Ubuntu', '--no-launch')
        $script:rebootRequired = $true
        Write-Host 'After restarting, launch Ubuntu to finish creating your Linux user.'
    }
}

function Add-PowerShellProfileLine {
    param([string] $Line, [string] $Marker)

    $pwsh = Get-Command pwsh -ErrorAction Stop
    $profileOutput = & $pwsh.Source -NoProfile -Command '$PROFILE.CurrentUserAllHosts'
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate the PowerShell 7 profile.' }
    $profilePath = ($profileOutput | Out-String).Trim()
    if (!$profilePath) { throw 'PowerShell 7 returned an empty profile path.' }

    if (!(Test-Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    }
    $profileContent = [IO.File]::ReadAllText($profilePath)
    if (!$profileContent.Contains($Marker)) {
        Set-Content -LiteralPath $profilePath -Value "$profileContent`n$Line" -Encoding UTF8
    }
}

function Set-PoshProfile {
    $themePath = Join-Path $HOME '.mytheme.omp.json'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/maddymontaquila/scripts-n-things/main/terminal/madtheme.omp.json' -OutFile $themePath
    $ompInit = "oh-my-posh init pwsh --config '$($themePath.Replace("'", "''"))' | Invoke-Expression"
    Add-PowerShellProfileLine -Line $ompInit -Marker 'oh-my-posh init pwsh'
    Invoke-Checked -Command 'oh-my-posh' -Arguments @('font', 'install', 'meslo')
}

function Install-NodeWithFnm {
    Invoke-Checked -Command 'fnm' -Arguments @('install', '--lts')
    Invoke-Checked -Command 'fnm' -Arguments @('default', 'lts-latest')
    Invoke-Checked -Command 'fnm' -Arguments @('exec', '--using', 'default', 'node', '--version')
    Add-PowerShellProfileLine -Line 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression' -Marker 'fnm env'
    Invoke-Checked -Command 'fnm' -Arguments @('list')
    Write-Host 'Open a new PowerShell 7 window to use Node. fnm switches versions using .node-version or .nvmrc.'
}

function Update-TerminalSettingsFile {
    param([string] $Path, [string] $PowerShellPath, [string] $FontFace = '')

    # Run in PowerShell 7 to read Terminal JSON with comments and trailing commas.
    $settings = if (Test-Path $Path) {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
    } else { @{} }
    if ($settings -isnot [Collections.IDictionary]) { throw "Invalid Terminal settings object: $Path" }
    if (!$settings.Contains('profiles')) { $settings['profiles'] = @{} }
    if ($settings['profiles'] -isnot [Collections.IDictionary]) { throw "Invalid Terminal profiles object: $Path" }
    $profiles = $settings['profiles']
    if (!$profiles.Contains('list')) { $profiles['list'] = @() }
    if ($profiles['list'] -isnot [array]) { throw "Invalid Terminal profiles list: $Path" }
    foreach ($profile in $profiles['list']) {
        if ($profile -isnot [Collections.IDictionary]) { throw "Invalid Terminal profile entry: $Path" }
    }

    $profile = $profiles['list'] | Where-Object {
        $_['source'] -eq 'Windows.Terminal.PowershellCore' -and $_['hidden'] -ne $true
    } | Select-Object -First 1
    if (!$profile) {
        $profile = $profiles['list'] | Where-Object {
            $_['guid'] -eq '{64d9d19a-e036-4f98-91be-52ef9dbf8c31}'
        } | Select-Object -First 1
        if (!$profile) {
            $profile = @{ guid = '{64d9d19a-e036-4f98-91be-52ef9dbf8c31}'; name = 'PowerShell 7 (setup)' }
            $profiles['list'] = @($profiles['list']) + @($profile)
        }
        $profile['commandline'] = '"' + $PowerShellPath + '"'
        $profile['hidden'] = $false
    }
    if (!$profile['guid']) { throw "PowerShell Terminal profile has no GUID: $Path" }
    $settings['defaultProfile'] = $profile['guid']
    if ($FontFace) {
        if (!$profile.Contains('font')) { $profile['font'] = @{} }
        if ($profile['font'] -isnot [Collections.IDictionary]) { throw "Invalid PowerShell font settings: $Path" }
        $profile['font']['face'] = $FontFace
    }
    $json = $settings | ConvertTo-Json -Depth 100
    $directory = Split-Path -Parent $Path
    if (!(Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    if (Test-Path $Path) {
        $backup = "$Path.setup-backup-$([guid]::NewGuid())"
        Copy-Item -LiteralPath $Path -Destination $backup
        Write-Host "Terminal settings backup: $backup"
    }
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
    Write-Host "Configured Terminal PowerShell profile: $Path"
}

function Set-TerminalSettings {
    param([bool] $UseNerdFont)

    $pwsh = (Get-Command pwsh -ErrorAction Stop).Source
    $packagedPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    $unpackagedPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json'
    $paths = @($packagedPath, $unpackagedPath | Where-Object { Test-Path $_ })
    if ($paths.Count -eq 0) { $paths = @($packagedPath) }
    $font = if ($UseNerdFont) { 'MesloLGM Nerd Font' } else { '' }
    foreach ($path in $paths) {
        $command = @"
function Update-TerminalSettingsFile {
$(${function:Update-TerminalSettingsFile}.ToString())
}
Update-TerminalSettingsFile -Path '$($path.Replace("'", "''"))' -PowerShellPath '$($pwsh.Replace("'", "''"))' -FontFace '$font'
"@
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("`$ErrorActionPreference = 'Stop'`n$command"))
        Invoke-Checked -Command $pwsh -Arguments @('-NoProfile', '-OutputFormat', 'Text', '-EncodedCommand', $encodedCommand)
    }
    Write-Host 'PowerShell 7 is the Terminal default profile. The OS default terminal application is still set in Terminal > Settings > Startup.'
}

function Test-SetupAdministrator {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-GitHubAccess {
    Write-Host 'Complete GitHub sign-in in your browser, including your organization SSO if prompted.' -ForegroundColor Cyan
    Invoke-Checked -Command 'gh' -Arguments @('auth', 'login', '--hostname', 'github.com', '--git-protocol', 'https', '--web')
    Invoke-Checked -Command 'gh' -Arguments @('auth', 'setup-git', '--hostname', 'github.com')
    Invoke-Checked -Command 'gh' -Arguments @('auth', 'status', '--hostname', 'github.com')
    Write-Host 'Org access still requires membership, SSO authorization, and any organization approval/device requirements.'
    Write-Host 'Visit https://github.com/orgs/YOUR-ORG/sso, then verify access with: gh repo view YOUR-ORG/PRIVATE-REPO'
}

function Start-WindowsSetup {
    if (!(Test-SetupAdministrator)) {
        throw 'Run this script in an elevated PowerShell window using your own Windows account.'
    }

    $script:rebootRequired = $false
    $options = @(
        [pscustomobject]@{ Name = 'PowerShell 7'; Id = 'Microsoft.PowerShell'; Selected = $true }
        [pscustomobject]@{ Name = '.NET 10 SDK via dotnetup (preview)'; Id = 'dotnetup'; Selected = $true }
        [pscustomobject]@{ Name = 'Git'; Id = 'Git.Git'; Selected = $true }
        [pscustomobject]@{ Name = 'GitHub CLI'; Id = 'GitHub.cli'; Selected = $true }
        [pscustomobject]@{ Name = 'GitHub Copilot CLI'; Id = 'GitHub.Copilot'; Selected = $true }
        [pscustomobject]@{ Name = 'GitHub Copilot app'; Id = 'GitHub.CopilotApp'; Selected = $true }
        [pscustomobject]@{ Name = 'Docker Desktop'; Id = 'Docker.DockerDesktop'; Selected = $false }
        [pscustomobject]@{ Name = 'Windows Terminal'; Id = 'Microsoft.WindowsTerminal'; Selected = $true }
        [pscustomobject]@{ Name = 'VS Code Insiders'; Id = 'Microsoft.VisualStudioCode.Insiders'; Selected = $true }
        [pscustomobject]@{ Name = 'Oh My Posh + prompt + Meslo Nerd Font'; Id = 'JanDeDobbeleer.OhMyPosh'; Selected = $true }
        [pscustomobject]@{ Name = 'Azure CLI'; Id = 'Microsoft.AzureCLI'; Selected = $true }
        [pscustomobject]@{ Name = 'Azure VPN Client'; Id = 'Microsoft.AzureVPNClient'; Selected = $true }
        [pscustomobject]@{ Name = 'Azure Developer CLI'; Id = 'Microsoft.Azure.DevCLI'; Selected = $false }
        [pscustomobject]@{ Name = 'Aspire CLI'; Id = 'Microsoft.Aspire'; Selected = $true }
        [pscustomobject]@{ Name = 'Discord'; Id = 'Discord.Discord'; Selected = $true }
        [pscustomobject]@{ Name = 'Microsoft Office'; Id = 'Microsoft.Office'; Selected = $true }
        [pscustomobject]@{ Name = 'Microsoft Edge Beta'; Id = 'Microsoft.Edge.Beta'; Selected = $true }
        [pscustomobject]@{ Name = 'fnm + Node.js LTS + automatic project version switching'; Id = 'Schniz.fnm'; Selected = $true }
        [pscustomobject]@{ Name = 'WSL containers (wslc) + Ubuntu (restart may be needed)'; Id = 'wsl'; Selected = $true }
        [pscustomobject]@{ Name = 'Hide Widgets and use taskbar search icon'; Id = 'taskbar'; Selected = $true }
        [pscustomobject]@{ Name = 'Elgato Control Center'; Id = 'Elgato.ControlCenter'; Selected = $true }
        [pscustomobject]@{ Name = 'Elgato Stream Deck'; Id = 'Elgato.StreamDeck'; Selected = $true }
        [pscustomobject]@{ Name = 'Elgato Camera Hub'; Id = 'Elgato.CameraHub'; Selected = $true }
        [pscustomobject]@{ Name = 'Signal'; Id = 'OpenWhisperSystems.Signal'; Selected = $true }
        [pscustomobject]@{ Name = 'Slack'; Id = 'SlackTechnologies.Slack'; Selected = $true }
        [pscustomobject]@{ Name = 'GitHub browser sign-in + HTTPS Git credentials (interactive)'; Id = 'github-auth'; Selected = $false }
        [pscustomobject]@{ Name = 'Terminal: PowerShell 7 default profile + Nerd Font if selected'; Id = 'terminal-settings'; Selected = $true }
    )

    Write-Host 'Select your Windows setup. Nothing is installed until you confirm.' -ForegroundColor Cyan
    Write-Host 'Removing an item from this list skips it; it does not uninstall existing software.'
    while ($true) {
        for ($i = 0; $i -lt $options.Count; $i++) {
            $mark = if ($options[$i].Selected) { 'x' } else { ' ' }
            Write-Host ('{0,2}. [{1}] {2}' -f ($i + 1), $mark, $options[$i].Name)
        }
        $answer = (Read-Host 'Toggle numbers (e.g. 3,8), all, none, add, q to quit, or Enter to continue').Trim()
        if ($answer -eq '') { break }
        if ($answer -eq 'q') { return }
        if ($answer -in @('all', 'none')) {
            foreach ($option in $options) { $option.Selected = ($answer -eq 'all') }
        } elseif ($answer -eq 'add') {
            $id = (Read-Host 'Exact WinGet package ID (e.g. Microsoft.PowerToys)').Trim()
            if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*\.[A-Za-z0-9._+-]+$') {
                Write-Warning 'Enter an exact WinGet package ID, not a command or app display name.'
            } elseif ($id -in $options.Id) {
                Write-Warning 'That package is already in the list; toggle its number instead.'
            } else {
                $options += [pscustomobject]@{ Name = $id; Id = $id; Selected = $true }
            }
        } else {
            $numbers = @($answer -split '[,\s]+' | Where-Object { $_ -ne '' })
            $indices = @()
            foreach ($number in $numbers) {
                $index = 0
                if (![int]::TryParse($number, [ref] $index) -or $index -lt 1 -or $index -gt $options.Count) {
                    $indices = @()
                    Write-Warning 'Enter numbers from the list.'
                    break
                }
                $indices += $index - 1
            }
            foreach ($index in ($indices | Select-Object -Unique)) {
                $options[$index].Selected = !$options[$index].Selected
            }
        }
    }

    $selected = @($options | Where-Object Selected)
    if ($selected.Count -eq 0) {
        Write-Host 'Nothing selected. No changes made.'
        return
    }
    if (!(Read-YesNo "Apply these $($selected.Count) selections?")) { return }

    $packageOptions = @($selected | Where-Object { $_.Id -notin @('dotnetup', 'wsl', 'taskbar', 'github-auth', 'terminal-settings') })
    if (($packageOptions.Count -gt 0 -or 'wsl' -in $selected.Id) -and !(Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'WinGet is unavailable. Install/update App Installer from Microsoft Store, open a new terminal, and rerun.'
    }
    if (@($selected.Id | Where-Object { $_ -in @('JanDeDobbeleer.OhMyPosh', 'dotnetup', 'GitHub.Copilot', 'Schniz.fnm', 'terminal-settings') }).Count -gt 0 -and
        'Microsoft.PowerShell' -notin $selected.Id -and !(Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw 'The selected shell configuration steps require PowerShell 7. Select it in the menu or install it first.'
    }
    if ('terminal-settings' -in $selected.Id -and 'Microsoft.WindowsTerminal' -notin $selected.Id -and
        !(Get-Command wt -ErrorAction SilentlyContinue)) {
        throw 'Terminal settings require Windows Terminal. Select it in the menu or install it first.'
    }
    if ('github-auth' -in $selected.Id) {
        foreach ($dependency in @(
            @{ Id = 'Git.Git'; Command = 'git' },
            @{ Id = 'GitHub.cli'; Command = 'gh' }
        )) {
            if ($dependency.Id -notin $selected.Id -and !(Get-Command $dependency.Command -ErrorAction SilentlyContinue)) {
                throw "GitHub sign-in requires $($dependency.Id). Select it in the menu or install it first."
            }
        }
    }

    foreach ($option in $packageOptions) {
        Install-WinGetPackage -Id $option.Id
    }
    if ('dotnetup' -in $selected.Id) { Install-DotNet10 }
    if ('JanDeDobbeleer.OhMyPosh' -in $selected.Id) { Set-PoshProfile }
    if ('Schniz.fnm' -in $selected.Id) { Install-NodeWithFnm }
    if ('terminal-settings' -in $selected.Id) {
        Set-TerminalSettings -UseNerdFont ('JanDeDobbeleer.OhMyPosh' -in $selected.Id)
    }
    if ('github-auth' -in $selected.Id) { Set-GitHubAccess }

    if ('wsl' -in $selected.Id) { Install-WslContainers }
    if ('taskbar' -in $selected.Id) {
        $advancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        $searchKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
        foreach ($key in @($advancedKey, $searchKey)) {
            if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        }
        New-ItemProperty -Path $advancedKey -Name TaskbarDa -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $searchKey -Name SearchboxTaskbarMode -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Host 'Taskbar settings saved. Sign out or restart Windows to apply them.'
    }

    Write-Host 'Selected setup steps completed. Open a new terminal before using installed tools.' -ForegroundColor Green
    if ($script:rebootRequired) { Write-Warning 'Restart Windows before using WSL / Docker.' }
    if ('Microsoft.WindowsTerminal' -in $selected.Id) {
        Write-Host 'Terminal > Settings > Startup: choose Windows Terminal as the OS default terminal application.'
    }
    if ('Docker.DockerDesktop' -in $selected.Id) {
        Write-Host 'Launch Docker Desktop to finish setup and enable Ubuntu integration if wanted.'
    }
    if ('GitHub.Copilot' -in $selected.Id -or 'GitHub.CopilotApp' -in $selected.Id) {
        Write-Host 'Launch copilot and the GitHub Copilot app to sign in. Organization policies may govern access.'
    }
    if ('GitHub.cli' -in $selected.Id -and 'github-auth' -notin $selected.Id) {
        Write-Host 'GitHub org access: run gh auth login --hostname github.com --git-protocol https --web, then gh auth setup-git --hostname github.com.'
        Write-Host 'Complete organization SSO/approval and verify a private repo. See setup/readme.md for the checklist.'
    }
    if ('dotnetup' -in $selected.Id) {
        Write-Host '.NET 10 is managed by dotnetup in PowerShell 7 shell mode, not installed machine-wide.'
    }
}

Start-WindowsSetup
