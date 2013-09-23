;*************************  memset64.asm  *************************************
; Author:           Agner Fog
; Date created:     2008-07-19
; Last modified:    2008-10-16
; Description:
; Faster version of the standard memset function:
; void * A_memset(void * dest, int c, size_t count);
; Sets 'count' bytes from 'dest' to the 8-bit value 'c'
;
; Overriding standard function memset:
; The alias ?OVR_memset is changed to _memset in the object file if
; it is desired to override the standard library function memset.
;
; extern "C" size_t GetMemsetCacheLimit(); // Data blocks bigger than this will be stored uncached by memset
; extern "C" void   SetMemsetCacheLimit(); // Change limit in GetMemsetCacheLimit
;
; Optimization:
; Uses XMM registers to set 16 bytes at a time, aligned.
;
; The latest version of this file is available at:
; www.agner.org/optimize/asmexamples.zip
; Copyright (c) 2009 GNU General Public License www.gnu.org/licenses
;******************************************************************************

default rel

global A_memset: function              ; Function memset
global ?OVR_memset: function           ; ?OVR removed if standard function memset overridden
global GetMemsetCacheLimit: function   ; Data blocks bigger than this will be stored uncached by memset
global SetMemsetCacheLimit: function   ; Change limit in GetMemsetCacheLimit

; Imported from cachesize64.asm:
extern DataCacheSize                   ; Get size of data cache


SECTION .text  align=16

; extern "C" void * memset(void * dest, int c, size_t count);
; Function entry:
A_memset:
?OVR_memset:

%IFDEF  WINDOWS
%define Rdest   rcx                    ; dest
        movzx   eax, dl                ; c
        mov     rdx, r8                ; count
%define Rcount  rdx                    ; count
%define Rdest2  r9                     ; copy of dest
%define Rcount2 r8                     ; copy of count

%ELSE   ; Unix
%define Rdest   rdi                    ; dest
        movzx   eax, sil               ; c
%define Rcount  rdx                    ; count
%define Rdest2  rcx                    ; copy of dest
%define Rcount2 rsi                    ; copy of count
        mov     Rcount2, Rcount        ; copy count
%ENDIF

        imul    eax, 01010101H         ; Broadcast c into all bytes of eax
        ; (multiplication is slow on Pentium 4, but faster on later processors)
        mov     Rdest2, Rdest          ; save dest
        cmp     Rcount, 16
        ja      M100
        
        lea     r10, [MemsetJTab]
        jmp     qword [r10+Rcount*8]
        
; Separate code for each count from 0 to 16:
M16:    mov     [Rdest+12], eax
M12:    mov     [Rdest+8],  eax
M08:    mov     [Rdest+4],  eax
M04:    mov     [Rdest],    eax
M00:    mov     rax, Rdest2            ; return dest
        ret

M15:    mov     [Rdest+11], eax
M11:    mov     [Rdest+7],  eax
M07:    mov     [Rdest+3],  eax
M03:    mov     [Rdest+1],  ax
M01:    mov     [Rdest],    al
        mov     rax, Rdest2            ; return dest
        ret
       
M14:    mov     [Rdest+10], eax
M10:    mov     [Rdest+6],  eax
M06:    mov     [Rdest+2],  eax
M02:    mov     [Rdest],    ax
        mov     rax, Rdest2            ; return dest
        ret

M13:    mov     [Rdest+9],  eax
M09:    mov     [Rdest+5],  eax
M05:    mov     [Rdest+1],  eax
        mov     [Rdest],    al
        mov     rax, Rdest2            ; return dest
        ret
        

M100:   ; count > 16. Use SSE2 instruction set
        movd    xmm0, eax
        pshufd  xmm0, xmm0, 0          ; Broadcast c into all bytes of xmm0
        
        ; Store the first unaligned part.
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the subsequent regular part, than to make possibly mispredicted
        ; branches depending on the size of the first part.
        movq    qword [Rdest],   xmm0
        movq    qword [Rdest+8], xmm0
        
        ; Check if count very big
