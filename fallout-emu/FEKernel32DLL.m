//
//  FEKernel32DLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 08/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEKernel32DLL.h"
#include "FEThreadContext.h"
#include "FEMemoryMap.h"
#import "FEStack.h"
#import "FEProcess.h"

#import "FETime.h"
#import "FENLS.h"

#import "NSString+FE.h"

#include <sys/time.h>
#include <mach/mach_time.h>

// stdcall calling convention
// callee cleans up the stack

@interface FEKernel32DLL()


- (uint32_t) createModuleWithName:(NSString*) dllName;
- (uint32_t) createMutexWithName:(NSString*)name;
- (uint32_t) createFileHandleFromFile:(FILE*) file path:(NSString*) path;

@end

// stdcall
// The stdcall calling convention is a variation on the Pascal calling convention in which the callee is responsible for cleaning up the stack, but the
// parameters are pushed onto the stack in right-to-left order, as in the _cdecl calling convention. Registers EAX, ECX, and EDX are designated for use
// within the function. Return values are stored in the EAX register.
// stdcall is the standard calling convention for the Microsoft Win32 API and for Open Watcom C++.

static uint8_t fe_GetModuleHandleA(FEProcess *process) {
    //LPCTSTR lpModuleName
    
    // skipping 4 bytes of ret address
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t lpModuleNameAddr = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
#pragma unused(lpModuleNameAddr)
    assert(lpModuleNameAddr == 0);
    //NSLog(@"%s",[process.memory localAddressFromVirtualAddress:lpModuleNameAddr size:1 access:kFEMemoryAccessMode_Read]);
    process.currentThread->eax = 0xaabbcc;
    
    // bytes to pop after ret. size of arguments on stack
    return 4;
}

static uint8_t fe_GetCurrentThreadId(FEProcess *process) {
    process.currentThread->eax = process.currentThread->threadId;
    return 0;
}

static uint8_t fe_GetStdHandle(FEProcess *process) {
    /*
     HANDLE WINAPI GetStdHandle(
     _In_  DWORD nStdHandle
     );
     */
    // db dw dd
    // define byte
    // define word
    
    // define double word
    uint32_t ptrToArgs = process.currentThread->esp+4;
    int32_t nStdHandle = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    
    static const int32_t STD_INPUT_HANDLE  = -10;
    static const int32_t STD_OUTPUT_HANDLE = -11;
    static const int32_t STD_ERROR_HANDLE  = -12;
    
    switch(nStdHandle) {
        case STD_INPUT_HANDLE:
            process.currentThread->eax = 0;;
            break;
        case STD_OUTPUT_HANDLE:
            process.currentThread->eax = 0;;
            break;
        case STD_ERROR_HANDLE:
            process.currentThread->eax = 0;;
            break;
        default:
            process.currentThread->eax = 0;;
    }
    
    return 4;
}

/*
 void WINAPI GetSystemTimeAsFileTime(
 _Out_  LPFILETIME lpSystemTimeAsFileTime
 );

 */
static uint8_t fe_GetSystemTimeAsFileTime(FEProcess *process) {

    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_systemTime = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    FILETIME systemTime;
    LPFILETIME pSystemTime = &systemTime;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory,&systemTime,arg_systemTime,sizeof(FILETIME));
    
    struct timeval now;
    
    gettimeofday(&now, 0);
    uint64_t ticks = now.tv_sec * (uint64_t)TICKSPERSEC + TICKS_1601_TO_1970 + now.tv_usec * 10;
    
    pSystemTime->dwLowDateTime = ticks & 0xffff;
    pSystemTime->dwHighDateTime = (ticks >> 16) & 0xffff;
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,arg_systemTime,pSystemTime,sizeof(FILETIME));
    
    return 4;
}

static uint8_t fe_GetCurrentProcessId(FEProcess *process) {
    process.currentThread->eax = 1;
    return 0;
}

static uint8_t fe_GetTickCount(FEProcess *process) {
    const int64_t kOneMillion = 1000 * 1000;
    static mach_timebase_info_data_t s_timebase_info;
    
    if (s_timebase_info.denom == 0) {
        (void) mach_timebase_info(&s_timebase_info);
    }
    
    // mach_absolute_time() returns billionth of seconds,
    // so divide by one million to get milliseconds
    uint32_t result = (uint32_t)((mach_absolute_time() * s_timebase_info.numer) / (kOneMillion * s_timebase_info.denom));
    
    process.currentThread->eax = result;
    
    if(process.logExternalCalls) {
        printf("%u\n", result);
    }
    
    return 0;
}

