.model tiny
.code
org 100h

locals @@

ENDL    equ 00h
BTP     equ BYTE PTR
WDP     equ WORD PTR

TERMINATE macro
        mov AX, 4C00h
        int 21h
endm

_start:
        mov ax, 24Fh
        mov dl, 10d
        mul dl
        ; mov SI, offset dataKira
        ; mov AH, 'K'
        ; call strchr
        
        ; mov SI, offset dataShort
        ; call strlen

        ; mov SI, offset dataShort
        ; mov DI, offset dataFree
        ; call strncpy

        ; mov SI, offset dataShort
        ; mov DI, offset dataCmp
        ; mov CX, 20h
        ; call strncmp

        ; mov CL, 04h
        ; mov DI, offset dataFree
        ; mov AX, 304d
        ; call itoa

        ; mov DX, offset dataFree
        ; mov AH, 09h
        ; int 21h

        ; xor AX, AX
        ; mov AL, 'K'
        ; push AX
        ; mov AX, offset dataKira
        ; push AX
        ; call strchr_s

        mov SI, offset dataDec
        call atoi

        mov DI, offset dataFree
        call itoa10

        mov AH, 09h
        mov DX, offset dataFree
        int 21h

        TERMINATE

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Register-based functions
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

;==============================================
; Returns the position of the first entry
; of the key in string. Stops if ENDL (00h) symbol is encountered
; Expects:
;       AH - Key (Letter to look for)
;       SI - String address
; Returns:
;       SI - Address of the first entry (if found)
;       AL - Key if found; 00h if not
; Destr:
;       AX
;==============================================

strchr  proc

@@ChLoop:
        lodsb                   ; save [SI] to AL
        cmp AL, AH              ; check if key
        je  @@FIN

        sub AL, ENDL            ; check if line ended
        jz  @@FIN

        jmp @@ChLoop

@@FIN:
        dec SI                  ; last inc was obsolete
        ret
endp

;==============================================
; Counts sting length. Stops, if ENDL (00h) sign
; is encountered. ENDL sign is not included in str len
; Expects:
;       ES - String segment
;       SI - Target string address
; Returns:
;       CX - String length in bytes
;       SI - String end address
;==============================================

strlen  proc
        xor CX, CX

@@ChLoop:
        cmp BTP ES:[SI], ENDL           ; check if line ended
        je  @@EOL
        inc CX                          ; length counter
        inc SI
        jmp @@ChLoop

@@EOL:
        ret
endp

;==============================================
; Copies n bytes of string into buffer. Puts
; ENDL (00h) symbol at the end of the str.
; Expects:
;       CX - Number of bytes to copy
;       DI - Buffer of length >= n + 1
;       DS - String segment
;       ES - Buffer segment
;       SI - String address
; Returns:
;       CX - 00h if successful, non-zero value if not
; Destr:
;       AX
;==============================================

strncpy proc

@@CpyByte:
        lodsb                           ; copy 1 byte to AL
        cmp AL, ENDL                    ; check if byte is 00h
        je  @@EOL
        stosb                           ; [DI] = AL 

        Loop @@CpyByte

@@EOL:
        mov BTP [DI], ENDL              ; ENDL symbol
        ret
endp

;==============================================
; Compares first n symbols of two strings
; Expects:
;       CX - Number of sybmbols to compare
;       DI - First string
;       SI - Second string
;       ES - Second string segment
; Returns:
;       AL - 00h if strings are identical;
;            (Char2 - Char1) if different
;            symbols are encountered
; Destr:
;       AX
;==============================================

strncmp proc
        xor AX, AX

@@ChLoop:
        mov AH, BTP ES:[DI]             ; first str byte
        inc DI

        lodsb                           ; second str byte

        sub AL, AH                      ; compare the two
        jne @@ENDCmp

        cmp AH, 00h                     ; if stings ended, return
        je  @@ENDCmp
        
        Loop @@ChLoop

@@ENDCmp:
        ret
endp

;==============================================
; Converts integer value into a string, base 2^n
; Expects:
;       CL - Base = power of 2
;       DX - Integer value
;       DI - Buffer to write str into
;       ES - Buffer segment
; Returns:
;       DI - Result string
; Destr:
;       AX, BX, CX
;==============================================

