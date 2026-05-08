; env.asm - environment variables (skeleton)
; MVP: supports `set NAME=VALUE` by calling SetEnvironmentVariableA.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE axs.inc

INCLUDELIB kernel32.lib

.data
msgSetOk     BYTE "OK",0Dh,0Ah,0
msgSetFail   BYTE "set: failed",0Dh,0Ah,0
msgSetListFail BYTE "set: failed to read environment",0Dh,0Ah,0

TmpBuf BYTE MAX_LINE DUP(0)
NameBuf BYTE MAX_ENV_NAME DUP(0)
ValBuf  BYTE MAX_ENV_VALUE DUP(0)

.code

Env_Init PROC
    ret
Env_Init ENDP

; Env_ExpandPercentVars(pLine, cbLine)
; Replace %NAME% with GetEnvironmentVariableA(NAME).
; Best-effort: if variable not found, keeps the original %NAME%.
Env_ExpandPercentVars PROC USES esi edi ebx ecx edx, pLine:PTR BYTE, cbLine:DWORD
    mov esi, pLine
    mov edi, OFFSET TmpBuf

copy_loop:
    mov al, [esi]
    cmp al, 0
    je  finish

    cmp al, '%'
    jne copy_char

    ; attempt read %NAME%
    inc esi
    mov ebx, OFFSET NameBuf
    xor ecx, ecx

name_loop:
    mov al, [esi]
    cmp al, 0
    je  not_var
    cmp al, '%'
    je  name_done
    cmp ecx, MAX_ENV_NAME-1
    jae not_var
    mov [ebx], al
    inc ebx
    inc esi
    inc ecx
    jmp name_loop

name_done:
    mov BYTE PTR [ebx], 0
    ; esi points at closing '%'
    inc esi

    ; fetch value
    INVOKE GetEnvironmentVariableA, ADDR NameBuf, ADDR ValBuf, MAX_ENV_VALUE
    cmp eax, 0
    je  keep_original

    ; copy value to tmp
    mov ebx, OFFSET ValBuf
val_copy:
    mov al, [ebx]
    cmp al, 0
    je  copy_loop
    mov [edi], al
    inc edi
    inc ebx
    jmp val_copy

keep_original:
    ; write back %NAME%
    mov BYTE PTR [edi], '%'
    inc edi
    mov ebx, OFFSET NameBuf
ko_loop:
    mov al, [ebx]
    cmp al, 0
    je  ko_end
    mov [edi], al
    inc edi
    inc ebx
    jmp ko_loop
ko_end:
    mov BYTE PTR [edi], '%'
    inc edi
    jmp copy_loop

not_var:
    ; treat as literal '%'
    mov BYTE PTR [edi], '%'
    inc edi
    jmp copy_loop

copy_char:
    mov [edi], al
    inc edi
    inc esi
    jmp copy_loop

finish:
    mov BYTE PTR [edi], 0
    ; copy tmp back to line
    INVOKE Str_copy, ADDR TmpBuf, pLine
    ret
Env_ExpandPercentVars ENDP

; Env_SetFromCommand(pCmd)
; Expects argv[1] = NAME=VALUE
; Returns: EAX=1 success, EAX=2 API failure, EAX=0 invalid.
Env_SetFromCommand PROC USES esi edi ebx, pCmd:PTR COMMAND
    mov edi, pCmd
    mov eax, [edi].COMMAND.argc
    cmp eax, 2
    jb  invalid

    mov esi, [edi].COMMAND.argv[4] ; argv[1]

    ; find '='
    mov ebx, esi
find_eq:
    mov al, [ebx]
    cmp al, 0
    je  invalid
    cmp al, '='
    je  split
    inc ebx
    jmp find_eq

split:
    ; name = esi, value = ebx+1 (in-place)
    mov BYTE PTR [ebx], 0
    lea edx, [ebx+1]

    INVOKE SetEnvironmentVariableA, esi, edx
    cmp eax, 0
    je  fail

    mov edx, OFFSET msgSetOk
    call WriteString
    mov eax, 1
    ret

fail:
    mov edx, OFFSET msgSetFail
    call WriteString
    mov eax, 2
    ret

invalid:
    xor eax, eax
    ret
Env_SetFromCommand ENDP

Env_PrintAll PROC
    LOCAL pEnv:DWORD

    INVOKE GetEnvironmentStringsA
    mov pEnv, eax
    cmp eax, 0
    jne env_loop

    mov edx, OFFSET msgSetListFail
    call WriteString
    ret

env_loop:
    mov esi, pEnv

next_str:
    mov al, [esi]
    cmp al, 0
    je  done

    mov edx, esi
    call WriteString
    call Crlf

    ; advance to next string
adv:
    mov al, [esi]
    inc esi
    cmp al, 0
    jne adv
    jmp next_str

done:
    INVOKE FreeEnvironmentStringsA, pEnv
    ret
Env_PrintAll ENDP

END
