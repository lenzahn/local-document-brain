@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d=[Environment]::GetFolderPath('Desktop'); $w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut($d + '\Local Document Brain.lnk'); $s.TargetPath='%~dp0start.cmd'; $s.WorkingDirectory='%~dp0'; $s.IconLocation='%SystemRoot%\System32\shell32.dll,13'; $s.Save(); Write-Host ('Shortcut created: ' + $d + '\Local Document Brain.lnk')"
echo.
pause
