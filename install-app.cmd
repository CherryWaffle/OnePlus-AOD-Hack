@echo off
rem Double-click to install the prebuilt AOD Keep-On app on the phone over USB.
rem The phone needs USB debugging on. Needs only adb (SDK Platform-Tools), see README.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\install.ps1" %*
pause
