; axs.inc
; Shared constants, data structures, and module APIs for AXS.

option casemap:none

INCLUDE win32_min.inc

; --- Limits (tune as needed) ---
MAX_LINE            EQU 512
MAX_TOKENS          EQU 32
HISTORY_SIZE        EQU 10
MAX_ENV_VARS        EQU 32
MAX_ENV_NAME        EQU 32
MAX_ENV_VALUE       EQU 256

; --- Command structure (in-place tokenization) ---
COMMAND STRUCT
  argc DWORD ?
  argv DWORD MAX_TOKENS DUP(?)   ; pointers to 0-terminated tokens inside line buffer
COMMAND ENDS

; --- Parse/dispatch flags (future use) ---
CMD_FLAG_NONE       EQU 0

; --- Module APIs ---

; utils.asm
StrSkipSpaces       PROTO, pStr:PTR BYTE
StrStartsWithI      PROTO, pStr:PTR BYTE, pPrefix:PTR BYTE
StrEqI              PROTO, pA:PTR BYTE, pB:PTR BYTE
StrToLowerInPlace   PROTO, pStr:PTR BYTE
StrLen              PROTO, pStr:PTR BYTE

; parser.asm
Parser_Init         PROTO
Parser_ParseLine    PROTO, pLine:PTR BYTE, pCmd:PTR COMMAND

; builtins.asm
Builtins_Init       PROTO
Builtins_TryExecute PROTO, pCmd:PTR COMMAND

; external.asm
External_Init       PROTO
External_Execute    PROTO, pCmd:PTR COMMAND

; pipeline.asm (advanced)
Pipeline_Init       PROTO
Pipeline_TryExecute PROTO, pLine:PTR BYTE

; env.asm
Env_Init            PROTO
Env_ExpandPercentVars PROTO, pLine:PTR BYTE, cbLine:DWORD
Env_SetFromCommand  PROTO, pCmd:PTR COMMAND
Env_PrintAll        PROTO

; history.asm
History_Init        PROTO
History_Add         PROTO, pLine:PTR BYTE
History_HandleKey   PROTO

; script.asm
Script_Init         PROTO
Script_RunFile      PROTO, pFile:PTR BYTE

; --- Shared globals (defined in main.asm) ---
EXTERN gLineBuf:BYTE
EXTERN gCmd:COMMAND
EXTERN gShouldExit:DWORD
