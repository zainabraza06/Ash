# Ash (minimal x86 shell for Windows) – A Feature-Rich Command-Line Interpreter in Pure Assembly Language

**Group 11 – Project Proposal**

## Advanced Shell with Scripting & Pipeline Support in x86 Assembly Language

---

## 1. Project Title

**Ash (minimal x86 shell for Windows) – A Feature-Rich Command-Line Interpreter in Pure Assembly Language**

---

## 2. Group Members & Roles

| Member | Role | Specific Responsibilities |
|--------|------|---------------------------|
| **Zainab Raza Malik** | Core Engine & Parser Architect | Main loop design, command parsing, tokenization, quote handling, escape sequences, input validation |
| **Eiman Zahra** | Built-in Commands & File System | Implementation of `cd`, `dir`, `type`, `copy`, `del`, `mkdir`, `rmdir`, `ren`, current directory tracking, file attribute handling |
| **Saliha Waqas** | Advanced Features (Pipes & Redirections) | I/O redirection (`<`, `>`), piping (`|`), command chaining (`&&`, `||`), background execution (`&`), environment variables (`%VAR%`) |
| **Fatima Ahmed** | External Execution & Integration | Windows API `CreateProcess` implementation, PATH searching, error handling, script file execution, testing, debugging, documentation |

---

## 3. Project Introduction / Description

### 3.1 Overview

This project presents **Ash (minimal x86 shell for Windows)**, a fully functional command-line interpreter developed entirely in x86 Assembly Language using the MASM assembler and Irvine32 library. The shell provides an interactive environment for users to execute commands, manage files, run external programs, and automate tasks through script files — all implemented at the lowest practical level of software.

Unlike typical COAL projects that focus on games or simple calculators, Ash demonstrates **real operating system internals** including process creation, file I/O, string parsing, environment variable management, and inter-process communication (pipes) — concepts that directly translate to understanding how Windows Command Prompt, Linux Bash, and Unix shells work under the hood.

### 3.2 Why Assembly Language?

Assembly Language is uniquely suited for building a shell because:

| Shell Component | Why Assembly Excels |
|----------------|---------------------|
| **Command parsing** | Direct byte-by-byte string scanning without abstraction overhead |
| **Process creation** | Direct Windows API calls without C runtime libraries |
| **Error handling** | Fine-grained control over return codes and exception conditions |
| **Memory management** | Explicit control over buffers, stacks, and heaps |
| **Performance** | Minimal overhead for frequently executed shell loops |

### 3.3 Advanced & Innovative Features

Beyond a basic shell, Ash incorporates **five advanced features** that make it stand out:

#### Feature 1: Pipeline Support (`|`)

Users can chain multiple commands together where the output of one becomes the input of the next:

```text
MyShell> dir | find ".txt" | sort
```

**Implementation approach:** Create child processes for each command, redirect standard handles using `SetStdHandle` and `CreatePipe` Windows APIs.

#### Feature 2: I/O Redirection (`>`, `>>`, `<`)

```text
MyShell> dir > filelist.txt          (overwrite)
MyShell> echo Hello >> log.txt       (append)
MyShell> sort < unsorted.txt         (input redirection)
```

#### Feature 3: Command Chaining (`&&`, `||`)

```text
MyShell> compile.bat && run.exe       (run only if first succeeds)
MyShell> test.exe || echo "Failed"    (run only if first fails)
```

#### Feature 4: Script/Batch File Execution

Users can create `.shl` script files containing multiple commands:

```batch
# myscript.shl
echo Starting backup...
mkdir C:\backup
copy *.txt C:\backup
echo Done!
```

The shell reads and executes each line sequentially.

#### Feature 5: Environment Variable Support

```text
MyShell> set MYNAME=John
MyShell> echo Hello %MYNAME%
Hello John
MyShell> set PATH=C:\Windows;%PATH%
```

#### Feature 6: Command History (Arrow Keys)

Press **Up Arrow** to recall previous commands, **Down Arrow** to navigate forward — implemented using raw console input.

#### Feature 7: Tab Completion

Press **Tab** to auto-complete file/directory names in the current path.

---

## 4. Technical Architecture

