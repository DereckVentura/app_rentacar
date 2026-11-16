@echo off
setlocal DisableDelayedExpansion
set "AUTORENT_CODEX_EXE="

rem Usa Codex instalado por la extension oficial de OpenAI.
for /d %%D in ("%USERPROFILE%\.vscode\extensions\openai.chatgpt-*") do (
    if exist "%%~fD\bin\windows-x86_64\codex.exe" set "AUTORENT_CODEX_EXE=%%~fD\bin\windows-x86_64\codex.exe"
)

if not defined AUTORENT_CODEX_EXE (
    echo No se encontro Codex. Instala la extension oficial openai.chatgpt en VS Code.
    exit /b 1
)

"%AUTORENT_CODEX_EXE%" --cd "%~dp0." %*
exit /b %ERRORLEVEL%
