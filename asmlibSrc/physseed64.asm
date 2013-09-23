;*************************  physseed64.asm  **********************************
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

global PhysicalSeed

SECTION .text  align=16

PhysicalSeed:
        push    rbx
%IFDEF WINDOWS
        push    rsi
        push    rdi
        mov     rdi, rcx               ; seeds
        mov     esi, edx               ; NumSeeds
%ENDIF
        ; test if RDSEED supported
        xor     eax, eax
        cpuid
        cmp     eax, 7
        jb      P200                   ; RDSEED not supported
        cmp     eax, 1
        jb      FAILURE                ; nothing supported
        mov     eax, 7
        xor     ecx, ecx
        cpuid
        bt      ebx, 18
;       jc      USE_RDSEED             ; not tested yet
P200:
        ; test if RDRAND supported
        mov     eax, 1
        cpuid
        bt      ecx, 30
        jc      USE_RDRAND
        
        ; test if VIA xstore instruction supported
        mov     eax, 0C0000000H
        mov     r8d, eax
        cpuid
        cmp     eax, r8d
        jna     P300                   ; not a VIA processor
        lea     eax, [r8+1]
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
        mov     ecx, esi               ; NumSeeds
        shr     ecx, 1
        jz      R150
        ; do 64 bits at a time
R100:   mov     ebx, NUM_TRIES
R110:   ; rdrand rax
        db 48h, 0Fh, 0C7h, 0F0h        ; rdrand rax
        jc      R120
        ; failed. try again
        dec     ebx
        jz      FAILURE
        jmp     R110
R120:   mov     [rdi], rax
        add     rdi, 8
        dec     ecx
        jnz     R100                   ; loop 64 bits
R150:
        and     esi, 1
        jz      R300
        ; an odd 32 bit remains
R200:   mov     ebx, NUM_TRIES
R210:   ; rdrand rax
        db 0Fh, 0C7h, 0F0h             ; rdrand eax
        jc      R220
        ; failed. try again
        dec     ebx
        jz      FAILURE
        jmp     R210
R220:   mov     [rdi], eax
R300:   mov     eax, 3                 ; return value
        jmp     EXIT1


USE_RDSEED:     ; Use RDSEED instruction (not tested yet)
        mov     ecx, esi               ; NumSeeds
        shr     ecx, 1
        jz      S150
        ; do 64 bits at a time
S100:   mov     ebx, NUM_TRIES
S110:   ; rdseed rax
        db 48h, 0Fh, 0C7h, 0F8h        ; rdseed rax
        jc      S120
        ; failed. try again
        dec     ebx
        jz      FAILURE
        jmp     S110
S120:   mov     [rdi], rax
        add     rdi, 8
        dec     ecx
        jnz     S100                   ; loop 64 bits
S150:
        and     esi, 1
        jz      S300
        ; an odd 32 bit remains
S200:   mov     ebx, NUM_TRIES
S210:   ; rdseed rax
        db 0Fh, 0C7h, 0F8h             ; rdseed eax
        jc      S220
        ; failed. try again
        dec     ebx
        jz      FAILURE
        jmp     S210
S220:   mov     [rdi], eax
S300:   mov     eax, 4                 ; return value
        jmp     EXIT1
        

VIA_METHOD:     ; Use VIA xstore instructions   
;       VIA XSTORE  supported
        mov     ecx, esi               ; NumSeeds
        and     ecx, -2                ; round down to nearest even
        jz      T200                   ; NumSeeds <= 1
        ; make an even number of random dwords
        shl     ecx, 2                 ; number of bytes (divisible by 8)
        mov     edx, 3                 ; quality factor
        db 0F3H, 00FH, 0A7H, 0C0H      ; rep xstore instuction
T200:        
        test    esi, 1
        jz      T300
        ; NumSeeds is odd. Make 8 bytes in temporary buffer and store 4 of the bytes
        mov     rbx, rdi               ; current output pointer
        mov     ecx, 4                 ; Will generate 4 or 8 bytes, depending on CPU
        mov     edx, 3                 ; quality factor
        push    rcx                    ; make temporary space on stack
        mov     rdi, rsp               ; point to buffer on stack
        db 0F3H, 00FH, 0A7H, 0C0H      ; rep xstore instuction
        pop     rax
        mov     [rbx], eax             ; store the last 4 bytes
T300:
        mov     eax, 2                 ; return value        
        jmp     EXIT1
        
USE_RDTSC:
        test    esi, esi
        jz      U300
        xor     eax, eax
        mov     ecx, esi
        push    rdi
        rep stosd                      ; fill seeds with zeroes
        pop     rdi
        cpuid                          ; serialize
        rdtsc                          ; get time stamp counter
        mov     [rdi], eax             ; store time stamp counter as seeds[0]
        cmp     esi, 1  ; seeds
        jna     U300
        mov     [rdi+4], edx           ; store high bits as seeds[1]        
U300:
        mov     eax, 1                 ; return value
        
EXIT1:  ; return
%IFDEF WINDOWS
        pop     rdi
        pop     rsi
%ENDIF        
        pop     rbx
        ret        
