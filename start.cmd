@echo off
setlocal EnableExtensions
title Local Document Brain
cd /d "%~dp0"

echo.
echo  ==========================================
echo    Local Document Brain
echo  ==========================================
echo.

rem ---------------------------------------------------------------
rem  1. Docker Desktop
rem ---------------------------------------------------------------
docker info >nul 2>&1
if not errorlevel 1 goto docker_ready

echo  [1/5] Starting Docker Desktop...
set "DOCKER_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
if exist "%DOCKER_EXE%" (
    start "" "%DOCKER_EXE%"
) else (
    echo.
    echo  Docker Desktop was not found at:
    echo    %DOCKER_EXE%
    echo  Install it from https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

set /a wait=0
:wait_docker
timeout /t 3 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto docker_ready
set /a wait+=1
if %wait% lss 60 goto wait_docker
echo.
echo  Docker did not start within three minutes.
echo  Open Docker Desktop yourself, then run this again.
echo.
pause
exit /b 1

:docker_ready
echo  [1/5] Docker is ready.

rem ---------------------------------------------------------------
rem  2. Ollama
rem ---------------------------------------------------------------
curl.exe -s -o NUL --max-time 3 http://127.0.0.1:11434/api/tags >nul 2>&1
if not errorlevel 1 goto ollama_ready

echo  [2/5] Starting Ollama...
set "OLLAMA_EXE=%LOCALAPPDATA%\Programs\Ollama\ollama app.exe"
if exist "%OLLAMA_EXE%" (
    start "" "%OLLAMA_EXE%"
) else (
    echo        Not found in the usual place. Start Ollama from the Start menu.
)

set /a wait=0
:wait_ollama
timeout /t 2 /nobreak >nul
curl.exe -s -o NUL --max-time 3 http://127.0.0.1:11434/api/tags >nul 2>&1
if not errorlevel 1 goto ollama_ready
set /a wait+=1
if %wait% lss 60 goto wait_ollama
echo.
echo  Ollama is not answering on port 11434.
echo  Start Ollama yourself, then run this again.
echo.
pause
exit /b 1

:ollama_ready
echo  [2/5] Ollama is ready.

rem ---------------------------------------------------------------
rem  3. Models
rem ---------------------------------------------------------------
echo  [3/5] Checking models...
call :ensure_model granite4.2:8b
call :ensure_model ibm/granite3.3-vision:2b
call :ensure_model nomic-embed-text

rem ---------------------------------------------------------------
rem  4. Services
rem ---------------------------------------------------------------
echo  [4/5] Starting the services...
docker compose up -d
if errorlevel 1 (
    echo.
    echo  Could not start the services. Last log lines:
    echo.
    docker compose logs --tail 40
    echo.
    pause
    exit /b 1
)

rem ---------------------------------------------------------------
rem  5. Wait for the site, then open it and show logs
rem ---------------------------------------------------------------
echo  [5/5] Waiting for the website to answer...
set /a wait=0
:wait_web
curl.exe -s -o NUL --max-time 3 http://localhost:3000 >nul 2>&1
if not errorlevel 1 goto web_ready
set /a wait+=1
if %wait% lss 90 goto wait_web
echo.
echo  The website did not answer in time. Last log lines:
echo.
docker compose logs --tail 40
echo.
pause
exit /b 1

:web_ready
start "" http://localhost:3000
echo.
echo  ==========================================
echo    Ready - opening http://localhost:3000
echo  ==========================================
echo.
echo  Live logs below. Press Ctrl+C to close this window.
echo  The services keep running either way.
echo.
docker compose logs -f
exit /b 0

rem ---------------------------------------------------------------
rem  Helper: pull a model only if it is missing
rem ---------------------------------------------------------------
:ensure_model
ollama list | findstr /C:"%~1" >nul 2>&1
if not errorlevel 1 (
    echo        %~1 - already present
    exit /b 0
)
echo        %~1 - downloading now, this is a one-time several GB download...
ollama pull %~1
exit /b 0