/*
 BOOL WINAPI QueryPerformanceCounter(
 _Out_  LARGE_INTEGER *lpPerformanceCount
 );
 */
static uint8_t fe_QueryPerformanceCounter(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_performanceCount = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint64_t outPerformanceCount;
    
    fe_memoryMap_memcpyToRealFromVirtual(process.memory,&outPerformanceCount,arg_performanceCount,8);
    
    outPerformanceCount = 31337;
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,arg_performanceCount,&outPerformanceCount,8);
    
    process.currentThread->eax = 1;
    return 0;
}

/*
 LPVOID WINAPI VirtualAlloc(
 _In_opt_  LPVOID lpAddress,
 _In_      SIZE_T dwSize,
 _In_      DWORD flAllocationType,
 _In_      DWORD flProtect
 );

 */
static uint8_t fe_VirtualAlloc(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t lpAddress = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t dwSize = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t flAllocationType = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t flProtect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
#pragma unused(lpAddress)
#pragma unused(flAllocationType)
#pragma unused(flProtect)
    
    assert(lpAddress == 0);
    assert(flProtect == 0x40);
    assert(flAllocationType == 0x1000);
    assert(dwSize != 0);
    
    NSString* tag = [NSString stringWithFormat:@"VirtualAlloc from 0x%x",process.currentThread->eip];
    uint32_t allocatedMemory = 0;
    static uint32_t calls = 0;
    if(calls != 0) {
                 allocatedMemory =       fe_memoryMap_malloc(process.memory, dwSize, kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write,[ tag cStringUsingEncoding: NSASCIIStringEncoding]);
    } else {
        void* amem = malloc(dwSize);
        
        FEMemoryMapBlock *block = fe_memoryMapBlock_create([tag cStringUsingEncoding: NSASCIIStringEncoding]);
        block->localAddress = amem;
        block->virtualAddress = 0x3f0000;
        block->size = dwSize;
        block->end = block->virtualAddress + block->size;
        block->freeWhenDone = 1;

        fe_memoryMap_map(process.memory, block,kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write);
        
        allocatedMemory = 0x3f0000;
    }
    calls++;
    
    process.currentThread->eax = allocatedMemory;
    
    return 16;
}

static uint8_t fe_GetEnvironmentStrings(FEProcess *process) {
    NSString* tag = [NSString stringWithFormat:@"GetEnvironmentStrings from 0x%x",process.currentThread->eip];
    
    NSString* env = @"=::=::\\\0"
    "ALLUSERSPROFILE=C:\\Documents and Settings\\All Users\0"
    "APPDATA=C:\\Documents and Settings\\smirn0v\\Application Data\0"
    "CLIENTNAME=Console\0"
    "CommonProgramFiles=C:\\Program Files\\Common Files\0"
    "COMPUTERNAME=HOME-0C4A91F82E\0"
    "ComSpec=C:\\WINDOWS\\system32\\cmd.exe\0"
    "EDPATH=C:\\WATCOM\\EDDAT\0"
    "FP_NO_HOST_CHECK=NO\0"
    "HOMEDRIVE=C:\0"
    "HOMEPATH=\\Documents and Settings\\smirn0v\0"
    "INCLUDE=C:\\WATCOM\\H;C:\\WATCOM\\H\\NT;C:\\WATCOM\\H\\NT\\DIRECTX;C:\\WATCOM\\H\\NT\\DDK\0"
    "LOGONSERVER=\\\\HOME-0C4A91F82E\0"
    "NUMBER_OF_PROCESSORS=1\0"
    "OS=Windows_NT\0"
    "Path=C:\\WATCOM\\BINNT;C:\\WATCOM\\BINW;C:\\WINDOWS\\system32;C:\\WINDOWS;C:\\WINDOWS\\System32\\Wbem\0"
    "PATHEXT=.COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH\0"
    "PROCESSOR_ARCHITECTURE=x86\0"
    "PROCESSOR_IDENTIFIER=x86 Family 6 Model 58 Stepping 9, GenuineIntel\0"
    "PROCESSOR_LEVEL=6\0"
    "PROCESSOR_REVISION=3a09\0"
    "ProgramFiles=C:\\Program Files\0"
    "SESSIONNAME=Console\0"
    "SystemDrive=C:\0"
    "SystemRoot=C:\\WINDOWS\0"
    "TEMP=C:\\DOCUME~1\\smirn0v\\LOCALS~1\\Temp\0"
    "TMP=C:\\DOCUME~1\\smirn0v\\LOCALS~1\\Temp\0"
    "USERDOMAIN=HOME-0C4A91F82E\0"
    "USERNAME=smirn0v\0"
    "USERPROFILE=C:\\Documents and Settings\\smirn0v\0"
    "VS100COMNTOOLS=C:\\Program Files\\Microsoft Visual Studio 10.0\\Common7\\Tools\\\0"
    "WATCOM=C:\\WATCOM\0"
    "WHTMLHELP=C:\\WATCOM\\BINNT\\HELP\0"
    "windir=C:\\WINDOWS\0"
    "WIPFC=C:\\WATCOM\\WIPFC\0\0";
    
    uint32_t allocatedMemory = fe_memoryMap_malloc(process.memory, (uint32_t)env.length, kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write,[ tag cStringUsingEncoding: NSASCIIStringEncoding]);

    fe_memoryMap_memcpyToVirtualFromReal(process.memory, allocatedMemory, (char*)[env cStringUsingEncoding: NSASCIIStringEncoding], (uint32_t)env.length);
    
    process.currentThread->eax = allocatedMemory;
    return 0;
}

