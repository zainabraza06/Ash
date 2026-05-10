; pipeline.asm - pipes, redirection, chaining, background execution
; Supports: |  <  >  >>  &&  ||  & (trailing)
;
; Notes:
; - Built-ins are executed in-process, with temporary std-handle redirection.
; - External programs are executed with CreateProcessA and STARTF_USESTDHANDLES.

.386
.model flat, stdcall
option casemap:none

INCLUDE Irvine32.inc
INCLUDE ash.inc

INCLUDELIB kernel32.lib

EXTERN gLastExitCode:DWORD
EXTERN gShouldExit:DWORD

.data
msgExecFail BYTE "Execution failed.",0Dh,0Ah,0
msgBadRedir BYTE "Redirection syntax error.",0Dh,0Ah,0

StageBuf BYTE MAX_LINE DUP(0)
CmdLineBuf BYTE MAX_LINE DUP(0)

.code

Pipeline_Init PROC
    ret
Pipeline_Init ENDP

; returns EAX = pointer to first non-space
Pipe_SkipSpaces PROC USES esi, pStr:PTR BYTE
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
Pipe_SkipSpaces ENDP

; trims trailing spaces in-place; returns EAX=pStr
Pipe_TrimRight PROC USES esi ecx, pStr:PTR BYTE
    mov esi, pStr
    INVOKE StrLen, esi
    mov ecx, eax
    cmp ecx, 0
    je  done

    dec ecx
back:
    mov al, [esi+ecx]
    cmp al, ' '
    je  zap
    cmp al, 9
    je  zap
    jmp done
zap:
    mov BYTE PTR [esi+ecx], 0
    cmp ecx, 0
    je  done
    dec ecx
    jmp back

done:
    mov eax, pStr
    ret
Pipe_TrimRight ENDP

; Finds next unquoted occurrence of a char.
; EAX = pointer if found else 0.
Pipe_FindCharUnquoted PROC USES esi, pStr:PTR BYTE, needle:BYTE
    mov esi, pStr
    xor ecx, ecx           ; inQuotes = 0
scan:
    mov al, [esi]
    cmp al, 0
    je  none
    cmp al, '"'
    jne chk
    xor ecx, 1
    jmp adv
chk:
    cmp ecx, 0
    jne adv
    cmp al, needle
    jne adv
    mov eax, esi
    ret
adv:
    inc esi
    jmp scan
none:
    xor eax, eax
    ret
Pipe_FindCharUnquoted ENDP

; Parses a redirection operator in a command string.
; If found, splits the string and returns filename pointer in EAX; also sets *pAppend (0/1).
; Only supports first occurrence.
Pipe_ParseOutputRedir PROC USES esi edi ebx, pCmdStr:PTR BYTE, pAppend:PTR DWORD
    mov esi, pCmdStr
    xor ebx, ebx

    ; find '>' unquoted
    INVOKE Pipe_FindCharUnquoted, esi, '>'
    cmp eax, 0
    je  none

    mov edi, eax

    ; check >>
    mov al, [edi+1]
    cmp al, '>'
    jne single

    ; append
    mov DWORD PTR [pAppend], 1
    mov BYTE PTR [edi], 0
    mov BYTE PTR [edi+1], ' '
    lea edi, [edi+2]
    jmp get_name

single:
    mov DWORD PTR [pAppend], 0
    mov BYTE PTR [edi], 0
    lea edi, [edi+1]

get_name:
    INVOKE Pipe_SkipSpaces, edi
    mov edi, eax
    mov al, [edi]
    cmp al, 0
    je  bad

    ; terminate filename at next space
    mov esi, edi
term:
    mov al, [esi]
    cmp al, 0
    je  ok
    cmp al, ' '
    je  z
    cmp al, 9
    je  z
    inc esi
    jmp term
z:
    mov BYTE PTR [esi], 0

ok:
    mov eax, edi
    ret

bad:
    xor eax, eax
    ret

none:
    xor eax, eax
    ret
Pipe_ParseOutputRedir ENDP

