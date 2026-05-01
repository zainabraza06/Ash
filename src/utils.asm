; utils.asm - small string helpers used across modules

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ..\include\axs.inc

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
    je  eq

    inc esi
    inc edi
    jmp @B

eq:
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

END
