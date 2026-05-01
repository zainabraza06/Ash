; env.asm - environment variables (skeleton)
; MVP: supports `set NAME=VALUE` by calling SetEnvironmentVariableA.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

INCLUDELIB kernel32.lib

.data
msgSetOk     BYTE "OK",0Dh,0Ah,0
msgSetFail   BYTE "set: failed",0Dh,0Ah,0
msgSetListNI BYTE "set: listing env vars not implemented yet.",0Dh,0Ah,0

.code

Env_Init PROC
    ret
Env_Init ENDP

; Env_ExpandPercentVars(pLine, cbLine)
; TODO: Replace %NAME% with GetEnvironmentVariableA(NAME).
Env_ExpandPercentVars PROC, pLine:PTR BYTE, cbLine:DWORD
    ; no-op skeleton
    ret
Env_ExpandPercentVars ENDP

; Env_SetFromCommand(pCmd)
; Expects argv[1] = NAME=VALUE
; Returns EAX=1 if parsed and attempted, EAX=0 if invalid.
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
    mov eax, 1
    ret

invalid:
    xor eax, eax
    ret
Env_SetFromCommand ENDP

Env_PrintAll PROC
    mov edx, OFFSET msgSetListNI
    call WriteString
    ret
Env_PrintAll ENDP

END