/*
 DWORD GetModuleFileNameA
 (
 HMODULE hModule,
 LPSTR   lpFileName,
 DWORD   size
 )
 */
static uint8_t fe_GetModuleFileNameA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_module = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_fileName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_size = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
#pragma unused(arg_module)
    
    assert(arg_module == 0);
    assert(arg_size >= process.path.length+1);
    
    fe_memoryMap_strncpyFromRealToVirtual(process.memory, arg_fileName, (char*)[process.path cStringUsingEncoding: NSASCIIStringEncoding], arg_size);
    
    process.currentThread->eax = (uint32_t)process.path.length;
    
    return 12;
}

// LPTSTR WINAPI GetCommandLine(void);
static uint8_t fe_GetCommandLineA(FEProcess *process) {
    
    NSString* tag = [NSString stringWithFormat:@"GetCommandLine from 0x%x",process.currentThread->eip];
    NSString* quotedPath = [NSString stringWithFormat:@"\"%@\"",process.path];
    uint32_t allocatedMemory = fe_memoryMap_malloc(process.memory, (uint32_t)quotedPath.length + 1, kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write,[ tag cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_strncpyFromRealToVirtual(process.memory, allocatedMemory, (char*)[quotedPath cStringUsingEncoding: NSASCIIStringEncoding], (uint32_t)quotedPath.length+1);
    
    
    process.currentThread->eax = allocatedMemory;
    
    return 0;
}

// DWORD WINAPI GetVersion(void);
static uint8_t fe_GetVersion(FEProcess *process) {
    process.currentThread->eax = 0xa280105;
    return 0;
}

/*
 BOOL GetCPInfo
 (
 UINT     codepage,
 LPCPINFO cpinfo
 )
 */

/*
 typedef struct
  {
      UINT MaxCharSize;
      BYTE DefaultChar[2];
      BYTE LeadByte[12];
} CPINFO, *LPCPINFO;
 */
static uint8_t fe_GetCPInfo(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_codepage = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_cpinfo = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(arg_codepage)
    
    if(arg_cpinfo == 0) {
        process.currentThread->eax = 0;;
        goto fe_GetCPInfo_exit;
    }
    
    assert(arg_codepage == CP_OEMCP);

    CPINFO cpinfo;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory,&cpinfo,arg_cpinfo,sizeof(CPINFO));


    LPCPINFO p_cpinfo = &cpinfo;
    
    p_cpinfo->MaxCharSize = 1;
    p_cpinfo->DefaultChar[0] = 0x3f;//'?'
    p_cpinfo->DefaultChar[1] = 0;
    memset(p_cpinfo->LeadByte, 0, sizeof(p_cpinfo->LeadByte));
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,arg_cpinfo,&cpinfo,sizeof(CPINFO));
    
fe_GetCPInfo_exit:
    return 8;
}

/*
 HANDLE WINAPI CreateMutex(
 _In_opt_  LPSECURITY_ATTRIBUTES lpMutexAttributes,
 _In_      BOOL bInitialOwner,
 _In_opt_  LPCTSTR lpName
 );
 */
static uint8_t fe_CreateMutexA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpMutexAttributes = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    //    uint32_t bInitialOwner = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lpName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
#pragma unused(arg_lpMutexAttributes)
    
    assert(arg_lpMutexAttributes == 0);
    //assert(bInitialOwner == 1);
    
    char *name ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&name , arg_lpName);
    NSString* mutexName = [NSString stringWithCString: name encoding: NSASCIIStringEncoding];
    free(name);
    
    assert(mutexName);
    
    if(process.logExternalCalls) {
        printf("mutex: %s\n", [mutexName cStringUsingEncoding: NSASCIIStringEncoding]);
    }
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    uint32_t handle = [kernel32 createMutexWithName: mutexName];
    
    process.currentThread->eax = handle;
    
    return 12;
}

