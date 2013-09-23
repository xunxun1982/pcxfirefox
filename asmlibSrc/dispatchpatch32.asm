;***********************  dispatchpatch32.asm  ********************************
; Author:           Agner Fog
; Date created:     2007-07-20
; Last modified:    2012-07-06
; Source URL:       www.agner.org/optimize
; Project:          asmlib.zip
; Language:         assembly, NASM/YASM syntax, 32 bit
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

; extern _InstructionSet: function
%include "instrset32.asm"              ; include code for _InstructionSet function

; InstructionSet function return value:
;  0 =  80386 instruction set only
;  1 or above = MMX instructions supported
;  2 or above = conditional move and FCOMI supported
;  3 or above = SSE (XMM) supported by processor and operating system
;  4 or above = SSE2 supported
;  5 or above = SSE3 supported
;  6 or above = Supplementary SSE3
;  8 or above = SSE4.1 supported
;  9 or above = POPCNT supported
; 10 or above = SSE4.2 supported
; 11 or above = AVX supported by processor and operating system
; 12 or above = PCLMUL and AES supported
; 13 or above = AVX2 supported



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Dispatcher for Intel standard libraries and SVML library
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global ___intel_cpu_indicator
global ___intel_cpu_indicator_init


SECTION .data
intel_cpu_indicator@:                  ; local name
___intel_cpu_indicator: dd 0
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

; This is already in instrset.asm file
;%IFDEF POSITIONINDEPENDENT
; Local function for reading instruction pointer into edi
;GetThunkEDX:
;        mov     edx, [esp]
;        ret
;%ENDIF  ; POSITIONINDEPENDENT


___intel_cpu_indicator_init:
        pushad                         ; Must save registers
        call    _InstructionSet
        cmp     eax, itablelen
        jb      L100
        mov     eax, itablelen - 1     ; limit to table length
L100:   
%IFDEF POSITIONINDEPENDENT
        ; Position-independent code for ELF and Mach-O shared objects:
        call    GetThunkEDX
        add     edx, intel_cpu_indicator@ - $
%ELSE
        lea     edx, [intel_cpu_indicator@]
%ENDIF  
        mov     eax, [edx + (itable - intel_cpu_indicator@) + 4*eax]
        mov     [edx], eax             ; store in ___intel_cpu_indicator
        popad
        ret
;___intel_cpu_indicator_init ENDP


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;     Dispatcher for Math Kernel Library (MKL),
;     version 10.2 and higher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global _mkl_serv_cpu_detect

SECTION .data
; table of indicator values
; Note: the table is different in 32 bit and 64 bit mode

mkltab  DD      0, 0, 0, 0             ; 0-3: generic version, 80386 instruction set
        DD      2                      ; 4:      SSE2
        DD      3                      ; 5:      SSE3
        DD      4, 4, 4, 4             ; 6-9:    SSSE3
        DD      5                      ; 10:     SSE4.2
        DD      6                      ; 11:     AVX
mkltablen equ ($ - mkltab) / 4         ; length of table

SECTION .text

_mkl_serv_cpu_detect:
        push    ecx                    ; Perhaps not needed
        push    edx
        call    _InstructionSet
        cmp     eax, mkltablen
        jb      M100
        mov     eax, mkltablen - 1     ; limit to table length
M100:   
%IFDEF POSITIONINDEPENDENT
        ; Position-independent code for ELF and Mach-O shared objects:
        call    GetThunkEDX
        add     edx, mkltab - $
%ELSE
        lea     edx, [mkltab]
%ENDIF  
        mov     eax, [edx + 4*eax]
        pop     edx
        pop     ecx
        ret
; end _mkl_serv_cpu_detect        


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;     Dispatcher for Vector Math Library (VML)
;     version 10.0 and higher
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global _mkl_vml_serv_cpu_detect

SECTION .data
; table of indicator values
; Note: the table is different in 32 bit and 64 bit mode

vmltab  DD      0, 0, 0, 0             ; 0-3: generic version, 80386 instruction set
        DD      2                      ; 4:      SSE2
        DD      3                      ; 5:      SSE3
        DD      4, 4                   ; 6-7:    SSSE3
        DD      5, 5                   ; 8-9:    SSE4.1
        DD      6                      ; 10:     SSE4.2
        DD      7                      ; 11:     AVX
vmltablen equ ($ - vmltab) / 4         ; length of table

SECTION .text

_mkl_vml_serv_cpu_detect:
        push    ecx                    ; Perhaps not needed
        push    edx
        call    _InstructionSet
        cmp     eax, vmltablen
        jb      V100
        mov     eax, vmltablen - 1     ; limit to table length
V100:   
%IFDEF POSITIONINDEPENDENT
        ; Position-independent code for ELF and Mach-O shared objects:
        call    GetThunkEDX
        add     edx, vmltab - $
%ELSE
        lea     edx, [vmltab]
%ENDIF  
        mov     eax, [edx + 4*eax]
        pop     edx
        pop     ecx
        ret
; end _mkl_vml_serv_cpu_detect        
