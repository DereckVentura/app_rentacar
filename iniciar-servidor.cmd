@echo off
cd /d "%~dp0backend"
set "PATH=C:\Program Files\nodejs\Documents;%PATH%"
node dist/server.js
pause
