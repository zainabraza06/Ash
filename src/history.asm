; history.asm - command history & key handling (skeleton)

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

.code

History_Init PROC
    ret
History_Init ENDP

History_Add PROC, pLine:PTR BYTE
    ; TODO: store into circular buffer
    ret
History_Add ENDP

History_HandleKey PROC
    ; TODO: implement arrow-key navigation using raw console input
    ret
History_HandleKey ENDP

END
