# Run with: pwsh -NoProfile -File ./setup/windows.Tests.ps1
# Installations are mocked; Terminal settings use temporary files.
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'windows.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref] $tokens, [ref] $parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$definitions = $ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst]
}, $false)

function Reset-SetupFunctions {
    foreach ($definition in $definitions) {
        Invoke-Expression "function global:$($definition.Name) $($definition.Body.Extent.Text)"
    }
    $script:installed = @()
    $script:packageSources = @{}
    $script:actions = @()
    $script:answers = [Collections.Generic.Queue[string]]::new()
    $script:commands = @()
    $script:rebootRequired = $false
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (!$Condition) { throw $Message }
}

function Assert-Throws {
    param([scriptblock] $Action, [string] $Message)
    $caught = $null
    try { & $Action } catch { $caught = $_ }
    Assert-True ($null -ne $caught) 'Expected an error.'
    Assert-True ($caught.ToString() -like "*$Message*") "Unexpected error: $caught"
}

function Mock-Setup {
    param([string[]] $Answers)
    foreach ($answer in $Answers) { $script:answers.Enqueue($answer) }
    function global:Read-Host {
        param($Prompt)
        if ($script:answers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }
        return $script:answers.Dequeue()
    }
    function global:Test-SetupAdministrator { return $true }
    function global:Get-Command {
        param($Name, $ErrorAction)
        return [pscustomobject]@{ Source = $Name }
    }
    function global:Install-WinGetPackage {
        param($Id, $Source = 'winget')
        $script:installed += $Id
        $script:packageSources[$Id] = $Source
    }
    function global:Install-DotNet10 { $script:actions += 'dotnet10' }
    function global:Set-PoshProfile { $script:actions += 'prompt-font' }
    function global:Install-WslContainers { $script:actions += 'wslc' }
    function global:Set-GitHubAccess { $script:actions += 'github-auth' }
    function global:Install-NodeWithFnm { $script:actions += 'node-fnm' }
    function global:Set-TerminalSettings { param($UseNerdFont) $script:actions += "terminal-font-$UseNerdFont" }
    function global:Test-Path { param($Path) return $true }
    function global:New-Item { param($Path, [switch] $Force) }
    function global:New-ItemProperty { param($Path, $Name, $Value, $PropertyType, [switch] $Force) }
}

function Test-Case {
    param([string] $Name, [scriptblock] $Body)
    Reset-SetupFunctions
    & $Body
    Write-Host "PASS: $Name"
}

Test-Case 'Defaults include developer, messaging, Elgato, fnm and Terminal setup; Docker and azd are opt-in' {
    Mock-Setup -Answers @('', 'y')
    Start-WindowsSetup
    foreach ($id in @(
        'Git.Git', 'GitHub.cli', 'GitHub.Copilot', 'GitHub.CopilotApp', 'Microsoft.Aspire',
        'Elgato.ControlCenter', 'Elgato.StreamDeck', 'Elgato.CameraHub',
        'OpenWhisperSystems.Signal', 'SlackTechnologies.Slack', 'Discord.Discord', 'Schniz.fnm',
        '9PMX96TSF295', 'Microsoft.PowerToys', 'Audient.iD', 'Logitech.OptionsPlus', '9NCBCSZSJRSB'
    )) {
        Assert-True ($id -in $script:installed) "Missing default package: $id"
    }
    Assert-True ('Docker.DockerDesktop' -notin $script:installed) 'Docker should be opt-in.'
    Assert-True ('Microsoft.Office' -notin $script:installed) 'Office should be installed separately, not block setup.'
    Assert-True ('OpenJS.NodeJS.LTS' -notin $script:installed) 'Do not install standalone Node alongside fnm.'
    Assert-True ('Microsoft.Azure.DevCLI' -notin $script:installed) 'azd should be opt-in.'
    Assert-True ('Microsoft.AzureCLI' -in $script:installed) 'az should remain selected.'
    Assert-True ('github-auth' -notin $script:actions) 'GitHub login should be opt-in.'
    Assert-True ($script:packageSources['9PMX96TSF295'] -eq 'msstore') 'Spend Tray must use the Microsoft Store source.'
    Assert-True ($script:packageSources['9NCBCSZSJRSB'] -eq 'msstore') 'Spotify must use the Microsoft Store source.'
    Assert-True ($script:packageSources['Microsoft.PowerToys'] -eq 'winget') 'PowerToys should use the WinGet source.'
    Assert-True (($script:installed -like 'Microsoft.DotNet.SDK*').Count -eq 0) 'Do not install .NET through WinGet.'
    foreach ($action in @('dotnet10', 'prompt-font', 'wslc', 'node-fnm', 'terminal-font-True')) {
        Assert-True ($action -in $script:actions) "Missing default action: $action"
    }
}