M150:   mov     rax, [MemsetCacheLimit]        
        cmp     Rcount, rax
        ja      M500                   ; Use non-temporal store if count > MemsetCacheLimit
        
        ; Point to end of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     Rcount, [Rdest+Rcount-1]
        and     Rcount, -10H
        
        ; Point to start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     Rdest, 10H
        and     Rdest, -10H
        
        ; -(size of regular part)
        sub     Rdest, Rcount
        jnl     M300                   ; Jump if not negative
        
M200:   ; Loop through regular part
        ; Rcount = end of regular part
        ; Rdest = negative index from the end, counting up to zero
        movdqa  [Rcount+Rdest], xmm0
        add     Rdest, 10H
        jnz     M200
        
M300:   ; Do the last irregular part
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     rax, Rdest2                          ; dest
        movq    qword [rax+Rcount2-10H], xmm0
        movq    qword [rax+Rcount2-8], xmm0
        ret
        
M400:   ; first time, determine MemsetCacheLimit
        push    Rdest
        push    Rdest2
        push    Rcount
        push    Rcount2        
        call    GetMemsetCacheLimit
        pop     Rcount2
        pop     Rcount
        pop     Rdest2
        pop     Rdest
        jmp     M150
   
M500:   ; check if first time
        test    rax, rax
        jz      M400

        ; Use non-temporal moves, same code as above:
        ; End of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     Rcount, [Rdest+Rcount-1]
        and     Rcount, -10H
        
        ; Start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     Rdest, 10H
        and     Rdest, -10H
        
        ; -(size of regular part)
        sub     Rdest, Rcount
        jnl     M700                   ; Jump if not negative
        
M600:   ; Loop through regular part
        ; Rcount = end of regular part
        ; Rdest = negative index from the end, counting up to zero
        movntdq [Rcount+Rdest], xmm0
        add     Rdest, 10H
        jnz     M600
        
M700:   ; Do the last irregular part
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     rax, Rdest2            ; dest
        movq    qword [rax+Rcount2-10H], xmm0
        movq    qword [rax+Rcount2-8], xmm0
        ret
        
; extern "C" size_t GetMemsetCacheLimit(); // Data blocks bigger than this will be stored uncached by memset
GetMemsetCacheLimit:
        mov     rax, [MemsetCacheLimit]
        test    rax, rax
        jnz     U200
        ; Get half the size of the largest level cache
%ifdef  WINDOWS
        xor     ecx, ecx               ; 0 means largest level cache
%else
        xor     edi, edi               ; 0 means largest level cache
%endif
        call    DataCacheSize          ; get cache size
        shr     eax, 1                 ; half the size
        jnz     U100
        mov     eax, 400000H           ; cannot determine cache size. use 4 Mbytes
U100:   mov     [MemsetCacheLimit], eax
U200:   ret

; extern "C" void   SetMemsetCacheLimit(); // Change limit in GetMemsetCacheLimit
SetMemsetCacheLimit:
%ifdef  WINDOWS
        mov     rax, rcx
%else
        mov     rax, rdi
%endif
        test    rax, rax
        jnz     U400
        ; zero, means default
        mov     [MemsetCacheLimit], rax
        call    GetMemsetCacheLimit
U400:   mov     [MemsetCacheLimit], rax
        ret
        
   
SECTION .data  align=16
; Jump table for count from 0 to 16:
MemsetJTab:DQ M00, M01, M02, M03, M04, M05, M06, M07
           DQ M08, M09, M10, M11, M12, M13, M14, M15, M16

; Bypass cache by using non-temporal moves if count > MemsetCacheLimit
; The optimal value of MemsetCacheLimit is difficult to estimate, but
; a reasonable value is half the size of the largest cache
MemsetCacheLimit: DQ 0
