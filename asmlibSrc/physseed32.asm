;*************************  physseed32.asm  **********************************
; Author:           Agner Fog
; Date created:     2010-08-03
; Last modified:    2013-07-26
; Source URL:       www.agner.org/optimize
; Project:          asmlib.zip
; C++ prototype:
; extern "C" int PhysicalSeed(int seeds[], int NumSeeds);
;
; Description:
; Generates a non-deterministic random seed from a physical random number generator 
; which is available on some processors. 
; Uses the time stamp counter (which is less random) if no physical random number
; generator is available.
; The code is not optimized for speed because it is typically called only once.
;
; Parameters:
; int seeds[]       An array which will be filled with random numbers
; int NumSeeds      Indicates the desired number of 32-bit random numbers
;
; Return value:     0   Failure. No suitable instruction available (processor older than Pentium)
;                   1   No physical random number generator. Used time stamp counter instead
;                   2   Success. VIA physical random number generator used
;                   3   Success. Intel physical random number generator used
;                   4   Success. Intel physical seed generator used
; 
; The return value will indicate the availability of a physical random number generator
; even if NumSeeds = 0.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define NUM_TRIES   20                 ; max number of tries for random number generator

global _PhysicalSeed

SECTION .text  align=16

_PhysicalSeed:
        push    ebx
        push    esi
        push    edi
        pushfd
        pop     eax
        btc     eax, 21                ; check if CPUID bit can toggle
        push    eax
        popfd
        pushfd
        pop     ebx
        xor     ebx, eax
        xor     eax, eax               ; 0
        bt      ebx, 21
        jc      FAILURE                ; CPUID not supported
        
        cpuid                          ; get number of CPUID functions
        test    eax, eax
        jz      FAILURE                ; function 1 not supported

        ; test if RDSEED supported
        xor     eax, eax
        cpuid
        cmp     eax, 7
        jb      P200                   ; RDSEED not supported
        mov     eax, 7
        xor     ecx, ecx
        cpuid
        bt      ebx, 18
;       jc      USE_RDSEED             ; not tested yet

P200:   ; test if RDRAND supported
        mov     eax, 1
        cpuid
        bt      ecx, 30
        jc      USE_RDRAND

        ; test if VIA xstore instruction supported
        mov     eax, 0C0000000H
        mov     esi, eax
        cpuid
        cmp     eax, esi
        jna     P300                   ; not a VIA processor
        lea     eax, [esi+1]
        cpuid
        bt      edx, 3
        jc      VIA_METHOD

P300:   ; test if RDTSC supported
        mov     eax, 1
        cpuid
        bt      edx, 4
        jc      USE_RDTSC              ; XSTORE instruction not supported or not enabled
        
FAILURE: ; No useful instruction supported
        xor     eax, eax
        jmp     EXIT1     

USE_RDRAND:     ; Use RDRAND instruction        
        mov     edi, [esp+16]          ; seeds
        mov     ecx, [esp+20]          ; NumSeeds
        jecxz   R300
        ; do 32 bits at a time
R100:   mov     ebx, NUM_TRIES
R110:   ; rdrand eax
        db 0Fh, 0C7h, 0F0h             ; rdrand eax
        jc      R120
        ; failed. try again
        dec     ebx
        jz      FAILURE
        jmp     R110
R120:   mov     [edi], eax
        add     edi, 4
        dec     ecx
        jnz     R100                   ; loop 32 bits
R300:   mov     eax, 3                 ; return value
        jmp     EXIT1


USE_RDSEED:     ; Use RDSEED instruction (not tested yet)
        mov     edi, [esp+16]          ; seeds
        mov     ecx, [esp+20]          ; NumSeeds
        jecxz   S300
        ; do 32 bits at a time
S100:   mov     ebx, NUM_TRIES
S110:   ; rdrand eax
        db 0Fh, 0C7h, 0F0h             ; rdrand eax
        jc      S120
        ; failed. try again
        dec     ebx
        jz      FAILURE
        jmp     S110
S120:   mov     [edi], eax
        add     edi, 4
        dec     ecx
        jnz     S100                   ; loop 32 bits
S300:   mov     eax, 4                 ; return value
        jmp     EXIT1


VIA_METHOD:     ; Use VIA xstore instructions   
;       VIA XSTORE  supported
        mov     edi, [esp+16]          ; seeds
        mov     ecx, [esp+20]          ; NumSeeds
        mov     ebx, ecx
        and     ecx, -2                ; round down to nearest even
        jz      T200                  ; NumSeeds <= 1
        ; make an even number of random dwords
        shl     ecx, 2                 ; number of bytes (divisible by 8)
        mov     edx, 3                 ; quality factor
        db 0F3H, 00FH, 0A7H, 0C0H      ; rep xstore instuction
T200:
        test    ebx, 1
        jz      T300
        ; NumSeeds is odd. Make 8 bytes in temporary buffer and store 4 of the bytes
        mov     esi, edi               ; current output pointer
        push    ebp
        mov     ebp, esp
        sub     esp, 8                 ; make temporary space on stack
        and     esp, -8                ; align by 8
        mov     edi, esp
        mov     ecx, 4                 ; Will generate 4 or 8 bytes, depending on CPU
        mov     edx, 3                 ; quality factor
        db 0F3H, 00FH, 0A7H, 0C0H      ; rep xstore instuction
        mov     eax, [esp]
        mov     [esi], eax             ; store the last 4 bytes
        mov     esp, ebp
        pop     ebp
T300:
        mov     eax, 2                 ; return value
        jmp     EXIT1

        
USE_RDTSC:
        mov     edi, [esp+16]          ; seeds
        mov     ecx, [esp+20]          ; NumSeeds
        jecxz   U300
        xor     eax, eax
        mov     esi, edi
        rep stosd                      ; fill seeds with zeroes
        cpuid                          ; serialize
        rdtsc                          ; get time stamp counter
        mov     [esi], eax             ; store time stamp counter as seeds[0]
        cmp     dword [esp+20], 1      ; seeds
        jna     U300
        mov     [esi+4], edx           ; store high bits as seeds[1]        
U300:
        mov     eax, 1                 ; return value        
EXIT1:
        pop     edi
        pop     esi
        pop     ebx
        ret 
        
        
;_PhysicalSeed ENDP
