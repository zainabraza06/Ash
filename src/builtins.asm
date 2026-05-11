; builtins.asm - built-in commands for Ash

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ash.inc

INCLUDELIB kernel32.lib

EXTERN gShouldExit:DWORD
EXTERN gLastExitCode:DWORD

.data
sExit     BYTE "exit",0
sHelp     BYTE "help",0
sCls      BYTE "cls",0
sEcho     BYTE "echo",0
sCd       BYTE "cd",0
sSet      BYTE "set",0
sRun      BYTE "run",0
sDir      BYTE "dir",0
sType     BYTE "type",0
sCopy     BYTE "copy",0
sDel      BYTE "del",0
sMkdir    BYTE "mkdir",0
sRmdir    BYTE "rmdir",0
sRen      BYTE "ren",0
sVer      BYTE "ver",0
sTitle    BYTE "title",0
sRem      BYTE "rem",0
sPause    BYTE "pause",0
sTime     BYTE "time",0

helpText BYTE "Built-in Commands:",0Dh,0Ah
         BYTE "  cd [dir]           - Change directory",0Dh,0Ah
         BYTE "  dir [pattern]      - List directory contents (default *.*)",0Dh,0Ah
         BYTE "  type <file>        - Display file contents",0Dh,0Ah
         BYTE "  copy <src> <dest>  - Copy file",0Dh,0Ah
         BYTE "  del <file>         - Delete file",0Dh,0Ah
         BYTE "  mkdir <dir>        - Create directory",0Dh,0Ah
         BYTE "  rmdir <dir>        - Remove directory",0Dh,0Ah
         BYTE "  ren <old> <new>    - Rename/move file",0Dh,0Ah
         BYTE "  echo [text]        - Display text",0Dh,0Ah
         BYTE "  set [VAR=val]      - Show/set environment variables",0Dh,0Ah
         BYTE "  run <script.shl>   - Run script file",0Dh,0Ah
         BYTE "  cls                - Clear screen",0Dh,0Ah
         BYTE "  ver                - Show Windows version",0Dh,0Ah
         BYTE "  title <text>       - Set console window title",0Dh,0Ah
         BYTE "  rem <text>         - Comment (ignored)",0Dh,0Ah
         BYTE "  pause              - Wait for a key press",0Dh,0Ah
         BYTE "  time               - Show local date and time",0Dh,0Ah
         BYTE "  exit               - Exit shell",0Dh,0Ah
         BYTE 0

cdBuf BYTE 260 DUP(0)
msgErr BYTE "Error.",0Dh,0Ah,0

usageType  BYTE "Usage: type <file>",0Dh,0Ah,0
usageCopy  BYTE "Usage: copy <src> <dest>",0Dh,0Ah,0
usageDel   BYTE "Usage: del <file>",0Dh,0Ah,0
usageMkdir BYTE "Usage: mkdir <dir>",0Dh,0Ah,0
usageRmdir BYTE "Usage: rmdir <dir>",0Dh,0Ah,0
usageRen   BYTE "Usage: ren <old> <new>",0Dh,0Ah,0
usageRun   BYTE "Usage: run <script.shl>",0Dh,0Ah,0
usageSet   BYTE "Usage: set NAME=VALUE   (or: set)",0Dh,0Ah,0
usageTitle BYTE "Usage: title <text>",0Dh,0Ah,0

okMsg BYTE "OK",0Dh,0Ah,0

; buffers for type
TypeBuf BYTE 4096 DUP(0)

starPattern BYTE "*.*",0

fmtVerOut BYTE "Ash: Windows %u.%u (build %u)",0Dh,0Ah,0
VerOutBuf BYTE 160 DUP(0)

TitleBuf BYTE 260 DUP(0)

fmtTime BYTE "Current local time: %04lu-%02lu-%02lu %02lu:%02lu:%02lu",0Dh,0Ah,0
TimeBuf BYTE 96 DUP(0)

msgPause BYTE "Press any key to continue...",0Dh,0Ah,0

