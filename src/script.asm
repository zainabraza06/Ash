; script.asm - .shl script execution

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ash.inc

INCLUDELIB kernel32.lib

EXTERN gShouldExit:DWORD
EXTERN gLastExitCode:DWORD

.data
msgScriptOpenFail BYTE "run: cannot open script",0Dh,0Ah,0
msgScriptDone     BYTE "(script finished)",0Dh,0Ah,0

ChunkBuf BYTE 512 DUP(0)
LineBuf  BYTE MAX_LINE DUP(0)

.code

Script_Init PROC
    ret
Script_Init ENDP

; Trim leading spaces, returns pointer in EAX
Script_SkipSpaces PROC USES esi, pStr:PTR BYTE
    mov esi, pStr
@@:
    mov al, [esi]
    cmp al, ' '
    je  s
    cmp al, 9
    je  s
    mov eax, esi
    ret
s:
    inc esi
    jmp @B
Script_SkipSpaces ENDP

Script_RunFile PROC USES esi edi ebx ecx edx, pFile:PTR BYTE
    LOCAL hFile:DWORD
    LOCAL bytesRead:DWORD
    LOCAL lineLen:DWORD

    mov lineLen, 0

    INVOKE CreateFileA, pFile, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov hFile, eax
    cmp eax, INVALID_HANDLE_VALUE
    jne read_more

    mov edx, OFFSET msgScriptOpenFail
    call WriteString
    mov gLastExitCode, 1
    ret

read_more:
    INVOKE ReadFile, hFile, ADDR ChunkBuf, SIZEOF ChunkBuf, ADDR bytesRead, NULL
    cmp eax, 0
    je  finish

    mov eax, bytesRead
    cmp eax, 0
    je  finish

    xor ebx, ebx
process_chunk:
    cmp ebx, bytesRead
    jae read_more

    mov al, ChunkBuf[ebx]
    inc ebx

    ; ignore CR
    cmp al, 0Dh
    je  process_chunk

    ; newline
    cmp al, 0Ah
    jne add_char

    ; terminate line
    mov ecx, lineLen
    cmp ecx, MAX_LINE-1
    jb  term_ok
    mov ecx, MAX_LINE-1
term_ok:
    mov LineBuf[ecx], 0

    ; execute line if not empty/comment
    INVOKE Script_SkipSpaces, ADDR LineBuf
    mov esi, eax
    mov al, [esi]
    cmp al, 0
    je  reset
    cmp al, '#'
    je  reset

    INVOKE Shell_ExecuteLine, esi

    cmp gShouldExit, 0
    jne finish

reset:
    mov lineLen, 0
    jmp process_chunk

add_char:
    mov ecx, lineLen
    cmp ecx, MAX_LINE-1
    jae process_chunk
    mov LineBuf[ecx], al
    inc ecx
    mov lineLen, ecx
    jmp process_chunk

finish:
    ; flush last line if present
    mov ecx, lineLen
    cmp ecx, 0
    je  close

    mov LineBuf[ecx], 0
    INVOKE Script_SkipSpaces, ADDR LineBuf
    mov esi, eax
    mov al, [esi]
    cmp al, 0
    je  close
    cmp al, '#'
    je  close
    INVOKE Shell_ExecuteLine, esi

close:
    INVOKE CloseHandle, hFile
    ; keep gLastExitCode from last executed line
    ret
Script_RunFile ENDP

END
