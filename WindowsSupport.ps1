#requires -Version 5.1
<# Interactive Windows support console. Run locally on the affected PC. #>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_-]{1,40}$')]
    [string]$TicketId = 'General',
    [string]$Task
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'This tool requires Windows and Windows PowerShell 5.1 or newer.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$script:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$logDirectory = Join-Path $env:LOCALAPPDATA 'WindowsSupport\Logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$logPath = Join-Path $logDirectory ('Support-{0}-{1}.txt' -f $TicketId, (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
Start-Transcript -Path $logPath | Out-Null

function Confirm-Repair {
    param([string]$Description)
    Write-Host "`n$Description" -ForegroundColor Yellow
    return ((Read-Host 'Type YES to proceed') -ceq 'YES')
}

function Invoke-Native {
    param([string]$File, [string[]]$Arguments, [int[]]$SuccessCodes = @(0))
    & $File @Arguments | Out-Host
    $code = $LASTEXITCODE
    if ($SuccessCodes -notcontains $code) {
        throw "$File returned exit code $code. Review its output and the log before continuing."
    }
    if ($code -eq 3010) { Write-Host 'A restart is required to complete this operation.' -ForegroundColor Yellow }
}

$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$backupDirectory = Join-Path $env:LOCALAPPDATA 'WindowsSupport\RegistryBackups'

function Set-ExplorerPreference {
    param([string]$Name, [string]$Description, [string[]]$AllowedValues = @('0', '1'))
    $key = Get-Item -LiteralPath $registryPath
    $exists = $key.GetValueNames() -contains $Name
    $previous = $null
    $kind = $null
    if ($exists) {
        $previous = $key.GetValue($Name)
        $kind = $key.GetValueKind($Name).ToString()
    }
    Write-Host "$Description | Current value: $previous (present: $exists)"
    $choice = Read-Host ('Enter {0}, or leave blank to cancel' -f ($AllowedValues -join ' or '))
    if ($choice -notin $AllowedValues) { return }
    if (-not (Confirm-Repair "Sets $Name to $choice for the current user. Explorer windows may need reopening or sign-out.")) { return }
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $backup = Join-Path $backupDirectory (([guid]::NewGuid().ToString()) + '.clixml')
    [pscustomobject]@{ Path = $registryPath; Name = $Name; Exists = $exists; Value = $previous; Kind = $kind } |
        Export-Clixml -LiteralPath $backup
    New-ItemProperty -LiteralPath $registryPath -Name $Name -Value ([int]$choice) -PropertyType DWord -Force | Out-Null
    Write-Host "Saved previous value to $backup"
    Write-Host "New value: $((Get-Item -LiteralPath $registryPath).GetValue($Name))"
}

function Restore-ExplorerPreference {
    if (-not (Test-Path -LiteralPath $backupDirectory)) { Write-Host 'No registry backups yet.'; return }
    $files = @(Get-ChildItem -LiteralPath $backupDirectory -Filter '*.clixml' | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) { Write-Host 'No registry backups yet.'; return }
    for ($i = 0; $i -lt $files.Count; $i++) { Write-Host "$($i + 1). $($files[$i].LastWriteTime) $($files[$i].Name)" }
    $number = 0
    $choice = Read-Host 'Backup number (blank cancels)'
    if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $files.Count) { return }
    $saved = Import-Clixml -LiteralPath $files[$number - 1].FullName
    if ($saved.Path -ne $registryPath -or $saved.Name -notin @('HideFileExt', 'Hidden', 'LaunchTo')) {
        throw 'Backup is not a supported Explorer preference.'
    }
    if ($saved.Exists -isnot [bool] -or ($saved.Exists -and $saved.Kind -ne 'DWord')) {
        throw 'Backup contains an unsupported registry value type.'
    }
    if (Confirm-Repair "Restore $($saved.Name) to the selected backup? This replaces its current value. Reopen Explorer or sign out afterward.") {
        if ($saved.Exists) {
            New-ItemProperty -LiteralPath $registryPath -Name $saved.Name -Value ([int]$saved.Value) -PropertyType DWord -Force | Out-Null
        } else {
            $key = Get-Item -LiteralPath $registryPath
            if ($key.GetValueNames() -contains $saved.Name) { Remove-ItemProperty -LiteralPath $registryPath -Name $saved.Name }
        }
        Write-Host 'Previous setting restored. Backup retained.'
    }
}

$actions = @(
    @{ Name = 'System overview'; Admin = $false; Run = {
        Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, LastBootUpTime, FreePhysicalMemory | Format-List | Out-Host
        Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory | Format-List | Out-Host
        Get-Volume | Select-Object DriveLetter, FileSystemLabel, HealthStatus, SizeRemaining, Size | Format-Table -AutoSize | Out-Host
    } },
    @{ Name = 'Network diagnostics'; Admin = $false; Run = {
        Get-NetIPConfiguration | Format-List | Out-Host
        Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table -AutoSize | Out-Host
        Resolve-DnsName 'www.microsoft.com' | Format-Table -AutoSize | Out-Host
        Test-NetConnection 'www.microsoft.com' -Port 443 | Format-List | Out-Host
    } },
    @{ Name = 'Recent system errors'; Admin = $false; Run = {
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = @(1, 2); StartTime = (Get-Date).AddDays(-3) } -MaxEvents 50 |
            Select-Object TimeCreated, ProviderName, Id, Message | Format-List | Out-Host
    } },
    @{ Name = 'Check Windows component store (DISM)'; Admin = $true; Run = {
        Invoke-Native 'dism.exe' @('/Online', '/Cleanup-Image', '/ScanHealth')
    } },
    @{ Name = 'Repair Windows image and system files (DISM + SFC)'; Admin = $true; Run = {
        if (Confirm-Repair 'Repairs Windows components and protected system files. May download repair files from Windows Update and take a long time. Back up important data first.') {
            Invoke-Native 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') @(0, 3010)
            Invoke-Native 'sfc.exe' @('/scannow')
            Write-Host 'Review the SFC summary above; its exit code alone does not establish that all files were repaired.'
        }
    } },
    @{ Name = 'Scan system drive for filesystem problems'; Admin = $true; Run = {
        Invoke-Native 'chkdsk.exe' @($env:SystemDrive, '/scan')
    } },
    @{ Name = 'Clear DNS cache'; Admin = $true; Run = {
        if (Confirm-Repair 'Clears cached DNS answers. New connections will resolve names again.') {
            Clear-DnsClientCache
            Write-Host 'DNS cache cleared.'
        }
    } },
    @{ Name = 'Reset Winsock'; Admin = $true; Run = {
        if (Confirm-Repair 'Resets the Winsock catalog. This can affect VPN or network software. A restart is required; remote sessions may be affected.') {
            Invoke-Native 'netsh.exe' @('winsock', 'reset')
            Write-Host 'Restart Windows manually when convenient.' -ForegroundColor Yellow
        }
    } },
    @{ Name = 'Reset TCP/IP configuration'; Admin = $true; Run = {
        if (Confirm-Repair 'Resets TCP/IP settings and can remove custom network configuration. Record static IP and DNS settings first. Do not use over a remote support connection. A restart is required.') {
            Invoke-Native 'netsh.exe' @('int', 'ip', 'reset', (Join-Path $logDirectory 'TcpIpReset.txt'))
            Write-Host 'Restart Windows manually when convenient.' -ForegroundColor Yellow
        }
    } },
    @{ Name = 'Restart print spooler'; Admin = $true; Run = {
        if (Confirm-Repair 'Restarts the print spooler. Active printing will be interrupted. Queued print jobs are retained.') {
            Restart-Service -Name Spooler -ErrorAction Stop
            Get-Service Spooler | Format-Table -AutoSize | Out-Host
        }
    } },
    @{ Name = 'Microsoft Defender status'; Admin = $false; Run = {
        Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanStartTime, QuickScanEndTime | Format-List | Out-Host
    } },
    @{ Name = 'Run Microsoft Defender quick scan'; Admin = $true; Run = {
        if (Confirm-Repair 'Starts a Defender quick scan. Defender may quarantine detected threats according to existing policy. This requires an available Defender service.') {
            Start-MpScan -ScanType QuickScan
            Write-Host 'Scan requested. Use Defender status to check the last completed scan; scan request alone does not confirm a clean result.'
        }
    } }

)

