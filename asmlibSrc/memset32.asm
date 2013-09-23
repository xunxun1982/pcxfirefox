;*************************  memset32.asm  *************************************
; Author:           Agner Fog
; Date created:     2008-07-19
; Last modified:    2011-08-21
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
; Position-independent code is generated if POSITIONINDEPENDENT is defined.
;
; Optimization:
; Uses XMM registers to set 16 bytes at a time, aligned.
;
; The latest version of this file is available at:
; www.agner.org/optimize/asmexamples.zip
; Copyright (c) 2009 GNU General Public License www.gnu.org/licenses
;******************************************************************************

global _A_memset: function             ; Function memset
global ?OVR_memset: function           ; ?OVR removed if standard function memset overridden
global _GetMemsetCacheLimit: function  ; Data blocks bigger than this will be stored uncached by memset
global _SetMemsetCacheLimit: function  ; Change limit in GetMemsetCacheLimit


; Imported from cachesize32.asm:
extern _DataCacheSize                  ; Get size of data cache

; Imported from instrset32.asm
extern _InstructionSet                 ; Instruction set for CPU dispatcher


SECTION .text  align=16

; extern "C" void * memset(void * dest, int c, size_t count);
; Function entry:
_A_memset:
?OVR_memset:
        mov     edx, [esp+4]           ; dest
        movzx   eax, byte [esp+8]      ; c
        mov     ecx, [esp+12]          ; count
        imul    eax, 01010101H         ; Broadcast c into all bytes of eax
        ; (multiplication is slow on Pentium 4, but faster on later processors)
        cmp     ecx, 16
        ja      M100
        
        ; count <= 16
        
%IFNDEF POSITIONINDEPENDENT

        jmp     dword [MemsetJTab+ecx*4]
        
; Separate code for each count from 0 to 16:
M16:    mov     [edx+12], eax
M12:    mov     [edx+8],  eax
M08:    mov     [edx+4],  eax
M04:    mov     [edx],    eax
M00:    mov     eax, [esp+4]           ; dest
        ret

M15:    mov     [edx+11], eax
M11:    mov     [edx+7],  eax
M07:    mov     [edx+3],  eax
M03:    mov     [edx+1],  ax
M01:    mov     [edx],    al
        mov     eax, [esp+4]           ; dest
        ret
       
M14:    mov     [edx+10], eax
M10:    mov     [edx+6],  eax
M06:    mov     [edx+2],  eax
M02:    mov     [edx],    ax
        mov     eax, [esp+4]           ; dest
        ret

M13:    mov     [edx+9],  eax
M09:    mov     [edx+5],  eax
M05:    mov     [edx+1],  eax
        mov     [edx],    al
        mov     eax, [esp+4]           ; dest
        ret
        
%ELSE   ; position-independent code. Too complicated to use jump table

        ; ecx = count, from 0 to 16:
        add     edx, ecx               ; end of dest
        neg     ecx                    ; negative index from the end
        jz      A500
        cmp     ecx, -16
        jng     A600
A100:   cmp     ecx, -8
        jg      A200
        ; set 8 bytes
        mov     [edx+ecx], eax
        mov     [edx+ecx+4], eax
        add     ecx, 8
A200:   cmp     ecx, -4
        jg      A300
        ; set 4 bytes
        mov     [edx+ecx], eax
        add     ecx, 4
A300:   cmp     ecx, -2
        jg      A400
        ; set 2 bytes
        mov     [edx+ecx], ax
        add     ecx, 2
A400:   cmp     ecx, -1
        jg      A500
        ; set 1 byte
        mov     [edx+ecx], al
A500:   ret

A600:   ; set 16 bytes
        mov     [edx+ecx], eax
        mov     [edx+ecx+4], eax
        mov     [edx+ecx+8], eax
        mov     [edx+ecx+12], eax
        ret

%ENDIF
        
align   16
M100:   ; count > 16. 
%IFNDEF POSITIONINDEPENDENT
        jmp     dword [memsetDispatch] ; Go to appropriate version, depending on instruction set

