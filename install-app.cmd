@echo off
rem Double-click to build the AOD Keep-On app and install it on the phone over USB.
rem The phone needs USB debugging on. Needs Android Studio (or the Android SDK and a JDK 17+).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\build.ps1" -Install %*
pause
