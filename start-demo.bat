@echo off
cd /d "%~dp0"
start "Campus Table server" /min python -m http.server 4173 --bind 127.0.0.1
timeout /t 2 >nul
start "Campus Table" http://127.0.0.1:4173/
