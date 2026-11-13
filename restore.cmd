@echo off
rem Double-click to undo everything: turns keep_aod_on off and lists AOD setting changes.
rem From a terminal you can also pass: restore.cmd -ApplySettings
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1" %*
pause