; Parses input redirection '<' and returns filename pointer in EAX or 0.
Pipe_ParseInputRedir PROC USES esi edi, pCmdStr:PTR BYTE
    mov esi, pCmdStr

    INVOKE Pipe_FindCharUnquoted, esi, '<'
    cmp eax, 0
    je  none

    mov edi, eax
    mov BYTE PTR [edi], 0
    lea edi, [edi+1]

    INVOKE Pipe_SkipSpaces, edi
    mov edi, eax
    mov al, [edi]
    cmp al, 0
    je  bad

    mov esi, edi
term:
    mov al, [esi]
    cmp al, 0
    je  ok
    cmp al, ' '
    je  z
    cmp al, 9
    je  z
    inc esi
    jmp term
z:
    mov BYTE PTR [esi], 0

ok:
    mov eax, edi
    ret

bad:
    xor eax, eax
    ret

none:
    xor eax, eax
    ret
Pipe_ParseInputRedir ENDP

; Spawns external process with explicit std handles.
; Returns EAX=1 on success and sets *pProcHandle; else EAX=0.
Pipe_SpawnExternal PROC USES esi edi ebx ecx edx,
    pCmdStr:PTR BYTE,
    hIn:DWORD,
    hOut:DWORD,
    hErr:DWORD,
    pProcHandle:PTR DWORD

    LOCAL startupInfo:STARTUPINFOA
    LOCAL pi:PROCESS_INFORMATION

    ; zero structs
    lea edi, startupInfo
    mov ecx, SIZEOF STARTUPINFOA
    xor eax, eax
zs:
    mov BYTE PTR [edi], al
    inc edi
    loop zs

    lea edi, pi
    mov ecx, SIZEOF PROCESS_INFORMATION
zp:
    mov BYTE PTR [edi], al
    inc edi
    loop zp

    mov startupInfo.cb, SIZEOF STARTUPINFOA
    mov startupInfo.dwFlags, STARTF_USESTDHANDLES
    mov eax, hIn
    mov startupInfo.hStdInput, eax
    mov eax, hOut
    mov startupInfo.hStdOutput, eax
    mov eax, hErr
    mov startupInfo.hStdError, eax

    ; copy command line to CmdLineBuf (CreateProcess may modify it)
    INVOKE Str_copy, pCmdStr, ADDR CmdLineBuf

    INVOKE CreateProcessA,
        NULL,
        ADDR CmdLineBuf,
        NULL,
        NULL,
        TRUE,
        0,
        NULL,
        NULL,
        ADDR startupInfo,
        ADDR pi

    cmp eax, 0
    jne ok

    xor eax, eax
    ret

ok:
    ; return process handle to caller
    mov ebx, pProcHandle
    mov eax, pi.hProcess
    mov [ebx], eax

    ; close thread handle in parent
    INVOKE CloseHandle, pi.hThread

    mov eax, 1
    ret
Pipe_SpawnExternal ENDP

; Runs already-parsed gCmd as a built-in with temporary std-handle redirection.
; Returns EAX = gLastExitCode.
Pipe_RunBuiltinWithHandles PROC USES eax,
    hIn:DWORD,
    hOut:DWORD,
    hErr:DWORD

    LOCAL oldIn:DWORD
    LOCAL oldOut:DWORD
    LOCAL oldErr:DWORD

    INVOKE GetStdHandle, STD_INPUT_HANDLE
    mov oldIn, eax
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov oldOut, eax
    INVOKE GetStdHandle, STD_ERROR_HANDLE
    mov oldErr, eax

    INVOKE SetStdHandle, STD_INPUT_HANDLE, hIn
    INVOKE SetStdHandle, STD_OUTPUT_HANDLE, hOut
    INVOKE SetStdHandle, STD_ERROR_HANDLE, hErr

    INVOKE Builtins_TryExecute, ADDR gCmd

    INVOKE SetStdHandle, STD_INPUT_HANDLE, oldIn
    INVOKE SetStdHandle, STD_OUTPUT_HANDLE, oldOut
    INVOKE SetStdHandle, STD_ERROR_HANDLE, oldErr

    mov eax, gLastExitCode
    ret
Pipe_RunBuiltinWithHandles ENDP

