#requires -Version 5.1
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT' -or $env:USERNAME -ne 'WDAGUtilityAccount' -or !(Test-Path 'C:\Toolkit') -or !(Test-Path 'C:\Results')){throw 'This runner requires the staged disposable Windows Sandbox.'}
Start-Transcript 'C:\Results\SandboxTranscript.txt' | Out-Null
$checks=@(
 @{Name='PowerShell parsing and control-flow mocks';Run={ & 'C:\Toolkit\ValidatePowerShell.ps1' -Root 'C:\Toolkit' }},
 @{Name='Operating system';Run={Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber}},
 @{Name='Network adapters';Run={Get-NetAdapter | Select-Object Name,Status}},
 @{Name='Firewall profiles';Run={Get-NetFirewallProfile | Select-Object Name,Enabled}},
 @{Name='Local users';Run={Get-LocalUser | Select-Object Name,Enabled}},
 @{Name='Services';Run={Get-Service Spooler | Select-Object Name,Status}},
 @{Name='Volume inventory';Run={Get-Volume | Select-Object DriveLetter,HealthStatus}},
 @{Name='Feature inventory';Run={Get-WindowsOptionalFeature -Online | Select-Object FeatureName,State}}
)
$results=@()
try{
 foreach($check in $checks){
  try{$data=& $check.Run;$results+= [pscustomobject]@{Name=$check.Name;Status='completed';Output=($data | Out-String);Error=$null}}
  catch{$results+=[pscustomobject]@{Name=$check.Name;Status='failed';Output=$null;Error=$_.Exception.Message}}
 }
 $results | ConvertTo-Json -Depth 5 | Set-Content 'C:\Results\WindowsResults.json' -Encoding UTF8
 $results | Select-Object Name,Status | Format-Table -AutoSize
 Write-Host 'No repair, key retrieval, account changes, registry writes or firewall changes were automatically run.'
}finally{Stop-Transcript | Out-Null}
Read-Host 'Tests finished. Press Enter; then close Sandbox when ready' | Out-Null