# Assign existing troubleshooting tasks to their categories.
$categoryNames = @('Diagnostics', 'Networking', 'Diagnostics', 'Windows repairs', 'Windows repairs',
    'Windows repairs', 'Networking', 'Networking', 'Networking', 'Printing', 'Security', 'Security')
for ($i = 0; $i -lt $actions.Count; $i++) { $actions[$i].Category = $categoryNames[$i] }

$actions += @(
    @{ Category = 'Registry preferences'; Name = 'File extensions: show (0) / hide (1)'; Admin = $false; Run = {
        Set-ExplorerPreference 'HideFileExt' 'File extension visibility: 0 = show, 1 = hide'
    } },
    @{ Category = 'Registry preferences'; Name = 'Hidden files: show (1) / hide (2)'; Admin = $false; Run = {
        Set-ExplorerPreference 'Hidden' 'Hidden file visibility: 1 = show, 2 = hide; protected OS files remain separate' @('1', '2')
    } },
    @{ Category = 'Registry preferences'; Name = 'Explorer opens: This PC (1) / Home or Quick Access (2)'; Admin = $false; Run = {
        Set-ExplorerPreference 'LaunchTo' 'Explorer launch location: 1 = This PC, 2 = Home/Quick Access' @('1', '2')
    } },
    @{ Category = 'Registry preferences'; Name = 'Restore a saved registry preference'; Admin = $false; Run = { Restore-ExplorerPreference } },
    @{ Category = 'Group Policy'; Name = 'Show applied user and computer policies'; Admin = $true; Run = { Invoke-Native 'gpresult.exe' @('/r') } },
    @{ Category = 'Group Policy'; Name = 'Save applied policy HTML report (no browser launch)'; Admin = $true; Run = {
        $report = Join-Path $logDirectory ('GroupPolicy-{0}.html' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        Invoke-Native 'gpresult.exe' @('/h', $report)
        Write-Host "Report saved: $report"
    } },
    @{ Category = 'Group Policy'; Name = 'Refresh Group Policy'; Admin = $true; Run = {
        if (Confirm-Repair 'Reapplies configured user and computer policies. Some policies require sign-out or restart. Managed policies may replace local settings.') {
            Invoke-Native 'gpupdate.exe' @('/force', '/wait:60')
        }
    } },
    @{ Category = 'Group Policy'; Name = 'List policy categories and editor locations'; Admin = $false; Run = {
        @'
Computer Configuration > Administrative Templates:
  Windows Components > Windows Update: updates and restart behavior
  Windows Components > Microsoft Defender Antivirus: protection and scans
  Windows Components > Remote Desktop Services: remote sessions
  Windows Components > BitLocker Drive Encryption: encryption and recovery
  System > Removable Storage Access: removable device restrictions
  System > Device Installation: device installation restrictions
  Windows Components > Data Collection and Preview Builds: diagnostic data
Computer Configuration > Windows Settings > Security Settings:
  Account Policies: password and account lockout policies
  Advanced Audit Policy Configuration: security auditing
  Windows Defender Firewall with Advanced Security: firewall profiles/rules
  Application Control Policies: AppLocker (edition dependent)
User Configuration > Administrative Templates:
  Control Panel: settings access
  Start Menu and Taskbar: desktop experience
  Windows Components > File Explorer: Explorer policies
Paths and available policies vary by Windows build and installed ADMX templates.
Use applied-policy reports before changes. This menu does not override domain/MDM policy.
'@ | Out-Host
    } }
)
# Loaded by WindowsSupport.ps1. Functions use its confirmation, menu and logging helpers.
$script:LabFeatures = @(
    @{ Name = 'Hyper-V'; Feature = 'Microsoft-Hyper-V-All' },
    @{ Name = 'Windows Sandbox'; Feature = 'Containers-DisposableClientVM' },
    @{ Name = 'Windows Subsystem for Linux'; Feature = 'Microsoft-Windows-Subsystem-Linux' },
    @{ Name = 'Virtual Machine Platform'; Feature = 'VirtualMachinePlatform' },
    @{ Name = 'IIS web server'; Feature = 'IIS-WebServerRole' },
    @{ Name = '.NET Framework 3.5'; Feature = 'NetFx3' }
)
$script:LabPackages = @(
    @{ Name = 'Git'; Id = 'Git.Git' },
    @{ Name = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode' },
    @{ Name = '7-Zip'; Id = '7zip.7zip' },
    @{ Name = 'PowerShell 7'; Id = 'Microsoft.PowerShell' },
    @{ Name = 'Python 3.13'; Id = 'Python.Python.3.13' }
)

function Select-LabItem {
    param([string]$Title, [object[]]$Items)
    if ($Items.Count -eq 0) { Write-Host 'No available items.'; return }
    $choice = Show-Menu $Title $Items 'Cancel'
    if ($choice -gt 0) { return $Items[$choice - 1] }
}

function Show-LabInventory {
    Write-Host 'Registered applications (some portable and Store applications are not included):'
    $paths = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
    $entries = foreach ($path in $paths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
    }
    $entries | Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName, DisplayVersion -Unique |
        Format-Table -AutoSize | Out-Host
    Write-Host 'Commands available in the current PATH (restart the terminal after installations):'
    foreach ($name in @('winget', 'git', 'code', '7z', 'pwsh', 'python', 'wsl')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        [pscustomobject]@{ Command = $name; Available = [bool]$command } | Format-Table -AutoSize | Out-Host
    }
}

function Install-LabPackage {
    if (-not (Get-Command 'winget.exe' -ErrorAction SilentlyContinue)) {
        throw 'WinGet is unavailable. Install or update Microsoft App Installer from the Microsoft Store, then reopen this tool.'
    }
    $package = Select-LabItem 'Choose a lab application' $script:LabPackages
    if ($null -eq $package) { return }
    Write-Host 'Checking the exact package in the WinGet inventory:'
    & winget.exe list --id $package.Id --exact --accept-source-agreements --disable-interactivity | Out-Host
    Write-Host 'The inventory result above may also show a source or network error; installation is a separate explicit action.'
    if (Confirm-Repair "Install $($package.Name) ($($package.Id)) from the WinGet community source? This downloads software, accepts source/package agreements, and requests a silent installation. Run this tool elevated for machine-wide installers; unsupported silent installs may fail.") {
        Invoke-Native 'winget.exe' @('install', '--id', $package.Id, '--exact', '--source', 'winget',
            '--accept-source-agreements', '--accept-package-agreements', '--silent', '--disable-interactivity') @(0, 3010)
        Invoke-Native 'winget.exe' @('list', '--id', $package.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')
        Write-Host 'Reopen your terminal if the installer updated PATH.'
    }
}

function Show-LabFeatures {
    $available = @(Get-WindowsOptionalFeature -Online)
    foreach ($entry in $script:LabFeatures) {
        $feature = $available | Where-Object { $_.FeatureName -eq $entry.Feature }
        $state = 'Unavailable on this edition/build'
        if ($null -ne $feature) { $state = [string]$feature.State }
        [pscustomobject]@{ Feature = $entry.Name; State = $state } | Format-Table -AutoSize | Out-Host
    }
    Get-CimInstance Win32_Processor | Select-Object Name, VirtualizationFirmwareEnabled,
        SecondLevelAddressTranslationExtensions | Format-List | Out-Host
    Write-Host 'Virtualization features require compatible hardware/firmware and may conflict with other virtualization software.'
}

function Set-LabFeature {
    param([bool]$Enable)
    $available = @(Get-WindowsOptionalFeature -Online)
    $items = @($script:LabFeatures | Where-Object { $available.FeatureName -contains $_.Feature })
    $item = Select-LabItem 'Select a supported Windows feature' $items
    if ($null -eq $item) { return }
    $current = Get-WindowsOptionalFeature -Online -FeatureName $item.Feature
    Write-Host "Current state: $($current.State)"
    if ([string]$current.State -like '*Pending*') { throw 'A feature change is pending. Restart Windows manually before another change.' }
    $verb = 'Disable'
    if ($Enable) { $verb = 'Enable' }
    if (($Enable -and [string]$current.State -eq 'Enabled') -or (-not $Enable -and [string]$current.State -eq 'Disabled')) {
        Write-Host 'Feature already has the requested state.'; return
    }
    if (Confirm-Repair "$verb $($item.Name)? Enabling can download Windows components and enable dependencies. Disabling can affect dependent apps/features. A restart may be required; none is automatic.") {
        if ($Enable) {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $item.Feature -All -NoRestart
        } else {
            $result = Disable-WindowsOptionalFeature -Online -FeatureName $item.Feature -NoRestart
        }
        $result | Format-List | Out-Host
        Get-WindowsOptionalFeature -Online -FeatureName $item.Feature | Format-List FeatureName, State | Out-Host
        Write-Host 'Enabling WSL components does not install a Linux distribution. Configure one separately if needed.'
    }
}

function Show-LabFirewall {
    Get-NetConnectionProfile | Select-Object Name, InterfaceAlias, NetworkCategory | Format-Table -AutoSize | Out-Host
    Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, DefaultInboundAction,
        DefaultOutboundAction | Format-Table -AutoSize | Out-Host
    Write-Host 'These are effective profiles. Domain/MDM policy may override local changes.'
}

function Set-LabFirewall {
    param([bool]$Enable)
    $items = @(@('Domain', 'Private', 'Public') | ForEach-Object { @{ Name = $_ } })
    $profile = Select-LabItem 'Select one firewall profile' $items
    if ($null -eq $profile) { return }
    $current = Get-NetFirewallProfile -PolicyStore PersistentStore -Name $profile.Name
    $current | Select-Object Name, Enabled | Format-Table | Out-Host
    $warning = "Turn ON the $($profile.Name) firewall profile? This can block inbound lab connections."
    if (-not $Enable) {
        $warning = "Turn OFF the $($profile.Name) firewall profile? This exposes services when that profile is active. Use an isolated lab network and turn it back on afterward."
    }
    if (Confirm-Repair $warning) {
        $directory = Join-Path $env:LOCALAPPDATA 'WindowsSupport\FirewallBackups'
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $backup = Join-Path $directory (([guid]::NewGuid().ToString()) + '.clixml')
        [pscustomobject]@{ Name = $profile.Name; Enabled = [string]$current.Enabled } | Export-Clixml -LiteralPath $backup
        Set-NetFirewallProfile -PolicyStore PersistentStore -Name $profile.Name -Enabled $Enable
        Write-Host "Previous profile state saved: $backup"
        Show-LabFirewall
    }
}

function Restore-LabFirewall {
    $directory = Join-Path $env:LOCALAPPDATA 'WindowsSupport\FirewallBackups'
    if (-not (Test-Path -LiteralPath $directory)) { Write-Host 'No profile backups yet.'; return }
    $items = @(Get-ChildItem -LiteralPath $directory -Filter '*.clixml' | Sort-Object LastWriteTime -Descending |
        ForEach-Object { @{ Name = "$($_.LastWriteTime) $($_.Name)"; Path = $_.FullName } })
    $item = Select-LabItem 'Restore a previous firewall profile state' $items
    if ($null -eq $item) { return }
    $saved = Import-Clixml -LiteralPath $item.Path
    if ($saved.Name -notin @('Domain', 'Private', 'Public') -or $saved.Enabled -notin @('True', 'False', 'NotConfigured')) {
        throw 'Unsupported profile backup.'
    }
    if (Confirm-Repair "Restore $($saved.Name) firewall Enabled=$($saved.Enabled)? Restoring False disables protection for this profile.") {
        Set-NetFirewallProfile -PolicyStore PersistentStore -Name $saved.Name -Enabled $saved.Enabled
        Show-LabFirewall
    }
}

function Add-LabFirewallRule {
    $portText = Read-Host 'Inbound TCP port to allow (1-65535; blank cancels)'
    if ([string]::IsNullOrWhiteSpace($portText)) { return }
    $port = 0
    if (-not [int]::TryParse($portText, [ref]$port) -or $port -lt 1 -or $port -gt 65535) { throw 'Invalid port.' }
    if (Confirm-Repair "Allow inbound TCP port $port on Private networks, from the local subnet only? Public and Domain profiles are excluded.") {
        $id = 'WindowsSupportLab-' + [guid]::NewGuid().ToString()
        New-NetFirewallRule -PolicyStore PersistentStore -Name $id -DisplayName "Windows Support Lab TCP $port" -Group 'WindowsSupportLab' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -RemoteAddress LocalSubnet -Profile Private | Out-Host
        Write-Host 'Use Remove a lab firewall rule to undo this rule.'
    }
}

function Remove-LabFirewallRule {
    $rules = @(Get-NetFirewallRule -PolicyStore PersistentStore | Where-Object {
        $_.Group -eq 'WindowsSupportLab' -and $_.Name -like 'WindowsSupportLab-*'
    })
    $items = @($rules | ForEach-Object { @{ Name = "$($_.DisplayName) [$($_.Name)]"; RuleName = $_.Name } })
    $item = Select-LabItem 'Remove a rule created by this toolkit' $items
    if ($null -eq $item) { return }
    if (Confirm-Repair "Remove $($item.Name)? Inbound access permitted by this rule may stop.") {
        Remove-NetFirewallRule -PolicyStore PersistentStore -Name $item.RuleName
        Write-Host 'Rule removed.'
    }
}

function Assert-LocalAccountsAvailable {
    if (-not (Get-Command Get-LocalUser -ErrorAction SilentlyContinue)) {
        throw 'LocalAccounts commands are unavailable. Use 64-bit Windows PowerShell on a supported Windows PC; domain controllers require different tools.'
    }
}

function Select-LabUser {
    Assert-LocalAccountsAvailable
    $currentSid = $identity.User.Value
    $users = @(Get-LocalUser | Where-Object {
        $_.SID.Value -ne $currentSid -and $_.SID.Value -notmatch '-(500|501|503|504)$'
    })
    $items = @($users | ForEach-Object { @{ Name = "$($_.Name) (enabled: $($_.Enabled))"; User = $_ } })
    $item = Select-LabItem 'Select a local user (current and built-in accounts excluded)' $items
    if ($null -ne $item) { return $item.User }
}

function New-LabUser {
    Assert-LocalAccountsAvailable
    $name = Read-Host 'New local username (start with a letter; max 20 letters, digits, dots, underscores or hyphens)'
    if ([string]::IsNullOrWhiteSpace($name)) { return }
    if ($name -notmatch '^[A-Za-z][A-Za-z0-9_.-]{0,19}$' -or $name.EndsWith('.')) { throw 'Invalid username.' }
    if (@(Get-LocalUser | Where-Object { $_.Name -eq $name }).Count -gt 0) { throw 'That local account already exists.' }
    if (Confirm-Repair "Create $name as a standard local user? The password must meet this computer's account policy. No automatic logon or administrator access is configured.") {
        $password = Read-Host 'Password (hidden)' -AsSecureString
        try {
            $user = New-LocalUser -Name $name -Password $password -Description 'Windows Support lab account'
            Write-Host "Account $name created. Adding it to the standard Users group..."
            $group = Get-LocalGroup -SID 'S-1-5-32-545'
            Add-LocalGroupMember -Group $group -Member $user
            Get-LocalUser -Name $name | Select-Object Name, Enabled, SID | Format-Table | Out-Host
        } finally {
            if ($null -ne $password) { $password.Dispose() }
        }
    }
}

function Set-LabUserEnabled {
    param([bool]$Enable)
    $user = Select-LabUser
    if ($null -eq $user) { return }
    $verb = 'Disable'; if ($Enable) { $verb = 'Enable' }
    if (Confirm-Repair "$verb local user $($user.Name)? Disabling prevents future logons but does not terminate existing sessions.") {
        if ($Enable) { Enable-LocalUser -SID $user.SID } else { Disable-LocalUser -SID $user.SID }
        Get-LocalUser -SID $user.SID | Select-Object Name, Enabled | Format-Table | Out-Host
    }
}

function Set-LabAdministrator {
    param([bool]$Add)
    $user = Select-LabUser
    if ($null -eq $user) { return }
    $group = Get-LocalGroup -SID 'S-1-5-32-544'
    $members = @(Get-LocalGroupMember -Group $group)
    $isMember = @($members | Where-Object { $_.SID.Value -eq $user.SID.Value }).Count -gt 0
    Write-Host "Direct local administrator membership: $isMember"
    if ($Add -eq $isMember) { Write-Host 'Already in the requested state.'; return }
    $message = "Remove $($user.Name) from local Administrators? Direct membership only; other group memberships may still grant access."
    if ($Add) { $message = "Grant $($user.Name) local administrator rights? This gives full control of this PC. Use only for a trusted lab account." }
    if (Confirm-Repair $message) {
        if ($Add) { Add-LocalGroupMember -Group $group -Member $user } else { Remove-LocalGroupMember -Group $group -Member $user }
        Get-LocalGroupMember -Group $group | Select-Object Name, SID | Format-Table | Out-Host
        Write-Host 'Membership changes may require the user to sign out and back in.'
    }
}

$actions += @(
    @{ Category = 'Lab installations'; Name = 'Check installed applications and lab commands'; Admin = $false; Run = { Show-LabInventory } },
    @{ Category = 'Lab installations'; Name = 'Install a selected lab application with WinGet'; Admin = $true; Run = { Install-LabPackage } },
    @{ Category = 'Windows features'; Name = 'Check lab features and virtualization support'; Admin = $true; Run = { Show-LabFeatures } },
    @{ Category = 'Windows features'; Name = 'Enable a selected Windows feature'; Admin = $true; Run = { Set-LabFeature $true } },
    @{ Category = 'Windows features'; Name = 'Disable a selected Windows feature'; Admin = $true; Run = { Set-LabFeature $false } },
    @{ Category = 'Firewall'; Name = 'Show effective firewall and network profiles'; Admin = $false; Run = { Show-LabFirewall } },
    @{ Category = 'Firewall'; Name = 'Turn ON a firewall profile'; Admin = $true; Run = { Set-LabFirewall $true } },
    @{ Category = 'Firewall'; Name = 'Turn OFF a firewall profile'; Admin = $true; Run = { Set-LabFirewall $false } },
    @{ Category = 'Firewall'; Name = 'Restore a saved firewall profile state'; Admin = $true; Run = { Restore-LabFirewall } },
    @{ Category = 'Firewall'; Name = 'Allow a lab TCP port (Private / local subnet)'; Admin = $true; Run = { Add-LabFirewallRule } },
    @{ Category = 'Firewall'; Name = 'Remove a lab firewall rule'; Admin = $true; Run = { Remove-LabFirewallRule } },
    @{ Category = 'Local users'; Name = 'List local users and administrators'; Admin = $true; Run = {
        Assert-LocalAccountsAvailable
        Get-LocalUser | Select-Object Name, Enabled, LastLogon, SID | Format-Table -AutoSize | Out-Host
        Get-LocalGroupMember -Group (Get-LocalGroup -SID 'S-1-5-32-544') | Select-Object Name, SID | Format-Table -AutoSize | Out-Host
    } },
    @{ Category = 'Local users'; Name = 'Create a standard local user'; Admin = $true; Run = { New-LabUser } },
    @{ Category = 'Local users'; Name = 'Enable a local user'; Admin = $true; Run = { Set-LabUserEnabled $true } },
    @{ Category = 'Local users'; Name = 'Disable a local user'; Admin = $true; Run = { Set-LabUserEnabled $false } },
    @{ Category = 'Local users'; Name = 'Grant local administrator membership'; Admin = $true; Run = { Set-LabAdministrator $true } },
    @{ Category = 'Local users'; Name = 'Remove local administrator membership'; Admin = $true; Run = { Set-LabAdministrator $false } }
)

# Terminal-only staff workflow; loaded by WindowsSupport.ps1.
$script:SupportServices = @(
    @{ Name = 'Print spooler'; Service = 'Spooler' },
    @{ Name = 'Windows Update'; Service = 'wuauserv' },
    @{ Name = 'Background Intelligent Transfer'; Service = 'BITS' },
    @{ Name = 'Windows Time'; Service = 'W32Time' }
)

function Export-SupportReport {
    $path = Join-Path $logDirectory ('Report-{0}-{1}.txt' -f $TicketId, (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    @("Windows Support Report", "Ticket: $TicketId", "Collected: $(Get-Date -Format o)",
        "Technician account: $($identity.Name)", "Elevated: $script:IsAdmin",
        'Read-only diagnostics. A successful collection does not prove the PC is healthy.', '') |
        Out-File -LiteralPath $path -Encoding UTF8
    $checks = @(
        @{ Name = 'Operating system'; Run = { Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, LastBootUpTime, FreePhysicalMemory | Format-List } },
        @{ Name = 'Computer'; Run = { Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory, PartOfDomain | Format-List } },
        @{ Name = 'Storage'; Run = { Get-Volume | Select-Object DriveLetter, FileSystemLabel, HealthStatus, SizeRemaining, Size | Format-Table -AutoSize } },
        @{ Name = 'Network'; Run = { Get-NetIPConfiguration | Format-List } },
        @{ Name = 'Firewall'; Run = { Get-NetFirewallProfile -PolicyStore ActiveStore | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize } },
        @{ Name = 'Defender'; Run = { Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanEndTime | Format-List } },
        @{ Name = 'Support services'; Run = { Get-Service -Name $script:SupportServices.Service | Select-Object Name, Status, StartType | Format-Table -AutoSize } },
        @{ Name = 'Recent system errors'; Run = {
            Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = @(1, 2); StartTime = (Get-Date).AddDays(-3) } -MaxEvents 30 |
                Select-Object TimeCreated, ProviderName, Id, Message | Format-List
        } }
    )
    $failed = 0
    foreach ($check in $checks) {
        Add-Content -LiteralPath $path -Value "`r`n=== $($check.Name) ===" -Encoding UTF8
        try {
            $output = & $check.Run | Out-String -Width 200
            Add-Content -LiteralPath $path -Value $output -Encoding UTF8
            Write-Host "Collected: $($check.Name)"
        } catch {
            $failed++
            Add-Content -LiteralPath $path -Value "UNAVAILABLE/FAILED: $($_.Exception.Message)" -Encoding UTF8
            Write-Host "Could not collect $($check.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    Write-Host "Report saved: $path | Unavailable/failed sections: $failed"
    Write-Host 'Report contains identifying system/network details. Review before attaching to a ticket. Nothing is uploaded.'
}

function Show-SupportChecklist {
    $items = @(
        @{ Name = 'Slow PC or freezes'; Advice = 'Collect report > Diagnostics/system overview and recent errors > inspect disk space and memory. Use Windows repairs/DISM health scan if corruption is suspected; repair only when evidence supports it. Hardware errors or recurring freezes need escalation.' },
        @{ Name = 'No Internet or DNS problems'; Advice = 'Networking/network diagnostics > inspect adapter, IP, gateway and DNS results. Compare another device. Clear DNS only for stale resolution; use resets last, with recorded static settings. Do not reset networking over your only remote connection.' },
        @{ Name = 'Windows update or damaged system files'; Advice = 'Collect report > System configuration/installed hotfix history > Services/status. Check DISM health, then confirmed DISM/SFC repair if needed. Record the exact update/repair error and restart requirement.' },
        @{ Name = 'Printing problems'; Advice = 'Check printer power, connection and queue. Printing/restart spooler interrupts active printing but retains queued jobs. A driver or hardware issue needs further investigation.' },
        @{ Name = 'Application or lab setup'; Advice = 'Lab installations/inventory > select an approved package if missing. Windows features/status > enable only a required component. Verify the application afterward and record versions. This toolkit does not install arbitrary packages.' },
        @{ Name = 'User access or account setup'; Advice = 'Local users/list accounts > create a standard account or enable the selected existing account. Grant administrator rights only when justified. Current/built-in accounts are excluded from modifications. Domain accounts need your directory tools.' },
        @{ Name = 'Firewall or blocked lab connection'; Advice = 'Firewall/show effective profiles > check the application listening port. Prefer a scoped lab rule on Private/local-subnet networks. Disable a profile only for an isolated experiment and restore it afterward. Managed policy may override local changes.' },
        @{ Name = 'Suspected malware or security issue'; Advice = 'Follow your company incident procedure. Security/Defender status or quick scan is available, but does not prove a PC is clean. Preserve relevant logs and escalate suspicious activity; do not disable protection.' }
    )
    $item = Select-LabItem 'Choose the reported symptom' $items
    if ($null -ne $item) { Write-Host "`n$($item.Advice)" -ForegroundColor Cyan }
}

function Set-SupportService {
    param([bool]$Restart)
    $item = Select-LabItem 'Select a support service' $script:SupportServices
    if ($null -eq $item) { return }
    Get-Service -Name $item.Service | Select-Object Name, Status, StartType | Format-Table | Out-Host
    $verb = 'Start'; if ($Restart) { $verb = 'Restart' }
    if (Confirm-Repair "$verb $($item.Name)? Restarting interrupts work that depends on it. Disabled services are not reconfigured; organization policy remains in force.") {
        if ($Restart) { Restart-Service -Name $item.Service } else { Start-Service -Name $item.Service }
        $service = Get-Service -Name $item.Service
        $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        Get-Service -Name $item.Service | Format-Table Name, Status, StartType | Out-Host
        Write-Host 'Service running; verify the original problem separately.'
    }
}

$actions += @(
    @{ Category = 'Staff workflow'; Name = 'Guided troubleshooting checklist by symptom'; Admin = $false; Run = { Show-SupportChecklist } },
    @{ Category = 'Staff workflow'; Name = 'Collect a read-only support report'; Admin = $false; Run = { Export-SupportReport } },
    @{ Category = 'Staff workflow'; Name = 'Show ticket and log locations'; Admin = $false; Run = {
        Write-Host "Ticket: $TicketId"
        Write-Host "Session log: $logPath"
        Write-Host "Reports: $logDirectory"
        Write-Host 'Record symptom, chosen action, actual result, and required restart in your ticket. Do not include passwords.'
    } },
    @{ Category = 'System configuration'; Name = 'Installed Windows hotfix history'; Admin = $false; Run = {
        Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object HotFixID, Description, InstalledOn | Format-Table -AutoSize | Out-Host
        Write-Host 'Hotfix history is not a complete list of all updates or pending updates.'
    } },
    @{ Category = 'System configuration'; Name = 'Power plan configuration'; Admin = $false; Run = { Invoke-Native 'powercfg.exe' @('/list') } },
    @{ Category = 'System configuration'; Name = 'Device status and problems'; Admin = $false; Run = {
        Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
            Select-Object Name, Status, ConfigManagerErrorCode | Format-Table -AutoSize | Out-Host
        Write-Host 'Only devices reporting a nonzero configuration error are listed; an empty list does not rule out hardware failure.'
    } },
    @{ Category = 'System configuration'; Name = 'Windows Recovery Environment status'; Admin = $true; Run = { Invoke-Native 'reagentc.exe' @('/info') } },
    @{ Category = 'Services'; Name = 'Check support services'; Admin = $false; Run = {
        Get-Service -Name $script:SupportServices.Service | Select-Object Name, Status, StartType | Format-Table -AutoSize | Out-Host
    } },
    @{ Category = 'Services'; Name = 'Start a support service'; Admin = $true; Run = { Set-SupportService $false } },
    @{ Category = 'Services'; Name = 'Restart a support service'; Admin = $true; Run = { Set-SupportService $true } }
)


function Show-Menu {
    param([string]$Title, [object[]]$Items, [string]$ZeroLabel)
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $label = $Items[$i].Name
        if ($Items[$i].ContainsKey('Admin') -and $Items[$i].Admin) { $label += ' [Administrator]' }
        Write-Host ('{0,2}. {1}' -f ($i + 1), $label)
    }
    Write-Host " 0. $ZeroLabel"
    $choice = Read-Host 'Option'
    $number = 0
    if ([int]::TryParse($choice, [ref]$number) -and $number -ge 0 -and $number -le $Items.Count) { return $number }
    Write-Host 'Enter a listed option number.' -ForegroundColor Yellow
    return -1
}

try {
    Write-Host "Windows IT Support and Lab Toolkit | Administrator: $script:IsAdmin" -ForegroundColor Cyan
    Write-Host "Ticket: $TicketId | Session log: $logPath"
    Write-Host 'Choose diagnostics first. Repairs do not guarantee a fix. No automatic reboot or run-all repair is performed.'
    $categories = @('Staff workflow', 'Diagnostics', 'Windows repairs', 'Networking', 'Printing', 'Security',
        'System configuration', 'Registry preferences', 'Group Policy', 'Lab installations',
        'Windows features', 'Firewall', 'Local users', 'Services')
    $categoryItems = @($categories | ForEach-Object { @{ Name = $_ } })
    if ($Task) {
        $matches = @($actions | Where-Object { $_.Name -eq $Task })
        if ($matches.Count -ne 1) { throw "Unknown task: $Task. Open the menu to see supported tasks." }
        $selected = $matches[0]
        if ($selected.Admin -and -not $script:IsAdmin) { throw 'Open PowerShell as Administrator to use this task.' }
        Write-Host "Running: $($selected.Name)" -ForegroundColor Cyan
        & $selected.Run
    } else {
    while ($true) {
        $categoryChoice = Show-Menu 'Support categories' $categoryItems 'Exit'
        if ($categoryChoice -eq 0) { break }
        if ($categoryChoice -lt 0) { continue }
        $category = $categories[$categoryChoice - 1]
        $items = @($actions | Where-Object { $_.Category -eq $category })
        while ($true) {
            $choice = Show-Menu $category $items 'Back to categories'
            if ($choice -eq 0) { break }
            if ($choice -lt 0) { continue }
            $action = $items[$choice - 1]
            if ($action.Admin -and -not $script:IsAdmin) {
                Write-Host 'Open PowerShell as Administrator to use this task.' -ForegroundColor Yellow
                continue
            }
            try {
                Write-Host "`nRunning: $($action.Name)" -ForegroundColor Cyan
                & $action.Run
            } catch {
                Write-Host "Task failed: $($_.Exception.Message)" -ForegroundColor Red
            }
            Read-Host 'Press Enter to return to the category' | Out-Null
        }
    }
    }
} finally {
    Stop-Transcript | Out-Null
    Write-Host "Session log saved to $logPath"
}
