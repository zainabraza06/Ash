; dispatch.asm - shared line execution path for REPL and scripts

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ash.inc

EXTERN gLastExitCode:DWORD

.code

; Shell_ExecuteLine(pLine)
; - expands %VAR%
; - handles chaining/pipes/redirection (Pipeline_TryExecute)
; - otherwise parses and dispatches built-ins/external
Shell_ExecuteLine PROC USES edi, pLine:PTR BYTE
    ; expand env vars in-place
    INVOKE Env_ExpandPercentVars, pLine, MAX_LINE

    ; advanced handler (pipes/redirection/chaining/background)
    INVOKE Pipeline_TryExecute, pLine
    cmp eax, 1
    jne fallback

    ; Pipeline handler must set gLastExitCode
    ret

fallback:
    ; Parse argv
    INVOKE Parser_ParseLine, pLine, ADDR gCmd

    ; built-ins
    INVOKE Builtins_TryExecute, ADDR gCmd
    cmp eax, 1
    jne run_ext

    ; built-ins set gLastExitCode
    ret

run_ext:
    INVOKE External_Execute, ADDR gCmd
    mov gLastExitCode, eax
    ret
Shell_ExecuteLine ENDP

END
