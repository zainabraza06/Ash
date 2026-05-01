; pipeline.asm - pipes, redirections, chaining (skeleton)

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

.data
msgPipeNI BYTE "Pipes/redirection/chaining not implemented yet.",0Dh,0Ah,0

.code

Pipeline_Init PROC
    ret
Pipeline_Init ENDP

; Pipeline_TryExecute(pLine)
; Returns EAX=1 if the line contains pipe/redirection/chaining operators and was handled here.
; Returns EAX=0 to fall back to normal parse+dispatch.
Pipeline_TryExecute PROC USES esi, pLine:PTR BYTE
    mov esi, pLine

scan:
    mov al, [esi]
    cmp al, 0
    je  not_handled

    cmp al, '|'
    je  handled
    cmp al, '>'
    je  handled
    cmp al, '<'
    je  handled
    cmp al, '&'
    je  handled

    inc esi
    jmp scan

handled:
    mov edx, OFFSET msgPipeNI
    call WriteString
    mov eax, 1
    ret

not_handled:
    xor eax, eax
    ret
Pipeline_TryExecute ENDP

END
