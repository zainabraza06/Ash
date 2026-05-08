; console.asm - interactive line editor with history (Up/Down) and tab completion

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE axs.inc

INCLUDELIB kernel32.lib

.data
HistWorkBuf BYTE MAX_LINE DUP(0)
TabPattern  BYTE 260 DUP(0)

.code

Console_Init PROC
    ret
Console_Init ENDP

; Helpers for editing: erase current input by printing backspaces.
Console_EraseLine PROC USES ecx eax, len:DWORD
    mov ecx, len
    jecxz done
erase_loop:
    mov al, 8
    call WriteChar
    mov al, ' '
    call WriteChar
    mov al, 8
    call WriteChar
    loop erase_loop

done:
    ret
Console_EraseLine ENDP

; Completes current token from current directory: token* -> first match.
; Returns EAX=1 if completion was applied.
Console_TabComplete PROC USES esi edi ebx ecx edx, pBuf:PTR BYTE, cbBuf:DWORD, pLen:PTR DWORD
    LOCAL fd:WIN32_FIND_DATAA
    LOCAL hFind:DWORD

    mov esi, pBuf

    ; find end
    mov ecx, 0
find_end:
    mov al, [esi+ecx]
    cmp al, 0
    je  end_found
    inc ecx
    cmp ecx, cbBuf
    jb  find_end
    jmp no
end_found:

    ; find token start (after last space)
    mov ebx, ecx
back_scan:
    cmp ebx, 0
    je  token_start
    dec ebx
    mov al, [esi+ebx]
    cmp al, ' '
    je  token_start2
    cmp al, 9
    je  token_start2
    jmp back_scan

token_start2:
    inc ebx

token_start:
    ; token begins at buf+ebx, length = ecx-ebx
    mov edi, OFFSET TabPattern

    ; copy token
    mov edx, ebx
copy_tok:
    cmp edx, ecx
    jae tok_done
    mov al, [esi+edx]
    mov [edi], al
    inc edi
    inc edx
    jmp copy_tok

tok_done:
    ; append '*'
    mov BYTE PTR [edi], '*'
    inc edi
    mov BYTE PTR [edi], 0

    INVOKE FindFirstFileA, ADDR TabPattern, ADDR fd
    mov hFind, eax
    cmp eax, INVALID_HANDLE_VALUE
    je  no

    ; fd.cFileName is match; avoid "." and ".."
    lea edi, fd.cFileName
    mov al, [edi]
    cmp al, '.'
    jne use
    cmp BYTE PTR [edi+1], 0
    je  next
    cmp BYTE PTR [edi+1], '.'
    jne use
    cmp BYTE PTR [edi+2], 0
    je  next

use:
    ; apply completion: replace token with full filename
    ; First erase from screen only the remaining token already printed? Simplify: no erase here;
    ; caller erases entire line when history is used, but for tab we append remaining chars.

    ; compute existing token length = ecx - ebx
    mov edx, ecx
    sub edx, ebx

    ; compute match length
    INVOKE StrLen, edi
    mov ecx, eax

    ; if match shorter or equal to current token, nothing to add
    cmp ecx, edx
    jbe cleanup

    ; append remaining part of match to buffer and echo
    ; remaining start = match + edx
    lea eax, fd.cFileName
    add eax, edx

append_loop:
    mov dl, [eax]
    cmp dl, 0
    je  done_append

    ; ensure buffer space
    mov ebx, pLen
    mov ebx, [ebx]
    cmp ebx, cbBuf
    jae done_append

    ; write to buffer
    mov esi, pBuf
    mov [esi+ebx], dl
    inc ebx

    ; update len
    mov esi, pLen
    mov [esi], ebx

    ; echo char
    mov al, dl
    call WriteChar

    inc eax
    jmp append_loop

done_append:
    ; null terminate
    mov esi, pLen
    mov ebx, [esi]
    mov esi, pBuf
    mov BYTE PTR [esi+ebx], 0

cleanup:
    INVOKE FindClose, hFind
    mov eax, 1
    ret

next:
    ; try next match
    INVOKE FindNextFileA, hFind, ADDR fd
    cmp eax, 0
    je  cleanup2
    jmp use

cleanup2:
    INVOKE FindClose, hFind
no:
    xor eax, eax
    ret
Console_TabComplete ENDP

; Console_ReadKeyLike
; Emulates Irvine ReadKey using ReadChar:
; - Normal keys: AL=ASCII, AH=0
; - Extended keys: first ReadChar returns 0 or 0E0h, second returns scan code
;   Return format matches existing logic: AL=0, AH=scan
Console_ReadKeyLike PROC
    call ReadChar
    mov ah, 0
    cmp al, 0
    je  ext
    cmp al, 0E0h
    je  ext
    ret

ext:
    call ReadChar
    mov ah, al
    xor al, al
    ret
Console_ReadKeyLike ENDP

; Console_ReadLine(pBuf, cbBuf) -> EAX = length
; Handles: Enter, Backspace, Up/Down history, Tab completion.
Console_ReadLine PROC USES esi edi ebx ecx edx, pBuf:PTR BYTE, cbBuf:DWORD
    LOCAL curLen:DWORD

    mov esi, pBuf
    mov BYTE PTR [esi], 0
    xor ebx, ebx          ; current length

read_loop:
    call Console_ReadKeyLike  ; AL=ASCII, AH=scan code (ReadChar-based)

    ; Enter
    cmp al, 0Dh
    je  done

    ; Backspace
    cmp al, 08h
    jne check_special

    cmp ebx, 0
    je  read_loop

    dec ebx
    mov BYTE PTR [esi+ebx], 0

    mov al, 8
    call WriteChar
    mov al, ' '
    call WriteChar
    mov al, 8
    call WriteChar
    jmp read_loop

check_special:
    ; Special keys: AL=0, scan in AH
    cmp al, 0
    jne check_tab

    ; Up arrow: scan 48h
    cmp ah, 48h
    jne chk_down

    ; recall prev into HistWorkBuf
    INVOKE History_Prev, ADDR HistWorkBuf
    cmp eax, 1
    jne read_loop

    ; erase current line on screen
    INVOKE Console_EraseLine, ebx

    ; copy recalled to pBuf and print
    INVOKE Str_copy, ADDR HistWorkBuf, esi
    INVOKE StrLen, esi
    mov ebx, eax

    mov edx, esi
    call WriteString
    jmp read_loop

chk_down:
    cmp ah, 50h
    jne read_loop

    INVOKE History_Next, ADDR HistWorkBuf
    cmp eax, 1
    jne read_loop

    INVOKE Console_EraseLine, ebx
    INVOKE Str_copy, ADDR HistWorkBuf, esi
    INVOKE StrLen, esi
    mov ebx, eax

    mov edx, esi
    call WriteString
    jmp read_loop

check_tab:
    cmp al, 09h
    jne check_printable

    ; attempt tab completion
    mov curLen, ebx
    INVOKE Console_TabComplete, esi, cbBuf, ADDR curLen
    mov ebx, curLen
    jmp read_loop

check_printable:
    ; Ignore other control chars
    cmp al, 20h
    jb  read_loop

    ; Ensure space
    mov ecx, cbBuf
    dec ecx
    cmp ebx, ecx
    jae read_loop

    mov [esi+ebx], al
    inc ebx
    mov BYTE PTR [esi+ebx], 0

    call WriteChar
    jmp read_loop

done:
    call Crlf
    mov eax, ebx
    ret
Console_ReadLine ENDP

END