// DWORD WINAPI GetLastError(void);
static uint8_t fe_GetLastError(FEProcess *process) {
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    process.currentThread->eax = kernel32.lastError;
    
    if(process.logExternalCalls) {
        printf("code: %d\n",kernel32.lastError);
    }
    
    return 0;
}


/*
 BOOL WINAPI GetVersionEx(
 _Inout_  LPOSVERSIONINFO lpVersionInfo
 );
 */
static uint8_t fe_GetVersionExA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_lpVersionInfo = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    
    OSVERSIONINFO versionInfo;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory,&versionInfo,arg_lpVersionInfo,sizeof(OSVERSIONINFO));
    
    
    assert(versionInfo.dwOSVersionInfoSize == 148);
    assert(versionInfo.dwOSVersionInfoSize == sizeof(OSVERSIONINFO));
    
    // windows xp sp3
    versionInfo.dwMajorVersion = 5;
    versionInfo.dwMinorVersion = 1;
    versionInfo.dwBuildNumber = 0xa28;
    versionInfo.dwPlatformId = 2;
    strcpy(versionInfo.szCSDVersion,"Service Pack 3");
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,arg_lpVersionInfo,&versionInfo,sizeof(OSVERSIONINFO));
    
    return 4;
}

/*
 HMODULE LoadLibraryA
 (
 LPCSTR libname
 )
 */
static uint8_t fe_LoadLibraryA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_libname = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    char *libnamec ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&libnamec , arg_libname);
    NSString *dllName = [NSString stringWithCString: libnamec encoding: NSASCIIStringEncoding].lowercaseString;
    free(libnamec);
    assert(dllName);
    [process.importsProxy loadLibraryNamed: dllName];
    if(process.logExternalCalls) {
        printf("library: %s\n", [dllName cStringUsingEncoding: NSASCIIStringEncoding]);
    }
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    uint32_t module = [kernel32 createModuleWithName: dllName];
    
    process.currentThread->eax = module;
    
    return 4;
}


/*
 FARPROC WINAPI GetProcAddress(
 _In_  HMODULE hModule,
 _In_  LPCSTR lpProcName
 );

 */
static uint8_t fe_GetProcAddress(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hModule = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpProcName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
    char *procNameC;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory, &procNameC, arg_lpProcName);

    NSString* funcName = [NSString stringWithCString: procNameC encoding: NSASCIIStringEncoding];
    free(procNameC);
    assert(funcName);
    
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    NSDictionary *details = [kernel32 handleDetails: arg_hModule];
    
    if([details[@"type"] isEqual: @(kFEHandleType_Module)]) {
        NSString *dllName = details[@"name"];
        uint32_t addr = [process.importsProxy addressOfFunction: funcName fromDLL: dllName];
        process.currentThread->eax = addr;
        return 8;
    }
    
    assert(false);
    return 8;
}


#define GENERIC_ALL 0x10000000
#define GENERIC_READ 0x80000000
#define GENERIC_WRITE 0x40000000
#define GENERIC_EXECUTE 0x20000000
/*
 HANDLE WINAPI CreateFile(
 _In_      LPCTSTR lpFileName,
 _In_      DWORD dwDesiredAccess,
 _In_      DWORD dwShareMode,
 _In_opt_  LPSECURITY_ATTRIBUTES lpSecurityAttributes,
 _In_      DWORD dwCreationDisposition,
 _In_      DWORD dwFlagsAndAttributes,
 _In_opt_  HANDLE hTemplateFile
 );

 */
static uint8_t fe_CreateFileA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_fileName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_desiredAccess = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_shareMode = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_securityAttributes = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    //uint32_t arg_creationDisposition = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    uint32_t arg_flagsAndAttributes = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
    uint32_t arg_templateFile = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+24);
   