Test-Case 'An empty selection makes no changes' {
    Mock-Setup -Answers @('none', '')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0 -and $script:actions.Count -eq 0) 'Empty selection ran setup.'
}

Test-Case 'Custom exact IDs can be added without restoring default selections' {
    Mock-Setup -Answers @('none', 'add', '7zip.7zip', '', 'yes')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 1 -and $script:installed[0] -eq '7zip.7zip') 'Wrong custom selection.'
}

Test-Case 'Custom packages can be toggled off' {
    Mock-Setup -Answers @('none', 'add', '7zip.7zip', '32', '')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0) 'Deselected custom package was installed.'
}

Test-Case 'Invalid IDs and menu numbers are rejected without changing selections' {
    Mock-Setup -Answers @('none', 'add', 'Microsoft.PowerToys; exit', '999', '')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0) 'Invalid input changed selection.'
}

Test-Case 'Comma-separated toggles enable Docker and fnm' {
    Mock-Setup -Answers @('none', '7,17', '', 'y')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 2) 'Unexpected selection count.'
    Assert-True ('Docker.DockerDesktop' -in $script:installed) 'Docker was not selected.'
    Assert-True ('Schniz.fnm' -in $script:installed) 'fnm was not selected.'
    Assert-True ('node-fnm' -in $script:actions) 'Node was not configured.'
}

Test-Case 'Terminal configuration without Oh My Posh preserves font choice' {
    Mock-Setup -Answers @('none', '26', '', 'y')
    Start-WindowsSetup
    Assert-True ('terminal-font-False' -in $script:actions) 'Terminal should not select an uninstalled Nerd Font.'
}

Test-Case 'Quit and declined confirmation make no changes' {
    foreach ($responses in @(@('q'), @('', 'n'))) {
        Mock-Setup -Answers $responses
        Start-WindowsSetup
    }
    Assert-True ($script:installed.Count -eq 0) 'Cancellation installed packages.'
}

Test-Case 'GitHub authentication can be selected without treating it as a package' {
    Mock-Setup -Answers @('none', '25', '', 'y')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0) 'Authentication was treated as a package.'
    Assert-True ('github-auth' -in $script:actions) 'Authentication step was skipped.'
}

Test-Case 'GitHub access uses browser login and a host-specific Git credential helper' {
    function global:Invoke-Checked {
        param($Command, $Arguments)
        $script:commands += "$Command $($Arguments -join ' ')"
    }
    Set-GitHubAccess
    Assert-True ('gh auth login --hostname github.com --git-protocol https --web' -in $script:commands) 'Missing browser login.'
    Assert-True ('gh auth setup-git --hostname github.com' -in $script:commands) 'Missing Git credential configuration.'
    Assert-True ('gh auth status --hostname github.com' -in $script:commands) 'Missing authentication verification.'
}

Test-Case 'PowerShell dependency is checked before installations' {
    Mock-Setup -Answers @('1', '', 'y')
    function global:Get-Command {
        param($Name, $ErrorAction)
        if ($Name -ne 'pwsh') { return [pscustomobject]@{ Source = $Name } }
    }
    Assert-Throws { Start-WindowsSetup } 'require PowerShell 7'
    Assert-True ($script:installed.Count -eq 0) 'Dependency failure installed packages.'
}

