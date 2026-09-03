@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"
cd /d "%REPO_ROOT%"

if "%SOURCE_MANAGER_HOST%"=="" (
  set "HOST=127.0.0.1"
) else (
  set "HOST=%SOURCE_MANAGER_HOST%"
)
if "%SOURCE_MANAGER_PORT%"=="" (
  set "PORT_START=8765"
) else (
  set "PORT_START=%SOURCE_MANAGER_PORT%"
)

if "%LOCALAPPDATA%"=="" (
  set "LOG_DIR=%TEMP%\ADAM-SSM\Logs"
) else (
  set "LOG_DIR=%LOCALAPPDATA%\ADAM-SSM\Logs"
)
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>nul
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%I"
set "LOG_PATH=%LOG_DIR%\source-manager-%STAMP%.log"

echo ADAM SSM - Sleepless Source Manager
echo Started: %DATE% %TIME%
echo Working directory: %REPO_ROOT%
echo Requested URL: http://%HOST%:%PORT_START%
echo Log path: %LOG_PATH%
(
  echo ADAM SSM - Sleepless Source Manager
  echo Started: %DATE% %TIME%
  echo Working directory: %REPO_ROOT%
  echo Requested URL: http://%HOST%:%PORT_START%
  echo Log path: %LOG_PATH%
)>>"%LOG_PATH%"

where python >nul 2>nul
if %errorlevel%==0 (
  set "PY=python"
) else (
  where py >nul 2>nul
  if %errorlevel%==0 (
    set "PY=py -3"
  ) else (
    echo Python 3 was not found.
    echo Install Python from https://www.python.org/downloads/windows/ and try again.
    (
      echo Python 3 was not found.
      echo Install Python from https://www.python.org/downloads/windows/ and try again.
    )>>"%LOG_PATH%"
    pause
    exit /b 1
  )
)

for /f "delims=" %%I in ('where python 2^>nul') do (
  if not defined PYTHON_PATH set "PYTHON_PATH=%%I"
)
if not defined PYTHON_PATH for /f "delims=" %%I in ('where py 2^>nul') do (
  if not defined PYTHON_PATH set "PYTHON_PATH=%%I"
)
echo Python path: %PYTHON_PATH%
%PY% --version
echo Starting local server...
echo If the browser does not open, copy the URL printed below into your browser.
(
  echo Python path: %PYTHON_PATH%
  %PY% --version
  echo Starting local server...
  echo If the browser does not open, copy the URL printed below into your browser.
)>>"%LOG_PATH%" 2>&1
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { & %PY% 'code\tools\sources\ui_local.py' '--host' '%HOST%' '--port' '%PORT_START%' '--open-browser' 2>&1 | Tee-Object -FilePath '%LOG_PATH%' -Append; exit $LASTEXITCODE }"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo Exit code: %EXIT_CODE%
if "%EXIT_CODE%"=="0" (
  echo Final status: ADAM SSM stopped normally.
) else (
  echo Final status: ADAM SSM did not start or stopped with an error.
  echo Last log lines:
  powershell -NoProfile -Command "Get-Content -Path '%LOG_PATH%' -Tail 20" 2>nul
)
echo Full log path: %LOG_PATH%
(
  echo Exit code: %EXIT_CODE%
  if "%EXIT_CODE%"=="0" (
    echo Final status: ADAM SSM stopped normally.
  ) else (
    echo Final status: ADAM SSM did not start or stopped with an error.
  )
  echo Full log path: %LOG_PATH%
)>>"%LOG_PATH%"
pause
exit /b %EXIT_CODE%
