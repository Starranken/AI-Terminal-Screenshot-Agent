@echo off
setlocal
set "SCREENSHOT_AGENT_SCRIPT=%~dp0watch-screenshots.ps1"
powershell.exe -NoProfile -Command "$code = Get-Content -LiteralPath $env:SCREENSHOT_AGENT_SCRIPT -Raw; & ([scriptblock]::Create($code))"
endlocal
