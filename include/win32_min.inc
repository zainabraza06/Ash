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
FILE_ATTRIBUTE_DIRECTORY    EQU 00000010h

INVALID_HANDLE_VALUE        EQU 0FFFFFFFFh

STD_INPUT_HANDLE            EQU -10
STD_OUTPUT_HANDLE           EQU -11
STD_ERROR_HANDLE            EQU -12

INFINITE                   EQU 0FFFFFFFFh

; For SetFilePointer
FILE_BEGIN                  EQU 0
FILE_CURRENT                EQU 1
FILE_END                    EQU 2

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

WIN32_FIND_DATAA STRUCT
  dwFileAttributes DWORD ?
  ftCreationTime   QWORD ?
  ftLastAccessTime QWORD ?
  ftLastWriteTime  QWORD ?
  nFileSizeHigh    DWORD ?
  nFileSizeLow     DWORD ?
  dwReserved0      DWORD ?
  dwReserved1      DWORD ?
  cFileName        BYTE 260 DUP(?)
  cAlternateFileName BYTE 14 DUP(?)
WIN32_FIND_DATAA ENDS

; --- Win32 API prototypes (stdcall) ---

GetLastError PROTO STDCALL
CloseHandle  PROTO STDCALL, hObject:DWORD

GetEnvironmentStringsA PROTO STDCALL
FreeEnvironmentStringsA PROTO, lpszEnvironmentBlock:PTR BYTE

GetCurrentDirectoryA PROTO, nBufferLength:DWORD, lpBuffer:PTR BYTE
SetCurrentDirectoryA PROTO, lpPathName:PTR BYTE

CreateProcessA PROTO,
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

WaitForSingleObject PROTO, hHandle:DWORD, dwMilliseconds:DWORD
GetExitCodeProcess  PROTO, hProcess:DWORD, lpExitCode:PTR DWORD

CreatePipe PROTO, phReadPipe:PTR DWORD, phWritePipe:PTR DWORD, lpPipeAttributes:PTR SECURITY_ATTRIBUTES, nSize:DWORD
SetHandleInformation PROTO, hObject:DWORD, dwMask:DWORD, dwFlags:DWORD

GetEnvironmentVariableA PROTO, lpName:PTR BYTE, lpBuffer:PTR BYTE, nSize:DWORD
SetEnvironmentVariableA PROTO, lpName:PTR BYTE, lpValue:PTR BYTE

CreateFileA PROTO,
  lpFileName:PTR BYTE,
  dwDesiredAccess:DWORD,
  dwShareMode:DWORD,
  lpSecurityAttributes:DWORD,
  dwCreationDisposition:DWORD,
  dwFlagsAndAttributes:DWORD,
  hTemplateFile:DWORD

DeleteFileA PROTO, lpFileName:PTR BYTE
CopyFileA   PROTO, lpExisting:PTR BYTE, lpNew:PTR BYTE, bFailIfExists:DWORD
MoveFileA   PROTO, lpExisting:PTR BYTE, lpNew:PTR BYTE
CreateDirectoryA PROTO, lpPathName:PTR BYTE, lpSecurityAttributes:DWORD
RemoveDirectoryA PROTO, lpPathName:PTR BYTE

FindFirstFileA PROTO, lpFileName:PTR BYTE, lpFindFileData:PTR WIN32_FIND_DATAA
FindNextFileA  PROTO, hFindFile:DWORD, lpFindFileData:PTR WIN32_FIND_DATAA
FindClose      PROTO, hFindFile:DWORD

GetStdHandle PROTO, nStdHandle:DWORD
SetStdHandle PROTO, nStdHandle:DWORD, hHandle:DWORD