Test-Case 'Native failures stop setup; already-current and reboot codes are handled' {
    function global:fake-native { $global:LASTEXITCODE = $script:nativeCode }
    $script:nativeCode = 42
    Assert-Throws { Invoke-Checked -Command fake-native } 'exit code 42'
    $script:nativeCode = -1978335215
    Assert-Throws { Invoke-Checked -Command fake-native } 'exit code -1978335215'
    $script:nativeCode = -1978335189
    Invoke-Checked -Command fake-native -SuccessCodes @(0, -1978335189)
    foreach ($code in @(3010, -1978334967)) {
        $script:nativeCode = $code
        $script:rebootRequired = $false
        Invoke-Checked -Command fake-native
        Assert-True $script:rebootRequired "Reboot code $code was missed."
    }
    $script:nativeCode = -1978334966
    Assert-Throws { Invoke-Checked -Command fake-native } 'exit code'
    $script:nativeCode = 3010
    Assert-Throws { Invoke-Checked -Command fake-native -StopForReboot } 'Restart Windows and rerun'
}

Test-Case 'WinGet uses exact IDs and explicit source, including for Aspire' {
    function global:Invoke-Checked {
        param($Command, $Arguments, $SuccessCodes)
        $script:commands += [pscustomobject]@{ Command = $Command; Arguments = $Arguments }
    }
    function global:Update-SessionPath {}
    Install-WinGetPackage -Id Microsoft.Aspire
    $call = $script:commands[0]
    Assert-True ($call.Command -eq 'winget') 'Expected WinGet.'
    Assert-True ('Microsoft.Aspire' -in $call.Arguments -and '--exact' -in $call.Arguments) 'Missing exact Aspire ID.'
    Assert-True ('--source' -in $call.Arguments -and 'winget' -in $call.Arguments) 'Missing source.'
    Install-WinGetPackage -Id 9PMX96TSF295 -Source msstore
    $storeCall = $script:commands[1]
    Assert-True ('9PMX96TSF295' -in $storeCall.Arguments -and '--exact' -in $storeCall.Arguments) 'Missing exact Store product ID.'
    Assert-True ($storeCall.Arguments[$storeCall.Arguments.IndexOf('--source') + 1] -eq 'msstore') 'Wrong Store source.'
}

Test-Case 'dotnetup installs channel 10, configures pwsh shell mode, and verifies SDKs' {
    function global:Test-Path { param($Path) return $true }
    function global:Join-Path {
        param($Path, $ChildPath)
        if ($ChildPath -eq 'dotnetup.exe') { return 'fake-dotnetup' }
        return "$Path/$ChildPath"
    }
    function global:Invoke-Checked {
        param($Command, $Arguments)
        $script:commands += ($Arguments -join ' ')
    }
    function global:fake-dotnetup {
        $global:LASTEXITCODE = 0
        return $script:sdkOutput
    }
    $script:sdkOutput = '10.0.100 [managed SDK path]'
    $savedPath = $env:PATH
    try {
        Install-DotNet10
        Assert-True ('sdk install 10 --interactive false' -in $script:commands) 'Wrong SDK channel.'
        Assert-True ('env set shell --shell pwsh' -in $script:commands) 'Wrong environment mode.'
        $script:sdkOutput = '9.0.100 [managed SDK path]'
        Assert-Throws { Install-DotNet10 } 'did not report an installed .NET 10 SDK'
    } finally { $env:PATH = $savedPath }
}

Test-Case 'WSL setup updates WSL, checks wslc, and does not reinstall existing Ubuntu' {
    function global:Install-WinGetPackage { param($Id) $script:installed += $Id }
    function global:Invoke-Checked {
        param($Command, $Arguments)
        $script:commands += "$Command $($Arguments -join ' ')"
    }
    function global:Update-SessionPath {}
    function global:wsl {
        if ($args[0] -eq '--version') { $output = $script:wslVersion } else { $output = $script:distros }
        $global:LASTEXITCODE = 0
        return $output
    }
    $script:wslVersion = "WSL version: 2.9.3.0`0"
    $script:distros = "Ubuntu`0"
    Install-WslContainers
    Assert-True ('Microsoft.WSL' -in $script:installed) 'Missing WSL package.'
    Assert-True ('wsl --update' -in $script:commands) 'WSL was not updated.'
    Assert-True ('wslc --help' -in $script:commands) 'wslc was not checked.'
    Assert-True ('wsl --install --no-distribution' -in $script:commands) 'Windows WSL features were not enabled.'
    Assert-True (!($script:commands -like 'wsl --install -d*')) 'Existing Ubuntu was reinstalled.'
    $script:distros = @()
    Install-WslContainers
    Assert-True ('wsl --install -d Ubuntu --no-launch' -in $script:commands) 'Missing Ubuntu was not installed.'
    $script:wslVersion = 'WSL version: 2.9.2.0'
    Assert-Throws { Install-WslContainers } 'require WSL 2.9.3'
}

