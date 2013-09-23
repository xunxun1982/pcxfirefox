;***********************  dispatchpatch64.asm  ********************************
; Author:           Agner Fog
; Date created:     2007-07-20
; Last modified:    2012-07-06
; Source URL:       www.agner.org/optimize
; Project:          asmlib.zip
; Language:         assembly, NASM/YASM syntax, 64 bit
;
; C++ prototype:
; extern "C" int  __intel_cpu_indicator = 0;
; extern "C" void __intel_cpu_indicator_init()
;
; Description:
; Example of how to replace Intel CPU dispatcher in order to improve 
; compatibility of Intel function libraries with non-Intel processors.
; Only works with static link libraries (*.lib, *.a), not dynamic libraries
; (*.dll, *.so). Linking in this as an object file will override the functions
; with the same name in the library.; 
; 
; Copyright (c) 2007-2012 GNU LGPL License v. 3.0 www.gnu.org/licenses/lgpl.html
;******************************************************************************

; extern InstructionSet: function
%include "instrset64.asm"              ; include code for InstructionSet function

; InstructionSet function return value:
;  4 or above = SSE2 supported
;  5 or above = SSE3 supported
;  6 or above = Supplementary SSE3
;  8 or above = SSE4.1 supported
;  9 or above = POPCNT supported
; 10 or above = SSE4.2 supported
; 11 or above = AVX supported by processor and operating system
; 12 or above = PCLMUL and AES supported
; 13 or above = AVX2 supported

global __intel_cpu_indicator
global __intel_cpu_indicator_init


SECTION .data
intel_cpu_indicator@:                  ; local name
__intel_cpu_indicator: dd 0

; table of indicator values
itable  DD      1                      ; 0: generic version, 80386 instruction set
        DD      8, 8                   ; 1,   2: MMX
        DD      0x80                   ; 3:      SSE
        DD      0x200                  ; 4:      SSE2
        DD      0x800                  ; 5:      SSE3
        DD      0x1000, 0x1000         ; 6,   7: SSSE3
        DD      0x2000, 0x2000         ; 8,   9: SSE4.1
        DD      0x8000, 0x8000         ; 10, 11: SSE4.2 and popcnt
        DD      0x20000                ; 12:     AVX, pclmul, aes
        DD      0x400000               ; 13:     AVX2, etc.
itablelen equ ($ - itable) / 4         ; length of table

SECTION .text

__intel_cpu_indicator_init:
        push    rax                    ; registers must be pushed
        push    rcx
        push    rdx
        push    r8
        push    r9
        push    r10
        push    r11
%ifdef WINDOWS
        push    rsi
        push    rdi
%endif
        call    InstructionSet
        cmp     eax, itablelen
        jb      L100
        mov     eax, itablelen - 1     ; limit to table length
L100:   lea     rdx, [rel itable]
        mov     eax, [rdx + 4*rax]
        mov     [rel intel_cpu_indicator@], eax             ; store in __intel_cpu_indicator
%ifdef WINDOWS
        pop     rdi
        pop     rsi
%endif
        pop     r11
        pop     r10
        pop     r9
        pop     r8
        pop     rdx
        pop     rcx
        pop     rax
        ret

;__intel_cpu_indicator_init ENDP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;     Dispatcher for Math Kernel Library (MKL),
;     version 10.2 and higher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global mkl_serv_cpu_detect

SECTION .data
; table of indicator values
; Note: the table is different in 32 bit and 64 bit mode

mkltab  DD      0, 0, 0, 0             ; 0-3: generic version, 80386 instruction set
        DD      0                      ; 4:      SSE2
        DD      1                      ; 5:      SSE3
        DD      2, 2, 2, 2             ; 6-9:    SSSE3
        DD      3                      ; 10:     SSE4.2
        DD      4                      ; 11:     AVX
mkltablen equ ($ - mkltab) / 4         ; length of table

SECTION .text

mkl_serv_cpu_detect:
        push    rcx                    ; Perhaps not needed
        push    rdx
        push    r8
        push    r9
%ifdef WINDOWS
        push    rsi
        push    rdi
%endif
        call    InstructionSet
        cmp     eax, mkltablen
        jb      M100
        mov     eax, mkltablen - 1     ; limit to table length
M100:   
        lea     rdx, [rel mkltab]
        mov     eax, [rdx + 4*rax]
%ifdef WINDOWS
        pop     rdi
        pop     rsi
%endif
        pop     r9
        pop     r8
        pop     rdx
        pop     rcx
        ret
; end mkl_serv_cpu_detect        


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;     Dispatcher for Vector Math Library (VML)
;     version 10.0 and higher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global mkl_vml_serv_cpu_detect

SECTION .data
; table of indicator values
; Note: the table is different in 32 bit and 64 bit mode

vmltab  DD      0, 0, 0, 0             ; 0-3: generic version, 80386 instruction set
        DD      1, 1                   ; 4-5:    SSE2
        DD      2, 2                   ; 6-7:    SSSE3
        DD      3, 3                   ; 8-9:    SSE4.1
        DD      4                      ; 10:     SSE4.2
        DD      5                      ; 11:     AVX
vmltablen equ ($ - vmltab) / 4         ; length of table

SECTION .text

mkl_vml_serv_cpu_detect:
        push    rcx                    ; Perhaps not needed
        push    rdx
        push    r8
        push    r9
%ifdef WINDOWS
        push    rsi
        push    rdi
%endif
        call    InstructionSet
        cmp     eax, vmltablen
        jb      V100
        mov     eax, vmltablen - 1     ; limit to table length
V100:   
        lea     rdx, [rel vmltab]
        mov     eax, [rdx + 4*rax]
%ifdef WINDOWS
        pop     rdi
        pop     rsi
%endif
        pop     r9
        pop     r8
        pop     rdx
        pop     rcx
        ret
; end mkl_vml_serv_cpu_detect        