.code

Builtins_Init PROC
    ret
Builtins_Init ENDP

Builtin_SetExitCode PROC, code:DWORD
    mov eax, code
    mov gLastExitCode, eax
    ret
Builtin_SetExitCode ENDP

; --- Builtin output helpers ---
; Use WriteFile against the current STD_OUTPUT_HANDLE so redirection via SetStdHandle works.
Builtin_WriteStdoutBuf PROC USES ebx ecx edx, pBuf:PTR BYTE, cbBuf:DWORD
    LOCAL bytesWritten:DWORD

    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov ebx, eax

    mov ecx, cbBuf
    cmp ecx, 0
    je  done

    INVOKE WriteFile, ebx, pBuf, ecx, ADDR bytesWritten, 0

done:
    ret
Builtin_WriteStdoutBuf ENDP

Builtin_WriteStdoutZ PROC USES ecx, pStr:PTR BYTE
    INVOKE StrLen, pStr
    mov ecx, eax
    INVOKE Builtin_WriteStdoutBuf, pStr, ecx
    ret
Builtin_WriteStdoutZ ENDP

Builtin_WriteStdoutChar PROC USES eax, charVal:BYTE
    LOCAL tmp[2]:BYTE
    mov al, charVal
    mov tmp[0], al
    mov tmp[1], 0
    INVOKE Builtin_WriteStdoutBuf, ADDR tmp, 1
    ret
Builtin_WriteStdoutChar ENDP

Builtin_WriteStdoutCRLF PROC
    LOCAL tmp[2]:BYTE
    mov tmp[0], 0Dh
    mov tmp[1], 0Ah
    INVOKE Builtin_WriteStdoutBuf, ADDR tmp, 2
    ret
Builtin_WriteStdoutCRLF ENDP

Builtin_Ver PROC USES ebx ecx edx
    LOCAL vi:OSVERSIONINFOA

    mov vi.dwOSVersionInfoSize, SIZEOF OSVERSIONINFOA
    INVOKE GetVersionExA, ADDR vi
    cmp eax, 0
    jne ver_ok

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ver_ok:
    INVOKE wsprintfA, ADDR VerOutBuf, ADDR fmtVerOut, vi.dwMajorVersion, vi.dwMinorVersion, vi.dwBuildNumber
    INVOKE Builtin_WriteStdoutZ, ADDR VerOutBuf
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Ver ENDP

Builtin_Time PROC USES eax ebx ecx edx esi edi
    LOCAL locTime:SYSTEMTIME
    LOCAL tn:DWORD
    LOCAL tm:DWORD
    LOCAL td:DWORD
    LOCAL th:DWORD
    LOCAL ti:DWORD
    LOCAL ts:DWORD

    INVOKE GetLocalTime, ADDR locTime
    cmp eax, 0
    jne tm_ok

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

tm_ok:
    movzx eax, locTime.wYear
    mov tn, eax
    movzx eax, locTime.wMonth
    mov tm, eax
    movzx eax, locTime.wDay
    mov td, eax
    movzx eax, locTime.wHour
    mov th, eax
    movzx eax, locTime.wMinute
    mov ti, eax
    movzx eax, locTime.wSecond
    mov ts, eax

    INVOKE wsprintfA, ADDR TimeBuf, ADDR fmtTime, tn, tm, td, th, ti, ts
    INVOKE Builtin_WriteStdoutZ, ADDR TimeBuf
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Time ENDP

; Join argv[1..] with spaces into TitleBuf (Windows limit 260 chars including null).
Builtin_Title PROC USES esi edi ebx ecx, pCmd:PTR COMMAND
    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 2
    jb title_usage

    mov edi, OFFSET TitleBuf
    xor edx, edx
    mov esi, 1

title_next_arg:
    cmp esi, [ebx].COMMAND.argc
    jae title_apply

    cmp esi, 1
    je title_no_sep
    cmp edx, 259
    jae title_apply
    mov BYTE PTR [edi+edx], ' '
    inc edx