%ELSE   ; Position-independent code

        push    ebx
        call    get_thunk_ebx          ; get reference point for position-independent code
RP:                                    ; reference point eax = offset RP
A020:                                  ; Go here after CPU dispatching

        ; Make the following instruction with address relative to RP:
        cmp     dword [ebx-RP+memsetCPUVersion], 1
        
        jb      memsetCPUDispatch      ; First time: memsetCPUVersion = 0, go to dispatcher
        je      memset386              ; memsetCPUVersion = 1, go to 80386 version

%ENDIF

memsetSSE2:  ; SSE2 version. Use xmm register
        movd    xmm0, eax
        pshufd  xmm0, xmm0, 0          ; Broadcast c into all bytes of xmm0
        
        ; Store the first unaligned part.
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the subsequent regular part, than to make possibly mispredicted
        ; branches depending on the size of the first part.
        movq    qword [edx],   xmm0
        movq    qword [edx+8], xmm0
        
        ; Check if count very big
%IFNDEF POSITIONINDEPENDENT
        cmp     ecx, [_MemsetCacheLimit]        
%ELSE   ; position-independent code
        cmp     ecx, [ebx-RP+_MemsetCacheLimit]        
%ENDIF

        ja      M500                   ; Use non-temporal store if count > MemsetCacheLimit
        
        ; Point to end of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     ecx, [edx+ecx-1]
        and     ecx, -10H
        
        ; Point to start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     edx, 10H
        and     edx, -10H
        
        ; -(size of regular part)
        sub     edx, ecx
        jnl     M300                   ; Jump if not negative
        
M200:   ; Loop through regular part
        ; ecx = end of regular part
        ; edx = negative index from the end, counting up to zero
        movdqa  [ecx+edx], xmm0
        add     edx, 10H
        jnz     M200
        
M300:   ; Do the last irregular part
%IFDEF  POSITIONINDEPENDENT
        pop     ebx
%ENDIF
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     eax, [esp+4]           ; dest
        mov     ecx, [esp+12]          ; count
        movq    qword [eax+ecx-10H], xmm0
        movq    qword [eax+ecx-8], xmm0
        ret
   
M500:   ; Use non-temporal moves, same code as above:
        ; End of regular part:
        ; Round down dest+count to nearest preceding 16-bytes boundary
        lea     ecx, [edx+ecx-1]
        and     ecx, -10H
        
        ; Start of regular part:
        ; Round up dest to next 16-bytes boundary
        add     edx, 10H
        and     edx, -10H
        
        ; -(size of regular part)
        sub     edx, ecx
        jnl     M700                   ; Jump if not negative
        
M600:   ; Loop through regular part
        ; ecx = end of regular part
        ; edx = negative index from the end, counting up to zero
        movntdq [ecx+edx], xmm0
        add     edx, 10H
        jnz     M600
        
M700:   ; Do the last irregular part
%IFDEF  POSITIONINDEPENDENT
        pop     ebx
%ENDIF
        ; The size of this part is 1 - 16 bytes.
        ; It is faster to always write 16 bytes, possibly overlapping
        ; with the preceding regular part, than to make possibly mispredicted
        ; branches depending on the size of the last part.
        mov     eax, [esp+4]           ; dest
        mov     ecx, [esp+12]          ; count
        movq    qword [eax+ecx-10H], xmm0
        movq    qword [eax+ecx-8], xmm0
        ret
     
        
; 80386 version, ecx > 16
memset386:        
        push    edi
        mov     edi, edx
N200:   test    edi, 3
        jz      N300
        ; unaligned
N210:   mov     [edi], al              ; store 1 byte until edi aligned
        inc     edi
        dec     ecx
        test    edi, 3
        jnz     N210
N300:   ; aligned
        mov     edx, ecx
        shr     ecx, 2
        cld
        rep     stosd                  ; store 4 bytes at a time
        mov     ecx, edx
        and     ecx, 3
        rep     stosb                  ; store any remaining bytes
        pop     edi
