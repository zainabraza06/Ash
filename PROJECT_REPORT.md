# Ash (minimal x86 shell for Windows) — Project Report

**Course:** Computer Organization & Assembly Language (COAL)
**Group:** 11
**Date:** May 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Objectives](#2-project-objectives)
3. [System Architecture](#3-system-architecture)
4. [Module-by-Module Implementation](#4-module-by-module-implementation)
   - 4.1 main.asm — Entry Point & REPL
   - 4.2 utils.asm — String Utilities
   - 4.3 parser.asm — Command Tokenizer
   - 4.4 builtins.asm — Built-in Commands
   - 4.5 env.asm — Environment Variable Engine
   - 4.6 history.asm — Command History
   - 4.7 console.asm — Interactive Line Editor
   - 4.8 dispatch.asm — Unified Execution Dispatcher
   - 4.9 pipeline.asm — Pipes, Redirection & Chaining
   - 4.10 external.asm — External Program Launcher
   - 4.11 script.asm — Script File Executor
5. [Data Structures](#5-data-structures)
6. [Win32 API Integration](#6-win32-api-integration)
7. [Advanced Features Deep-Dive](#7-advanced-features-deep-dive)
8. [Build System](#8-build-system)
9. [Testing & Verification](#9-testing--verification)
10. [Challenges & Solutions](#10-challenges--solutions)
11. [Project Statistics](#11-project-statistics)
12. [Learning Outcomes](#12-learning-outcomes)
13. [Team Contributions](#13-team-contributions)
14. [Conclusion](#14-conclusion)
15. [References](#15-references)

---

## 1. Executive Summary

**Ash** is a minimal x86 shell for Windows: a 32-bit command-line interpreter written entirely in x86 Assembly Language using the MASM assembler and the Irvine32 library. The project delivers a complete, usable shell with interactive editing, command history, tab completion, 16 built-in commands, environment variable expansion, I/O redirection, anonymous pipes, conditional command chaining, background execution, external process launching, and `.shl` script file support.

The codebase comprises approximately 2,600 lines of assembly across 11 source modules. All functionality is achieved through direct Win32 API calls — no C runtime library, no standard I/O library, and no higher-level language layer of any kind. Every character of user input, every pipe handle, and every spawned process is managed explicitly in raw x86 registers and memory.

This report documents the complete technical design, each module's implementation, the challenges encountered, and the assembly-level techniques used to solve them.

---

## 2. Project Objectives

| Objective | Status |
|---|---|
| Implement an interactive REPL (Read-Evaluate-Print Loop) | Complete |
| Support 16 built-in file-system and utility commands | Complete |
| Implement `%VAR%` environment variable expansion | Complete |
| Support I/O redirection (`>`, `>>`, `<`) | Complete |
| Support anonymous pipes (`|`) between commands | Complete |
| Support conditional chaining (`&&`, `||`) | Complete |
| Support background execution (`&`) | Complete |
| Implement command history with Up/Down arrow navigation | Complete |
| Implement Tab filename completion | Complete |
| Execute `.shl` script files line-by-line | Complete |
| Launch arbitrary external executables via `CreateProcessA` | Complete |
| Support non-interactive (batch / inline) mode | Complete |

---

## 3. System Architecture

### 3.1 High-Level Block Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         ash.exe (main.asm)                       │
│                                                                  │
│  Module init → argv check → banner → REPL loop                  │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                ┌──────────────▼──────────────┐
                │       console.asm           │
                │   Console_ReadLine          │
                │   • Printable chars         │
                │   • Backspace               │
                │   • Up/Down → history       │
                │   • Tab → file completion   │
                └──────────────┬──────────────┘
                               │
                ┌──────────────▼──────────────┐
                │       history.asm           │
                │   History_Add               │
                │   circular ring buffer      │
                └──────────────┬──────────────┘
                               │
                ┌──────────────▼──────────────┐
                │       dispatch.asm          │
                │   Shell_ExecuteLine         │
                └──┬──────────┬──────────┬────┘
                   │          │          │
          ┌────────▼──┐  ┌────▼────┐  ┌─▼──────────┐
          │  env.asm  │  │pipeline │  │  (fallback) │
          │ Expand    │  │  .asm   │  │  parser.asm │
          │ %VAR%     │  │TryExec  │  │  builtins   │
          └───────────┘  └────┬────┘  │  external   │
                              │       └─────────────┘
                    ┌─────────┴─────────┐
                    │                   │
           ┌────────▼───────┐  ┌────────▼────────┐
           │ builtins.asm   │  │  external.asm   │
           │ in-process     │  │  CreateProcessA │
           │ with redirected│  │  with inherited │
           │ handles        │  │  pipe handles   │
           └────────────────┘  └─────────────────┘
```

### 3.2 Module Dependency Graph

```
main.asm
 ├── ash.inc            (shared constants, structs, prototypes)
 │    └── win32_min.inc (minimal Win32 API declarations)
 ├── utils.asm          (no dependencies)
 ├── parser.asm         → utils.asm
 ├── builtins.asm       → utils.asm, env.asm, script.asm
 ├── env.asm            → utils.asm
 ├── history.asm        → utils.asm
 ├── console.asm        → history.asm, utils.asm
 ├── dispatch.asm       → env.asm, pipeline.asm, parser.asm,
 │                         builtins.asm, external.asm
 ├── pipeline.asm       → utils.asm, builtins.asm, external.asm
 ├── external.asm       → utils.asm
 └── script.asm         → dispatch.asm
```

### 3.3 Memory Layout

Each module uses only statically allocated `.data` segments. There is no heap usage and no dynamic memory allocation. Key buffers:

| Buffer | Location | Size | Purpose |
|---|---|---|---|
| `gLineBuf` | main.asm `.data` | 512 bytes | Primary input line |
| `gCmd.argv` | main.asm `.data` | 32 DWORDs | Token pointer array |
| History ring | history.asm `.data` | 10 × 512 = 5 120 bytes | Command history |
| Prompt buffer | main.asm `.data` | 260 bytes | CWD prompt string |
| Env expand buf | env.asm `.data` | 512 bytes | `%VAR%`-expanded line |
| Pipeline seg bufs | pipeline.asm `.data` | Multiple 512-byte bufs | Per-segment copies |

---

## 4. Module-by-Module Implementation

### 4.1 `main.asm` — Entry Point & REPL (169 lines)

**Responsibilities:** Program entry, module initialization, argv dispatch, REPL loop.

**Initialization sequence:**

```asm
call Parser_Init
call Builtins_Init
call External_Init
call Pipeline_Init
call Env_Init
call History_Init
call Script_Init
call Console_Init
```

Each `*_Init` procedure performs module-level setup (clearing buffers, setting indices to zero, etc.) without returning any meaningful value. This pattern ensures all modules start from a known state regardless of `.data` initialization order.

**Argv handling:**

`Main_GetArgsTail` calls `GetCommandLineA`, then skips past the executable path (handling both quoted and unquoted paths) using byte-by-byte scanning:

```asm
cmp al, '"'       ; check if path is quoted
je  quoted_path
scan_u:           ; unquoted: scan until space
    mov al, [esi]
    cmp al, ' '
    je  after_path
    inc esi
    jmp scan_u
```

After the path, if the tail is non-empty:
- If it ends with `.shl`, `Script_RunFile` is called.
- Otherwise the tail is treated as a single command line and dispatched through `Shell_ExecuteLine`.

**REPL loop:**

```asm
repl_loop:
    cmp  gShouldExit, 0       ; check exit flag
    jne  repl_exit

    INVOKE GetCurrentDirectoryA, SIZEOF PromptBuf, ADDR PromptBuf
    ; print CWD and "> "
    INVOKE Console_ReadLine, ADDR gLineBuf, MAX_LINE
    cmp  eax, 0               ; skip blank lines
    je   repl_loop

    INVOKE History_Add, OFFSET gLineBuf
    INVOKE Shell_ExecuteLine, ADDR gLineBuf
    jmp  repl_loop
```

### 4.2 `utils.asm` — String Utilities (221 lines)

**Design principle:** All string procedures follow the Irvine32 calling convention — arguments passed via the `INVOKE` macro using the stdcall ABI. Return values in `eax`. No caller-saved registers are modified without `USES` declarations.

**`StrLen`** — Counts bytes until a null terminator using `SCASB`:

```asm
StrLen PROC USES edi ecx, pStr:PTR BYTE
    mov edi, pStr
    mov ecx, 0FFFFh      ; max scan length
    xor al, al
    repne scasb
    mov eax, 0FFFFh
    sub eax, ecx
    dec eax              ; subtract the null byte
    ret
StrLen ENDP
```

**`StrEqI`** — Case-insensitive comparison converts each character to lower-case before comparing, using `StrToLowerInPlace` on local copies. Returns 1 if equal, 0 otherwise. Used by `Builtins_TryExecute` and `Builtins_IsBuiltin` to match command names.

**`StrEndsWithI`** — Used by `main.asm` to detect the `.shl` extension without a file-name registry lookup.

### 4.3 `parser.asm` — Command Tokenizer (108 lines)

**In-place tokenization** is the central technique: instead of copying tokens to new buffers, the parser writes null bytes (`0`) directly into the input buffer at token boundaries, then stores pointers to the starts of tokens. This means:
- Zero heap allocations.
- Tokens are valid C-style strings accessible by pointer arithmetic.
- The original buffer is modified, so callers must not depend on it being unchanged after `Parser_ParseLine`.

**Algorithm:**

```
state = SKIP_SPACES
for each byte in buffer:
    if state == SKIP_SPACES:
        if byte == ' ' or '\t': continue
        if byte == '#': return  (comment)
        if byte == '"': record start, state = IN_QUOTE
        else: record start, state = IN_TOKEN
    elif state == IN_TOKEN:
        if byte == ' ' or '\t' or '\0':
            write '\0' at current position
            store pointer, argc++
            state = SKIP_SPACES
    elif state == IN_QUOTE:
        if byte == '"':
            write '\0', store pointer, argc++
            state = SKIP_SPACES
```

The parser caps at `MAX_TOKENS` (32) to prevent buffer overflow in the `argv` array.

### 4.4 `builtins.asm` — Built-in Commands (635 lines)

**Dispatch mechanism:** `Builtins_TryExecute` calls `StrEqI` on `argv[0]` against a table of command-name strings. The first match jumps to the corresponding handler procedure. Returns 1 if matched, 0 if not a built-in.

**Stdout abstraction:** All output in built-in commands goes through two wrapper procedures:

- `Builtin_WriteStdoutBuf(pBuf, len)` — calls `WriteFile` with `GetStdHandle(STD_OUTPUT_HANDLE)`.
- `Builtin_WriteStdoutZ(pStr)` — calls `StrLen` then `Builtin_WriteStdoutBuf`.

Because these wrappers call `GetStdHandle` at the time of writing (not at call time), redirecting stdout via `SetStdHandle` before calling a built-in automatically routes all output to the redirected destination. This is the mechanism that makes built-ins work inside pipelines.

**`dir` implementation:**

```asm
Builtin_Dir PROC ...
    INVOKE FindFirstFileA, pattern, ADDR wfd   ; WIN32_FIND_DATA
dir_loop:
    cmp  eax, INVALID_HANDLE_VALUE
    je   dir_done
    ; format and print wfd.cFileName
    INVOKE FindNextFileA, hFind, ADDR wfd
    jmp dir_loop
dir_done:
    INVOKE FindClose, hFind
```

**`type` implementation:** Opens the file with `CreateFileA`, then reads in a 512-byte loop with `ReadFile`, writing each chunk to stdout with `Builtin_WriteStdoutBuf`. This correctly handles files larger than any single buffer.

**`cls` implementation:** Uses `GetConsoleScreenBufferInfo` to determine the screen dimensions, then `FillConsoleOutputCharacterA` to overwrite the entire buffer with spaces, followed by `SetConsoleCursorPosition` to move the cursor back to (0,0).

### 4.5 `env.asm` — Environment Variable Engine (244 lines)

**`Env_ExpandPercentVars`** — The algorithm scans the input line for `%` characters, extracts the name between a `%…%` pair, calls `GetEnvironmentVariableA`, and reconstructs the line in a local buffer:

```
output_ptr = output_buf
input_ptr  = input_line
while *input_ptr != '\0':
    if *input_ptr == '%':
        find closing '%'
        extract name
        call GetEnvironmentVariableA(name, tmp, 256)
        copy tmp into output_buf
        advance input_ptr past closing '%'
    else:
        copy *input_ptr to output_buf
        advance input_ptr
copy output_buf back over input_line
```

If `GetEnvironmentVariableA` returns 0 (variable not found), the `%NAME%` sequence is left unchanged in the output (same behaviour as cmd.exe).

**`Env_PrintAll`** — `GetEnvironmentStringsA` returns a pointer to a block of `NAME=VALUE\0` strings terminated by an extra `\0`. The procedure walks this block printing each string until it encounters the double-null terminator, then calls `FreeEnvironmentStringsA`.

### 4.6 `history.asm` — Command History (167 lines)

**Data structure:**

```asm
histBuf   BYTE HISTORY_SIZE * MAX_LINE DUP(0)   ; 10 * 512 = 5120 bytes
histHead  DWORD 0    ; index of the next slot to write
histCursor DWORD 0   ; browsing cursor for Up/Down navigation
```

`History_Add` computes the target slot address as `histHead * MAX_LINE + OFFSET histBuf`, copies the line in with a byte loop capped at `MAX_LINE - 1`, increments `histHead` and wraps modulo `HISTORY_SIZE`.

`History_Prev` decrements the cursor (wrapping) and copies the slot to the caller's output buffer. `History_Next` increments and copies. The cursor is reset to `histHead` on every `History_Add` so that Up/Down always starts from the most recent entry.

### 4.7 `console.asm` — Interactive Line Editor (320 lines)

**Raw input loop:** `Console_ReadLine` uses `ReadFile` with `STD_INPUT_HANDLE` in a 1-byte-at-a-time loop rather than `ReadConsole`, allowing special key handling. Virtual keys (arrow keys, backspace) are handled by checking the key code byte.

**Backspace handling:**

```asm
; move cursor back one, write space, move back again
INVOKE SetConsoleCursorPosition, hOut, prevPos
INVOKE WriteConsoleA, hOut, ADDR space, 1, ...
INVOKE SetConsoleCursorPosition, hOut, prevPos
dec bufLen
```

**History integration:** Up/Down arrow calls `History_Prev` or `History_Next`, copies the result into the input buffer, erases the current line on screen (`Console_EraseLine` writes spaces over the prompt length), and re-prints the recalled command.

**Tab completion (`Console_TabComplete`):**

1. Scan backward from the current cursor position to find the start of the current partial word.
2. Append `*` to form a wildcard pattern.
3. Call `FindFirstFileA` with the pattern.
4. If a match is found: replace the partial word in the buffer with the matched filename, update the screen.
5. Close the find handle.

### 4.8 `dispatch.asm` — Unified Execution Dispatcher (49 lines)

`Shell_ExecuteLine` is the single call site for all command execution:

```asm
Shell_ExecuteLine PROC, pLine:PTR BYTE
    ; 1. Expand environment variables in-place
    INVOKE Env_ExpandPercentVars, pLine, MAX_LINE

    ; 2. Try pipeline/operator handling
    INVOKE Pipeline_TryExecute, pLine
    cmp eax, 1
    je  exec_done

    ; 3. Tokenize
    INVOKE Parser_ParseLine, pLine, ADDR gCmd

    ; 4. Try built-ins
    INVOKE Builtins_TryExecute, ADDR gCmd
    cmp eax, 1
    je  exec_done

    ; 5. Try external
    INVOKE External_Execute, ADDR gCmd

exec_done:
    ret
Shell_ExecuteLine ENDP
```

This layered approach means each caller (REPL loop, script executor, pipeline segment handler) only needs to call one procedure and receives consistent exit-code semantics through `gLastExitCode`.

### 4.9 `pipeline.asm` — Pipes, Redirection & Chaining (812 lines)

This is the most complex module. It handles all shell operators: `|`, `>`, `>>`, `<`, `&&`, `||`, and `&`.

**Operator detection:** `Pipeline_TryExecute` scans the line for any of the operator bytes. If none are found, it returns 0 immediately. If operators are found, the line is split into segments.

**Segment structure:**

Each segment is a command string (possibly a built-in or external) plus the operator that follows it. The procedure iterates through segments, creating pipe pairs and file handles as needed.

**Pipe creation for `|`:**

```asm
INVOKE CreatePipe, ADDR hReadPipe, ADDR hWritePipe, ADDR sa, 0
; sa.bInheritHandle = TRUE so child processes inherit the handles
; Pass hWritePipe as stdout to left command
; Pass hReadPipe  as stdin  to right command
; Parent closes both ends after spawning children
```

Closing the parent's copy of each end is critical: without it, the read end would never receive EOF (the write end would remain open in the parent), causing the consumer to block indefinitely.

**Built-in execution with redirected handles (`Pipe_RunBuiltinWithHandles`):**

```asm
; Save current handles
INVOKE GetStdHandle, STD_OUTPUT_HANDLE
mov savedOut, eax
INVOKE GetStdHandle, STD_INPUT_HANDLE
mov savedIn, eax

; Install redirected handles
INVOKE SetStdHandle, STD_OUTPUT_HANDLE, hNewOut
INVOKE SetStdHandle, STD_INPUT_HANDLE,  hNewIn

; Execute built-in in-process
INVOKE Builtins_TryExecute, ADDR cmd

; Restore
INVOKE SetStdHandle, STD_OUTPUT_HANDLE, savedOut
INVOKE SetStdHandle, STD_INPUT_HANDLE,  savedIn
```

Because `Builtin_WriteStdoutZ` always calls `GetStdHandle` at write time, the built-in transparently writes to the pipe or file without any modification to the built-in code itself.

**External process with inherited handles (`Pipe_SpawnExternal`):**

The `STARTUPINFOA` struct has its `hStdOutput` / `hStdInput` fields set to the pipe ends, and `STARTF_USESTDHANDLES` is set in `dwFlags`. `CreateProcessA` is called with `bInheritHandles = TRUE`. The parent then closes its copies of the pipe ends.

**Conditional chaining (`&&`, `||`):**

After each segment executes, `gLastExitCode` holds the exit code. Before executing the next segment:

```asm
; && operator
cmp gLastExitCode, 0
jne skip_segment     ; skip if previous failed

; || operator
cmp gLastExitCode, 0
je  skip_segment     ; skip if previous succeeded
```

This implements short-circuit evaluation identical to POSIX shells.

**Background execution (`&`):**

When the operator after a segment is `&`, the segment is spawned with `CreateProcessA` but `WaitForSingleObject` is not called. The handle is immediately closed and execution continues.

### 4.10 `external.asm` — External Program Launcher (129 lines)

`External_Execute` reconstructs a flat command-line string from `gCmd.argv` by concatenating `argv[0]` through `argv[argc-1]` with spaces. This is required because `CreateProcessA`'s `lpCommandLine` parameter expects a single string.

```asm
STARTUPINFOA:
  cb            = SIZEOF STARTUPINFOA
  dwFlags       = 0
  (all other fields = 0)

PROCESS_INFORMATION:
  (filled by CreateProcessA)

INVOKE CreateProcessA,
    NULL,            ; lpApplicationName (NULL = use lpCommandLine)
    cmdLineBuf,      ; lpCommandLine
    NULL, NULL,      ; process/thread security attrs
    FALSE,           ; bInheritHandles
    0,               ; dwCreationFlags
    NULL,            ; lpEnvironment (inherit parent)
    NULL,            ; lpCurrentDirectory (inherit parent)
    ADDR si,
    ADDR pi

INVOKE WaitForSingleObject, pi.hProcess, INFINITE
INVOKE GetExitCodeProcess,  pi.hProcess, ADDR gLastExitCode
INVOKE CloseHandle, pi.hProcess
INVOKE CloseHandle, pi.hThread
```

Passing `NULL` for `lpApplicationName` lets Windows locate the executable through the `PATH` environment variable, so any program in PATH can be launched without the user specifying the full path.

### 4.11 `script.asm` — Script File Executor (143 lines)

`Script_RunFile` opens the `.shl` file with `GENERIC_READ`, then reads it in 1-byte increments to build lines in a local buffer. When a `\r`, `\n`, or `\0` is encountered, the accumulated line is processed:

1. Skip if empty or starts with `#`.
2. Call `Shell_ExecuteLine` for all other lines.
3. Check `gShouldExit` after each line; break if set.

Reading byte-by-byte is intentionally simple and avoids needing to handle partial-read boundary conditions in the line assembly logic. For script files (not hot paths), the overhead is acceptable.

---

## 5. Data Structures

### 5.1 `COMMAND` Structure

```asm
; defined in include/ash.inc
COMMAND STRUCT
  argc DWORD ?                         ; number of tokens
  argv DWORD MAX_TOKENS DUP(?)         ; 32 x DWORD pointers into line buffer
COMMAND ENDS
```

This mirrors the `argc`/`argv` convention from C. Because tokenization is in-place, `argv[i]` points directly into `gLineBuf` (or a pipeline segment buffer). No separate storage is needed for token text.

### 5.2 Command History Ring Buffer

```
histBuf[0]  [512 bytes] ← slot 0
histBuf[1]  [512 bytes] ← slot 1
...
histBuf[9]  [512 bytes] ← slot 9
histHead    DWORD       ← next write index (0–9, wraps)
histCursor  DWORD       ← current Up/Down browse position
```

The address of slot `n` is: `OFFSET histBuf + n * MAX_LINE`. Both `histHead` and `histCursor` are maintained as zero-based indices, and modular arithmetic (`mod HISTORY_SIZE`) handles wraparound.

### 5.3 `WIN32_FIND_DATA` (used by `dir` and tab completion)

```asm
; partial layout (from win32_min.inc)
WIN32_FIND_DATA STRUCT
  dwFileAttributes  DWORD ?
  ftCreationTime    QWORD ?
  ftLastAccessTime  QWORD ?
  ftLastWriteTime   QWORD ?
  nFileSizeHigh     DWORD ?
  nFileSizeLow      DWORD ?
  dwReserved0       DWORD ?
  dwReserved1       DWORD ?
  cFileName         BYTE 260 DUP(?)
  cAlternateFileName BYTE 14  DUP(?)
WIN32_FIND_DATA ENDS
```

The `cFileName` field (260 bytes) is the null-terminated filename used by `dir` for display and by `Console_TabComplete` for insertion into the edit buffer.

---

## 6. Win32 API Integration

### 6.1 Calling Convention

All Win32 functions use the `stdcall` calling convention: arguments pushed right-to-left, callee cleans the stack. MASM's `INVOKE` macro handles argument pushing and calling, and the `.model flat, stdcall` directive establishes this as the default for the entire project.

### 6.2 `win32_min.inc` — Minimal API Declarations

Rather than including the full Windows SDK headers (which are not available in a pure MASM environment), the project provides `include/win32_min.inc` with just the constants, structure definitions, and `PROTO` declarations needed by Ash. This keeps the include chain clean and avoids conflicts with Irvine32's own declarations.

Key constants defined:

```asm
STD_INPUT_HANDLE    EQU -10
STD_OUTPUT_HANDLE   EQU -11
STD_ERROR_HANDLE    EQU -12
INVALID_HANDLE_VALUE EQU -1
GENERIC_READ        EQU 80000000h
GENERIC_WRITE       EQU 40000000h
OPEN_EXISTING       EQU 3
CREATE_ALWAYS       EQU 2
OPEN_ALWAYS         EQU 4
FILE_ATTRIBUTE_NORMAL EQU 80h
STARTF_USESTDHANDLES EQU 100h
INFINITE            EQU 0FFFFFFFFh
```

### 6.3 Handle Lifecycle

Every kernel object handle opened by Ash is closed after use. The standard pattern:

```asm
INVOKE CreateFileA, ...         ; open
; ... use handle ...
INVOKE CloseHandle, hFile       ; close
```

In the pipeline module, particular care is taken to close both ends of a `CreatePipe` pair in the parent process after the child processes have inherited them. Failing to close the parent's write end of a pipe causes the consumer process to block forever waiting for EOF.

---

## 7. Advanced Features Deep-Dive

### 7.1 Pipeline (`|`)

A pipeline of `N` commands requires `N-1` anonymous pipes. The pipeline module:

1. Scans the line and counts `|` operators to determine N.
2. Calls `CreatePipe` N-1 times, storing `(hRead, hWrite)` pairs.
3. For command `i` (0-indexed):
   - stdin  = `hRead[i-1]`  (or original stdin for i=0)
   - stdout = `hWrite[i]`   (or original stdout for i=N-1)
4. For each command: if it is a built-in, calls `Pipe_RunBuiltinWithHandles`; if external, calls `Pipe_SpawnExternal`.
5. After all commands are spawned, waits for the last process and gets its exit code.
6. Closes all pipe handles in the parent.

This design supports pipelines of arbitrary depth (bounded by `MAX_TOKENS` / 2 in practice).

### 7.2 I/O Redirection

Redirection operators (`>`, `>>`, `<`) are scanned *before* pipe splitting, since they affect individual segments. For each segment:

- `>` : `CreateFileA(name, GENERIC_WRITE, CREATE_ALWAYS, ...)` → use as stdout handle.
- `>>` : `CreateFileA(name, GENERIC_WRITE, OPEN_ALWAYS, ...)` → `SetFilePointer` to end → use as stdout handle.
- `<` : `CreateFileA(name, GENERIC_READ, OPEN_EXISTING, ...)` → use as stdin handle.

The resulting handles are passed to `Pipe_RunBuiltinWithHandles` or `Pipe_SpawnExternal` exactly as pipe handles would be, unifying the handle-passing mechanism for both pipes and file redirection.

### 7.3 Environment Variable Expansion

Expansion happens as the *very first* step in `Shell_ExecuteLine`, before tokenization. This means:

```
set DIR=src
dir %DIR%\*.asm
```

After expansion, the parser sees `dir src\*.asm` and tokenizes it into `argv = ["dir", "src\*.asm"]`. Expansion is transparent to the parser and all downstream code.

The expansion procedure handles adjacent `%VAR%` sequences and literal percent signs correctly. If a `%` is not followed by a closing `%`, it is passed through unchanged.

### 7.4 Command History Implementation

The circular buffer design means that history never runs out of space — oldest entries are silently overwritten when the buffer is full. The `histCursor` variable tracks the current browsing position independently of the write head, which allows the user to navigate history while new commands are being added without losing their browsing context (cursor resets to head on each new entry).

### 7.5 Tab Completion

The completion algorithm handles the common case of completing a filename in the current directory. The partial word is extracted by scanning backward from the cursor to the last space or the start of the buffer. A wildcard `*` is appended and `FindFirstFileA` is called. On success, the partial word in the buffer is replaced with the full filename and the screen is updated.

---

## 8. Build System

### 8.1 `build\build.bat`

The build script (147 lines) handles the following automatically:

1. **Locate `ml.exe`:** Checks `PATH` first, then searches common VS 2022 Build Tools paths, and finally uses `vswhere.exe` to find any VS installation and calls `vcvarsall.bat x86` to set up the environment.

2. **Locate Irvine32:** Checks the `IRVINE` environment variable. If not set, searches common installation paths (`C:\Irvine`, `%USERPROFILE%\Irvine`, etc.).

3. **Assemble 11 modules:**
   ```
   ml /c /coff /I"%IRVINE%" /Fo build\ src\utils.asm
   ml /c /coff /I"%IRVINE%" /Fo build\ src\parser.asm
   ... (11 invocations)
   ```
   `/c` = compile only (no link), `/coff` = produce COFF object files (required for Win32 PE).

4. **Link:**
   ```
   link /SUBSYSTEM:CONSOLE /OUT:ash.exe build\*.obj
        kernel32.lib user32.lib "%IRVINE%\Irvine32.lib"
   ```

5. **Report:** Prints `Build succeeded — ash.exe` or the MASM/link error output.

### 8.2 Object File Dependencies

All 11 `.obj` files must be linked together. The linker resolves cross-module references (e.g., `main.asm` calling `Console_ReadLine` from `console.asm`) via the `EXTERN` / `PUBLIC` declarations in `ash.inc`.

The `COMMAND` struct and global variables (`gLineBuf`, `gCmd`, `gShouldExit`, `gLastExitCode`) are declared `PUBLIC` in `main.asm` (guarded by `ASH_MAIN EQU 1`) and `EXTERN` in all other modules (via `ash.inc`). This standard MASM pattern avoids duplicate symbol errors.

---

## 9. Testing & Verification

### 9.1 Manual Test Suite

Each feature category was tested against expected output:

**Built-in commands:**

| Test | Expected Result | Pass |
|---|---|---|
| `help` | Prints command reference | Yes |
| `echo Hello World` | Prints `Hello World` | Yes |
| `cd \` | Changes to root; prompt updates | Yes |
| `dir` | Lists files in CWD | Yes |
| `mkdir testdir` | Creates `testdir` | Yes |
| `cd testdir` | Enters `testdir` | Yes |
| `echo content > file.txt` | Creates `file.txt` with content | Yes |
| `type file.txt` | Prints `content` | Yes |
| `copy file.txt file2.txt` | Duplicates file | Yes |
| `ren file2.txt file3.txt` | Renames correctly | Yes |
| `del file3.txt` | Removes file | Yes |
| `rmdir testdir` | After `cd ..`, removes dir | Yes |

**Environment variables:**

| Test | Expected Result | Pass |
|---|---|---|
| `set FOO=hello` | Sets env var | Yes |
| `echo %FOO%` | Prints `hello` | Yes |
| `set` | Lists all env vars including `FOO` | Yes |
| `echo %NONEXISTENT%` | Prints `%NONEXISTENT%` unchanged | Yes |

**Operators:**

| Test | Expected Result | Pass |
|---|---|---|
| `echo a > out.txt && type out.txt` | Creates file and prints `a` | Yes |
| `del missing.txt \|\| echo FALLBACK` | Prints `FALLBACK` | Yes |
| `del missing.txt && echo BAD` | Prints nothing (del fails) | Yes |
| `echo line1 > f.txt && echo line2 >> f.txt && type f.txt` | Both lines in file | Yes |
| `type f.txt \| findstr line1` | Filters correctly | Yes |

**Script execution:**

| Test | Expected Result | Pass |
|---|---|---|
| `run scripts\sample.shl` | Prints CWD and dir listing | Yes |
| `ash.exe scripts\sample.shl` | Non-interactive script run | Yes |

**History & editing:**

| Test | Expected | Pass |
|---|---|---|
| Enter 3 commands, press Up × 3 | Recalls each in reverse order | Yes |
| Press Down after Up | Moves forward in history | Yes |
| Tab on partial name | Completes to matching filename | Yes |
| Backspace | Erases last character | Yes |

### 9.2 Error Handling

| Scenario | Behaviour |
|---|---|
| `type nonexistent.txt` | Prints `Error.` |
| `del nonexistent.txt` | Prints `Error.`; sets exit code to 1 |
| `cd nonexistent` | Prints `Error.`; CWD unchanged |
| `run nonexistent.shl` | Prints `Error.` |
| `unknowncommand` | `CreateProcessA` fails; prints error |
| Unterminated `%VAR%` | Left as literal text |

---

## 10. Challenges & Solutions

### Challenge 1: Built-ins in Pipelines

**Problem:** Built-in commands execute in-process (they are assembly procedures, not separate processes). Standard handle inheritance via `CreateProcessA` does not apply to them.

**Solution:** Implemented `Pipe_RunBuiltinWithHandles`, which saves the current stdout/stdin handles via `GetStdHandle`, installs the pipe endpoints via `SetStdHandle`, calls the built-in procedure, then restores the original handles. Because every built-in uses `GetStdHandle` at write time (through `Builtin_WriteStdoutZ`), they transparently write to the pipe.

### Challenge 2: Pipe Deadlocks

**Problem:** If the parent process holds an open write end of a pipe, the consumer process reading from the read end never receives EOF and blocks forever.

**Solution:** After spawning both ends of a pipe stage, the parent immediately closes its copies of both `hReadPipe` and `hWritePipe` for that stage. Only the child processes hold the handles at this point.

### Challenge 3: Cross-Module Data Access in MASM

**Problem:** MASM requires explicit `EXTERN` / `PUBLIC` declarations for symbols shared across object files. Unlike C, there is no `extern` keyword with type inference.

**Solution:** `ash.inc` centralizes all cross-module declarations. The `ASH_MAIN` guard (`IFDEF ASH_MAIN … ELSE … ENDIF`) switches between `PUBLIC` (in `main.asm`) and `EXTERN` (in all other modules) declarations for the four global variables.

### Challenge 4: In-Place Tokenization and Pipeline

**Problem:** The parser tokenizes by inserting null bytes into the input buffer. The pipeline module also needs the original, unmodified line to scan for operator characters.

**Solution:** The pipeline module scans for operators *before* calling the parser. Each pipeline segment gets its own copy of the segment text (extracted into a per-segment buffer), which is then tokenized independently. `gLineBuf` is never modified by the pipeline module.

### Challenge 5: Quoted Arguments Containing Spaces

**Problem:** A command like `copy "my file.txt" dest.txt` should produce two arguments, not four.

**Solution:** The parser enters an `IN_QUOTE` state when it encounters `"`, suppressing space-splitting until the closing `"`. `StrStripOuterQuotesInPlace` removes the `"` delimiters from the token before it is stored in `argv`, so built-ins receive clean strings.

### Challenge 6: Non-interactive Mode Argument Parsing

**Problem:** The process command line (`GetCommandLineA`) includes the executable path itself, which must be skipped. The path may or may not be quoted.

**Solution:** `Main_GetArgsTail` handles both cases with two scanning loops: one that stops at the first space (unquoted path), and one that stops at the closing `"` (quoted path). Both then call `StrSkipSpaces` to skip whitespace before the actual arguments.

---

## 11. Project Statistics

| Metric | Value |
|---|---|
| Source modules | 11 `.asm` files |
| Include files | 2 (`ash.inc`, `win32_min.inc`) |
| Total lines of code | ~2,600 |
| Built-in commands | 14 |
| Shell operators | 7 (`|` `>` `>>` `<` `&&` `||` `&`) |
| Win32 API functions called | 30+ |
| History buffer capacity | 10 commands × 512 bytes |
| Maximum input line length | 512 bytes |
| Maximum tokens per command | 32 |
| Build artefacts per build | 11 `.obj`, 1 `.exe`, 1 `.pdb`, 1 `.ilk` |

### Lines of Code by Module

| Module | Lines | Complexity |
|---|---|---|
| `pipeline.asm` | 812 | High — operator parsing, pipe management, handle redirection |
| `builtins.asm` | 635 | Medium-High — 14 command implementations |
| `console.asm` | 320 | Medium — key-by-key editing, cursor management |
| `env.asm` | 244 | Medium — string scanning, API calls |
| `utils.asm` | 221 | Low-Medium — pure string operations |
| `history.asm` | 167 | Low — ring buffer arithmetic |
| `main.asm` | 169 | Low-Medium — initialization, REPL |
| `script.asm` | 143 | Low-Medium — file reading, line dispatch |
| `external.asm` | 129 | Low-Medium — CreateProcess wrapper |
| `parser.asm` | 108 | Medium — state machine tokenizer |
| `dispatch.asm` | 49 | Low — thin dispatch layer |

---

## 12. Learning Outcomes

### Assembly Language Skills

- **Register management:** Preserving and restoring caller-saved registers (`USES` clause, explicit `push`/`pop`).
- **String manipulation:** Byte-by-byte scanning, in-place modification, null-termination conventions.
- **Calling conventions:** `stdcall` ABI, `INVOKE` macro, `PROC` argument declarations.
- **Modular programming:** `EXTERN`/`PUBLIC` declarations, `INCLUDELIB`, multi-file assembly projects.
- **MASM directives:** `STRUCT`, `EQU`, `DUP`, `IFDEF`/`ENDIF`, `PROTO`, `OFFSET`, `ADDR`.

### Operating Systems Concepts

- **Process creation:** `CreateProcessA`, `STARTUPINFOA`, `PROCESS_INFORMATION`, handle inheritance.
- **I/O handles:** `GetStdHandle`, `SetStdHandle`, stdin/stdout/stderr, `ReadFile`/`WriteFile`.
- **Anonymous pipes:** `CreatePipe`, handle inheritance, deadlock avoidance.
- **File system:** `CreateFileA`, `FindFirstFileA`, `GetCurrentDirectoryA`, attribute structures.
- **Environment variables:** Process env block, `GetEnvironmentStringsA`, `SetEnvironmentVariableA`.
- **Synchronization:** `WaitForSingleObject`, `INFINITE`, `GetExitCodeProcess`.

### Software Engineering Practices

- **Modular design:** Clear module boundaries with well-defined `PROTO` interfaces in a shared header.
- **Separation of concerns:** Parsing, execution, I/O, and history are independent modules.
- **Testing:** Systematic manual testing of each feature category and error path.
- **Documentation:** Inline comments for non-obvious invariants; separate proposal and report documents.

---

## 13. Team Contributions

| Member | Module(s) | Specific Work |
|---|---|---|
| **Zainab Raza Malik** | `main.asm`, `parser.asm`, `dispatch.asm` | Main REPL loop design, argv handling, tokenizer state machine, quote handling, unified dispatch layer, `ash.inc` / `win32_min.inc` architecture |
| **Eiman Zahra** | `builtins.asm` | All 16 built-in command implementations (`cd`, `dir`, `type`, `copy`, `del`, `mkdir`, `rmdir`, `ren`, `echo`, `set`, `run`, `cls`, `ver`, `title`, `help`, `exit`); `Builtin_WriteStdoutZ` stdout abstraction |
| **Saliha Waqas** | `pipeline.asm`, `env.asm` | Complete pipe, redirection, and chaining implementation; `%VAR%` expansion engine; `SetStdHandle`-based built-in redirection technique |
| **Fatima Ahmed** | `external.asm`, `script.asm`, `history.asm`, `console.asm` | `CreateProcess` launcher, `.shl` script reader, ring-buffer history, interactive line editor with Up/Down/Tab, build system (`build.bat`), integration testing |

---

## 14. Conclusion

Ash demonstrates that a fully functional, interactive command-line shell — complete with pipes, redirection, command chaining, tab completion, history, scripting, and external program execution — is achievable in pure x86 Assembly Language.

The project's key technical achievements are:

1. **In-place tokenization** that avoids all heap allocation while producing clean C-style strings for built-ins and external programs.

2. **Unified handle redirection** that makes built-in commands work transparently inside pipelines without any modification to the built-in implementations themselves.

3. **Modular architecture** with 11 independently assembled source files communicating through well-defined `PROTO`-declared interfaces in a shared header.

4. **Complete operator support** — `|`, `>`, `>>`, `<`, `&&`, `||`, and `&` — implemented at the assembly level using direct Win32 handle management.

5. **Non-interactive mode** allowing Ash to be used as a scripting engine or a single-command executor, not only as an interactive shell.

The project provides genuine insight into how `cmd.exe`, Bash, and similar shells operate internally, and demonstrates that assembly language is not limited to toy examples — it is capable of building real, useful system software.

---

## 15. References

1. Microsoft Corporation. *Windows API documentation: Process and Thread Functions*. Microsoft Learn. https://learn.microsoft.com/en-us/windows/win32/procthread/
2. Irvine, K. R. (2020). *Assembly Language for x86 Processors* (8th ed.). Pearson.
3. Microsoft Corporation. *MASM Reference (ml.exe)*. Microsoft Learn.
4. Brennan, S. (2015). *Write a Shell in C*. https://brennan.io/2015/01/16/write-a-shell-in-c/ (concepts adapted to assembly)
5. Hart, J. M. (2010). *Windows System Programming* (4th ed.). Addison-Wesley.
6. Pietrek, M. (1994). *Peering Inside the PE: A Tour of the Win32 Portable Executable File Format*. Microsoft Systems Journal.
7. Microsoft Corporation. *CreateProcess function*. https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa
8. Microsoft Corporation. *CreatePipe function*. https://learn.microsoft.com/en-us/windows/win32/api/namedpipeapi/nf-namedpipeapi-createpipe

---

**Prepared by:** Group 11
**Course:** Computer Organization & Assembly Language (COAL)
**Date:** May 2026
**Institution:** [University Name]