Test-Case 'Prompt setup preserves an existing Unicode profile and does not duplicate initialization' {
    $script:testProfile = [IO.Path]::Combine([IO.Path]::GetTempPath(), "setup-profile-$([guid]::NewGuid()).ps1")
    $existingContent = "# Existing profile $([char] 0xE9)`n"
    [IO.File]::WriteAllText($script:testProfile, $existingContent, [Text.Encoding]::Unicode)
    function global:Get-Command {
        param($Name, $ErrorAction)
        return [pscustomobject]@{ Source = 'fake-profile-pwsh' }
    }
    function global:fake-profile-pwsh {
        $global:LASTEXITCODE = 0
        return $script:testProfile
    }
    function global:Invoke-WebRequest {
        param($Uri, $OutFile, [switch] $UseBasicParsing)
        $script:themeUri = $Uri
    }
    function global:Invoke-Checked {
        param($Command, $Arguments)
        $script:commands += "$Command $($Arguments -join ' ')"
    }
    try {
        Set-PoshProfile
        Set-PoshProfile
        $content = [IO.File]::ReadAllText($script:testProfile)
        Assert-True ($content.StartsWith($existingContent)) 'Existing profile content was damaged.'
        Assert-True (([regex]::Matches($content, 'oh-my-posh init pwsh')).Count -eq 1) 'Duplicate prompt initialization.'
        Assert-True ('oh-my-posh font install meslo' -in $script:commands) 'Nerd Font was not installed.'
        Assert-True ($script:themeUri -eq 'https://raw.githubusercontent.com/maddymontaquila/scripts-n-things/main/terminal/madtheme.omp.json') 'Theme should come from this repository.'
    } finally { [IO.File]::Delete($script:testProfile) }
}

