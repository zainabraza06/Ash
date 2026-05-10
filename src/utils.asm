; utils.asm - small string helpers used across modules

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE axs.inc

.code

; DWORD StrLen(pStr)
StrLen PROC USES esi, pStr:PTR BYTE
    mov esi, pStr
    xor eax, eax
@@:
    cmp BYTE PTR [esi], 0
    je  @F
    inc esi
    inc eax
    jmp @B
@@:
    ret
StrLen ENDP

; BYTE* StrSkipSpaces(pStr) -> EAX
StrSkipSpaces PROC USES esi, pStr:PTR BYTE
    mov esi, pStr
@@:
    mov al, [esi]
    cmp al, ' '
    je  skip
    cmp al, 9
    je  skip
    mov eax, esi
    ret
skip:
    inc esi
    jmp @B
StrSkipSpaces ENDP

; void StrToLowerInPlace(pStr)
StrToLowerInPlace PROC USES esi, pStr:PTR BYTE
    mov esi, pStr
@@:
    mov al, [esi]
    cmp al, 0
    je  done
    cmp al, 'A'
    jb  next
    cmp al, 'Z'
    ja  next
    add al, 32
    mov [esi], al
next:
    inc esi
    jmp @B
done:
    ret
StrToLowerInPlace ENDP

; BOOL StrEqI(pA, pB) -> EAX=1 if equal (case-insensitive ASCII)
StrEqI PROC USES esi edi, pA:PTR BYTE, pB:PTR BYTE
    mov esi, pA
    mov edi, pB
@@:
    mov al, [esi]
    mov dl, [edi]

    ; tolower al
    cmp al, 'A'
    jb  a_ok
    cmp al, 'Z'
    ja  a_ok
    add al, 32
 a_ok:

    ; tolower dl
    cmp dl, 'A'
    jb  b_ok
    cmp dl, 'Z'
    ja  b_ok
    add dl, 32
 b_ok:

    cmp al, dl
    jne not_eq

    cmp al, 0
    je  is_eq

    inc esi
    inc edi
    jmp @B

is_eq:
    mov eax, 1
    ret
not_eq:
    xor eax, eax
    ret
StrEqI ENDP

; BOOL StrStartsWithI(pStr, pPrefix) -> EAX=1/0
StrStartsWithI PROC USES esi edi, pStr:PTR BYTE, pPrefix:PTR BYTE
    mov esi, pStr
    mov edi, pPrefix
@@:
    mov dl, [edi]
    cmp dl, 0
    je  yes

    mov al, [esi]
    cmp al, 0
    je  no

    ; tolower al
    cmp al, 'A'
    jb  a_ok
    cmp al, 'Z'
    ja  a_ok
    add al, 32
 a_ok:

    ; tolower dl
    cmp dl, 'A'
    jb  b_ok
    cmp dl, 'Z'
    ja  b_ok
    add dl, 32
 b_ok:

    cmp al, dl
    jne no

    inc esi
    inc edi
    jmp @B

yes:
    mov eax, 1
    ret
no:
    xor eax, eax
    ret
StrStartsWithI ENDP

; BOOL StrEndsWithI(pStr, pSuffix) -> EAX=1 if suffix matches end (ASCII case-insensitive)
StrEndsWithI PROC USES esi edi ebx ecx, pStr:PTR BYTE, pSuffix:PTR BYTE
    INVOKE StrLen, pStr
    mov ebx, eax
    INVOKE StrLen, pSuffix
    mov ecx, eax
    cmp ebx, ecx
    jb  no2
    mov esi, pStr
    add esi, ebx
    sub esi, ecx
    mov edi, pSuffix

tail_cmp:
    cmp ecx, 0
    je  yes2
    mov al, [esi]
    mov dl, [edi]

    cmp al, 'A'
    jb  a_ok2
    cmp al, 'Z'
    ja  a_ok2
    add al, 32
 a_ok2:
    cmp dl, 'A'
    jb  b_ok2
    cmp dl, 'Z'
    ja  b_ok2
    add dl, 32
 b_ok2:
    cmp al, dl
    jne no2
    inc esi
    inc edi
    dec ecx
    jmp tail_cmp

yes2:
    mov eax, 1
    ret
no2:
    xor eax, eax
    ret
StrEndsWithI ENDP

; If pBuf starts with ", copies inner characters in place (first "..." pair).
StrStripOuterQuotesInPlace PROC USES esi edi, pBuf:PTR BYTE
    mov esi, pBuf
    mov al, [esi]
    cmp al, '"'
    jne strip_done

    mov edi, esi
    inc esi
strip_loop:
    mov al, [esi]
    cmp al, 0
    je  strip_truncate
    cmp al, '"'
    je  strip_close
    mov [edi], al
    inc esi
    inc edi
    jmp strip_loop

strip_close:
    mov BYTE PTR [edi], 0
strip_truncate:
strip_done:
    ret
StrStripOuterQuotesInPlace ENDP

END
