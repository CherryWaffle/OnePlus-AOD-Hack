@echo off
rem Double-click to build AOD Keep-On from source and install it on the phone over USB.
rem Needs Android Studio (or the Android SDK and a JDK 17+). Most people want install-app.cmd.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\build.ps1" -Install %*
pause
