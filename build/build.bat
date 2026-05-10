@echo off
setlocal enabledelayedexpansion

REM Always run from repo root (so relative paths like src\... resolve)
pushd "%~dp0.." >nul

REM Build script for Ash (32-bit MASM + Irvine32)
REM Recommended: run from a "Developer Command Prompt for VS".

REM --- Ensure assembler is discoverable ---
where ml >nul 2>nul
if errorlevel 1 (
  if exist "C:\Masm615\ML.EXE" (
    set "PATH=C:\Masm615;%PATH%"
  )
)

where ml >nul 2>nul
if errorlevel 1 (
  echo [Ash] ERROR: ml.exe not found.
  echo [Ash] - Open "Developer Command Prompt for VS", OR
  echo [Ash] - Install MASM and ensure ml.exe is on PATH.
  exit /b 1
)

REM --- Configure Irvine32 location ---
if "%IRVINE%"=="" (
  REM Common install locations (first match wins)
  if exist "C:\Irvine\Irvine32.inc" set "IRVINE=C:\Irvine"
  if "%IRVINE%"=="" if exist "C:\Irvine32\Irvine32.inc" set "IRVINE=C:\Irvine32"
  if "%IRVINE%"=="" if exist "C:\Irvine\Irvine\Irvine32.inc" set "IRVINE=C:\Irvine\Irvine"
  if "%IRVINE%"=="" if exist "C:\Users\%USERNAME%\Documents\Irvine\Irvine32.inc" set "IRVINE=C:\Users\%USERNAME%\Documents\Irvine"
  if "%IRVINE%"=="" set "IRVINE=C:\Irvine"
)

REM Irvine folder layouts vary. Support:
REM 1) %IRVINE%\Irvine32.inc + %IRVINE%\Irvine32.lib
REM 2) %IRVINE%\INCLUDE\Irvine32.inc + %IRVINE%\LIB\Irvine32.lib (e.g. C:\Masm615)
set "IRVINE_INC=%IRVINE%"
set "IRVINE_LIB=%IRVINE%"

if not exist "%IRVINE_INC%\Irvine32.inc" (
  if exist "%IRVINE%\INCLUDE\Irvine32.inc" set "IRVINE_INC=%IRVINE%\INCLUDE"
)

if not exist "%IRVINE_LIB%\Irvine32.lib" (
  if exist "%IRVINE%\LIB\Irvine32.lib" set "IRVINE_LIB=%IRVINE%\LIB"
)

if not exist "%IRVINE_INC%\Irvine32.inc" (
  echo [Ash] ERROR: Irvine32.inc not found.
  echo [Ash] IRVINE is "%IRVINE%"
  echo [Ash] Looked for:
  echo [Ash] - "%IRVINE%\Irvine32.inc"
  echo [Ash] - "%IRVINE%\INCLUDE\Irvine32.inc"
  echo [Ash] Fix: set IRVINE to the parent folder that contains Irvine32.inc
  exit /b 1
)

if not exist "%IRVINE_LIB%\Irvine32.lib" (
  echo [Ash] ERROR: Irvine32.lib not found.
  echo [Ash] IRVINE is "%IRVINE%"
  echo [Ash] Looked for:
  echo [Ash] - "%IRVINE%\Irvine32.lib"
  echo [Ash] - "%IRVINE%\LIB\Irvine32.lib"
  exit /b 1
)

REM --- Linker ---
REM Preferred: MSVC link.exe (from Visual Studio/Build Tools)
REM NOTE: The old MASM615 LINK.EXE is 16-bit and will not run on modern Windows.
set "LINKPATH="
for /f "delims=" %%L in ('where link.exe 2^>nul') do (
  set "LINKPATH=%%L"
  goto check_link
)
:check_link
if defined LINKPATH (
  if /I "%LINKPATH%"=="C:\Masm615\LINK.EXE" set "LINKPATH="
)
if defined LINKPATH goto have_link

REM Try to locate MSVC tools automatically via vswhere
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSINSTALL="
if exist "%VSWHERE%" for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%I"
if defined VSINSTALL if exist "%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat" call "%VSINSTALL%\VC\Auxiliary\Build\vcvarsall.bat" x86 >nul

set "LINKPATH="
for /f "delims=" %%L in ('where link.exe 2^>nul') do (
  set "LINKPATH=%%L"
  goto check_link2
)
:check_link2
if defined LINKPATH (
  if /I "%LINKPATH%"=="C:\Masm615\LINK.EXE" set "LINKPATH="
)
if not defined LINKPATH goto no_link
goto have_link

:no_link
echo [Ash] ERROR: link.exe not found (MSVC linker required).
echo [Ash] Fix: Install "Visual Studio Build Tools" with:
echo [Ash]   - Workload: Desktop development with C++
echo [Ash]   - Component: MSVC v143 (or similar) x86/x64 tools
echo [Ash]   - Windows 10/11 SDK
echo [Ash] Then open "x86 Native Tools Command Prompt for VS" and run build\build.bat
exit /b 1

:have_link

set "OUT=ash.exe"

echo [Ash] Assembling...
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\main.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\utils.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\parser.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\builtins.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\env.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\history.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\console.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\dispatch.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\pipeline.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\script.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE_INC%" /I include src\external.asm
if errorlevel 1 exit /b 1

echo [Ash] Linking...
link /nologo /SUBSYSTEM:CONSOLE /DEBUG /OUT:%OUT% ^
  main.obj utils.obj parser.obj builtins.obj env.obj history.obj console.obj dispatch.obj pipeline.obj script.obj external.obj ^
  "%IRVINE_LIB%\Irvine32.lib" kernel32.lib user32.lib
if errorlevel 1 exit /b 1

echo [Ash] OK: %OUT%
popd >nul
endlocal