title_no_sep:
    mov ecx, [ebx].COMMAND.argv[esi*4]

tok_copy:
    cmp edx, 259
    jae title_apply
    mov al, [ecx]
    cmp al, 0
    je tok_done
    mov [edi+edx], al
    inc ecx
    inc edx
    jmp tok_copy

tok_done:
    inc esi
    jmp title_next_arg

title_apply:
    mov BYTE PTR [edi+edx], 0
    INVOKE SetConsoleTitleA, edi
    cmp eax, 0
    jne title_ok

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

title_ok:
    INVOKE Builtin_SetExitCode, 0
    ret

title_usage:
    mov edx, OFFSET usageTitle
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret
Builtin_Title ENDP

Builtin_Dir PROC USES ebx ecx edx, pCmd:PTR COMMAND
    LOCAL fd:WIN32_FIND_DATAA
    LOCAL hFind:DWORD

    mov ebx, pCmd

    mov edx, [ebx].COMMAND.argv[4] ; argv[1] if present
    mov eax, [ebx].COMMAND.argc
    cmp eax, 2
    jae have

    ; default pattern
    mov edx, OFFSET starPattern
have:
    INVOKE FindFirstFileA, edx, ADDR fd
    mov hFind, eax
    cmp eax, INVALID_HANDLE_VALUE
    jne dir_loop

    INVOKE Builtin_SetExitCode, 1
    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    ret

dir_loop:
    lea edx, fd.cFileName
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_WriteStdoutCRLF

    INVOKE FindNextFileA, hFind, ADDR fd
    cmp eax, 0
    jne dir_loop

    INVOKE FindClose, hFind
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Dir ENDP

Builtin_Type PROC USES ebx ecx edx, pCmd:PTR COMMAND
    LOCAL hFile:DWORD
    LOCAL bytesRead:DWORD
    LOCAL bytesWritten:DWORD
    LOCAL hOut:DWORD

    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 2
    jae ok

    mov edx, OFFSET usageType
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ok:
    mov edx, [ebx].COMMAND.argv[4]
    INVOKE CreateFileA, edx, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov hFile, eax
    cmp eax, INVALID_HANDLE_VALUE
    jne read_loop

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

read_loop:
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov hOut, eax

    INVOKE ReadFile, hFile, ADDR TypeBuf, SIZEOF TypeBuf, ADDR bytesRead, NULL
    cmp eax, 0
    je  close

    mov eax, bytesRead
    cmp eax, 0
    je  close

    INVOKE WriteFile, hOut, ADDR TypeBuf, bytesRead, ADDR bytesWritten, NULL
    jmp read_loop

close:
    INVOKE CloseHandle, hFile
    INVOKE Builtin_WriteStdoutCRLF
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Type ENDP

Builtin_Copy PROC USES ebx ecx edx, pCmd:PTR COMMAND
    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 3
    jae ok

    mov edx, OFFSET usageCopy
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ok:
    mov edx, [ebx].COMMAND.argv[4]
    mov ecx, [ebx].COMMAND.argv[8]
    INVOKE CopyFileA, edx, ecx, FALSE
    cmp eax, 0
    jne good

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

good:
    mov edx, OFFSET okMsg
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Copy ENDP

Builtin_Del PROC USES ebx edx, pCmd:PTR COMMAND
    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 2
    jae ok

    mov edx, OFFSET usageDel
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ok:
    mov edx, [ebx].COMMAND.argv[4]
    INVOKE DeleteFileA, edx
    cmp eax, 0
    jne good

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

good:
    mov edx, OFFSET okMsg
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Del ENDP

Builtin_Mkdir PROC USES ebx edx, pCmd:PTR COMMAND
    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 2
    jae ok

    mov edx, OFFSET usageMkdir
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ok:
    mov edx, [ebx].COMMAND.argv[4]
    INVOKE CreateDirectoryA, edx, NULL
    cmp eax, 0
    jne good

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

