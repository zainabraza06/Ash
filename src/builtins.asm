; builtins.asm - built-in commands (cd/dir/type/...)
; Implements a small subset; the rest are structured stubs.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

INCLUDELIB kernel32.lib

EXTERN gShouldExit:DWORD

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

msgNI     BYTE "(not implemented yet)",0Dh,0Ah,0
msgUnknown BYTE "Unknown built-in command.",0Dh,0Ah,0

helpText BYTE \
"Built-in Commands:",0Dh,0Ah,
"  cd [dir]        - Change directory",0Dh,0Ah,
"  dir [path]      - List directory contents",0Dh,0Ah,
"  type <file>     - Display file contents",0Dh,0Ah,
"  copy <s> <d>    - Copy file",0Dh,0Ah,
"  del <file>      - Delete file",0Dh,0Ah,
"  mkdir <name>    - Create directory",0Dh,0Ah,
"  rmdir <name>    - Remove directory",0Dh,0Ah,
"  ren <o> <n>     - Rename file",0Dh,0Ah,
"  echo [text]     - Display text",0Dh,0Ah,
"  set [VAR=val]   - Show/set environment variables",0Dh,0Ah,
"  cls             - Clear screen",0Dh,0Ah,
"  exit            - Exit shell",0Dh,0Ah,0

cdBuf BYTE 260 DUP(0)
cdErr BYTE "cd: failed to change directory",0Dh,0Ah,0

runUsage BYTE "Usage: run <script.shl>",0Dh,0Ah,0
setUsage BYTE "Usage: set NAME=VALUE   (or: set)",0Dh,0Ah,0

.code

Builtins_Init PROC
    ret
Builtins_Init ENDP

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
    mov eax, 1
    ret

check_help:
    INVOKE StrEqI, esi, ADDR sHelp
    cmp eax, 1
    jne check_cls
    mov edx, OFFSET helpText
    call WriteString
    mov eax, 1
    ret

check_cls:
    INVOKE StrEqI, esi, ADDR sCls
    cmp eax, 1
    jne check_echo
    call Clrscr
    mov eax, 1
    ret

check_echo:
    INVOKE StrEqI, esi, ADDR sEcho
    cmp eax, 1
    jne check_cd

    ; echo args...
    mov ebx, 1
    mov ecx, [edi].COMMAND.argc
    cmp ecx, 1
    jbe echo_done

echo_loop:
    cmp ebx, ecx
    jae echo_done
    mov edx, [edi].COMMAND.argv[ebx*4]
    call WriteString
    mov al, ' '
    call WriteChar
    inc ebx
    jmp echo_loop

echo_done:
    call Crlf
    mov eax, 1
    ret

check_cd:
    INVOKE StrEqI, esi, ADDR sCd
    cmp eax, 1
    jne check_set

    mov eax, [edi].COMMAND.argc
    cmp eax, 1
    jbe cd_print

    ; cd <dir>
    mov edx, [edi].COMMAND.argv[4]     ; argv[1]
    INVOKE SetCurrentDirectoryA, edx
    cmp eax, 0
    jne cd_ok
    mov edx, OFFSET cdErr
    call WriteString
cd_ok:
    mov eax, 1
    ret

cd_print:
    INVOKE GetCurrentDirectoryA, SIZEOF cdBuf, ADDR cdBuf
    mov edx, OFFSET cdBuf
    call WriteString
    call Crlf
    mov eax, 1
    ret

check_set:
    INVOKE StrEqI, esi, ADDR sSet
    cmp eax, 1
    jne check_run

    mov eax, [edi].COMMAND.argc
    cmp eax, 1
    je  do_set_print

    ; set NAME=VALUE
    INVOKE Env_SetFromCommand, edi
    cmp eax, 1
    je  set_ok
    mov edx, OFFSET setUsage
    call WriteString
set_ok:
    mov eax, 1
    ret

do_set_print:
    call Env_PrintAll
    mov eax, 1
    ret

check_run:
    INVOKE StrEqI, esi, ADDR sRun
    cmp eax, 1
    jne check_other

    mov eax, [edi].COMMAND.argc
    cmp eax, 2
    jb  run_usage

    mov edx, [edi].COMMAND.argv[4]     ; argv[1]
    INVOKE Script_RunFile, edx
    mov eax, 1
    ret

run_usage:
    mov edx, OFFSET runUsage
    call WriteString
    mov eax, 1
    ret

check_other:
    ; Remaining built-ins are structured stubs for the team to implement.
    INVOKE StrEqI, esi, ADDR sDir
    cmp eax, 1
    jne chk_type
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

chk_type:
    INVOKE StrEqI, esi, ADDR sType
    cmp eax, 1
    jne chk_copy
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

chk_copy:
    INVOKE StrEqI, esi, ADDR sCopy
    cmp eax, 1
    jne chk_del
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

chk_del:
    INVOKE StrEqI, esi, ADDR sDel
    cmp eax, 1
    jne chk_mkdir
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

chk_mkdir:
    INVOKE StrEqI, esi, ADDR sMkdir
    cmp eax, 1
    jne chk_rmdir
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

chk_rmdir:
    INVOKE StrEqI, esi, ADDR sRmdir
    cmp eax, 1
    jne chk_ren
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

chk_ren:
    INVOKE StrEqI, esi, ADDR sRen
    cmp eax, 1
    jne not_handled
    mov edx, OFFSET msgNI
    call WriteString
    mov eax, 1
    ret

not_handled:
    xor eax, eax
    ret
Builtins_TryExecute ENDP

END
