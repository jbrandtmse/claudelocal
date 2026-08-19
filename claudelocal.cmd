@echo off
setlocal enabledelayedexpansion
REM claudelocal - run Claude Code CLI against a local model hosted on Ollama or LM Studio.
REM Works with localhost or any reachable host/IP on your network.
REM
REM   Ollama:    Anthropic-compatible endpoint at http://<host>:11434
REM   LM Studio: Anthropic-compatible endpoint at http://<host>:1234
REM
REM Docs:
REM   https://docs.ollama.com/integrations/claude-code
REM   https://lmstudio.ai/docs/integrations/claude-code

REM ---------------------------------------------------------------------------
REM Defaults (overridden by config file, then by command-line flags)
REM ---------------------------------------------------------------------------
set "BACKEND=ollama"
set "HOST=localhost"
set "PORT="
set "MODEL="
set "CONTEXT_TOKENS=65536"
set "AUTO_COMPACT_TOKENS="
set "AUTH_TOKEN="
set "TIMEOUT_MS="
set "CONFIG_FILE=%~dp0claudelocal.conf"
set "CLAUDE_ARGS="

REM ---------------------------------------------------------------------------
REM Config file selection: -c/--config must be the FIRST option if used
REM ---------------------------------------------------------------------------
if /i "%~1"=="-c" (set "CONFIG_FILE=%~2" & shift & shift)
if /i "%~1"=="--config" (set "CONFIG_FILE=%~2" & shift & shift)

REM ---------------------------------------------------------------------------
REM Config file (simple KEY=VALUE, # comments, blank lines ok)
REM ---------------------------------------------------------------------------
if exist "%CONFIG_FILE%" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    set "CKEY=%%A"
    set "CVAL=%%B"
    for /f "tokens=* delims= " %%K in ("!CKEY!") do set "CKEY=%%K"
    if /i "!CKEY!"=="BACKEND" set "BACKEND=!CVAL!"
    if /i "!CKEY!"=="HOST" set "HOST=!CVAL!"
    if /i "!CKEY!"=="PORT" set "PORT=!CVAL!"
    if /i "!CKEY!"=="MODEL" set "MODEL=!CVAL!"
    if /i "!CKEY!"=="CONTEXT_TOKENS" set "CONTEXT_TOKENS=!CVAL!"
    if /i "!CKEY!"=="AUTO_COMPACT_TOKENS" set "AUTO_COMPACT_TOKENS=!CVAL!"
    if /i "!CKEY!"=="AUTH_TOKEN" set "AUTH_TOKEN=!CVAL!"
    if /i "!CKEY!"=="TIMEOUT_MS" set "TIMEOUT_MS=!CVAL!"
  )
)

REM ---------------------------------------------------------------------------
REM Command-line flags (unknown args pass through to claude)
REM ---------------------------------------------------------------------------
:parse
if "%~1"=="" goto parse_done
set "ARG=%~1"

if /i "%~1"=="-m" (set "MODEL=%~2" & shift & shift & goto parse)
if /i "%~1"=="--model" (set "MODEL=%~2" & shift & shift & goto parse)
if /i "%~1"=="-b" (set "BACKEND=%~2" & shift & shift & goto parse)
if /i "%~1"=="--backend" (set "BACKEND=%~2" & shift & shift & goto parse)
if /i "%~1"=="-H" (set "HOST=%~2" & shift & shift & goto parse)
if /i "%~1"=="--host" (set "HOST=%~2" & shift & shift & goto parse)
REM -p: numeric value => our port flag; otherwise it's claude's -p (print mode)
if /i "%~1"=="-p" (
  echo %~2 | findstr /r /c:"^[0-9][0-9]*$" >nul
  if not errorlevel 1 (set "PORT=%~2" & shift & shift & goto parse)
  set "CLAUDE_ARGS=!CLAUDE_ARGS! "%~1""
  shift
  goto parse
)
if /i "%~1"=="--port" (
  echo %~2 | findstr /r /c:"^[0-9][0-9]*$" >nul
  if not errorlevel 1 (set "PORT=%~2" & shift & shift & goto parse)
  set "CLAUDE_ARGS=!CLAUDE_ARGS! "%~1""
  shift
  goto parse
)
if /i "%~1"=="-x" (set "CONTEXT_TOKENS=%~2" & shift & shift & goto parse)
if /i "%~1"=="--context" (set "CONTEXT_TOKENS=%~2" & shift & shift & goto parse)
if /i "%~1"=="-k" (set "AUTH_TOKEN=%~2" & shift & shift & goto parse)
if /i "%~1"=="--token" (set "AUTH_TOKEN=%~2" & shift & shift & goto parse)
if /i "%~1"=="-t" (set "TIMEOUT_MS=%~2" & shift & shift & goto parse)
if /i "%~1"=="--timeout" (set "TIMEOUT_MS=%~2" & shift & shift & goto parse)
if /i "%~1"=="-h" goto usage
if /i "%~1"=="--help" goto usage