### 4.1 System Block Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                         ASH SHELL MAIN                          │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    INITIALIZATION MODULE                        │
│  - Clear screen, set up buffers, load PATH environment          │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                       MAIN LOOP (REPL)                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Prompt    │ →  │    Read     │ →  │   Parse     │         │
│  │  Display    │    │   Input     │    │  Command    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                    COMMAND DISPATCHER                           │
│         ┌──────────────┬──────────────┬──────────────┐          │
│         ▼              ▼              ▼              ▼          │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐     │
│   │ Built-in │   │ Pipeline │   │Redirection│   │External  │     │
│   │Commands  │   │ Handler  │   │ Handler   │   │Execution │     │
│   └──────────┘   └──────────┘   └──────────┘   └──────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Data Structures (Assembly Implementations)

| Structure | Assembly Implementation | Purpose |
|-----------|------------------------|---------|
| Command Buffer | Byte array `BUFFER DB 256 DUP(?)` | Stores raw user input |
| Argument Array | DWORD array of pointers | Stores parsed command tokens |
| Command History | Circular buffer of 10 strings | Stores last 10 commands for recall |
| Environment Variables | Parallel arrays (name + value) | Stores user-defined variables |
| PATH Directories | Array of string pointers | Search locations for executables |

### 4.3 Windows API Calls Used

| API Function | Purpose | Called From |
|--------------|---------|-------------|
| `CreateProcess` | Launch external program | Member 4 |
| `CreatePipe` | Create pipeline between commands | Member 3 |
| `SetStdHandle` | Redirect input/output | Member 3 |
| `GetCurrentDirectory` | Get working directory | Member 2 |
| `SetCurrentDirectory` | Change working directory | Member 2 |
| `FindFirstFile` / `FindNextFile` | Directory listing (`dir`) | Member 2 |
| `GetEnvironmentVariable` | Read environment variables | Member 4 |
| `SetEnvironmentVariable` | Set environment variables | Member 3 |
| `ReadConsole` / `WriteConsole` | Raw console I/O | All members |

---

## 5. Command Set Summary

### 5.1 Built-in Commands (No external process)

| Command | Syntax | Description |
|---------|--------|-------------|
| `cd` | `cd [directory]` | Change current directory |
| `dir` | `dir [path]` | List directory contents |
| `type` | `type <filename>` | Display file contents |
| `copy` | `copy <src> <dest>` | Copy file |
| `del` | `del <filename>` | Delete file |
| `mkdir` | `mkdir <dirname>` | Create directory |
| `rmdir` | `rmdir <dirname>` | Remove directory |
| `ren` | `ren <old> <new>` | Rename file |
| `echo` | `echo [text]` | Display text or toggle echo |
| `set` | `set [VAR=value]` | Show/set environment variables |
| `cls` | `cls` | Clear screen |
| `exit` | `exit` | Exit shell |
| `help` | `help [command]` | Show help |

### 5.2 External Program Support

Any `.exe`, `.com`, or `.bat` file in the current directory or PATH can be executed:

```text
MyShell> notepad
MyShell> calc
MyShell> myprogram.exe arg1 arg2
```

### 5.3 Scripting Support

```text
MyShell> run myscript.shl
```

Scripts can contain any commands, comments (lines starting with `#`), and environment variables.

---

## 6. Complexity & Innovation Justification

### Why This Project Deserves Top Marks

| Criterion | How Ash compares |
|----------|-----------------|
| **Novelty** | No other group is building a shell; all others are doing games or simple utilities |
| **Technical depth** | Demonstrates process creation, pipe management, string parsing, file I/O — 5+ advanced OS concepts |
| **Lines of code** | Estimated 1500-2000 lines of well-commented assembly |
| **Real-world relevance** | Directly maps to how cmd.exe, bash, and PowerShell work internally |
| **Team collaboration** | Clear module boundaries with well-defined interfaces |
| **Innovation** | Features like pipes, redirections, command history, tab completion, scripting are uncommon in student projects |

### Comparison with Existing Student Projects

| Feature | Typical Game Project | Ash shell |
|--------|----------------------|----------|
| Demonstrates OS knowledge | ❌ No | ✅ Yes |
| Process management | ❌ No | ✅ Yes |
| File system interaction | ⚠️ Minimal | ✅ Extensive |
| String parsing complexity | Low | High |
| Reusable knowledge | Low (game-specific) | High (systems programming) |
| Interview talking point | Average | Excellent |

