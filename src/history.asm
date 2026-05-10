; history.asm - command history (working)

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ash.inc

.data
; Simple circular buffer: HISTORY_SIZE slots, each MAX_LINE bytes
; head = next write slot
; cursor = browsing pointer (0xFFFFFFFF means not browsing)

gHistCount   DWORD 0

gHistHead    DWORD 0

gHistCursor  DWORD 0FFFFFFFFh

gHistoryBuf  BYTE (HISTORY_SIZE * MAX_LINE) DUP(0)

.code

History_Init PROC
    mov gHistCount, 0
    mov gHistHead, 0
    mov gHistCursor, 0FFFFFFFFh
    ret
History_Init ENDP

; Copies a 0-terminated line into next slot.
History_Add PROC USES esi edi ebx ecx, pLine:PTR BYTE
    mov esi, pLine

    ; ignore empty
    mov al, [esi]
    cmp al, 0
    je  done

    ; write to head slot
    mov ebx, gHistHead
    imul ebx, MAX_LINE
    lea edi, gHistoryBuf
    add edi, ebx

    ; copy up to MAX_LINE-1
    mov ecx, MAX_LINE-1
copy_loop:
    mov al, [esi]
    mov [edi], al
    cmp al, 0
    je  copied
    inc esi
    inc edi
    loop copy_loop

    ; force null
    mov BYTE PTR [edi], 0

copied:
    ; advance head
    mov eax, gHistHead
    inc eax
    cmp eax, HISTORY_SIZE
    jb  head_ok
    xor eax, eax
head_ok:
    mov gHistHead, eax

    ; increase count up to HISTORY_SIZE
    mov eax, gHistCount
    cmp eax, HISTORY_SIZE
    jae count_ok
    inc eax
    mov gHistCount, eax
count_ok:

    ; reset browsing cursor
    mov gHistCursor, 0FFFFFFFFh

done:
    ret
History_Add ENDP

; Returns EAX=1 and fills out buffer if available; else EAX=0.
History_Prev PROC USES ebx edx, pOutBuf:PTR BYTE
    mov eax, gHistCount
    cmp eax, 0
    je  none

    mov ebx, gHistCursor
    cmp ebx, 0FFFFFFFFh
    jne have_cursor

    ; start from most recent entry (head-1)
    mov ebx, gHistHead
    dec ebx
    jns cursor_ok
    mov ebx, HISTORY_SIZE-1
cursor_ok:
    mov gHistCursor, ebx
    jmp copy

have_cursor:
    dec ebx
    jns older_ok
    mov ebx, HISTORY_SIZE-1
older_ok:
    mov gHistCursor, ebx

copy:
    mov eax, gHistCursor
    imul eax, MAX_LINE
    lea edx, gHistoryBuf
    add edx, eax
    INVOKE Str_copy, edx, pOutBuf
    mov eax, 1
    ret

none:
    xor eax, eax
    ret
History_Prev ENDP

; Returns EAX=1 and fills out buffer if available; else EAX=0.
History_Next PROC USES ebx edx, pOutBuf:PTR BYTE
    mov eax, gHistCount
    cmp eax, 0
    je  none

    mov ebx, gHistCursor
    cmp ebx, 0FFFFFFFFh
    je  none

    inc ebx
    cmp ebx, HISTORY_SIZE
    jb  newer_ok
    xor ebx, ebx
newer_ok:

    ; if reached head, stop browsing and clear
    cmp ebx, gHistHead
    jne keep

    mov gHistCursor, 0FFFFFFFFh
    mov edx, pOutBuf
    mov BYTE PTR [edx], 0
    mov eax, 1
    ret

keep:
    mov gHistCursor, ebx
    mov eax, gHistCursor
    imul eax, MAX_LINE
    lea edx, gHistoryBuf
    add edx, eax
    INVOKE Str_copy, edx, pOutBuf
    mov eax, 1
    ret

none:
    xor eax, eax
    ret
History_Next ENDP

END
