from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
groups={
'Diagnostics':[
('System information','systeminfo',False,False),('Windows version','ver',False,False),('Current identity','whoami /all',False,False),('Running processes','tasklist',False,False),('Installed drivers','driverquery /v',False,False)],
'Windows repair':[
('Component store scan','DISM /Online /Cleanup-Image /ScanHealth',True,False),('Repair Windows image','DISM /Online /Cleanup-Image /RestoreHealth',True,True),('Repair protected files','sfc /scannow',True,True),('Online system disk scan','chkdsk %SystemDrive% /scan',True,False)],
'Networking':[
('IP configuration','ipconfig /all',False,False),('DNS lookup','nslookup www.microsoft.com',False,False),('Connections','netstat -ano',False,False),('Clear DNS cache','ipconfig /flushdns',True,True),('Reset Winsock - restart required','netsh winsock reset',True,True)],
'Firewall and policy':[
('Firewall profiles','netsh advfirewall show allprofiles',False,False),('Private firewall ON','netsh advfirewall set privateprofile state on',True,True),('Private firewall OFF','netsh advfirewall set privateprofile state off',True,True),('Applied policy','gpresult /r',True,False),('Refresh policy','gpupdate /force',True,True)],
'Users and services':[
('List local users','net user',False,False),('Create a standard local user',"powershell.exe -NoLogo -NoProfile -Command \"$u=Read-Host 'Username (letters/digits/underscore/hyphen)'; if($u -notmatch '^[A-Za-z0-9_-]{1,20}$'){throw 'Invalid username'}; $p=Read-Host 'Password' -AsSecureString; New-LocalUser -Name $u -Password $p -ErrorAction Stop; $g=Get-LocalGroup -SID 'S-1-5-32-545'; Add-LocalGroupMember -Group $g -Member $u -ErrorAction Stop\"",True,True),('Print spooler status','sc query Spooler',False,False),('Restart print spooler','net stop Spooler\r\nnet start Spooler',True,True)],
'Windows features':[
('Optional feature inventory','DISM /Online /Get-Features /Format:Table',True,False),('WSL feature status','DISM /Online /Get-FeatureInfo /FeatureName:Microsoft-Windows-Subsystem-Linux',True,False),('Virtual Machine Platform status','DISM /Online /Get-FeatureInfo /FeatureName:VirtualMachinePlatform',True,False)]}
lines=['@echo off','setlocal EnableExtensions DisableDelayedExpansion','title Windows IT Support - CMD Menu',':home','cls','echo WINDOWS IT SUPPORT - CMD','echo Choose a specific check or repair. No automatic reboot.']
for i,g in enumerate(groups,1):lines.append(f'echo {i}. {g}')
lines+=['echo 0. Exit',f'choice /c 0123456 /n /m "Category: "','set "pick=%errorlevel%"','if "%pick%"=="1" exit /b 0']
for i,g in enumerate(groups,2):lines.append(f'if "%pick%"=="{i}" goto category{i-1}')
lines+=['goto home']
for i,(g,actions) in enumerate(groups.items(),1):
 lines += [f':category{i}','cls',f'echo {g}']
 for j,(name,cmd,admin,change) in enumerate(actions,1):lines.append(f'echo {j}. {name}')
 lines+=['echo 0. Back',f'choice /c 0'+''.join(str(j) for j in range(1,len(actions)+1))+' /n /m "Task: "','set "pick=%errorlevel%"','if "%pick%"=="1" goto home']
 for j in range(1,len(actions)+1):lines.append(f'if "%pick%"=="{j+1}" goto action{i}_{j}')
 lines.append(f'goto category{i}')
 for j,(name,cmd,admin,change) in enumerate(actions,1):
  lines += [f':action{i}_{j}',f'echo {name}']
  if admin:lines+=['fltmc >nul 2>&1',f'if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category{i})']
  if change:lines+=['echo This changes the system. Record current settings and use an authorized lab first.','choice /c YN /n /m "Proceed? Y/N: "',f'if errorlevel 2 goto category{i}']
  lines += [cmd,'echo Review output above. Command completion does not prove the problem is fixed.','pause',f'goto category{i}']
raw=('\r\n'.join(lines)+'\r\n').encode('ascii')
(ROOT/'WindowsSupport.bat').write_bytes(raw);(ROOT/'dist/WindowsSupport.bat').write_bytes(raw)
print('Built CMD menu:',sum(len(a) for a in groups.values()),'actions')
