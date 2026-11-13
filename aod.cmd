@echo off
rem Double-click after a reboot to turn all-day full-screen AOD back on.
rem From a terminal you can also pass: aod.cmd off   /   aod.cmd status
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0aod.ps1" %*
pause