; Executes one pipeline segment (no && / || splitting).
; Input: pSeg points to modifiable string.
; Returns exit code in EAX and sets gLastExitCode.
Pipe_ExecuteSegment PROC USES esi edi ebx ecx edx, pSeg:PTR BYTE
    LOCAL stagePtrs[16]:DWORD
    LOCAL stageCount:DWORD
    LOCAL iStage:DWORD
    LOCAL hIn:DWORD
    LOCAL hOut:DWORD
    LOCAL hErr:DWORD
    LOCAL hRead:DWORD
    LOCAL hWrite:DWORD
    LOCAL sa:SECURITY_ATTRIBUTES
    LOCAL appendFlag:DWORD
    LOCAL pInFile:DWORD
    LOCAL pOutFile:DWORD
    LOCAL isBackground:DWORD
    LOCAL procHandles[16]:DWORD
    LOCAL procCount:DWORD
    LOCAL lastExit:DWORD
    LOCAL hProc:DWORD

    mov stageCount, 0
    mov procCount, 0
    mov lastExit, 0
    mov isBackground, 0
    mov pInFile, 0
    mov pOutFile, 0
    mov appendFlag, 0

    ; trim right and detect trailing '&'
    INVOKE Pipe_TrimRight, pSeg
    mov esi, eax

    INVOKE StrLen, esi
    mov ecx, eax
    cmp ecx, 0
    je  done

    dec ecx
    mov al, [esi+ecx]
    cmp al, '&'
    jne split_pipe

    mov BYTE PTR [esi+ecx], 0
    mov isBackground, 1
    INVOKE Pipe_TrimRight, esi

split_pipe:
    ; split into stages on '|'
    mov edi, pSeg
    mov eax, stageCount
    mov stagePtrs[eax*4], edi
    inc eax
    mov stageCount, eax

split_loop:
    INVOKE Pipe_FindCharUnquoted, edi, '|'
    cmp eax, 0
    je  after_split

    ; null-terminate stage and add next
    mov BYTE PTR [eax], 0
    lea edi, [eax+1]
    INVOKE Pipe_SkipSpaces, edi
    mov edi, eax

    mov eax, stageCount
    mov stagePtrs[eax*4], edi
    inc eax
    mov stageCount, eax
    jmp split_loop

after_split:
    ; input redirection only in first stage string
    mov esi, stagePtrs[0]
    INVOKE Pipe_ParseInputRedir, esi
    mov pInFile, eax

    ; output redirection only in last stage string
    mov eax, stageCount
    dec eax
    mov esi, stagePtrs[eax*4]
    INVOKE Pipe_ParseOutputRedir, esi, ADDR appendFlag
    mov pOutFile, eax

    ; setup stderr
    INVOKE GetStdHandle, STD_ERROR_HANDLE
    mov hErr, eax

    ; setup initial stdin
    mov eax, pInFile
    cmp eax, 0
    je  use_std_in

    INVOKE CreateFileA, pInFile, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    mov hIn, eax
    cmp eax, INVALID_HANDLE_VALUE
    jne in_ok

    mov edx, OFFSET msgBadRedir
    call WriteString
    mov lastExit, 1
    jmp cleanup

in_ok:
    jmp exec

use_std_in:
    INVOKE GetStdHandle, STD_INPUT_HANDLE
    mov hIn, eax

exec:
    ; security attributes for inheritable handles
    mov sa.nLength, SIZEOF SECURITY_ATTRIBUTES
    mov sa.lpSecurityDescriptor, NULL
    mov sa.bInheritHandle, TRUE

    mov iStage, 0
stage_loop:
    mov eax, iStage
    cmp eax, stageCount
    jae wait_or_return

    ; determine stdout for this stage
    mov eax, iStage
    mov ecx, stageCount
    dec ecx
    cmp eax, ecx
    jne make_pipe

    ; last stage
    mov eax, pOutFile
    cmp eax, 0
    je  use_std_out

    ; open output file
    cmp appendFlag, 0
    je  open_overwrite

    ; append: OPEN_ALWAYS then seek end
    INVOKE CreateFileA, pOutFile, GENERIC_WRITE, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp eax, INVALID_HANDLE_VALUE
    jne app_ok
    ; if not exist, create
    INVOKE CreateFileA, pOutFile, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
app_ok:
    mov hOut, eax
    cmp eax, INVALID_HANDLE_VALUE
    jne seek_end

    mov edx, OFFSET msgBadRedir
    call WriteString
    mov lastExit, 1
    jmp cleanup

