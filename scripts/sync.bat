@echo off
REM Manual sync: pull latest, then push any local commits.
REM Run: scripts\sync.bat
cd /d "%~dp0\.."
for /f "tokens=*" %%i in ('git branch --show-current') do set branch=%%i
echo Pulling from origin/%branch%...
git pull --rebase origin %branch% 2>nul || git pull origin %branch%
echo Pushing to origin/%branch%...
git push origin %branch%
echo Sync complete.
