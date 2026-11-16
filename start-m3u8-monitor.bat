@echo off
:: Run the m3u8 monitor in the background (async, hidden, 0.2s interval)
start /b "" pythonw "C:\Users\Adminator\Documents\SeeRuta\teammate\monitor-omegle-m3u8.py" > "%TEMP%\omegle_monitor_bg.log" 2>&1
echo Monitor started in background.
echo Log: %TEMP%\omegle_monitor_bg.log
echo Found links: %TEMP%\omegle_m3u8_found.txt
