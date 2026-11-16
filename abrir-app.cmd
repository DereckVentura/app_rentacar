@echo off
cd /d "%~dp0backend"
set "PATH=C:\Program Files\nodejs\Documents;%PATH%"
echo Abre http://127.0.0.1:8080 en tu navegador.
node scripts/serve-web.mjs
pause