Test-Case 'fnm installs LTS, sets the default, and adds project switching to the profile' {
    function global:Invoke-Checked {
        param($Command, $Arguments)
        $script:commands += "$Command $($Arguments -join ' ')"
    }
    function global:Add-PowerShellProfileLine {
        param($Line, $Marker)
        $script:profileLine = $Line
    }
    Install-NodeWithFnm
    Assert-True ('fnm install --lts' -in $script:commands) 'Missing LTS installation.'
    Assert-True ('fnm default lts-latest' -in $script:commands) 'Missing default version.'
    Assert-True ('fnm exec --using default node --version' -in $script:commands) 'Installed Node was not verified.'
    Assert-True ($script:profileLine -eq 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression') 'Missing project switching.'
}

function Invoke-TerminalFixture {
    param([scriptblock] $Body)
    foreach ($name in @('Test-Path', 'New-Item', 'Join-Path', 'Get-Command')) {
        Remove-Item -LiteralPath "Function:\$name" -ErrorAction SilentlyContinue
    }
    $directory = [IO.Path]::Combine([IO.Path]::GetTempPath(), "terminal-setup-$([guid]::NewGuid())")
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    try { & $Body $directory } finally { Remove-Item -LiteralPath $directory -Recurse -Force }
}

Test-Case 'Terminal JSONC keeps settings, backs up the original, and updates the existing PowerShell profile' {
    Invoke-TerminalFixture {
        param($directory)
        $path = Join-Path $directory 'settings.json'
        $original = @'
{
    // Keep user settings even though serialization removes comments.
    "theme": "dark",
    "profiles": {
        "defaults": { "font": { "size": 14 } },
        "list": [
            { "guid": "{existing-pwsh}", "name": "My PowerShell", "source": "Windows.Terminal.PowershellCore", "font": { "size": 16 }, },
            { "guid": "{ubuntu}", "name": "Ubuntu", "colorScheme": "Campbell" },
        ],
    },
}
'@
        [IO.File]::WriteAllText($path, $original)
        Update-TerminalSettingsFile -Path $path -PowerShellPath 'C:\Program Files\PowerShell\7\pwsh.exe' -FontFace 'MesloLGM Nerd Font'
        $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        Assert-True ($settings.defaultProfile -eq '{existing-pwsh}') 'Existing PowerShell profile was not reused.'
        Assert-True ($settings.theme -eq 'dark') 'Unrelated settings changed.'
        Assert-True ($settings.profiles.list.Count -eq 2) 'Extra profile created.'
        Assert-True ($settings.profiles.list[0].font.face -eq 'MesloLGM Nerd Font') 'Font face was not configured.'
        Assert-True ($settings.profiles.list[0].font.size -eq 16) 'Existing font size changed.'
        Assert-True ($settings.profiles.list[1].colorScheme -eq 'Campbell') 'Ubuntu settings changed.'
        $backups = @(Get-ChildItem -LiteralPath $directory -Filter 'settings.json.setup-backup-*')
        Assert-True ($backups.Count -eq 1) 'Missing settings backup.'
        Assert-True ([IO.File]::ReadAllText($backups[0].FullName) -eq $original) 'Backup differs from original.'
        Update-TerminalSettingsFile -Path $path -PowerShellPath 'C:\Program Files\PowerShell\7\pwsh.exe'
        $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        Assert-True ($settings.profiles.list.Count -eq 2) 'Rerun duplicated profile.'
        Assert-True ($settings.profiles.list[0].font.face -eq 'MesloLGM Nerd Font') 'Omitted font option changed the font.'
    }
}

Test-Case 'Terminal settings work before first launch and remain idempotent' {
    Invoke-TerminalFixture {
        param($directory)
        $path = Join-Path $directory 'new/settings.json'
        Update-TerminalSettingsFile -Path $path -PowerShellPath 'C:\Program Files\PowerShell\7\pwsh.exe'
        Update-TerminalSettingsFile -Path $path -PowerShellPath 'C:\Program Files\PowerShell\7\pwsh.exe'
        $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        Assert-True ($settings.profiles.list.Count -eq 1) 'New profile duplicated.'
        Assert-True ($settings.defaultProfile -eq $settings.profiles.list[0].guid) 'Wrong default profile.'
        Assert-True ($settings.profiles.list[0].commandline -eq '"C:\Program Files\PowerShell\7\pwsh.exe"') 'PowerShell path was not quoted.'
        Assert-True ($null -eq $settings.profiles.list[0].font) 'Font should be untouched.'
    }
}

Test-Case 'Invalid Terminal JSON or schema is not overwritten' {
    Invoke-TerminalFixture {
        param($directory)
        $path = Join-Path $directory 'settings.json'
        foreach ($content in @('{invalid', '{"profiles": []}', '{"profiles": {"list": [null]}}')) {
            [IO.File]::WriteAllText($path, $content)
            Assert-Throws { Update-TerminalSettingsFile -Path $path -PowerShellPath 'pwsh.exe' } ''
            Assert-True ([IO.File]::ReadAllText($path) -eq $content) 'Invalid settings were overwritten.'
        }
    }
}

Test-Case 'Terminal wrapper runs the settings editor in a real PowerShell 7 process' {
    Invoke-TerminalFixture {
        param($directory)
        $savedLocalAppData = $env:LOCALAPPDATA
        $script:actualPowerShell = (Get-Process -Id $PID).Path
        function global:Get-Command {
            param($Name, $ErrorAction)
            return [pscustomobject]@{ Source = $script:actualPowerShell }
        }
        try {
            $env:LOCALAPPDATA = $directory
            Set-TerminalSettings -UseNerdFont $true
            $path = Join-Path $directory 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
            $settings = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            Assert-True ($settings.profiles.list[0].font.face -eq 'MesloLGM Nerd Font') 'Child process did not configure Terminal.'
            $unpackagedPath = Join-Path $directory 'Microsoft\Windows Terminal\settings.json'
            [IO.Directory]::CreateDirectory((Split-Path -Parent $unpackagedPath)) | Out-Null
            [IO.File]::WriteAllText($unpackagedPath, '{}')
            Set-TerminalSettings -UseNerdFont $false
            $unpackagedSettings = Get-Content -LiteralPath $unpackagedPath -Raw | ConvertFrom-Json
            Assert-True ($unpackagedSettings.profiles.list.Count -eq 1) 'Existing unpackaged Terminal was not configured.'
        } finally { $env:LOCALAPPDATA = $savedLocalAppData }
    }
}

Write-Host 'All Windows setup tests passed.'