#pragma unused(arg_shareMode)
#pragma unused(arg_securityAttributes)
#pragma unused(arg_flagsAndAttributes)
#pragma unused(arg_templateFile)
    
    char *fileNamec;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory, &fileNamec, arg_fileName);
    NSString *fileName = [NSString stringWithCString: fileNamec
                                            encoding: NSASCIIStringEncoding];
    
    //    fileName stringByReplacingCharactersInRange:<#(NSRange)#> withString:<#(NSString *)#>
    free(fileNamec);
    assert(fileName);
    
    //assert(arg_desiredAccess == (GENERIC_READ|GENERIC_WRITE));
    assert(arg_shareMode == 3);//read|write share.
    assert(arg_securityAttributes == 0);
    //assert(arg_creationDisposition == 1);
    assert(arg_flagsAndAttributes == 0x80); //no attributes
    assert(arg_templateFile == 0);
    
    
    NSString *path = [fileName fe_win_convertToRealPathWithDiskAtPath: process.diskCPath
                                                          currentPath: process.currentRealPath];
    
    if(process.logExternalCalls) {
        printf("CreateFileA: %s origName: %s\n",[path cStringUsingEncoding: NSASCIIStringEncoding], [fileName cStringUsingEncoding: NSASCIIStringEncoding]);
        
        if(arg_desiredAccess & GENERIC_READ) {
            printf("read\n");
        }
        if(arg_desiredAccess & GENERIC_WRITE) {
            printf("write\n");
        }
        if(arg_desiredAccess & GENERIC_EXECUTE) {
            printf("execute\n");
        }
    }
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    FILE* file = fopen([path cStringUsingEncoding: NSASCIIStringEncoding], "rw");
    
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: path isDirectory: &isDirectory];
    
    if(file && !isDirectory && exists) {
        uint32_t handle = [kernel32 createFileHandleFromFile: file path: path];
        process.currentThread->eax = handle;
    } else {
        if(isDirectory) {
            kernel32.lastError = 5;
        } else if(!exists) {
            kernel32.lastError = 2;
        } else {
            assert(false);
        }
        
        if(process.logExternalCalls) {
            printf("error: %d\n", kernel32.lastError);
        }
        
        process.currentThread->eax = -1;
    }
    
    return 28;
}

// input = handle
static uint8_t fe_GetFileType(FEProcess *process) {
    process.currentThread->eax = 1;//disk file
    return 4;
}

/*
 DWORD WINAPI SetFilePointer(
 _In_         HANDLE hFile,
 _In_         LONG lDistanceToMove,
 _Inout_opt_  PLONG lpDistanceToMoveHigh,
 _In_         DWORD dwMoveMethod
 );
 */
static uint8_t fe_SetFilePointer(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hFile = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_distanceToMove = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_distanceToMoveHigh = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_moveMethod = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
#pragma unused(arg_distanceToMoveHigh)
    
    assert(arg_distanceToMoveHigh == 0);
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    NSDictionary* fileDesc = [[kernel32 handleDetails: arg_hFile] objectForKey: @"payload"];
    
    assert(fileDesc);
    
    NSValue *filePtrValue = fileDesc[@"file"];
    
    FILE* file = filePtrValue.pointerValue;

    if(fseek(file, arg_distanceToMove, arg_moveMethod) == 0) {
        fpos_t position;
        if(fgetpos(file, &position) == 0) {
            process.currentThread->eax = (uint32_t)position;
        } else {
            assert(false);
        }
    } else {
        assert(false);
    }
    
    return 16;
}

/*
 BOOL WINAPI CloseHandle(
 _In_  HANDLE hObject
 );

 */
static uint8_t fe_CloseHandle(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hObject = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    NSDictionary *details = [kernel32 handleDetails: arg_hObject];

    if(process.logExternalCalls) {
        printf("closing: %s\n", [details.description cStringUsingEncoding: NSASCIIStringEncoding]);
    }
    
    switch ([details[@"type"] integerValue]) {
        case kFEHandleType_File: {
            NSValue *filePtrValue = details[@"payload"][@"file"];
            
            assert(filePtrValue);
            
            FILE* file = filePtrValue.pointerValue;
            
            int result = fclose(file);
#pragma unused(result)
            assert(result == 0);

        }
            break;
        case kFEHandleType_Mutex: {
            // no action required
        }
            break;
        default:
            break;
    }
    
    [kernel32 freeHandle: arg_hObject];
    
    process.currentThread->eax = 1;
    
    return 4;
}

/*
 BOOL WINAPI DeleteFile(
 _In_  LPCTSTR lpFileName
 );

 */
static uint8_t fe_DeleteFileA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_fileName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    char *fileNamec;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory, &fileNamec, arg_fileName);
    NSString *fileName = [NSString stringWithCString: fileNamec
                                            encoding: NSASCIIStringEncoding];
    free(fileNamec);
    assert(fileName);
    
    NSString *path = [process.path stringByDeletingLastPathComponent];
    path = [path stringByAppendingPathComponent: fileName];
    
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath: path error: nil];
    
    process.currentThread->eax = success;
    
    return 4;
}

/*
 BOOL WINAPI ReadFile(
 _In_         HANDLE hFile,
 _Out_        LPVOID lpBuffer,
 _In_         DWORD nNumberOfBytesToRead,
 _Out_opt_    LPDWORD lpNumberOfBytesRead,
 _Inout_opt_  LPOVERLAPPED lpOverlapped
 );
 */
