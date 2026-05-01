@echo off
setlocal enabledelayedexpansion

REM Build script for AXS (32-bit MASM + Irvine32)
REM Run this from a "Developer Command Prompt for VS".

REM --- Configure Irvine32 location ---
if "%IRVINE%"=="" (
  REM Example default; edit if needed or set IRVINE env var.
  set "IRVINE=C:\Irvine"
)

if not exist "%IRVINE%\Irvine32.inc" (
  echo [AXS] ERROR: Irvine32 not found at "%IRVINE%".
  echo [AXS] Set IRVINE to your Irvine32 folder, e.g.
  echo [AXS]   set IRVINE=C:\Irvine
  exit /b 1
)

set "OUT=axs.exe"

echo [AXS] Assembling...
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\main.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\utils.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\parser.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\builtins.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\env.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\history.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\pipeline.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\script.asm
if errorlevel 1 exit /b 1
ml /nologo /c /coff /Zi /W3 /I "%IRVINE%" src\external.asm
if errorlevel 1 exit /b 1

echo [AXS] Linking...
link /nologo /SUBSYSTEM:CONSOLE /DEBUG /OUT:%OUT% \
  main.obj utils.obj parser.obj builtins.obj env.obj history.obj pipeline.obj script.obj external.obj \
  "%IRVINE%\Irvine32.lib" kernel32.lib user32.lib
if errorlevel 1 exit /b 1

echo [AXS] OK: %OUT%
endlocal