itoa    proc
        call CountBytes
        
        add DI, AX                      ; save space for elder bits in buff: _ _ _ DI: _
        
        xor BX, BX                      ; BX = CL
        mov BL, CL

        mov BTP ES:[DI], '$'            ; put $ as last byte: _ _ _ _ $
        dec DI                          ; _ _ _ DI: _ $

        mov CH, [BX + offset BASE]      ; get base sign
        mov BTP ES:[DI], CH             ; put it in the end of string: _ _ _ DI: b $
        dec DI

        mov AX, 01b                     ; mask = 0..01b
        shl AX, CL                      ; mask = 0..010..0b
        dec AX                          ; mask = 0..01..1b

@@BitLoop:
        mov BX, AX

        and BX, DX                      ; apply mask to DX
        shr DX, CL                      ; cut off masked bits: 01010011 -> 001010|011

        mov BL, BTP [BX + offset HEX]
        mov BTP ES:[DI], BL

@@CmpZero:
        dec DI                          ; moving backwards: _ _ DI: _ 0 1 0 $
        cmp DX, 00h                     ; check if the whole value has been printed
        ja  @@BitLoop

        ret
endp

;==============================================
; Counts amount of bytes needed to save the
; number into buffer
;
; Expects:
;       DX - Value
;       CL - Base
; Returns:
;       AX = AL - amount of bytes needed
;==============================================

CountBytes proc
        mov AX, DX                      ; save value in ax to count bits in it
        xor CH, CH

@@Loop:
        inc CH                          ; bytes counter
        shr AX, CL                      ; AX >> 1
        jnz @@Loop

        mov AL, CH

        ret
endp

;==============================================
; Converts integer value into a string, base 10
; Expects:
;       AX - Integer value
;       DI - Buffer to write into
;       ES - Buffer segment
; Returns:
;       None
; Destr:
;       DX, CX, BX
;==============================================

itoa10  proc
        mov CX, AX                      ; save value to CX
        mov BX, 10d

@@CntBytes:                             ; skips, bytes that are required to save the value
        xor DX, DX                      ; reset remaining
        div BX                          ; AX = AX / 10; DX = AX % 10

        inc DI
        cmp AX, 0000h
        ja @@CntBytes

        mov AX, CX                      ; reset value

        mov WDP ES:[DI], '$d'
        dec DI

@@Print:
        xor DX, DX
        div BX                          ; AX = AX / 10; DX = AX % 10
        
        add DL, '0'                     ; to ASCII
        mov BTP ES:[DI], DL
        dec DI

        cmp AX, 0000h
        ja @@Print

        ret
endp

;==============================================
; Translates number base 10 
; from string to integer value
; Expects:
;       SI - String ptr
; Returns:
;       AX - Value
; Destr:
;       DX, BX
;==============================================

atoi    proc
        xor AX, AX

@@Loop:
        xor BX, BX
        mov BL, BYTE PTR [SI]   ; DX = [SI]
        inc SI

        cmp BL, ENDL            ; if [SI] == \0
        je  @@FIN               ; jmp to Loop
        
        mov DX, 10d
        mul DX                  ; AX *= 10d

        sub BX, '0'             ; ASCII to value
        add AX, BX              ; AX = 10 * AX + [SI]

        jmp @@Loop

@@FIN:
        ret
endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Stack-based functions
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

strchr_s proc pascal
ARG @Key: BYTE, @Str: WORD = ARGS
        mov AH, @Key
        mov SI, @Str

        call strchr
        ret
endp

strlen_s proc c
ARG @Str: WORD, @Seg: WORD
USES ES, SI
        mov SI, @Str
        mov ES, @Seg

        call strlen
        ret
endp

strncpy_s proc pascal
ARG @Num: WORD, @Buf: WORD, @StrSeg: WORD, @BufSeg: WORD, @Str: WORD
USES AX, DI, DS, ES, SI
        mov CX, @Num
        mov DI, @Buf
        mov DS, @StrSeg
        mov ES, @BufSeg
        mov SI, @Str

        call strncpy

        ret
endp

HEX       db '0123456789ABCDEFGHIJKLMNOP'
BASE      db ' bqoh'
dataKira  db 'Watashi no na wa Kira Yoshikage', 00h
dataShort db 'Kono DIO da!', 00h
dataCmp   db 'Kono Nijimura Okuyasu no za hando ga kesu!', 00h
dataFree  db 10h dup(00h)
dataDec   db '65535', 00h

end _start