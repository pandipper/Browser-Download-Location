@echo off
REM Thin ASCII wrapper: runs Install-Shortcut.ps1 next to this file.
REM Bypass execution policy because this machine blocks unsigned .ps1 by default.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Shortcut.ps1"
echo.
pause