REM --flag=value forms (/c: needed so findstr doesn't parse leading -- as switches)
echo "!ARG!" | findstr /i /b /c:"--model=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "MODEL=%%Y" & shift & goto parse)
echo "!ARG!" | findstr /i /b /c:"--backend=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "BACKEND=%%Y" & shift & goto parse)
echo "!ARG!" | findstr /i /b /c:"--host=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "HOST=%%Y" & shift & goto parse)
echo "!ARG!" | findstr /i /b /c:"--port=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "PORT=%%Y" & shift & goto parse)
echo "!ARG!" | findstr /i /b /c:"--context=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "CONTEXT_TOKENS=%%Y" & shift & goto parse)
echo "!ARG!" | findstr /i /b /c:"--token=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "AUTH_TOKEN=%%Y" & shift & goto parse)
echo "!ARG!" | findstr /i /b /c:"--timeout=" >nul && (for /f "tokens=1,* delims==" %%X in ("!ARG!") do set "TIMEOUT_MS=%%Y" & shift & goto parse)

if "%~1"=="--" (
  shift
  goto passthru
)

REM Unknown argument: pass through to claude
set "CLAUDE_ARGS=!CLAUDE_ARGS! "%~1""
shift
goto parse

:passthru
if "%~1"=="" goto parse_done
set "CLAUDE_ARGS=!CLAUDE_ARGS! "%~1""
shift
goto passthru

:parse_done

REM ---------------------------------------------------------------------------
REM Resolve backend-specific defaults
REM ---------------------------------------------------------------------------
if /i "%BACKEND%"=="lms" set "BACKEND=lmstudio"
if /i "%BACKEND%"=="lm-studio" set "BACKEND=lmstudio"
if /i not "%BACKEND%"=="ollama" if /i not "%BACKEND%"=="lmstudio" (
  echo claudelocal: ERROR: unknown backend '%BACKEND%' ^(expected 'ollama' or 'lmstudio'^)
  exit /b 1
)
if "%PORT%"=="" (
  if /i "%BACKEND%"=="ollama" (set "PORT=11434") else (set "PORT=1234")
)

REM Build the base URL (HOST may be a bare host/IP or a full URL)
set "BASE_URL=%HOST%"
echo %BASE_URL% | findstr /i /b "http://" >nul
if errorlevel 1 (
  echo %BASE_URL% | findstr /i /b "https://" >nul
  if errorlevel 1 set "BASE_URL=http://%BASE_URL%"
)
echo %BASE_URL% | findstr /c:":%PORT%" >nul
if errorlevel 1 set "BASE_URL=%BASE_URL%:%PORT%"

if "%AUTH_TOKEN%"=="" set "AUTH_TOKEN=%BACKEND%"

REM ---------------------------------------------------------------------------
REM Reachability check + model auto-detect
REM ---------------------------------------------------------------------------
where curl >nul 2>&1
if not errorlevel 1 (
  curl -s -m 5 -o nul "%BASE_URL%/v1/models"
  if errorlevel 1 (
    echo claudelocal: WARNING: could not reach %BASE_URL%
    echo   Is the %BACKEND% server running on %HOST%:%PORT%? Continuing anyway...
  )
)

if "%MODEL%"=="" (
  for /f "usebackq delims=" %%M in (`powershell -NoProfile -Command "try { (Invoke-RestMethod -TimeoutSec 5 -Uri '%BASE_URL%/v1/models').data[0].id } catch { '' }"`) do set "MODEL=%%M"
  if "!MODEL!"=="" (
    echo claudelocal: ERROR: no model configured and none could be auto-detected.
    echo   Set MODEL in claudelocal.conf or pass -m/--model.
    exit /b 1
  )
  echo claudelocal: auto-detected model '!MODEL!'
)

REM ---------------------------------------------------------------------------
REM Environment for the launched Claude Code session
REM ---------------------------------------------------------------------------
set "ANTHROPIC_BASE_URL=%BASE_URL%"
set "ANTHROPIC_AUTH_TOKEN=%AUTH_TOKEN%"
set "ANTHROPIC_API_KEY="

REM Every model tier and subagent uses the same local model
set "ANTHROPIC_MODEL=%MODEL%"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=%MODEL%"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=%MODEL%"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=%MODEL%"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=%MODEL%"
set "ANTHROPIC_SMALL_FAST_MODEL=%MODEL%"
set "CLAUDE_CODE_SUBAGENT_MODEL=%MODEL%"

REM Auto-compact window: leave ~25% headroom below the real context window so
REM compaction starts at ~70-75% usage, with room for the response and overhead.
if "%AUTO_COMPACT_TOKENS%"=="" set /a AUTO_COMPACT_TOKENS=CONTEXT_TOKENS * 3 / 4

REM Context / compaction tuned to the local model's window
set "CLAUDE_CODE_MAX_CONTEXT_TOKENS=%CONTEXT_TOKENS%"
set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=%AUTO_COMPACT_TOKENS%"

REM Keep the session local-first; tool search targets Anthropic's backend
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
set "ENABLE_TOOL_SEARCH=false"

REM Per-request API timeout: only override Claude Code's own default
REM (600000ms) when the user configured one.
set "TIMEOUT_MSG="
if not "%TIMEOUT_MS%"=="" (
  set "API_TIMEOUT_MS=%TIMEOUT_MS%"
  set "TIMEOUT_MSG= timeout=%TIMEOUT_MS%"
)

echo claudelocal: backend=%BACKEND% url=%BASE_URL% model=%MODEL% context=%CONTEXT_TOKENS% compact=%AUTO_COMPACT_TOKENS%%TIMEOUT_MSG%
call claude %CLAUDE_ARGS%
exit /b %errorlevel%

:usage
echo claudelocal - run Claude Code against a local Ollama or LM Studio model.
echo.
echo Usage: claudelocal [-c config] [options] [--] [claude args...]
echo.
echo Options:
echo   -m, --model NAME      Model name (overrides config; default: first model
echo                         the server reports, e.g. qwen2.5-coder:7b)
echo   -b, --backend NAME    ollama ^| lmstudio   (default: ollama or config)
echo   -H, --host HOST       Hostname or IP of the model server (default: localhost)
echo   -p, --port PORT       Port (default: 11434 for Ollama, 1234 for LM Studio).
echo                         A non-numeric value after -p is passed to claude
echo                         (claude's own -p/--print flag keeps working)
echo   -x, --context N       Context window in tokens (default: 65536 or config);
echo                         auto-compact window is calculated as 75%% of this
echo   -k, --token TOKEN     Auth token if the server requires one (LM Studio
echo                         "Require Authentication"); placeholder otherwise
echo   -t, --timeout MS      API request timeout in milliseconds (default:
echo                         Claude Code's own default of 600000 / 10 min).
echo                         Raise this if slow local inference causes "API
echo                         Error (Request timed out)"
echo   -c, --config FILE     Use a different config file (must be first option)
echo   -h, --help            Show this help
echo.
echo Any other arguments are passed through to claude, e.g.:
echo   claudelocal -m qwen2.5-coder:14b -- --verbose
echo   claudelocal -b lmstudio -H 192.168.1.50 -p 1234
echo.
echo Config file: claudelocal.conf next to this script (see claudelocal.conf.example).
echo Precedence: command-line flag ^> config file ^> built-in default.
exit /b 0
