;*************************  unalignedisfaster32.asm  ******************************
; Author:           Agner Fog
; Date created:     2011-07-09
; Last modified:    2013-07-25
; Source URL:       www.agner.org/optimize
; Project:          asmlib.zip
; Language:         assembly, NASM/YASM syntax, 64 bit
;
; C++ prototype:
; extern "C" int UnalignedIsFaster(void);
;
; Description:
; This function finds out if unaligned 16-bytes memory read is
; faster than aligned read followed by an alignment shift (PALIGNR) on the
; current CPU.
;
; Return value:
; 0:   Unaligned read is probably slower than alignment shift
; 1:   Unknown
; 2:   Unaligned read is probably faster than alignment shift
;
;
; C++ prototype:
; extern "C" int Store256BitIsFaster(void);
;
; Description:
; This function finds out if a 32-bytes memory write is
; faster than two 16-bytes writes on the current CPU.
;
; Return value:
; 0:   32-bytes memory write is slower or AVX not supported
; 1:   Unknown
; 2:   32-bytes memory write is faster
;
; Copyright (c) 2011 - 2013 GNU General Public License www.gnu.org/licenses
;******************************************************************************
;
; C++ prototype:
; extern "C" int UnalignedIsFaster(void);

global _UnalignedIsFaster: function
global _Store256BitIsFaster: function
extern _CpuType
extern _InstructionSet


SECTION .text

_UnalignedIsFaster:
        push    ebx
        push    0                      ; vendor
        push    0                      ; family 
        push    0                      ; model
        mov     eax, esp
        push    eax                    ; &model
        add     eax, 4
        push    eax                    ; &family
        add     eax, 4
        push    eax                    ; &vendor
        call    _CpuType               ; get vendor, family, model
        add     esp, 12
        pop     edx                    ; model
        pop     ecx                    ; family
        pop     ebx                    ; vendor
        xor     eax, eax               ; return value
        dec     ebx
        jz      Intel
        dec     ebx
        jz      AMD
        dec     ebx
        jz      VIA
        ; unknown vendor
        inc     eax
        jmp     Uend
        
Intel:  ; Unaligned read is faster on Intel Nehalem and later, but not Atom
        ; Nehalem  = family 6, model 1AH
        ; Atom     = family 6, model 1CH
        ; Netburst = family 0FH
        ; Future models are likely to be family 6, mayby > 6, model > 1C
        cmp     ecx, 6
        jb      Uend                   ; old Pentium 1, etc
        cmp     ecx, 0FH
        je      Uend                   ; old Netburst architecture
        cmp     edx, 1AH
        jb      Uend                   ; earlier than Nehalem
        cmp     edx, 1CH
        je      Uend                   ; Intel Atom
        or      eax, 2                 ; Intel Nehalem and later, except Atom
        jmp     Uend
        
AMD:    ; Uanligned read is fast on AMD K10 and later
        ; The PALIGNR instruction is slow on AMD Bobcat
        ; K10    = family 10H
        ; Bobcat = family 14H
        cmp     ecx, 10H
        jb      Uend                   ; AMD K8 or earlier
        or      eax, 2                 ; AMD K10 or later
        jmp     Uend
        
VIA:    ; Unaligned read is not faster than PALIGNR on VIA Nano 2000 and 3000                
        cmp     ecx, 0FH
        jna     Uend                   ; VIA Nano
        inc     eax                    ; Future versions: unknown
       ;jmp     Uend
        
Uend:   pop     ebx
        ret

;_UnalignedIsFaster ENDP


_Store256BitIsFaster:
        call    _InstructionSet
        cmp     eax, 11                ; AVX supported
        jb      S90        
        push    0                      ; vendor
        push    0                      ; family 
        push    0                      ; model
        mov     eax, esp
        push    eax                    ; &model
        add     eax, 4
        push    eax                    ; &family
        add     eax, 4
        push    eax                    ; &vendor
        call    _CpuType               ; get vendor, family, model
        add     esp, 12
        pop     edx                    ; model
        pop     ecx                    ; family
        pop     eax                    ; vendor
        cmp     eax, 1                 ; Intel
        je      S92
        cmp     eax, 2                 ; AMD
        jne     S91                    ; other vendor, not known
        ; AMD
        cmp     ecx, 15H               ; family 15h = Bulldozer, Piledriver
        ja      S92                    ; assume future AMD families are faster
        ; model 1 = Bulldozer is a little slower on 256 bit write
        ; model 2 = Piledriver is terribly slow on 256 bit write
        ; assume future models 3-4 are like Bulldozer
        cmp     edx, 4
        jbe     S90
        jmp     S91                    ; later models: don't know        
        
S90:    xor     eax, eax               ; return 0
        ret
        
S91:    mov     eax, 1                 ; return 1
        ret        
        
S92:    mov     eax, 2                 ; return 2
        ret        
        
; _Store256BitIsFaster ENDP

