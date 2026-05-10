# AXS — Advanced x86 Shell

**A fully functional 32-bit Windows command-line interpreter written entirely in x86 Assembly Language (MASM).**

AXS implements the complete REPL cycle — interactive input with history and tab-completion, a tokenizing parser, 16 built-in commands, environment variable expansion, I/O redirection, anonymous pipes, command chaining, background execution, external process launching, and `.shl` script execution — using only Win32 API calls and the Irvine32 helper library. No C runtime. No higher-level language.

> **Course:** Computer Organization & Assembly Language (COAL) — Group 11
> **Platform:** Windows (32-bit COFF PE), MASM + Irvine32
> **Output binary:** `axs.exe`

---

## Table of Contents

1. [Features](#features)
2. [Repository Layout](#repository-layout)
3. [Architecture Overview](#architecture-overview)
4. [Module Reference](#module-reference)
5. [Built-in Commands](#built-in-commands)
6. [Operators & Special Syntax](#operators--special-syntax)
7. [Environment Variables](#environment-variables)
8. [Script Files (.shl)](#script-files-shl)
9. [Command History & Tab Completion](#command-history--tab-completion)
10. [Build Instructions](#build-instructions)
11. [Running AXS](#running-axs)
12. [Quick Test Checklist](#quick-test-checklist)
13. [Data Structures & Constants](#data-structures--constants)
14. [Win32 API Surface](#win32-api-surface)
15. [Team](#team)

---

## Features

| Category | Details |
|---|---|
| **Interactive REPL** | Prompt shows current working directory; full line editing |
| **Command History** | Circular buffer of 10 entries; Up/Down arrow navigation |
| **Tab Completion** | Filename auto-complete via `FindFirstFileA` / `FindNextFileA` |
| **Parser** | Space-delimited tokenizer with quoted-string grouping; in-place 0-termination |
| **Built-ins** | `cd dir type copy del mkdir rmdir ren echo set run cls help ver title exit` (16 commands) |
| **Environment Vars** | `%VAR%` expansion; `set NAME=VALUE`; `set` listing; backed by Win32 env block |
| **Pipes** | `cmd1 | cmd2 | cmd3` — anonymous pipes between built-ins and/or external programs |
| **Redirection** | `>` (overwrite), `>>` (append), `<` (input) |
| **Chaining** | `&&` (run-on-success), `||` (run-on-failure) |
| **Background** | Trailing `&` — launch without waiting |
| **External Programs** | `CreateProcessA`-based launch of any `.exe` / `.com` / `.bat` |
| **Script Files** | `.shl` batch files executed line-by-line with full shell semantics |
| **Non-interactive mode** | Pass a `.shl` path or an inline command as argv; process exits when done |

---

## Repository Layout

```
minimal_Shell/
├── src/
│   ├── main.asm        Entry point — initialization, REPL loop, argv handling
│   ├── utils.asm       String utilities (StrLen, StrEqI, StrToLowerInPlace, …)
│   ├── parser.asm      Tokenizer — quote-aware, in-place 0-termination
│   ├── builtins.asm    16 built-in command implementations
│   ├── env.asm         %VAR% expansion, set/list environment variables
│   ├── history.asm     Circular command-history buffer (10 slots)
│   ├── console.asm     Interactive line editor — backspace, arrows, tab
│   ├── dispatch.asm    Shell_ExecuteLine — unified execution entry point
│   ├── pipeline.asm    Pipes, redirections, chaining, background (| > >> < && || &)
│   ├── external.asm    CreateProcess-based external program launcher
│   └── script.asm      .shl script file reader / executor
├── include/
│   ├── axs.inc         Shared constants, COMMAND struct, all module PROTOs
│   └── win32_min.inc   Minimal Win32 API declarations (no full SDK headers needed)
├── scripts/
│   └── sample.shl      Safe demo script (echo, cd, dir)
├── build/
│   ├── build.bat       Assembles all 11 modules and links axs.exe
│   └── clean.bat       Removes .obj / .exe / .pdb / .ilk artefacts
├── build.bat           Convenience wrapper -> build\build.bat
├── clean.bat           Convenience wrapper -> build\clean.bat
├── docs/
│   └── PROPOSAL.md     Original project proposal (Group 11)
└── PROJECT_REPORT.md   Comprehensive implementation report
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           axs.exe                                   │
│                         main.asm                                    │
│   Init all modules → Check argv → Banner → REPL loop               │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  Console_ReadLine (console.asm)
                               │  • raw key-by-key input
                               │  • Up/Down → history recall
                               │  • Tab → filename completion
                               ▼
                        History_Add (history.asm)
                               │
                               ▼
                   Shell_ExecuteLine (dispatch.asm)
                               │
              ┌────────────────┼────────────────────┐
              │                │                    │
   Env_ExpandPercentVars  Pipeline_TryExecute   (fallback)
     (env.asm)              (pipeline.asm)      Parser_ParseLine
                               │                    │
                    ┌──────────┤          ┌──────────┴──────────┐
                    │  found   │          │                     │
              segments split  │  Builtins_TryExecute   External_Execute
              on | > >> <     │    (builtins.asm)       (external.asm)
              && || &         │
                    │         │
              Pipe_SpawnExternal / Pipe_RunBuiltinWithHandles
              (handle inheritance, CreatePipe, SetStdHandle)
```

### Execution path summary

1. `Console_ReadLine` gathers a line character-by-character, handling editing keys.
2. The line is pushed to the history ring buffer.
3. `Shell_ExecuteLine` first expands any `%VAR%` tokens.
4. If the line contains `|`, `>`, `>>`, `<`, `&&`, `||`, or `&`, `Pipeline_TryExecute` takes over:
   - Splits the line into *segments* separated by operators.
   - Allocates anonymous pipes between adjacent segments.
   - For each segment: if it is a built-in, calls `Pipe_RunBuiltinWithHandles` (which temporarily redirects `SetStdHandle` before calling the built-in in-process); otherwise calls `Pipe_SpawnExternal` (which passes inherited handles to `CreateProcessA`).
   - Evaluates `&&`/`||` by checking the last exit code before proceeding.
5. If no operators are found, the line is tokenized by `Parser_ParseLine`, tried as a built-in, and finally attempted as an external program.

---

## Module Reference

### `main.asm` — Entry point (169 lines)

- Calls `*_Init` for every module at startup.
- Checks the process command line (`GetCommandLineA`) for a `.shl` path or an inline command tail; runs non-interactively if found.
- Runs the REPL loop: prompt → read → history → execute → repeat.
- Uses `GetCurrentDirectoryA` to build the prompt string dynamically.

### `utils.asm` — String utilities (221 lines)

| Procedure | Description |
|---|---|
| `StrLen` | Null-terminated string length |
| `StrSkipSpaces` | Advance past space/tab characters |
| `StrToLowerInPlace` | ASCII lower-case conversion in place |
| `StrEqI` | Case-insensitive equality (returns 1/0) |
| `StrStartsWithI` | Case-insensitive prefix test |
| `StrEndsWithI` | Case-insensitive suffix test |
| `StrStripOuterQuotesInPlace` | Remove surrounding `"` pair |

### `parser.asm` — Tokenizer (108 lines)

`Parser_ParseLine` scans the input buffer byte-by-byte:
- Lines beginning with `#` produce zero tokens (comment).
- Quoted spans (`"…"`) are captured as a single token regardless of embedded spaces.
- Tokens are 0-terminated **in-place** — no heap allocation, no copies.
- Stores up to `MAX_TOKENS` (32) DWORD pointers in `COMMAND.argv`; count in `COMMAND.argc`.

### `builtins.asm` — Built-in commands (635 lines)

`Builtins_TryExecute` compares `argv[0]` case-insensitively against each built-in name. All output goes through `Builtin_WriteStdoutBuf` / `Builtin_WriteStdoutZ` so that stdout can be redirected through pipes without changing the call sites.

### `env.asm` — Environment variables (244 lines)

- `Env_ExpandPercentVars` — scans for `%NAME%` pairs, calls `GetEnvironmentVariableA`, splices value into a fresh buffer.
- `Env_SetFromCommand` — parses `NAME=VALUE` and calls `SetEnvironmentVariableA`.
- `Env_PrintAll` — retrieves the process environment block (`GetEnvironmentStringsA`) and prints each `NAME=VALUE` pair.

### `history.asm` — Command history (167 lines)

- Static array of `HISTORY_SIZE` (10) slots, each `MAX_LINE` (512) bytes wide.
- `head` index advances with each `History_Add`; wraps at 10 (circular).
- `History_Prev` / `History_Next` copy the selected slot to the caller's buffer.

### `console.asm` — Line editor (320 lines)

`Console_ReadLine` reads raw key events in a loop:
- **Printable key** → append to buffer, echo to screen.
- **Backspace** → erase last character from buffer and screen.
- **Up arrow** → call `History_Prev`, replace current line.
- **Down arrow** → call `History_Next`, replace current line.
- **Tab** → call `Console_TabComplete` (`FindFirstFileA`-based).
- **Enter** → null-terminate buffer, return length.

### `dispatch.asm` — Unified executor (49 lines)

`Shell_ExecuteLine`:
1. `Env_ExpandPercentVars` on the raw line.
2. `Pipeline_TryExecute` — returns handled=1 if any operator was found.
3. Otherwise: `Parser_ParseLine` → `Builtins_TryExecute` → `External_Execute`.

### `pipeline.asm` — Operators (812 lines)

The most complex module. Key procedures:

| Procedure | Role |
|---|---|
| `Pipeline_TryExecute` | Entry point; detects operators, splits line into segments |
| `Pipe_ExecuteSegment` | Execute one segment with specified stdin/stdout handles |
| `Pipe_SpawnExternal` | `CreateProcessA` with handle inheritance for pipe endpoints |
| `Pipe_RunBuiltinWithHandles` | Temporarily `SetStdHandle`, call built-in in-process, restore |

Pipe creation uses `CreatePipe`; the write end is passed to one process as stdout, the read end to the next as stdin. Both ends in the parent are closed after inheritance to avoid deadlocks.

### `external.asm` — External launcher (129 lines)

`External_Execute` rebuilds a flat command-line string from the `argv` array, then calls `CreateProcessA`. The parent waits with `WaitForSingleObject` and retrieves the exit code via `GetExitCodeProcess`, storing it in `gLastExitCode`.

### `script.asm` — Script executor (143 lines)

`Script_RunFile` opens the file with `CreateFileA` and reads it line-by-line. Lines starting with `#` are skipped. Each non-empty line is dispatched through `Shell_ExecuteLine`. `exit` inside a script sets `gShouldExit`.

---

## Built-in Commands

| Command | Syntax | Description |
|---|---|---|
| `cd` | `cd [dir]` | Change directory; bare `cd` prints CWD |
| `dir` | `dir [pattern]` | List directory entries (default `*.*`) |
| `type` | `type <file>` | Print file contents to stdout |
| `copy` | `copy <src> <dest>` | Copy file (`CopyFileA`) |
| `del` | `del <file>` | Delete file (`DeleteFileA`) |
| `mkdir` | `mkdir <dir>` | Create directory (`CreateDirectoryA`) |
| `rmdir` | `rmdir <dir>` | Remove directory (`RemoveDirectoryA`) |
| `ren` | `ren <old> <new>` | Rename / move file (`MoveFileA`) |
| `echo` | `echo [text]` | Print text to stdout |
| `set` | `set [NAME=VALUE]` | Set or display environment variables |
| `run` | `run <file.shl>` | Execute a `.shl` script |
| `cls` | `cls` | Clear the console screen |
| `ver` | `ver` | Print Windows version (`GetVersionExA`) |
| `title` | `title <text>` | Set console window title (`SetConsoleTitleA`) |
| `help` | `help` | Print command reference |
| `exit` | `exit` | Exit the shell |

---

## Operators & Special Syntax

### Pipe `|`

```
type file.txt | findstr pattern
dir | sort
```

Chains commands so stdout of the left becomes stdin of the right. Both built-ins and external programs work as producer or consumer.

### Output Redirection `>` and `>>`

```
dir > listing.txt        # overwrite
echo new line >> log.txt # append
```

### Input Redirection `<`

```
sort < unsorted.txt
```

### Conditional Chaining `&&` and `||`

```
compile.bat && echo Build OK
compile.bat || echo Build FAILED
```

`&&` runs the right side only if the left exits with code 0.
`||` runs the right side only if the left exits with a non-zero code.

### Background Execution `&`

```
notepad &
```

Launches the process and returns to the prompt immediately (no `WaitForSingleObject`).

---

## Environment Variables

```
set MYPATH=C:\Tools         # define
set                         # list all (reads Win32 env block)
echo %MYPATH%               # expand inline
set COMBINED=%MYPATH%\bin   # expansion within set
```

`%VAR%` expansion happens before tokenization. Standard system variables (`PATH`, `TEMP`, `USERNAME`, etc.) are available immediately.

---

## Script Files (.shl)

```
# myscript.shl
echo Starting tasks...
mkdir output
dir *.txt > output\listing.txt
type output\listing.txt
echo Done.
```

Run with:

```
run myscript.shl
```

or pass directly to `axs.exe`:

```
axs.exe myscript.shl
```

- Lines beginning with `#` are comments.
- All operators (`|`, `>`, `>>`, `<`, `&&`, `||`, `&`) work inside scripts.
- `exit` terminates the script.

---

## Command History & Tab Completion

### History

- Last 10 commands kept in a circular buffer (512 bytes per slot).
- **Up arrow** recalls the previous command.
- **Down arrow** moves forward in history.
- In-memory only; not persisted across sessions.

### Tab Completion

- Press **Tab** while typing a partial filename to auto-complete it.
- Uses `FindFirstFileA` with the partial word as a wildcard prefix.

---

## Build Instructions

### Prerequisites

| Component | Notes |
|---|---|
| **Visual Studio 2022** (or Build Tools) | Must include *Desktop development with C++* |
| **MASM (`ml.exe`)** | Bundled with VS; build script auto-locates it |
| **MSVC linker (`link.exe`)** | Required — old MASM615 `LINK.EXE` will not work |
| **Irvine32 library** | Folder must contain `Irvine32.inc` and `Irvine32.lib` |

### Steps

**1.** Open **x86 Native Tools Command Prompt for VS 2022** (recommended).

> Alternatively run `build\build.bat` from any shell — the script auto-invokes `vswhere.exe` and `vcvarsall.bat`.

**2.** Set the Irvine path once per terminal session:

```
set IRVINE=C:\Irvine
```

To find your installation:

```powershell
Get-ChildItem -Path $env:USERPROFILE -Filter Irvine32.inc -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 5 -ExpandProperty FullName
```

**3.** From the repository root:

```
build.bat
```

Output: `axs.exe`

**4.** To clean artefacts:

```
clean.bat
```

---

## Running AXS

### Interactive mode

```
axs.exe
```

```
========================================
    AXS Shell v0.1 - Advanced x86 Shell
    Type 'help' for available commands
========================================
C:\Users\You> _
```

### Non-interactive: script file

```
axs.exe scripts\sample.shl
```

### Non-interactive: inline command

```
axs.exe echo hello world
axs.exe dir > listing.txt
```

---

## Quick Test Checklist

```
help
echo hi
cd \
dir
set
ver
title AXS test window

set FOO=bar
echo %FOO%

echo hello > out.txt
echo again >> out.txt
type out.txt

type out.txt | findstr hello

del missing.txt && echo should_not_print
del missing.txt || echo failure_ok

run scripts\sample.shl
```

---

## Data Structures & Constants

All shared definitions live in [include/axs.inc](include/axs.inc):

```asm
MAX_LINE        EQU 512      ; Maximum input/line buffer size (bytes)
MAX_TOKENS      EQU 32       ; Maximum tokens per parsed command
HISTORY_SIZE    EQU 10       ; Command history ring-buffer slots
MAX_ENV_VARS    EQU 32       ; (reserved) tracked env var limit
MAX_ENV_NAME    EQU 32       ; Max environment variable name length
MAX_ENV_VALUE   EQU 256      ; Max environment variable value length

COMMAND STRUCT
  argc  DWORD ?
  argv  DWORD MAX_TOKENS DUP(?)   ; DWORD pointers into the line buffer
COMMAND ENDS
```

Global state (defined in `main.asm`, exported via `axs.inc`):

| Symbol | Type | Purpose |
|---|---|---|
| `gLineBuf` | `BYTE[512]` | Shared input line buffer |
| `gCmd` | `COMMAND` | Shared parsed-command structure |
| `gShouldExit` | `DWORD` | Set to 1 by `exit` to break the REPL |
| `gLastExitCode` | `DWORD` | Exit code of the last command |

---

## Win32 API Surface

| API | Purpose |
|---|---|
| `GetCommandLineA` | Retrieve process command line |
| `GetCurrentDirectoryA` | Read CWD for prompt and `cd` |
| `SetCurrentDirectoryA` | Implement `cd` |
| `CreateFileA` | Open files for `type`, redirection, scripts |
| `ReadFile` | Read file contents |
| `WriteFile` | Write to stdout / file |
| `DeleteFileA` | Implement `del` |
| `CopyFileA` | Implement `copy` |
| `MoveFileA` | Implement `ren` |
| `CreateDirectoryA` | Implement `mkdir` |
| `RemoveDirectoryA` | Implement `rmdir` |
| `FindFirstFileA` / `FindNextFileA` / `FindClose` | `dir` listing, tab completion |
| `CreateProcessA` | Spawn external programs |
| `WaitForSingleObject` | Wait for process to finish |
| `GetExitCodeProcess` | Retrieve exit code |
| `CloseHandle` | Release kernel object handles |
| `CreatePipe` | Create anonymous pipe for `|` |
| `GetStdHandle` / `SetStdHandle` | Save and redirect stdout/stdin/stderr |
| `GetEnvironmentVariableA` | Read `%VAR%` expansion source |
| `SetEnvironmentVariableA` | `set NAME=VALUE` |
| `GetEnvironmentStringsA` / `FreeEnvironmentStringsA` | List all env vars |
| `ExitProcess` | Terminate with exit code |
| `GetVersionExA` | `ver` — OS version info |
| `wsprintfA` | Format `ver` output |
| `SetConsoleTitleA` | `title` — window caption |
| `FillConsoleOutputCharacterA` | `cls` — clear screen buffer |
| `SetConsoleCursorPosition` | `cls` — reset cursor |
| `GetConsoleScreenBufferInfo` | `cls` — get screen dimensions |

---

## Team

**Group 11 — COAL Project**

| Member | Role |
|---|---|
| Zainab Raza Malik | Core Engine & Parser — main loop, tokenizer, quote handling, input validation |
| Eiman Zahra | Built-in Commands & File System — `cd dir type copy del mkdir rmdir ren`, directory tracking |
| Saliha Waqas | Advanced Features — pipes, I/O redirection, chaining, background execution, env vars |
| Fatima Ahmed | External Execution & Integration — `CreateProcess`, error handling, scripting, testing |

---

*AXS demonstrates that a real, usable shell can be written entirely in assembly language — every byte of command parsing, every pipe handle, every process spawn orchestrated in raw x86 with no C runtime and no standard library.*
