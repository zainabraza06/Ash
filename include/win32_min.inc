; win32_min.inc
; Minimal Win32 declarations for a MASM/Irvine32 32-bit project.
; Keep this small and extend only as needed.

option casemap:none

IFNDEF NULL
NULL                        EQU 0
ENDIF
IFNDEF TRUE
TRUE                        EQU 1
ENDIF
IFNDEF FALSE
FALSE                       EQU 0
ENDIF

IFNDEF STARTF_USESTDHANDLES
STARTF_USESTDHANDLES        EQU 00000100h
ENDIF
IFNDEF HANDLE_FLAG_INHERIT
HANDLE_FLAG_INHERIT         EQU 00000001h
ENDIF

IFNDEF GENERIC_READ
GENERIC_READ                EQU 80000000h
ENDIF
IFNDEF GENERIC_WRITE
GENERIC_WRITE               EQU 40000000h
ENDIF
IFNDEF FILE_SHARE_READ
FILE_SHARE_READ             EQU 00000001h
ENDIF
IFNDEF FILE_SHARE_WRITE
FILE_SHARE_WRITE            EQU 00000002h
ENDIF
IFNDEF OPEN_EXISTING
OPEN_EXISTING               EQU 3
ENDIF
IFNDEF CREATE_ALWAYS
CREATE_ALWAYS               EQU 2
ENDIF
IFNDEF FILE_ATTRIBUTE_NORMAL
FILE_ATTRIBUTE_NORMAL       EQU 00000080h
ENDIF
IFNDEF FILE_ATTRIBUTE_DIRECTORY
FILE_ATTRIBUTE_DIRECTORY    EQU 00000010h
ENDIF

IFNDEF INVALID_HANDLE_VALUE
INVALID_HANDLE_VALUE        EQU 0FFFFFFFFh
ENDIF

IFNDEF STD_INPUT_HANDLE
STD_INPUT_HANDLE            EQU -10
ENDIF
IFNDEF STD_OUTPUT_HANDLE
STD_OUTPUT_HANDLE           EQU -11
ENDIF
IFNDEF STD_ERROR_HANDLE
STD_ERROR_HANDLE            EQU -12
ENDIF

IFNDEF INFINITE
INFINITE                   EQU 0FFFFFFFFh
ENDIF

; For SetFilePointer
IFNDEF FILE_BEGIN
FILE_BEGIN                  EQU 0
ENDIF
IFNDEF FILE_CURRENT
FILE_CURRENT                EQU 1
ENDIF
IFNDEF FILE_END
FILE_END                    EQU 2
ENDIF

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

OSVERSIONINFOA STRUCT
  dwOSVersionInfoSize DWORD ?
  dwMajorVersion      DWORD ?
  dwMinorVersion      DWORD ?
  dwBuildNumber       DWORD ?
  dwPlatformId        DWORD ?
  szCSDVersion        BYTE 128 DUP(?)
OSVERSIONINFOA ENDS

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

GetCommandLineA PROTO STDCALL
ExitProcess PROTO STDCALL, uExitCode:DWORD

GetVersionExA PROTO STDCALL, lpVersionInformation:PTR OSVERSIONINFOA

wsprintfA PROTO C :PTR BYTE, :PTR BYTE, :VARARG
