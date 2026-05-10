# AXS (Advanced x86 Shell)

AXS is a 32-bit Windows command-line interpreter written in **x86 Assembly (MASM)** using the **Irvine32** library.

- Proposal: [docs/PROPOSAL.md](docs/PROPOSAL.md)
- Entry point: [src/main.asm](src/main.asm)

## Folder layout

- [src/](src/) — assembly modules (REPL, parser, built-ins, external execution, etc.)
- [include/](include/) — shared headers (`axs.inc`, minimal Win32 declarations)
- [scripts/](scripts/) — example `.shl` scripts
- [build/](build/) — `build.bat` / `clean.bat`

## Build (MASM + Irvine32)

Prerequisites:
- Visual Studio 2022 (or Build Tools) with **Desktop development with C++**
  - Provides the MSVC `link.exe` (required to produce a Win32 COFF console EXE)
   - Provides MASM `ml.exe` (recommended). If you only have MASM615, the build script can still find `ml.exe`, but you still need the MSVC linker (the old MASM615 `LINK.EXE` will not run on modern Windows).
- Irvine32 library folder (must contain `Irvine32.inc` and `Irvine32.lib`)

Steps:
1. Open **x86 Native Tools Command Prompt for VS** (recommended).
   - `build\build.bat` will also try to auto-locate Build Tools via `vswhere`/`vcvarsall.bat` if you run it from a normal shell.
2. Set the Irvine path (once per terminal):
   - `set IRVINE=C:\path\to\Irvine`
   - The folder must contain `Irvine32.inc` and `Irvine32.lib`.
3. From the repo root, run:
   - `build.bat` (or `build\build.bat`)

Finding your Irvine32 folder:
- If you’re not sure where Irvine is installed, search for `Irvine32.inc` and set `IRVINE` to the folder that contains it.
- PowerShell example (search under your user profile):
  - `Get-ChildItem -Path $env:USERPROFILE -Filter Irvine32.inc -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5 -ExpandProperty FullName`

Output:
- `axs.exe`

## Current status

- Working REPL loop with history (Up/Down) and Tab completion
- Parser: space + quoted tokens
- Built-ins: `cd dir type copy del mkdir rmdir ren echo set run help cls exit`
- Env: `%VAR%` expansion + `set` listing via Win32 env block
- Scripts: run `.shl` via `run yourfile.shl`
- Execution: CreateProcess-based external commands
- Operators: `| < > >> && || &` (basic pipeline + chaining)

## Run

- From the repo root: `./axs.exe`

## Quick test checklist

Inside AXS:
- Built-ins: `help`, `echo hi`, `cd \`, `dir`, `set`
- Env expansion: `set FOO=bar` then `echo %FOO%`
- Redirection: `echo hello > out.txt`, `echo again >> out.txt`, `type out.txt`
- Pipeline: `type out.txt | findstr hello`
- Chaining: `del missing.txt && echo should_not_print`, `del missing.txt || echo failure_ok`
- Script: `run scripts\sample.shl`