---

## 7. Development Timeline

| Phase | Duration | Deliverables | Responsible |
|-------|----------|--------------|-------------|
| **Phase 1** | Week 1-2 | Main loop, prompt, input reading, basic parsing | Member 1 |
| **Phase 2** | Week 3-4 | Built-in commands (cd, dir, type, exit, cls, help) | Member 2 |
| **Phase 3** | Week 5-6 | External program execution, PATH search | Member 4 |
| **Phase 4** | Week 7-8 | Pipes, redirections, command chaining | Member 3 |
| **Phase 5** | Week 9-10 | Environment variables, script execution | Member 3 & 4 |
| **Phase 6** | Week 11-12 | Command history, tab completion, testing, debug | All members |
| **Phase 7** | Week 13-14 | Documentation, report writing, presentation prep | All members |

---

## 8. Required Tools & Setup

| Tool | Purpose |
|------|---------|
| **MASM** (Microsoft Macro Assembler) | Assembly code compilation |
| **Visual Studio (or VS Code)** | Development environment |
| **Irvine32 Library** | Simplified Windows API access, console I/O |
| **Windows SDK** | Access to Windows API libraries |
| **WinDbg or x64dbg** | Debugging assistance |

---

## 9. Sample Session

```text
========================================
    Ash v1.0 — Minimal x86 shell for Windows
    Type 'help' for available commands
========================================

C:\Users\Group11> help

Built-in Commands:
  cd <dir>      - Change directory
  dir [path]    - List directory contents
  type <file>   - Display file contents
  copy <src> <dest> - Copy file
  del <file>    - Delete file
  mkdir <name>  - Create directory
  rmdir <name>  - Remove directory
  echo [text]   - Display text
  set [VAR=val] - Environment variables
  cls           - Clear screen
  exit          - Exit shell

External Commands:
  Any .exe, .com, or .bat file can be executed

Special Features:
  |, >, >>, <    - Pipes and redirections
  &&, ||        - Command chaining
  %VAR%          - Environment variables
  Up/Down Arrow  - Command history
  Tab            - Auto-completion

C:\Users\Group11> set MYNAME=AssemblyExpert

C:\Users\Group11> echo Hello %MYNAME%!
Hello AssemblyExpert!

C:\Users\Group11> dir *.txt > filelist.txt

C:\Users\Group11> type filelist.txt
report.txt
notes.txt
README.txt

C:\Users\Group11> dir | find ".asm" > asmfiles.txt

C:\Users\Group11> compile.bat && echo "Compilation successful!"

C:\Users\Group11> exit
Goodbye!
```

---

## 10. Risks & Mitigation

| Risk | Probability | Mitigation |
|------|-------------|------------|
| Windows API complexity | Medium | Use Irvine32 where possible; test each API call in isolation |
| Pipeline implementation | Medium | Start with simple redirections first; test each component separately |
| Time constraints | Low | Feature-complete MVP achievable in 8 weeks; advanced features are stretch goals |
| Debugging assembly | Medium | Use Visual Studio debugger with register/memory views; implement lightweight logging |
| String parsing bugs | Medium | Extensive test cases; modular parser design |

---

## 11. Conclusion

The **Ash (minimal x86 shell for Windows)** project represents a **significant departure from typical COAL projects** (games, calculators, simple utilities) by tackling a **real systems programming challenge** — building a functional command-line interpreter from scratch in assembly language.

The project demonstrates:
- **Deep understanding** of OS internals (processes, pipes, file I/O)
- **Practical assembly skills** (string parsing, API calling, memory management)
- **Innovative features** (pipes, redirections, command history, tab completion, scripting)
- **Professional collaboration** (clear module boundaries, documented interfaces)

This project will serve as an **excellent portfolio piece** for interviews, showcasing systems-level thinking.

---

## 12. References & Resources

1. Microsoft Windows API Documentation – Process and Thread functions
2. Irvine, K. (2020). *Assembly Language for x86 Processors*
3. "Writing a Shell in C" – Stephen Brennan (concepts adapted to assembly)
4. MASM Programmer's Guide – Microsoft Documentation
5. Windows System Programming – Johnson M. Hart

---

**Prepared by:** Group 11  
**Date:** April 2026  
**Course:** Computer Organization & Assembly Language (COAL)
