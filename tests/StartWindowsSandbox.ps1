#requires -Version 5.1
param([string]$OutputDirectory = (Join-Path $env:LOCALAPPDATA 'WindowsSupport\SandboxResults'))
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT'){throw 'Run on Windows with Windows Sandbox installed.'}
$root=Split-Path $PSScriptRoot -Parent
$stage=Join-Path $env:TEMP ('WindowsSupportLab-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Copy-Item (Join-Path $root 'WindowsSupport.ps1') $stage
Copy-Item (Join-Path $root 'WindowsSupport.bat') $stage
Copy-Item (Join-Path $PSScriptRoot 'ValidatePowerShell.ps1') $stage
Copy-Item (Join-Path $PSScriptRoot 'TestInWindowsSandbox.ps1') $stage
$source=[Security.SecurityElement]::Escape($stage)
$output=[Security.SecurityElement]::Escape((Resolve-Path $OutputDirectory).Path)
$wsb=@"
<Configuration>
 <Networking>Disable</Networking><ClipboardRedirection>Disable</ClipboardRedirection>
 <MappedFolders>
  <MappedFolder><HostFolder>$source</HostFolder><SandboxFolder>C:\Toolkit</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
  <MappedFolder><HostFolder>$output</HostFolder><SandboxFolder>C:\Results</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
 </MappedFolders>
 <LogonCommand><Command>powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File C:\Toolkit\TestInWindowsSandbox.ps1</Command></LogonCommand>
</Configuration>
"@
$path=Join-Path $stage 'SupportLab.wsb';$wsb | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Read-only source stage: $stage"
Write-Host "Sandbox results: $OutputDirectory"
Write-Host 'Automatic tests run read-only diagnostics and control-flow mocks; repairs require separate lab review.'
Start-Process -FilePath $path
