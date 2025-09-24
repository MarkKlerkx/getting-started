<#
.SYNOPSIS
    This script optimizes a Windows 11 installation by removing unnecessary files,
    disabling features, and reducing the overall disk footprint.
    It must be run as an Administrator.

.DESCRIPTION
    The script performs the following actions:
    1. Disables the Hibernation feature (removes hiberfil.sys).
    2. Sets the Page File to a fixed, smaller size (2 GB).
    3. Disables System Restore and removes existing restore points.
    4. Permanently disables the Windows Update service and clears its cache.
    5. Removes a list of common 'bloatware' apps.
    6. Performs a deep system cleanup using DISM.
    7. Compresses the operating system files using CompactOS.
#>

# Step 0: Check for Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as an Administrator."
    Write-Host "Right-click the script file and select 'Run with PowerShell as administrator'."
    Read-Host "Press Enter to exit."
    Exit
}

# Start of the script
Write-Host "🚀 Starting the Windows 11 Optimization Script..." -ForegroundColor Green
Write-Host "======================================================="

# --- Section 1: System Tweaks ---

Write-Host "⚙️ Section 1: Applying System Tweaks" -ForegroundColor Cyan

# Step 1.1: Disable Hibernation
Write-Host "  - Step 1.1: Disabling Hibernation (removing hiberfil.sys)..." -ForegroundColor Yellow
powercfg /h off

# Step 1.2: Set a fixed Page File size
Write-Host "  - Step 1.2: Setting Page File (pagefile.sys) to a fixed size of 2048 MB..." -ForegroundColor Yellow
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
$ComputerSystem.AutomaticManagedPagefile = $false
$ComputerSystem.Put() | Out-Null
$PageFile = Get-WmiObject -Query "SELECT * FROM Win32_PageFileSetting WHERE Name='C:\pagefile.sys'"
if ($PageFile) {
    $PageFile.InitialSize = 2048
    $PageFile.MaximumSize = 2048
    $PageFile.Put() | Out-Null
} else {
    Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name="C:\pagefile.sys"; InitialSize = 2048; MaximumSize = 2048} | Out-Null
}

# Step 1.3: Disable System Restore
Write-Host "  - Step 1.3: Disabling System Restore..." -ForegroundColor Yellow
Disable-ComputerRestore -Drive "C:\"

# Step 1.4: Disable Windows Update
Write-Host "  - Step 1.4: Disabling Windows Update service..." -ForegroundColor Yellow
# Stop the service first
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
# Set the service to Disabled
Set-Service -Name wuauserv -StartupType Disabled

# For good measure, set the policy in the registry as well
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-NOT (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
}
Set-ItemProperty -Path $RegistryPath -Name NoAutoUpdate -Value 1 -Force

# Step 1.5: Clear the Windows Update cache
Write-Host "  - Step 1.5: Clearing the Windows Update cache (SoftwareDistribution)..." -ForegroundColor Yellow
$UpdateCachePath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $UpdateCachePath) {
    Remove-Item -Path "$UpdateCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
}


# --- Section 2: Remove Unnecessary Software ---

Write-Host "🗑️ Section 2: Removing Unnecessary Software" -ForegroundColor Cyan

# Step 2.1: Remove Bloatware Apps
Write-Host "  - Step 2.1: Removing default bloatware apps..." -ForegroundColor Yellow
$BloatwareApps = @(
    "Microsoft.YourPhone",
    "Microsoft.ZuneVideo",
    "Microsoft.ZuneMusic",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.WindowsMaps",
    "Microsoft.People",
    "Microsoft.GamingApp",
    "Microsoft.549981C3F5F10" # Cortana
)

foreach ($App in $BloatwareApps) {
    Write-Host "    - Attempting to remove: $App"
    Get-AppxPackage -Name $App | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*$App*"} | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# --- Section 3: Deep System Cleanup ---

Write-Host "🧹 Section 3: Performing Deep System Cleanup" -ForegroundColor Cyan

# Step 3.1: Clean up Component Store (WinSxS) with DISM
Write-Host "  - Step 3.1: Cleaning up the Component Store (WinSxS) with DISM (this may take a while)..." -ForegroundColor Yellow
DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# Step 3.2: Enable CompactOS
Write-Host "  - Step 3.2: Enabling CompactOS to compress system files..." -ForegroundColor Yellow
compact.exe /CompactOS:always

# --- Completion ---
Write-Host "======================================================="
Write-Host "✅ Optimization complete!" -ForegroundColor Green
Write-Host "A system restart is recommended for all changes to take effect."
Read-Host "Press Enter to close this window."