good:
    mov edx, OFFSET okMsg
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Mkdir ENDP

Builtin_Rmdir PROC USES ebx edx, pCmd:PTR COMMAND
    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 2
    jae ok

    mov edx, OFFSET usageRmdir
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ok:
    mov edx, [ebx].COMMAND.argv[4]
    INVOKE RemoveDirectoryA, edx
    cmp eax, 0
    jne good

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

good:
    mov edx, OFFSET okMsg
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Rmdir ENDP

Builtin_Ren PROC USES ebx ecx edx, pCmd:PTR COMMAND
    mov ebx, pCmd
    mov eax, [ebx].COMMAND.argc
    cmp eax, 3
    jae ok

    mov edx, OFFSET usageRen
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

ok:
    mov edx, [ebx].COMMAND.argv[4]
    mov ecx, [ebx].COMMAND.argv[8]
    INVOKE MoveFileA, edx, ecx
    cmp eax, 0
    jne good

    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    ret

good:
    mov edx, OFFSET okMsg
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 0
    ret
Builtin_Ren ENDP

; Returns EAX=1 if handled, else EAX=0.
Builtins_TryExecute PROC USES esi edi ebx, pCmd:PTR COMMAND
    mov edi, pCmd

    mov eax, [edi].COMMAND.argc
    cmp eax, 0
    je  not_handled

    mov esi, [edi].COMMAND.argv[0]

    ; exit
    INVOKE StrEqI, esi, ADDR sExit
    cmp eax, 1
    jne check_help
    mov gShouldExit, 1
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_help:
    INVOKE StrEqI, esi, ADDR sHelp
    cmp eax, 1
    jne check_cls
    mov edx, OFFSET helpText
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_cls:
    INVOKE StrEqI, esi, ADDR sCls
    cmp eax, 1
    jne check_ver
    call ClrScr
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_ver:
    INVOKE StrEqI, esi, ADDR sVer
    cmp eax, 1
    jne check_title
    call Builtin_Ver
    mov eax, 1
    ret

check_title:
    INVOKE StrEqI, esi, ADDR sTitle
    cmp eax, 1
    jne check_rem
    INVOKE Builtin_Title, edi
    mov eax, 1
    ret

check_rem:
    INVOKE StrEqI, esi, ADDR sRem
    cmp eax, 1
    jne check_pause
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_pause:
    INVOKE StrEqI, esi, ADDR sPause
    cmp eax, 1
    jne check_time
    mov edx, OFFSET msgPause
    INVOKE Builtin_WriteStdoutZ, edx
    call ReadChar
    INVOKE Builtin_WriteStdoutCRLF
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_time:
    INVOKE StrEqI, esi, ADDR sTime
    cmp eax, 1
    jne check_echo
    call Builtin_Time
    mov eax, 1
    ret

check_echo:
    INVOKE StrEqI, esi, ADDR sEcho
    cmp eax, 1
    jne check_cd

    mov ebx, 1
    mov ecx, [edi].COMMAND.argc
    cmp ecx, 1
    jbe echo_done

echo_loop:
    cmp ebx, ecx
    jae echo_done
    cmp ebx, 1
    je  echo_token
    INVOKE Builtin_WriteStdoutChar, ' '
echo_token:
    mov edx, [edi].COMMAND.argv[ebx*4]
    INVOKE Builtin_WriteStdoutZ, edx
    inc ebx
    jmp echo_loop

echo_done:
    INVOKE Builtin_WriteStdoutCRLF
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_cd:
    INVOKE StrEqI, esi, ADDR sCd
    cmp eax, 1
    jne check_set

    mov eax, [edi].COMMAND.argc
    cmp eax, 1
    jbe cd_print

    mov edx, [edi].COMMAND.argv[4]
    INVOKE SetCurrentDirectoryA, edx
    cmp eax, 0
    jne cd_ok
    mov edx, OFFSET msgErr
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    mov eax, 1
    ret

cd_ok:
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

