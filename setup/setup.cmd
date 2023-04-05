@echo off
pushd "%~dp0"
PowerShell.exe -NoProfile Invoke-Build -File .\setup.ps1 %*
set err=%errorlevel%
popd
exit /b %err%


