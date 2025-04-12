@ECHO off
setlocal enabledelayedexpansion

REM Detect path prefix
if defined RUNFILES_DIR (
    set "PATH_PREFIX=%RUNFILES_DIR%\{workspace_name}\"
) else if exist "%~dp0\..\..\MANIFEST" (
    set "PATH_PREFIX="%~dp0\"
) else if exist "%~f0.runfiles" (
    set "PATH_PREFIX=%~f0.runfiles\{workspace_name}\"
) else (
    set "PATH_PREFIX=.\"
)

REM Set PERL5LIB environment variable
set "PERL5LIB=%PERL5LIB%{PERL5LIB}"

REM Set environment variables
{env_vars}

REM Run the main interpreter
"%PATH_PREFIX%{interpreter}" "%PATH_PREFIX%{main}" %*

exit /b %ERRORLEVEL%