seek_end:
    INVOKE SetFilePointer, hOut, 0, NULL, FILE_END
    jmp spawn

open_overwrite:
    INVOKE CreateFileA, pOutFile, GENERIC_WRITE, FILE_SHARE_READ, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    mov hOut, eax
    cmp eax, INVALID_HANDLE_VALUE
    jne spawn

    mov edx, OFFSET msgBadRedir
    call WriteString
    mov lastExit, 1
    jmp cleanup

use_std_out:
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov hOut, eax
    jmp spawn

make_pipe:
    INVOKE CreatePipe, ADDR hRead, ADDR hWrite, ADDR sa, 0
    cmp eax, 0
    jne pipe_ok

    mov edx, OFFSET msgExecFail
    call WriteString
    mov lastExit, 1
    jmp cleanup

pipe_ok:
    ; ensure current child doesn't inherit read end
    INVOKE SetHandleInformation, hRead, HANDLE_FLAG_INHERIT, 0
    mov eax, hWrite
    mov hOut, eax

spawn:
    ; trim stage command
    mov eax, iStage
    mov esi, stagePtrs[eax*4]
    INVOKE Pipe_SkipSpaces, esi
    mov esi, eax
    INVOKE Pipe_TrimRight, esi

    ; copy stage into StageBuf for built-in detection
    INVOKE Str_copy, esi, ADDR StageBuf
    INVOKE Parser_ParseLine, ADDR StageBuf, ADDR gCmd

    ; built-in?
    INVOKE Builtins_IsBuiltin, ADDR gCmd
    cmp eax, 1
    jne spawn_external

    INVOKE Pipe_RunBuiltinWithHandles, hIn, hOut, hErr
    mov lastExit, eax
    jmp stage_done

spawn_external:
    ; external
    INVOKE Pipe_SpawnExternal, esi, hIn, hOut, hErr, ADDR hProc
    cmp eax, 1
    jne ext_fail

    mov eax, procCount
    mov edx, hProc
    mov procHandles[eax*4], edx
    inc eax
    mov procCount, eax

    jmp stage_done

ext_fail:
    mov edx, OFFSET msgExecFail
    call WriteString
    mov lastExit, 1
    jmp cleanup

stage_done:
    ; parent cleanup for this stage
    ; close output file handle if last stage output redirection
    mov eax, iStage
    mov ecx, stageCount
    dec ecx
    cmp eax, ecx
    jne close_pipe

    ; last stage: if output was file, close it
    mov eax, pOutFile
    cmp eax, 0
    je  after_close
    INVOKE CloseHandle, hOut
    jmp after_close

close_pipe:
    ; close write end
    INVOKE CloseHandle, hOut

    ; prepare stdin for next stage = read end
    ; make read end inheritable for next child
    INVOKE SetHandleInformation, hRead, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT

    ; close previous stdin if it was a pipe/file (not std)
    ; if input redirection file: close after first stage done
    mov eax, iStage
    cmp eax, 0
    jne maybe_close_in

    mov eax, pInFile
    cmp eax, 0
    je  skip_close_in0
    INVOKE CloseHandle, hIn
skip_close_in0:

maybe_close_in:
    ; if hIn is a pipe from previous stage, close it now (we keep only current)
    ; Parent must close previous read end after assigning next.

    mov eax, hRead
    mov hIn, eax

after_close:
    ; next stage
    mov eax, iStage
    inc eax
    mov iStage, eax
    jmp stage_loop

wait_or_return:
    cmp isBackground, 1
    je  bg_return

    ; wait on spawned external processes, get last exit from last process
    mov ecx, procCount
    cmp ecx, 0
    je  done

    xor ebx, ebx
wait_loop:
    mov eax, procHandles[ebx*4]
    INVOKE WaitForSingleObject, eax, INFINITE

    ; last process?
    mov edx, ebx
    inc edx
    cmp edx, procCount
    jne close_only

    INVOKE GetExitCodeProcess, procHandles[ebx*4], ADDR lastExit

close_only:
    INVOKE CloseHandle, procHandles[ebx*4]

    inc ebx
    cmp ebx, procCount
    jb  wait_loop

    jmp done