static uint8_t fe_ReadFile(FEProcess *process) {

    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hFile = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_pBuffer = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_numberOfBytesToRead = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_numberOfBytesRead = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_overlapped = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    
#pragma unused(arg_overlapped)
    
    assert(arg_overlapped == 0);
    assert(arg_numberOfBytesRead != 0);
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    NSDictionary* fileDesc = [[kernel32 handleDetails: arg_hFile] objectForKey: @"payload"];
    assert(fileDesc);
    NSValue *filePtrValue = fileDesc[@"file"];
    FILE* file = filePtrValue.pointerValue;
    

    void *buffer = malloc(arg_numberOfBytesToRead);
    uint32_t read = (uint32_t)fread(buffer, 1, arg_numberOfBytesToRead, file);
    if(read>0) {
        fe_memoryMap_memcpyToVirtualFromReal(process.memory,arg_pBuffer,buffer,read);
    }
    fe_memoryMap_setValue32(process.memory,arg_numberOfBytesRead,read);
    
    free(buffer);
    
    process.currentThread->eax = 1;
    
    return 20;
}

/*
 DWORD WINAPI GetCurrentDirectory(
 _In_  DWORD  nBufferLength,
 _Out_ LPTSTR lpBuffer
 );

 */
static uint8_t fe_GetCurrentDirectoryA(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_bufferLength = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_buffer = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
    assert(arg_buffer != 0);
    
    NSString *currentDirPath = [process.path fe_win_stringByDeletingLastPathComponent];
    
    assert(currentDirPath.length < arg_bufferLength);
    
    
    fe_memoryMap_strncpyFromRealToVirtual(process.memory, arg_buffer, (char*)[currentDirPath cStringUsingEncoding: NSASCIIStringEncoding], arg_bufferLength);

    return 8;
}

/*
 DWORD WINAPI GetFileAttributes(
 _In_ LPCTSTR lpFileName
 );
 */
static uint8_t fe_GetFileAttributesA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_fileName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    assert(arg_fileName != 0);
    
    char *fileNamec;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory, &fileNamec, arg_fileName);
    NSString *fileName = [NSString stringWithCString: fileNamec
                                            encoding: NSASCIIStringEncoding];
    
    free(fileNamec);
    assert(fileName);
    
    assert([fileName isEqualToString:@"patch000.dat"]);
    
    NSString *path = [fileName fe_win_convertToRealPathWithDiskAtPath: process.diskCPath
                                                          currentPath: process.currentRealPath];
    
    uint32_t result = 0x80;
    
    if([fileName isEqualToString:@"patch000.dat"]) {
        result = 0x20;
    }
    
    if(process.logExternalCalls) {
        printf("GetFileAttributesA: %s res: %d\n", [path cStringUsingEncoding:NSASCIIStringEncoding], result);
    }
    
    process.currentThread->eax = result;
    
    return 4;
}


/*
 BOOL VirtualFree(
 LPVOID lpAddress,
 DWORD dwSize,
 DWORD dwFreeType
 );
 */
static uint8_t fe_VirtualFree(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpAddress = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_dwSize = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_dwFreeType = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
#pragma unused(arg_dwSize)
#pragma unused(arg_dwFreeType)
    
    assert(arg_dwSize == 0);
    assert(arg_dwFreeType == 0x8000);
    
    fe_memoryMap_free(process.memory, arg_lpAddress);
    
    process.currentThread->eax = 1;
    
    return 12;
}


/*
 BOOL WINAPI CreateDirectory(
 _In_     LPCTSTR               lpPathName,
 _In_opt_ LPSECURITY_ATTRIBUTES lpSecurityAttributes
 );

 */
static uint8_t fe_CreateDirectoryA(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpPathName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpSecurityAttributes = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(arg_lpSecurityAttributes)
    
    char *pathNamec;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory, &pathNamec, arg_lpPathName);
    
    NSString *pathName = [NSString stringWithCString: pathNamec encoding:NSASCIIStringEncoding];
    
    free(pathNamec);
    
    

    NSString *dirPath = [pathName fe_win_convertToRealPathWithDiskAtPath: process.diskCPath
                                                             currentPath: process.currentRealPath];
    
    if(process.logExternalCalls) {
        NSLog(@"CreateDirectoryA: %@", dirPath);
    }
    
    assert(arg_lpSecurityAttributes == 0);
    
    NSError *error;
    BOOL success =
    [[NSFileManager defaultManager] createDirectoryAtPath: dirPath
                              withIntermediateDirectories: NO
                                               attributes: nil
                                                    error: &error];
    
    if(success) {
        process.currentThread->eax = 1;
    } else if(error.code == 516) {
        process.currentThread->eax = 0;
        FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
        kernel32.lastError = 183; // already exists
    } else {
        NSLog(@"%@", error);
        @throw [NSException new];
    }
    
    return 8;
}

