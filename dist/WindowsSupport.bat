@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Windows IT Support - CMD Menu
:home
cls
echo WINDOWS IT SUPPORT - CMD
echo Choose a specific check or repair. No automatic reboot.
echo 1. Diagnostics
echo 2. Windows repair
echo 3. Networking
echo 4. Firewall and policy
echo 5. Users and services
echo 6. Windows features
echo 0. Exit
choice /c 0123456 /n /m "Category: "
set "pick=%errorlevel%"
if "%pick%"=="1" exit /b 0
if "%pick%"=="2" goto category1
if "%pick%"=="3" goto category2
if "%pick%"=="4" goto category3
if "%pick%"=="5" goto category4
if "%pick%"=="6" goto category5
if "%pick%"=="7" goto category6
goto home
:category1
cls
echo Diagnostics
echo 1. System information
echo 2. Windows version
echo 3. Current identity
echo 4. Running processes
echo 5. Installed drivers
echo 0. Back
choice /c 012345 /n /m "Task: "
set "pick=%errorlevel%"
if "%pick%"=="1" goto home
if "%pick%"=="2" goto action1_1
if "%pick%"=="3" goto action1_2
if "%pick%"=="4" goto action1_3
if "%pick%"=="5" goto action1_4
if "%pick%"=="6" goto action1_5
goto category1
:action1_1
echo System information
systeminfo
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category1
:action1_2
echo Windows version
ver
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category1
:action1_3
echo Current identity
whoami /all
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category1
:action1_4
echo Running processes
tasklist
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category1
:action1_5
echo Installed drivers
driverquery /v
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category1
:category2
cls
echo Windows repair
echo 1. Component store scan
echo 2. Repair Windows image
echo 3. Repair protected files
echo 4. Online system disk scan
echo 0. Back
choice /c 01234 /n /m "Task: "
set "pick=%errorlevel%"
if "%pick%"=="1" goto home
if "%pick%"=="2" goto action2_1
if "%pick%"=="3" goto action2_2
if "%pick%"=="4" goto action2_3
if "%pick%"=="5" goto action2_4
goto category2
:action2_1
echo Component store scan
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category2)
DISM /Online /Cleanup-Image /ScanHealth
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category2
:action2_2
echo Repair Windows image
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category2)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category2
DISM /Online /Cleanup-Image /RestoreHealth
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category2
:action2_3
echo Repair protected files
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category2)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category2
sfc /scannow
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category2
:action2_4
echo Online system disk scan
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category2)
chkdsk %SystemDrive% /scan
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category2
:category3
cls
echo Networking
echo 1. IP configuration
echo 2. DNS lookup
echo 3. Connections
echo 4. Clear DNS cache
echo 5. Reset Winsock - restart required
echo 0. Back
choice /c 012345 /n /m "Task: "
set "pick=%errorlevel%"
if "%pick%"=="1" goto home
if "%pick%"=="2" goto action3_1
if "%pick%"=="3" goto action3_2
if "%pick%"=="4" goto action3_3
if "%pick%"=="5" goto action3_4
if "%pick%"=="6" goto action3_5
goto category3
:action3_1
echo IP configuration
ipconfig /all
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category3
:action3_2
echo DNS lookup
nslookup www.microsoft.com
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category3
:action3_3
echo Connections
netstat -ano
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category3
:action3_4
echo Clear DNS cache
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category3)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category3
ipconfig /flushdns
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category3
:action3_5
echo Reset Winsock - restart required
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category3)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category3
netsh winsock reset
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category3
:category4
cls
echo Firewall and policy
echo 1. Firewall profiles
echo 2. Private firewall ON
echo 3. Private firewall OFF
echo 4. Applied policy
echo 5. Refresh policy
echo 0. Back
choice /c 012345 /n /m "Task: "
set "pick=%errorlevel%"
if "%pick%"=="1" goto home
if "%pick%"=="2" goto action4_1
if "%pick%"=="3" goto action4_2
if "%pick%"=="4" goto action4_3
if "%pick%"=="5" goto action4_4
if "%pick%"=="6" goto action4_5
goto category4
:action4_1
echo Firewall profiles
netsh advfirewall show allprofiles
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category4
:action4_2
echo Private firewall ON
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category4)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category4
netsh advfirewall set privateprofile state on
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category4
:action4_3
echo Private firewall OFF
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category4)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category4
netsh advfirewall set privateprofile state off
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category4
:action4_4
echo Applied policy
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category4)
gpresult /r
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category4
:action4_5
echo Refresh policy
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category4)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category4
gpupdate /force
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category4
:category5
cls
echo Users and services
echo 1. List local users
echo 2. Create a standard local user
echo 3. Print spooler status
echo 4. Restart print spooler
echo 0. Back
choice /c 01234 /n /m "Task: "
set "pick=%errorlevel%"
if "%pick%"=="1" goto home
if "%pick%"=="2" goto action5_1
if "%pick%"=="3" goto action5_2
if "%pick%"=="4" goto action5_3
if "%pick%"=="5" goto action5_4
goto category5
:action5_1
echo List local users
net user
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category5
:action5_2
echo Create a standard local user
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category5)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category5
powershell.exe -NoLogo -NoProfile -Command "$u=Read-Host 'Username (letters/digits/underscore/hyphen)'; if($u -notmatch '^[A-Za-z0-9_-]{1,20}$'){throw 'Invalid username'}; $p=Read-Host 'Password' -AsSecureString; New-LocalUser -Name $u -Password $p -ErrorAction Stop; $g=Get-LocalGroup -SID 'S-1-5-32-545'; Add-LocalGroupMember -Group $g -Member $u -ErrorAction Stop"
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category5
:action5_3
echo Print spooler status
sc query Spooler
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category5
:action5_4
echo Restart print spooler
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category5)
echo This changes the system. Record current settings and use an authorized lab first.
choice /c YN /n /m "Proceed? Y/N: "
if errorlevel 2 goto category5
net stop Spooler
net start Spooler
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category5
:category6
cls
echo Windows features
echo 1. Optional feature inventory
echo 2. WSL feature status
echo 3. Virtual Machine Platform status
echo 0. Back
choice /c 0123 /n /m "Task: "
set "pick=%errorlevel%"
if "%pick%"=="1" goto home
if "%pick%"=="2" goto action6_1
if "%pick%"=="3" goto action6_2
if "%pick%"=="4" goto action6_3
goto category6
:action6_1
echo Optional feature inventory
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category6)
DISM /Online /Get-Features /Format:Table
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category6
:action6_2
echo WSL feature status
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category6)
DISM /Online /Get-FeatureInfo /FeatureName:Microsoft-Windows-Subsystem-Linux
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category6
:action6_3
echo Virtual Machine Platform status
fltmc >nul 2>&1
if errorlevel 1 (echo Open Command Prompt as Administrator. & pause & goto category6)
DISM /Online /Get-FeatureInfo /FeatureName:VirtualMachinePlatform
echo Review output above. Command completion does not prove the problem is fixed.
pause
goto category6
