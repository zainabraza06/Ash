; main.asm - AXS (Advanced x86 Shell)
; 32-bit MASM + Irvine32 skeleton.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
AXS_MAIN EQU 1
INCLUDE axs.inc

INCLUDELIB kernel32.lib

.data
; Shared globals (declared as EXTERN in axs.inc)
gLineBuf        BYTE MAX_LINE DUP(0)
gCmd            COMMAND <>

gShouldExit     DWORD 0
gLastExitCode   DWORD 0

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
    call Console_Init

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
    INVOKE Console_ReadLine, ADDR gLineBuf, MAX_LINE

    cmp  eax, 0
    je   repl_loop

    ; Add to history (no-op stub for now)
    mov  edx, OFFSET gLineBuf
    INVOKE History_Add, edx

    ; Execute line (handles env expansion, pipelines, built-ins, external)
    INVOKE Shell_ExecuteLine, ADDR gLineBuf
    jmp  repl_loop

repl_exit:
    exit
main ENDP

END main