/*
 HANDLE WINAPI FindFirstFile(
 _In_  LPCTSTR           lpFileName,
 _Out_ LPWIN32_FIND_DATA lpFindFileData
 );
 */
static uint8_t fe_FindFirstFileA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpFileName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t lpFindFileData = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(lpFindFileData)
    
    char *fileNamec;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory, &fileNamec, arg_lpFileName);
    
    NSString *fileName = [NSString stringWithCString: fileNamec encoding:NSASCIIStringEncoding];
    
    free(fileNamec);
    if(process.logExternalCalls) {
        NSLog(@"FindFirstFile: %@", fileName);
    }
    //xxx no saves can be found
    assert([fileName isEqualToString:@"MAPS\\*.SAV"] || [fileName isEqualToString:@"PROTO\\CRITTERS\\*.PRO"]|| [fileName isEqualToString:@"PROTO\\ITEMS\\*.PRO"] || [fileName isEqualToString:@"selfrun\\*.sdf"]);
    
    process.currentThread->eax = -1;

    return 8;
}

/*
 BOOL WINAPI VirtualProtect(
 _In_  LPVOID lpAddress,
 _In_  SIZE_T dwSize,
 _In_  DWORD  flNewProtect,
 _Out_ PDWORD lpflOldProtect
 );
 */
static uint8_t fe_VirtualProtect(FEProcess* process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpAddress = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_dwSize = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_flNewProtect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_lpflOldProtect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
    NSLog(@"VirtualProtect(address = 0x%X, size = %d, newProtect = 0x%X, oldProtect 0x%X", arg_lpAddress, arg_dwSize, arg_flNewProtect, arg_lpflOldProtect);
    
    //PAGE_EXECUTE_READWRITE 0x40
    assert(arg_flNewProtect = 0x40);
    
    
    FEMemoryAccessMode regionAccessMode = fe_memoryMap_accessModeAtAddress(process.memory, arg_lpAddress);
    
    //NSLog(@"Block accessMode = 0x%X, size = %d", block->accessMode, block->size);
    
    //    assert(block->size == arg_dwSize);
    
    uint32_t old_mode = 0;
    switch((int)regionAccessMode) {
        case kFEMemoryAccessMode_Read:
            old_mode = 0x2;
            break;
        case kFEMemoryAccessMode_Write:
            old_mode = 0x8;
            break;
        case kFEMemoryAccessMode_Execute:
            old_mode = 0x10;
            break;
        case ((FEMemoryAccessMode)(kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write)):
            old_mode = 0x4;
            break;
        case ((FEMemoryAccessMode)(kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Execute)):
            old_mode = 0x20;
            break;
        case ((FEMemoryAccessMode)(kFEMemoryAccessMode_Write|kFEMemoryAccessMode_Execute)):
            old_mode = 0x80;
            break;
        default:
            assert(0);
    }
    
    fe_memoryMap_setAccessModeAtAddress(process.memory, kFEMemoryAccessMode_Execute | kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write, arg_lpAddress, arg_dwSize);

    fe_memoryMap_setValue32(process.memory, arg_lpflOldProtect, old_mode);//read|write
    
    process.currentThread->eax = 1;
    
    return 16;
}

