# windows.ps1
# Run as Administrator

# Ensure elevation
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "`n❌ This script must be run as Administrator. Please right-click and choose 'Run as Administrator'." -ForegroundColor Red
    Read-Host -Prompt "Press Enter to exit"
    exit
}

Write-Output "💻 Setting up your Windows dev machine..."

# Update Winget first
Write-Output "⬆️ Updating Winget..."
winget upgrade --all --silent

Write-Host "🔄 Installing latest PowerShell..." -ForegroundColor Cyan
winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements

# Install essential dev tools
$apps = @(
    "Microsoft.DotNet.SDK.9",               # .NET SDK 9
    "Docker.DockerDesktop",                 # Docker Desktop
    "Microsoft.WindowsTerminal",           # Windows Terminal
    "Microsoft.VisualStudioCode.Insiders", # VS Code Insiders
    "JanDeDobbeleer.OhMyPosh",             # Oh My Posh
    "Microsoft.AzureCLI",                  # Azure CLI
    "Microsoft.AzureVPNClient",            # Azure VPN Client
    "Microsoft.Azure.DevCLI",              # Azure Developer CLI
    "Discord.Discord",                     # Discord
    "Microsoft.Office"
)

foreach ($app in $apps) {
    Write-Host "📦 Installing $app..." -ForegroundColor Green
    winget install --id $app --silent --accept-source-agreements --accept-package-agreements
}

# Install WSL2 and Ubuntu
Write-Host "🐧 Installing WSL2 and Ubuntu..." -ForegroundColor Cyan
wsl --install -d Ubuntu

# Download custom Oh My Posh theme
Write-Host "🎨 Applying custom Oh My Posh theme..." -ForegroundColor Magenta
$themeUrl = "https://raw.githubusercontent.com/maddymontaquila/ohmyposh-config/refs/heads/main/.mytheme.omp.json"
$themePath = "$HOME\.mytheme.omp.json"
Invoke-WebRequest -Uri $themeUrl -OutFile $themePath

# Set up PowerShell profile
$profilePath = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (!(Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$ompInit = "oh-my-posh init pwsh --config `"$themePath`" | Invoke-Expression"
if (-not (Get-Content $profilePath | Select-String -SimpleMatch "oh-my-posh init pwsh")) {
    Add-Content -Path $profilePath -Value $ompInit
    Write-Host "✅ PowerShell profile updated with Oh My Posh theme." -ForegroundColor Green
}

Write-Host "🚀 Installing Aspire CLI..." -ForegroundColor Cyan
Invoke-Expression "& { $(Invoke-RestMethod https://aspire.dev/install.ps1) }"

Write-Host "📌 Setting Windows Terminal as default terminal app..." -ForegroundColor Cyan
wt --set-default-terminal WindowsTerminal

Write-Host "🎛 Customizing Windows taskbar..." -ForegroundColor Cyan

# Disable Widgets, use search icon only
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1

# Restart Explorer to apply changes
Stop-Process -Name explorer -Force
Start-Process explorer.exe

Write-Host "✅ Windows UI cleanup complete." -ForegroundColor Green

Write-Host "`n✅ Setup complete!" -ForegroundColor Cyan
