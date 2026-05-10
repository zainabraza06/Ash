; main.asm - Ash (minimal x86 shell for Windows)
; 32-bit MASM + Irvine32 skeleton.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
ASH_MAIN EQU 1
INCLUDE ash.inc

INCLUDELIB kernel32.lib

.data
; Shared globals (declared as EXTERN in ash.inc)
gLineBuf        BYTE MAX_LINE DUP(0)
gCmd            COMMAND <>

gShouldExit     DWORD 0
gLastExitCode   DWORD 0

gBanner1        BYTE "========================================",0Dh,0Ah,0
gBanner2        BYTE "    Ash v0.1 - Minimal x86 shell for Windows",0Dh,0Ah,0
gBanner3        BYTE "    Type 'help' for available commands",0Dh,0Ah,0
gBanner4        BYTE "========================================",0Dh,0Ah,0

PromptBuf       BYTE 260 DUP(0)
PromptSep       BYTE "> ",0
extShl          BYTE ".shl",0

.code

; EAX -> first character after the executable path on the process command line (may be "" tail).
Main_GetArgsTail PROC USES esi
    INVOKE GetCommandLineA
    mov esi, eax
    INVOKE StrSkipSpaces, esi
    mov esi, eax

    mov al, [esi]
    cmp al, 0
    je  tail_done

    cmp al, '"'
    je  quoted_path

scan_u:
    mov al, [esi]
    cmp al, 0
    je  tail_done
    cmp al, ' '
    je  after_path
    cmp al, 9
    je  after_path
    inc esi
    jmp scan_u

quoted_path:
    inc esi
scan_q:
    mov al, [esi]
    cmp al, 0
    je  tail_done
    cmp al, '"'
    je  after_quote
    inc esi
    jmp scan_q

after_quote:
    inc esi

after_path:
    INVOKE StrSkipSpaces, esi

tail_done:
    mov eax, esi
    ret
Main_GetArgsTail ENDP

; Copy null-terminated tail into gLineBuf (caps at MAX_LINE-1 chars).
Main_CopyTailToLineBuf PROC USES esi edi ecx, pTail:PTR BYTE
    mov esi, pTail
    mov edi, OFFSET gLineBuf
    mov ecx, MAX_LINE - 1
ct_loop:
    mov al, [esi]
    mov [edi], al
    cmp al, 0
    je  ct_done
    inc esi
    inc edi
    loop ct_loop
    mov BYTE PTR [edi], 0
ct_done:
    ret
Main_CopyTailToLineBuf ENDP

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

    call Main_GetArgsTail
    INVOKE StrSkipSpaces, eax
    mov esi, eax
    mov al, [esi]
    cmp al, 0
    je   show_banner

    INVOKE Main_CopyTailToLineBuf, esi
    INVOKE StrStripOuterQuotesInPlace, ADDR gLineBuf

    INVOKE StrEndsWithI, ADDR gLineBuf, ADDR extShl
    cmp eax, 1
    jne batch_cmd

    INVOKE Script_RunFile, ADDR gLineBuf
    INVOKE ExitProcess, gLastExitCode

batch_cmd:
    INVOKE Shell_ExecuteLine, ADDR gLineBuf
    INVOKE ExitProcess, gLastExitCode

show_banner:
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

    mov  edx, OFFSET gLineBuf
    INVOKE History_Add, edx

    ; Execute line (handles env expansion, pipelines, built-ins, external)
    INVOKE Shell_ExecuteLine, ADDR gLineBuf
    jmp  repl_loop

repl_exit:
    INVOKE ExitProcess, gLastExitCode
main ENDP

END main
