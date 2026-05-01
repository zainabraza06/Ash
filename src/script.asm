; script.asm - .shl script execution (skeleton)

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

.data
msgScriptNI BYTE "Script execution not implemented yet.",0Dh,0Ah,0

.code

Script_Init PROC
    ret
Script_Init ENDP

Script_RunFile PROC, pFile:PTR BYTE
    mov edx, OFFSET msgScriptNI
    call WriteString
    ret
Script_RunFile ENDP

END
