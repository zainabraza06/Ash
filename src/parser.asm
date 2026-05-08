; parser.asm - tokenization, quote handling, input validation (skeleton)

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE axs.inc

.code

Parser_Init PROC
    ret
Parser_Init ENDP

; Parser_ParseLine(pLine, pCmd)
; - Splits input into argv/argc in-place (writes 0 terminators)
; - Handles quoted tokens: "hello world" -> one token
; - Ignores comment lines starting with '#'
Parser_ParseLine PROC USES esi edi ebx, pLine:PTR BYTE, pCmd:PTR COMMAND
    mov edi, pCmd

    ; argc = 0
    mov DWORD PTR [edi].COMMAND.argc, 0

    mov esi, pLine

    ; skip leading spaces
    INVOKE StrSkipSpaces, esi
    mov esi, eax

    ; comment?
    mov al, [esi]
    cmp al, '#'
    jne parse_loop
    ret

parse_loop:
    ; Skip spaces/tabs
    INVOKE StrSkipSpaces, esi
    mov esi, eax

    mov al, [esi]
    cmp al, 0
    je  done

    ; if argc >= MAX_TOKENS stop
    mov ebx, DWORD PTR [edi].COMMAND.argc
    cmp ebx, MAX_TOKENS
    jae done

    ; Token starts here (maybe after quote)
    cmp al, '"'
    jne token_unquoted

    ; quoted token: start after '"'
    inc esi
    mov eax, esi

    ; store argv[argc] = start
    mov ecx, DWORD PTR [edi].COMMAND.argc
    mov [edi].COMMAND.argv[ecx*4], eax
    inc DWORD PTR [edi].COMMAND.argc

scan_quoted:
    mov al, [esi]
    cmp al, 0
    je  done
    cmp al, '"'
    je  end_quoted
    inc esi
    jmp scan_quoted

end_quoted:
    ; terminate token and advance
    mov BYTE PTR [esi], 0
    inc esi
    jmp parse_loop

token_unquoted:
    mov eax, esi

    ; store argv[argc] = start
    mov ecx, DWORD PTR [edi].COMMAND.argc
    mov [edi].COMMAND.argv[ecx*4], eax
    inc DWORD PTR [edi].COMMAND.argc

scan_unquoted:
    mov al, [esi]
    cmp al, 0
    je  done
    cmp al, ' '
    je  end_unquoted
    cmp al, 9
    je  end_unquoted
    inc esi
    jmp scan_unquoted

end_unquoted:
    mov BYTE PTR [esi], 0
    inc esi
    jmp parse_loop

done:
    ret
Parser_ParseLine ENDP

END