bg_return:
    ; Close process handles (don't wait)
    mov ecx, procCount
    xor ebx, ebx
bg_close:
    cmp ebx, ecx
    jae done
    INVOKE CloseHandle, procHandles[ebx*4]
    inc ebx
    jmp bg_close

done:
    mov eax, lastExit
    mov gLastExitCode, eax
    ret

cleanup:
    mov eax, lastExit
    mov gLastExitCode, eax
    ret
Pipe_ExecuteSegment ENDP

; Pipeline_TryExecute(pLine)
; Returns EAX=1 if handled.
Pipeline_TryExecute PROC USES esi edi ebx ecx edx, pLine:PTR BYTE
    LOCAL hasOps:DWORD
    LOCAL lastExit:DWORD
    LOCAL segPtrs[16]:DWORD
    LOCAL segOps[16]:DWORD    ; 0=none/first, 1=&&, 2=|| (operator BEFORE this segment)
    LOCAL segCount:DWORD

    mov hasOps, 0
    mov lastExit, 0
    mov segCount, 0

    ; quick scan: only handle when any operator chars present
    mov esi, pLine
scan:
    mov al, [esi]
    cmp al, 0
    je  after_scan
    cmp al, '|'
    je  ops
    cmp al, '>'
    je  ops
    cmp al, '<'
    je  ops
    cmp al, '&'
    je  ops
    inc esi
    jmp scan
ops:
    mov hasOps, 1
after_scan:
    cmp hasOps, 0
    je  not_handled

    ; build segments split on && and || (unquoted)
    mov esi, pLine
    INVOKE Pipe_SkipSpaces, esi
    mov edi, eax
    cmp BYTE PTR [edi], 0
    je  not_handled

    mov eax, segCount
    mov segPtrs[eax*4], edi
    mov segOps[eax*4], 0
    inc eax
    mov segCount, eax

    xor ebx, ebx ; inQuotes
parse_loop:
    mov al, [edi]
    cmp al, 0
    je  exec_all
    cmp al, '"'
    jne chk_and
    xor ebx, 1
    inc edi
    jmp parse_loop

chk_and:
    cmp ebx, 0
    jne adv
    cmp al, '&'
    jne chk_or
    cmp BYTE PTR [edi+1], '&'
    jne adv

    ; terminate previous segment
    mov BYTE PTR [edi], 0
    mov BYTE PTR [edi+1], 0

    lea esi, [edi+2]
    INVOKE Pipe_SkipSpaces, esi
    mov esi, eax
    cmp BYTE PTR [esi], 0
    je  exec_all

    mov eax, segCount
    mov segPtrs[eax*4], esi
    mov segOps[eax*4], 1
    inc eax
    mov segCount, eax

    mov edi, esi
    jmp parse_loop

chk_or:
    cmp al, '|'
    jne adv
    cmp BYTE PTR [edi+1], '|'
    jne adv

    mov BYTE PTR [edi], 0
    mov BYTE PTR [edi+1], 0

    lea esi, [edi+2]
    INVOKE Pipe_SkipSpaces, esi
    mov esi, eax
    cmp BYTE PTR [esi], 0
    je  exec_all

    mov eax, segCount
    mov segPtrs[eax*4], esi
    mov segOps[eax*4], 2
    inc eax
    mov segCount, eax

    mov edi, esi
    jmp parse_loop

adv:
    inc edi
    jmp parse_loop

exec_all:
    xor ecx, ecx
exec_loop:
    cmp ecx, segCount
    jae finished

    ; short-circuit based on operator BEFORE this segment
    cmp ecx, 0
    je  do_exec

    mov eax, segOps[ecx*4]
    cmp eax, 1
    jne chk_sc_or
    cmp lastExit, 0
    jne skip_exec
    jmp do_exec

chk_sc_or:
    cmp eax, 2
    jne do_exec
    cmp lastExit, 0
    je  skip_exec

do_exec:
    mov eax, segPtrs[ecx*4]
    INVOKE Pipe_ExecuteSegment, eax
    mov lastExit, eax

skip_exec:
    inc ecx
    jmp exec_loop

finished:
    mov eax, lastExit
    mov gLastExitCode, eax
    mov eax, 1
    ret

not_handled:
    xor eax, eax
    ret
Pipeline_TryExecute ENDP

END
