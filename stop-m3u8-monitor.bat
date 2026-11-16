@echo off
:: Stop the background m3u8 monitor
taskkill /F /IM pythonw.exe >nul 2>&1
taskkill /F /IM python.exe >nul 2>&1
echo Monitor stopped.