@implementation FEKernel32DLL {
    NSMutableDictionary *_handles;
    NSDictionary* _funcToImpMap;
    int32_t _showCursorCounter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _handles = @{}.mutableCopy;
        
        _funcToImpMap = @{
                         @"GetModuleHandleA": [NSValue valueWithPointer: &fe_GetModuleHandleA],
                         @"GetCurrentThreadId": [NSValue valueWithPointer: &fe_GetCurrentThreadId],
                         @"GetStdHandle": [NSValue valueWithPointer: &fe_GetStdHandle],
                         @"GetSystemTimeAsFileTime": [NSValue valueWithPointer: &fe_GetSystemTimeAsFileTime],
                         @"GetCurrentProcessId": [NSValue valueWithPointer: &fe_GetCurrentProcessId],
                         @"GetTickCount": [NSValue valueWithPointer: &fe_GetTickCount],
                         @"QueryPerformanceCounter": [NSValue valueWithPointer: &fe_QueryPerformanceCounter],
                         @"VirtualAlloc": [NSValue valueWithPointer: &fe_VirtualAlloc],
                         @"GetEnvironmentStrings": [NSValue valueWithPointer: &fe_GetEnvironmentStrings],
                         @"GetModuleFileNameA": [NSValue valueWithPointer: &fe_GetModuleFileNameA],
                         @"GetCommandLineA": [NSValue valueWithPointer: &fe_GetCommandLineA],
                         @"GetVersion": [NSValue valueWithPointer: &fe_GetVersion],
                         @"GetCPInfo": [NSValue valueWithPointer: &fe_GetCPInfo],
                         @"CreateMutexA": [NSValue valueWithPointer: &fe_CreateMutexA],
                         @"GetLastError": [NSValue valueWithPointer: &fe_GetLastError],
                         @"GetVersionExA": [NSValue valueWithPointer: &fe_GetVersionExA],
                         @"LoadLibraryA": [NSValue valueWithPointer: &fe_LoadLibraryA],
                         @"GetProcAddress": [NSValue valueWithPointer: &fe_GetProcAddress],
                         @"CreateFileA": [NSValue valueWithPointer: &fe_CreateFileA],
                         @"GetFileType": [NSValue valueWithPointer: &fe_GetFileType],
                         @"SetFilePointer": [NSValue valueWithPointer: &fe_SetFilePointer],
                         @"CloseHandle": [NSValue valueWithPointer: &fe_CloseHandle],
                         @"DeleteFileA": [NSValue valueWithPointer: &fe_DeleteFileA],
                         @"ReadFile": [NSValue valueWithPointer: &fe_ReadFile],
                         @"GetCurrentDirectoryA": [NSValue valueWithPointer: &fe_GetCurrentDirectoryA],
                         @"GetFileAttributesA": [NSValue valueWithPointer: &fe_GetFileAttributesA],
                         @"VirtualFree": [NSValue valueWithPointer: &fe_VirtualFree],
                         @"CreateDirectoryA": [NSValue valueWithPointer: &fe_CreateDirectoryA],
                         @"FindFirstFileA": [NSValue valueWithPointer: &fe_FindFirstFileA],
                         @"VirtualProtect": [NSValue valueWithPointer: &fe_VirtualProtect]
                         };


    }
    return self;
}

- (NSArray*) funcNames {
    return _funcToImpMap.allKeys;
}

- (BOOL) hasFunctionWithName:(NSString*) funcName {
    return _funcToImpMap[funcName] != nil;
}

- (uint8_t) executeFunctionWithName:(NSString*) funcName process:(FEProcess*) process {
    NSValue* funcPtr = _funcToImpMap[funcName];
    
    if(funcPtr) {
        FEFunctionProxyIMP imp = funcPtr.pointerValue;
        if(![funcName isEqualToString:@"GetLastError"]) {
            self.lastError = 0;
        }
        
        uint8_t result =  imp(process);
        
        return result;
    }
    assert(false);
    return 0;
}

- (uint32_t) createHandleType:(FEHandleType) type name:(NSString*) name payload:(id) payload {
    static uint32_t handle = 0xeeeee;
    while(_handles[@(handle)]!=nil) {
        handle++;
    }
    
    [_handles setObject: @{
                           @"type": @(type),
                           @"name": name,
                           @"payload": payload ?: [NSNull null]
                           }
                 forKey: @(handle)];
    
    
    return handle;
}

- (NSDictionary*) handleDetails:(uint32_t)handle {
    return _handles[@(handle)];
}

- (void) freeHandle:(uint32_t) handle {
    [_handles removeObjectForKey: @(handle)];
}

- (BOOL) handle:(uint32_t*) handle withPredicate:(BOOL(^)(NSDictionary*)) predicate {
    __block BOOL result = NO;
    __block uint32_t interstitialHandle = 0;

    [_handles enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSDictionary *details = obj;
        interstitialHandle = ((NSNumber*)key).unsignedIntValue;
        result = *stop = predicate(details);
    }];
    
    if(result) {
        if(handle) {
            *handle = interstitialHandle;
        }
        return YES;
    }
    
    return NO;
}

#pragma mark - Private

- (uint32_t) createModuleWithName:(NSString*) dllName {
    return [self createHandleType: kFEHandleType_Module name: dllName payload: nil];
}


- (uint32_t) createMutexWithName:(NSString*)name {
    return [self createHandleType: kFEHandleType_Mutex name: name payload: nil];
}

- (uint32_t) createFileHandleFromFile:(FILE*) file path:(NSString*) path {
    return [self createHandleType: kFEHandleType_File name: path payload: @{
                                                                           @"file": [NSValue valueWithPointer: file],
                                                                           @"path": path
                                                                           }];
}
@end
