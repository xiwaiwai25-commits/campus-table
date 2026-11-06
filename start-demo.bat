@echo off
cd /d "%~dp0"
start "Campus Table server" /min python -m http.server 4173
timeout /t 2 >nul
start "Campus Table" http://localhost:4173