%IFDEF  POSITIONINDEPENDENT
        pop     ebx
%ENDIF
        ret
        
        
; CPU dispatching for memset. This is executed only once
memsetCPUDispatch:
%IFNDEF POSITIONINDEPENDENT
        pushad
        call    _GetMemsetCacheLimit
        call    _InstructionSet
        ; Point to generic version of memset
        mov     dword [memsetDispatch],  memset386
        cmp     eax, 4                 ; check SSE2
        jb      Q100
        ; SSE2 supported
        ; Point to SSE2 version of memset
        mov     dword [memsetDispatch],  memsetSSE2
Q100:   popad
        ; Continue in appropriate version of memset
        jmp     dword [memsetDispatch]

%ELSE   ; Position-independent version
        pushad
        call    _GetMemsetCacheLimit
        
        ; Make the following instruction with address relative to RP:
        lea     esi, [ebx-RP+memsetCPUVersion]
        ; Now esi points to memsetCPUVersion.

        call    _InstructionSet        

        mov     byte [esi], 1          ; Indicate generic version
        cmp     eax, 4                 ; check SSE2
        jb      Q100
        ; SSE2 supported
        mov     byte [esi], 2      ; Indicate SSE2 or later version
Q100:   popad
        jmp     A020                   ; Go back and dispatch
        
get_thunk_ebx: ; load caller address into ebx for position-independent code
        mov     ebx, [esp]
        ret
        
get_thunk_edx: ; load caller address into ebx for position-independent code
        mov     edx, [esp]
        ret
        
%ENDIF

; extern "C" size_t GetMemsetCacheLimit(); // Data blocks bigger than this will be stored uncached by memset
_GetMemsetCacheLimit:
        push    ebx
%ifdef  POSITIONINDEPENDENT
        call    get_thunk_ebx
        add     ebx, _MemsetCacheLimit - $
%else
        mov     ebx, _MemsetCacheLimit
%endif
        mov     eax, [ebx]
        test    eax, eax
        jnz     U200
        ; Get half the size of the largest level cache
        push    0                      ; 0 means largest level cache
        call    _DataCacheSize         ; get cache size
        pop     ecx
        shr     eax, 1                 ; half the size
        jnz     U100
        mov     eax, 400000H           ; cannot determine cache size. use 4 Mbytes
U100:   mov     [ebx], eax
U200:   pop     ebx
        ret

; extern "C" void   SetMemsetCacheLimit(); // Change limit in GetMemsetCacheLimit
_SetMemsetCacheLimit:
        push    ebx
%ifdef  POSITIONINDEPENDENT
        call    get_thunk_ebx
        add     ebx, _MemsetCacheLimit - $
%else
        mov     ebx, _MemsetCacheLimit
%endif
        mov     eax, [esp+8]
        test    eax, eax
        jnz     U400
        ; zero, means default
        mov     [ebx], eax
        call    _GetMemsetCacheLimit
U400:   
        mov     [ebx], eax
        pop     ebx
        ret


SECTION .data  align=16

%IFNDEF  POSITIONINDEPENDENT

; Jump table for count from 0 to 16:
MemsetJTab DD M00, M01, M02, M03, M04, M05, M06, M07
           DD M08, M09, M10, M11, M12, M13, M14, M15, M16

; Pointer to appropriate version.
; This initially points to memsetCPUDispatch. memsetCPUDispatch will
; change this to the appropriate version of memset, so that
; memsetCPUDispatch is only executed once:
memsetDispatch DD memsetCPUDispatch

%ELSE    ; position-independent

; CPU version: 0=unknown, 1=80386, 2=SSE2
memsetCPUVersion DD 0

%ENDIF

; Bypass cache by using non-temporal moves if count > MemsetCacheLimit
; The optimal value of MemsetCacheLimit is difficult to estimate, but
; a reasonable value is half the size of the largest cache
_MemsetCacheLimit: DD 0

%IFDEF POSITIONINDEPENDENT
; Fix potential problem in Mac linker
        DD      0, 0
%ENDIF
