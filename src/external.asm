; external.asm - external program execution (CreateProcess)

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE axs.inc

INCLUDELIB kernel32.lib

.data
CmdLineBuf BYTE MAX_LINE DUP(0)
msgLaunchFail BYTE "Failed to launch process. GetLastError=0x",0

.code

External_Init PROC
    ret
External_Init ENDP

; External_Execute(pCmd)
; Builds a command line from argv[] and launches it via CreateProcessA.
External_Execute PROC USES esi edi ebx ecx edx, pCmd:PTR COMMAND
    LOCAL startupInfo:STARTUPINFOA
    LOCAL procInfo:PROCESS_INFORMATION
    LOCAL exitCode:DWORD

    mov exitCode, 0

    mov edi, pCmd
    mov eax, [edi].COMMAND.argc
    cmp eax, 0
    je  done

    ; Build CmdLineBuf
    lea ebx, CmdLineBuf
    mov BYTE PTR [ebx], 0

    xor ecx, ecx
build_loop:
    cmp ecx, [edi].COMMAND.argc
    jae build_done

    mov esi, [edi].COMMAND.argv[ecx*4]
    ; copy token
copy_tok:
    mov al, [esi]
    cmp al, 0
    je  tok_done
    mov [ebx], al
    inc esi
    inc ebx
    jmp copy_tok

tok_done:
    ; add space between tokens
    mov al, ' '
    mov [ebx], al
    inc ebx

    inc ecx
    jmp build_loop

build_done:
    ; terminate (remove last space if present)
    cmp ebx, OFFSET CmdLineBuf
    jbe term
    dec ebx
    mov BYTE PTR [ebx], 0
term:

    ; zero structs
    lea esi, startupInfo
    mov ecx, SIZEOF STARTUPINFOA
    xor eax, eax
zero_si:
    mov BYTE PTR [esi], al
    inc esi
    loop zero_si

    lea esi, procInfo
    mov ecx, SIZEOF PROCESS_INFORMATION
zero_pi:
    mov BYTE PTR [esi], al
    inc esi
    loop zero_pi

    mov startupInfo.cb, SIZEOF STARTUPINFOA

    INVOKE CreateProcessA,
        NULL,
        ADDR CmdLineBuf,
        NULL,
        NULL,
        FALSE,
        0,
        NULL,
        NULL,
        ADDR startupInfo,
        ADDR procInfo

    cmp eax, 0
    jne launched

    ; print error
    mov edx, OFFSET msgLaunchFail
    call WriteString
    call GetLastError
    mov exitCode, eax
    call WriteHex
    call Crlf
    mov eax, exitCode
    ret

launched:
    ; wait and close handles
    INVOKE WaitForSingleObject, procInfo.hProcess, INFINITE
    INVOKE GetExitCodeProcess, procInfo.hProcess, ADDR exitCode

    INVOKE CloseHandle, procInfo.hThread
    INVOKE CloseHandle, procInfo.hProcess

done:
    mov eax, exitCode
    ret
External_Execute ENDP

END
