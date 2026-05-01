; main.asm - AXS (Advanced x86 Shell)
; 32-bit MASM + Irvine32 skeleton.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

INCLUDELIB kernel32.lib

.data
; Shared globals (declared as EXTERN in axs.inc)
gLineBuf        BYTE MAX_LINE DUP(0)
gCmd            COMMAND <>

gShouldExit     DWORD 0

gBanner1        BYTE "========================================",0Dh,0Ah,0
gBanner2        BYTE "    AXS Shell v0.1 - Advanced x86 Shell",0Dh,0Ah,0
gBanner3        BYTE "    Type 'help' for available commands",0Dh,0Ah,0
gBanner4        BYTE "========================================",0Dh,0Ah,0

PromptBuf       BYTE 260 DUP(0)
PromptSep       BYTE "> ",0

.code
main PROC
    ; Module init
    call Parser_Init
    call Builtins_Init
    call External_Init
    call Pipeline_Init
    call Env_Init
    call History_Init
    call Script_Init

    mov  edx, OFFSET gBanner1
    call WriteString
    mov  edx, OFFSET gBanner2
    call WriteString
    mov  edx, OFFSET gBanner3
    call WriteString
    mov  edx, OFFSET gBanner4
    call WriteString

repl_loop:
    cmp  gShouldExit, 0
    jne  repl_exit

    ; Prompt = current directory + "> "
    INVOKE GetCurrentDirectoryA, SIZEOF PromptBuf, ADDR PromptBuf
    mov  edx, OFFSET PromptBuf
    call WriteString
    mov  edx, OFFSET PromptSep
    call WriteString

    ; Read line
    mov  edx, OFFSET gLineBuf
    mov  ecx, MAX_LINE
    call ReadString          ; EAX = length

    cmp  eax, 0
    je   repl_loop

    ; Add to history (no-op stub for now)
    mov  edx, OFFSET gLineBuf
    INVOKE History_Add, edx

    ; Expand %VAR% (stub for now)
    INVOKE Env_ExpandPercentVars, ADDR gLineBuf, MAX_LINE

    ; Advanced: pipeline/redirection handler can short-circuit
    INVOKE Pipeline_TryExecute, ADDR gLineBuf
    cmp  eax, 1
    je   repl_loop

    ; Parse into argv/argc
    INVOKE Parser_ParseLine, ADDR gLineBuf, ADDR gCmd

    ; Try built-ins
    INVOKE Builtins_TryExecute, ADDR gCmd
    cmp  eax, 1
    je   repl_loop

    ; Otherwise run external command (stub)
    INVOKE External_Execute, ADDR gCmd
    jmp  repl_loop

repl_exit:
    exit
main ENDP

END main