cd_print:
    INVOKE GetCurrentDirectoryA, SIZEOF cdBuf, ADDR cdBuf
    mov edx, OFFSET cdBuf
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_WriteStdoutCRLF
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_set:
    INVOKE StrEqI, esi, ADDR sSet
    cmp eax, 1
    jne check_run

    mov eax, [edi].COMMAND.argc
    cmp eax, 1
    je  do_set_print

    INVOKE Env_SetFromCommand, edi
    cmp eax, 1
    je  set_ok
    cmp eax, 2
    je  set_fail
    mov edx, OFFSET usageSet
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    mov eax, 1
    ret

set_ok:
    ; Env_SetFromCommand prints OK/Fail and sets env; treat success as exitcode 0
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

set_fail:
    INVOKE Builtin_SetExitCode, 1
    mov eax, 1
    ret

do_set_print:
    call Env_PrintAll
    INVOKE Builtin_SetExitCode, 0
    mov eax, 1
    ret

check_run:
    INVOKE StrEqI, esi, ADDR sRun
    cmp eax, 1
    jne check_dir

    mov eax, [edi].COMMAND.argc
    cmp eax, 2
    jae run_ok

    mov edx, OFFSET usageRun
    INVOKE Builtin_WriteStdoutZ, edx
    INVOKE Builtin_SetExitCode, 1
    mov eax, 1
    ret

run_ok:
    mov edx, [edi].COMMAND.argv[4]
    INVOKE Script_RunFile, edx
    ; Script execution uses gLastExitCode from invoked commands
    mov eax, 1
    ret

check_dir:
    INVOKE StrEqI, esi, ADDR sDir
    cmp eax, 1
    jne check_type
    INVOKE Builtin_Dir, edi
    mov eax, 1
    ret

check_type:
    INVOKE StrEqI, esi, ADDR sType
    cmp eax, 1
    jne check_copy
    INVOKE Builtin_Type, edi
    mov eax, 1
    ret

check_copy:
    INVOKE StrEqI, esi, ADDR sCopy
    cmp eax, 1
    jne check_del
    INVOKE Builtin_Copy, edi
    mov eax, 1
    ret

check_del:
    INVOKE StrEqI, esi, ADDR sDel
    cmp eax, 1
    jne check_mkdir
    INVOKE Builtin_Del, edi
    mov eax, 1
    ret

check_mkdir:
    INVOKE StrEqI, esi, ADDR sMkdir
    cmp eax, 1
    jne check_rmdir
    INVOKE Builtin_Mkdir, edi
    mov eax, 1
    ret

check_rmdir:
    INVOKE StrEqI, esi, ADDR sRmdir
    cmp eax, 1
    jne check_ren
    INVOKE Builtin_Rmdir, edi
    mov eax, 1
    ret

check_ren:
    INVOKE StrEqI, esi, ADDR sRen
    cmp eax, 1
    jne not_handled
    INVOKE Builtin_Ren, edi
    mov eax, 1
    ret

not_handled:
    xor eax, eax
    ret
Builtins_TryExecute ENDP

; Builtins_IsBuiltin(pCmd) -> EAX=1 if argv[0] matches a built-in name
Builtins_IsBuiltin PROC USES esi edi, pCmd:PTR COMMAND
    mov edi, pCmd
    mov eax, [edi].COMMAND.argc
    cmp eax, 0
    je  no

    mov esi, [edi].COMMAND.argv[0]

    INVOKE StrEqI, esi, ADDR sExit
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sHelp
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sCls
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sVer
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sTitle
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sEcho
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sCd
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sSet
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sRun
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sDir
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sType
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sCopy
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sDel
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sMkdir
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sRmdir
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sRen
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sRem
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sPause
    cmp eax, 1
    je  yes
    INVOKE StrEqI, esi, ADDR sTime
    cmp eax, 1
    je  yes

no:
    xor eax, eax
    ret
yes:
    mov eax, 1
    ret
Builtins_IsBuiltin ENDP

END
