# Run with: pwsh -NoProfile -File ./setup/windows.Tests.ps1
# All installation and Windows-specific operations are mocked.
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
        param($Id)
        $script:installed += $Id
    }
    function global:Install-DotNet10 { $script:actions += 'dotnet10' }
    function global:Set-PoshProfile { $script:actions += 'prompt-font' }
    function global:Install-WslContainers { $script:actions += 'wslc' }
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

Test-Case 'Defaults include Git, gh, both Copilots, Aspire and Elgato apps; Docker and Node are opt-in' {
    Mock-Setup -Answers @('', 'y')
    Start-WindowsSetup
    foreach ($id in @(
        'Git.Git', 'GitHub.cli', 'GitHub.Copilot', 'GitHub.CopilotApp', 'Microsoft.Aspire',
        'Elgato.ControlCenter', 'Elgato.StreamDeck', 'Elgato.CameraHub'
    )) {
        Assert-True ($id -in $script:installed) "Missing default package: $id"
    }
    Assert-True ('Docker.DockerDesktop' -notin $script:installed) 'Docker should be opt-in.'
    Assert-True ('OpenJS.NodeJS.LTS' -notin $script:installed) 'Node should be opt-in.'
    Assert-True (($script:installed -like 'Microsoft.DotNet.SDK*').Count -eq 0) 'Do not install .NET through WinGet.'
    foreach ($action in @('dotnet10', 'prompt-font', 'wslc')) {
        Assert-True ($action -in $script:actions) "Missing default action: $action"
    }
}

Test-Case 'An empty selection makes no changes' {
    Mock-Setup -Answers @('none', '')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0 -and $script:actions.Count -eq 0) 'Empty selection ran setup.'
}

Test-Case 'Custom exact IDs can be added without restoring default selections' {
    Mock-Setup -Answers @('none', 'add', 'Microsoft.PowerToys', '', 'yes')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 1 -and $script:installed[0] -eq 'Microsoft.PowerToys') 'Wrong custom selection.'
}

Test-Case 'Custom packages can be toggled off' {
    Mock-Setup -Answers @('none', 'add', 'Microsoft.PowerToys', '24', '')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0) 'Deselected custom package was installed.'
}

Test-Case 'Invalid IDs and menu numbers are rejected without changing selections' {
    Mock-Setup -Answers @('none', 'add', 'Microsoft.PowerToys; exit', '999', '')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 0) 'Invalid input changed selection.'
}

Test-Case 'Comma-separated toggles enable Docker and Node' {
    Mock-Setup -Answers @('none', '7,18', '', 'y')
    Start-WindowsSetup
    Assert-True ($script:installed.Count -eq 2) 'Unexpected selection count.'
    Assert-True ('Docker.DockerDesktop' -in $script:installed) 'Docker was not selected.'
    Assert-True ('OpenJS.NodeJS.LTS' -in $script:installed) 'Node was not selected.'
}

Test-Case 'Quit and declined confirmation make no changes' {
    foreach ($responses in @(@('q'), @('', 'n'))) {
        Mock-Setup -Answers $responses
        Start-WindowsSetup
    }
    Assert-True ($script:installed.Count -eq 0) 'Cancellation installed packages.'
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
    function global:Invoke-WebRequest { param($Uri, $OutFile, [switch] $UseBasicParsing) }
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
    } finally { [IO.File]::Delete($script:testProfile) }
}

Write-Host 'All Windows setup tests passed.'
