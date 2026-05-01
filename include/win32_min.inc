; win32_min.inc
; Minimal Win32 declarations for a MASM/Irvine32 32-bit project.
; Keep this small and extend only as needed.

option casemap:none

NULL                        EQU 0
TRUE                        EQU 1
FALSE                       EQU 0

STARTF_USESTDHANDLES        EQU 00000100h
HANDLE_FLAG_INHERIT         EQU 00000001h

GENERIC_READ                EQU 80000000h
GENERIC_WRITE               EQU 40000000h
FILE_SHARE_READ             EQU 00000001h
FILE_SHARE_WRITE            EQU 00000002h
OPEN_EXISTING               EQU 3
CREATE_ALWAYS               EQU 2
FILE_ATTRIBUTE_NORMAL       EQU 00000080h

STD_INPUT_HANDLE            EQU -10
STD_OUTPUT_HANDLE           EQU -11
STD_ERROR_HANDLE            EQU -12

INFINITE                   EQU 0FFFFFFFFh

; --- Structs ---
SECURITY_ATTRIBUTES STRUCT
  nLength              DWORD ?
  lpSecurityDescriptor DWORD ?
  bInheritHandle       DWORD ?
SECURITY_ATTRIBUTES ENDS

PROCESS_INFORMATION STRUCT
  hProcess DWORD ?
  hThread  DWORD ?
  dwProcessId DWORD ?
  dwThreadId  DWORD ?
PROCESS_INFORMATION ENDS

STARTUPINFOA STRUCT
  cb              DWORD ?
  lpReserved      DWORD ?
  lpDesktop       DWORD ?
  lpTitle         DWORD ?
  dwX             DWORD ?
  dwY             DWORD ?
  dwXSize         DWORD ?
  dwYSize         DWORD ?
  dwXCountChars   DWORD ?
  dwYCountChars   DWORD ?
  dwFillAttribute DWORD ?
  dwFlags         DWORD ?
  wShowWindow     WORD  ?
  cbReserved2     WORD  ?
  lpReserved2     DWORD ?
  hStdInput       DWORD ?
  hStdOutput      DWORD ?
  hStdError       DWORD ?
STARTUPINFOA ENDS

; --- Win32 API prototypes (stdcall) ---

GetLastError PROTO STDCALL
CloseHandle  PROTO STDCALL, hObject:DWORD

GetCurrentDirectoryA PROTO STDCALL, nBufferLength:DWORD, lpBuffer:PTR BYTE
SetCurrentDirectoryA PROTO STDCALL, lpPathName:PTR BYTE

CreateProcessA PROTO STDCALL,
  lpApplicationName:DWORD,
  lpCommandLine:PTR BYTE,
  lpProcessAttributes:DWORD,
  lpThreadAttributes:DWORD,
  bInheritHandles:DWORD,
  dwCreationFlags:DWORD,
  lpEnvironment:DWORD,
  lpCurrentDirectory:DWORD,
  lpStartupInfo:PTR STARTUPINFOA,
  lpProcessInformation:PTR PROCESS_INFORMATION

WaitForSingleObject PROTO STDCALL, hHandle:DWORD, dwMilliseconds:DWORD
GetExitCodeProcess  PROTO STDCALL, hProcess:DWORD, lpExitCode:PTR DWORD

CreatePipe PROTO STDCALL, phReadPipe:PTR DWORD, phWritePipe:PTR DWORD, lpPipeAttributes:PTR SECURITY_ATTRIBUTES, nSize:DWORD
SetHandleInformation PROTO STDCALL, hObject:DWORD, dwMask:DWORD, dwFlags:DWORD

GetEnvironmentVariableA PROTO STDCALL, lpName:PTR BYTE, lpBuffer:PTR BYTE, nSize:DWORD
SetEnvironmentVariableA PROTO STDCALL, lpName:PTR BYTE, lpValue:PTR BYTE

CreateFileA PROTO STDCALL,
  lpFileName:PTR BYTE,
  dwDesiredAccess:DWORD,
  dwShareMode:DWORD,
  lpSecurityAttributes:DWORD,
  dwCreationDisposition:DWORD,
  dwFlagsAndAttributes:DWORD,
  hTemplateFile:DWORD

ReadFile PROTO STDCALL, hFile:DWORD, lpBuffer:PTR BYTE, nNumberOfBytesToRead:DWORD, lpNumberOfBytesRead:PTR DWORD, lpOverlapped:DWORD
WriteFile PROTO STDCALL, hFile:DWORD, lpBuffer:PTR BYTE, nNumberOfBytesToWrite:DWORD, lpNumberOfBytesWritten:PTR DWORD, lpOverlapped:DWORD

GetStdHandle PROTO STDCALL, nStdHandle:DWORD
SetStdHandle PROTO STDCALL, nStdHandle:DWORD, hHandle:DWORD
