.186
.model tiny
.code
org 100h

locals @@

STAYRES macro                           ; terminates the program and keeps it resident
        mov AX, 3100h
        mov DX, offset DataEnd          ; save in DX the amount of paragraphs needed
        add DX, 15d                     ; DX += 15 in case right shift drops any neccessary bits off
        shr DX, 04h                     ; paragraph = 16 bytes
        int 21h
endm

KBRD_ACK macro
        mov AH, AL                      ; save last read scancode byte to AH
        or  AL, 80h                     ; 0....b -> 1....b
        out 61h, AL                     ; send changed byte to kbrd ctrl
        mov AL, AH                      ; AL = saved Byte
        out 61h, AL                     ; send original byte to kbrd ctrl
endm

EOI     macro
        mov AL, 20h
        out 20h, AL
endm

CUR_INT = 08h * 4                       ; addr of the int to save. Init val = 08h = Time Int
INT_BUF equ Old08                       ; name of the buf to save old int to

SAVE_INT macro                          ; saves int at [CUR_INT], [CUR_INT + 2] to INT_BUF
        mov BX, CUR_INT                 ; curr cell of int table

        mov DI, offset INT_BUF          ; DI = &OldInt
        
        mov AX, WP ES:[BX]              ; Save old int addr to AX
        mov [DI], AX                    ; Save it to OldInt's lower 2 bytes

        mov AX, WP ES:[BX + 2]          ; Save old int seg to AX
        mov [DI + 2], AX                ; Save seg to OldInt's eldest 2 bytes
endm

SCR_WIDTH equ 160d		        ; screen width in bytes
WP        equ WORD PTR

_start:
        xor BX, BX
        mov ES, BX                      ; ES = 0000h

        SAVE_INT                        ; save int 08h
        
        cli                             ; Forbid interrupts
                                        ; Put our own Seg:Addr into int table

        mov WP ES:[BX], offset Res08    ; Addr

        mov AX, CS                      ; Segment
        mov WP ES:[BX + 2], AX

        sti                             ; Allow interrupts

        mov AX, 3509h                   ; Changing int by the means of DOS
        int 21h                         ; Getting old int 09h

        mov WORD PTR Old09, BX          ; saving into memory
        mov WORD PTR Old09 + 2, ES      ; old int 09h

        mov AX, CS
        mov DS, AX

        mov DX, offset Res09            ; Setting ourn own int
        mov AX, 2509h
        int 21h

        STAYRES                         ; Terminate and stay resident

;==============================================
; Draws a line on the screen
;
; Expects: 
;	AH - Color of the line
;	CX - Length of the line
; 	SI - addr of 3-byte line style array
;	BX = DI - addr of start of line
;
; Note:
;	ES = videoseg addr (0b800h)
;	BX += number of empty lines * width of the line
;       SI += 3
;
; Returns:  
;       None
;==============================================

DrawLine proc
				; UL corner
	lodsb			; ld byte from [si] to al
	stosw			; mov al to es:[di]
	
        jcxz @@Ret

	lodsb			; U prt
	rep stosw	        ; repeat stosw while cl > 0

	lodsb			; TR corner
	stosw

@@Ret:
	add BX, SCR_WIDTH	; bx = rows offset
	ret
endp

;==============================================
; Converts integer value into a string, base 16
; Expects:
;       DX - Integer value
;       SI - Buffer to write str into
;       DS - Buffer segment
; Returns:
;       SI - Result string
;==============================================

itoa16  proc
        pusha                           ; save all registers
        mov DI, SI                      ; save init SI value
        add SI, 3                       ; save space for significant bytes: _ _ _ _ SI: _ h

@@BitLoop:
        mov BX, 0Fh                     ; mask = 0..01111b

        and BX, DX                      ; apply mask to DX
        shr DX, CL                      ; cut off masked bits: 01010011b -> 00101|0011b

        mov BL, BYTE PTR DS:[BX + offset HEX]
        mov BYTE PTR DS:[SI], BL

        dec SI                          ; moving backwards: _ _ DI: _ 0 1 0 $
        cmp SI, DI                      ; check if all bytes have been printed
        ja  @@BitLoop

        popa                            ; reset all registers
        ret
endp

;==============================================
; Draws str from buffer to the video RAM
; Expects:
;	AH - Color
;	CL - Width
;	DI - Addr to draw to
;	SI - Addr of 3-byte char array
;	RegVal - Buffer
; Note:
;	ES = videoseg addr (0b800h)
;==============================================

DrawStr proc
        lodsb				; load from [si] to al
	stosw				; draw border
		
	push SI				; save si (pointing at the middle elem) to the stack
		
	lodsb
	stosw				; draw empty space

	mov SI, offset RegVal

@@PutC:
	lodsb				; load from array to al
	stosw				; print input str to video RAM
	dec CL
	ja  @@PutC

	pop SI				; return si value

	lodsb				; draw empty space
	stosw

	lodsb				; draw border
	stosw

	add BX, SCR_WIDTH		; iterate row

	ret
endp

;==============================================
; Draws frame during 08 int
;==============================================

;##############################################
; VIDEOPAGES AND DOUBLE BUFFERIZATION:
;
;----------------------------------------------
;       0 <-- Actual video memory. We see this 
;             on screen
;       
;       ADDR = 0b800h:DI
;
;----------------------------------------------
;       1 <-- Video memory clone. We restore
;             original image from here after 
;             the frame is turned off
;
;       ADDR = 0b800h:DI + 80 * 25  *  2
;                          ↑    ↑      ↑
;                        width  |      |
;                             height   |
;                                      |
;                           sym on scr = 2 bytes
;----------------------------------------------
;       2 <-- Last drawn frame. We compare it 
;             to the updated video memory to 
;             update 1st page respectively
;
;       ADDR = 0b800h:DI + 80 * 25 * 2 * 2
;##############################################

DrawFrame proc pascal
USES AX, BX, CX, DX, DI, DS, ES, SI
        push AX BX CX DX                ; save main registers to stack

        mov AX, CS                      ; set DS to curr code segment
        mov DS, AX

        mov AX, 0B800h                  ; save video segment to ES
        mov ES, AX

        mov DI, CS:CURDI                ; set DI to the saved position

        mov BX, DI                      ; save offset to BX
        mov AH, 09h                     ; color = blue on black

        mov SI, offset BRD              ; border symbols array
        mov CX, 6d                      ; width
        call DrawLine                   ; draw top line

        mov CH, 4d                      ; num of iterations of the next loop

@@RegLoop:
        mov CL, 4d                      ; reset width
        pop DX                          ; pop AX, BX, CX, DX from stack to DX
        mov DI, BX                      ; move DI to new printing position

        mov SI, offset RegVal           ; buffer to print register value into
        call itoa16                     ; print reg (popped to DX) value to buffer

        mov SI, offset BRD + 3          ; set SI to border chars arr
        call DrawStr                    ; draw reg value
        
        dec CH
        ja  @@RegLoop                   ; repeat 4 times: for each register

        mov DI, BX                      ; set new DI
        mov CX, 6d                      ; bottom line width
        call DrawLine                   ; draw bottom line

        ret
endp

;==============================================
; Compares video memory buffers on pages 0
; and 2. If any byte is changed, updates page 1
; buffer. As a result, page 1 will contain
; relevant screen image
; Expects:
;       CH - Width
;       CL - Height
;       CS:CURDI - video offset to start from
; Regs:
;       AL - Saved width
;       ES - Video Segment 0b800h
;       DS - Video page 1 segment
;            DS = 0b800h + 80 * 25 * 2 / 16
;       DI - Video page 0 and 1 iterator
;       SI - Video page 2 iterator
;
; Note:
;       SI = DI + 80 * 25 * 2 
;       SI points at the same coordinates as
;       DI, but on the next page
;
;==============================================

;##############################################
; Explanation:
;    PAGE 0:
;       xxxxxxxxxxxx    
;       x    1     x - A byte has just been
;       x    ↑     x   updated.
;       x [ES:DI]  x   
;       xxxxxxxxxxxx   NEXT: PAGE 2
;
;   PAGE 1:
;       xxxxxxxxxxxx    
;       x    9     x - So we update our screen
;       x    ↑     x   copy: 9 -> 1.
;       x [DS:DI]  x   
;       xxxxxxxxxxxx   NEXT: FINALLY
;
;   PAGE 2:
;       xxxxxxxxxxxx    
;       x    4     x - We compare it to the
;       x    ↑     x   previous screen state.
;       x [DS:SI]  x   They are not equal. (4 != 1)
;       xxxxxxxxxxxx   NEXT: PAGE 1
; 
;       FINALLY:
;               After that, we print the newest
;               version of frame into Page 2 buffer
;##############################################

UpdateBuf proc pascal
USES AX, BX, CX, DI, DS, ES, SI
        mov AX, 0B800h                  ; save video segment to ES
        mov ES, AX

        add AX, 80 / 16 * 25 * 2        ; DS = ES + page size
        mov DS, AX                      ; = video page 1 segment

        mov DI, CS:CURDI                ; set DI to the saved position
        mov SI, DI                      ; set SI = DI

        add SI, 80 * 25 * 2             ; videopage 2
        
        xor AX, AX
        mov AL, CH                      ; save width to AL

@@Loop:
        mov BX, ES:[DI]                 ; save page 0 byte to AH
        cmp DS:[SI], BX                 ; compare pages 0 and 2
        je  @@Continue                  ; if they are equal, continue comparing
                                        ; else
        mov DS:[DI], BX                 ; update page 1 byte with AH

@@Continue:
        add SI, 2                       ; iterate width
        add DI, 2

        sub CH, 2
        cmp  CH, 00h                    ; if not end of the line
        ja   @@Loop                     ; repeat

        mov  CH, AL                     ; reset width

        sub  DI, AX                     ; move iterator back to first symbol
        sub  SI, AX                     ; of the line

        add  DI, 80d * 2                ; next line
        add  SI, 80d * 2                ; next line

        dec  CL                         ; iterate height
        cmp  CL, 00h
        ja   @@Loop

        ret
endp

;==============================================
; Our resident function
; Registers:
;       AX - Color|symbol
;       BX = DI - Video addr to write into
;       DS - Curr (code) segment
;       ES - Video segment
;       SI - Border buffer
;       CX - Border len
;==============================================

Res08   proc
        cmp CS:ISOn, 00h                        ; if frame is off
        je  @@NoFrame                           ; do nothing

        push CX
        mov CX, 1006h                           ; set Width|Height
        call UpdateBuf                          ; Update screen buffer
        pop CX

        call DrawFrame                          ; draw frame to the video page 2
        
        ; Copy Buffer to Screen
        push DI CX SI DS BX

        mov DI, CS:CURDI                        ; DI = top-left corner
        mov SI, DI                              ; SI = DI
        
        mov CX, 0B800h + 80 / 16 * 25 * 2 * 2   ; segment of page 2
        mov DS, CX                              ; DS = 0b800h + page size
        
        mov CX, 1006h                           ; CX = Heigth|Width
        
        mov BH, 01h                             ; BH = 1 - copy from buffer to screen
        call CpyBuf
        pop BX DS SI CX DI

@@NoFrame:
        db 0EAh                                 ; longjmp
Old08   dd 0                                    ; to the original int 08h
endp

;==============================================
; Checks if arrow key is pressed
; Expects:
;       AL - key scancode
; Returns:
;       CX += relative offset
;             Up    += -80 * 12
;             Down  +=  80 * 12
;             Left  += -16
;             Right +=  16
;==============================================

ChkArr  proc
        cmp AL, 4Bh                     ; left arrow key
        jne @@RArr
        sub CX, 4

        jmp @@Fin

@@RArr:
        cmp AL, 4Dh                     ; right arrow key
        jne @@UArr

        add CX, 4
        jmp @@Fin 

@@UArr:
        cmp AL, 48h                     ; Up arrow key
        jne @@DArr

        sub CX, 80d * 4
        jmp @@Fin

@@DArr:
        cmp AL, 50h                     ; Up arrow key
        jne @@Fin

        add CX, 80d * 4
@@Fin:
        ret
endp

RSHIFT  equ 36h
LSHIFTD = 2Ah
LSHIFTU = 2Ah or 80h

;==============================================
; Draws (or saves) a rectangle from (to) buffer 
; to (from) the screen
; Expects:
;       DI - Top-Left corner of the border
;       CH - Height
;       CL - Width
;       SI - Buffer to draw from
;       DS - Segment to draw from
;       BH - 00h  = copy from scr to buf
;            else = copy from buf to scr
;==============================================

CpyBuf proc pascal
USES AX, ES
        mov AX, 0B800h                          ; ES = video buffer
        mov ES, AX

        xor AX, AX
        mov AL, CH                              ; save width to AL

@@LineLoop:
        cmp BH, 00h                             ; if BH != 0, copy from screen to buffer
        jne @@Saving

        mov BL, DS:[SI]                         ; copy bytes to videomem
        mov ES:[DI], BL
        jmp @@Moving

@@Saving:
        mov BL, ES:[DI]                         ; save bytes to buffer
        mov DS:[SI], BL

@@Moving:
        inc  SI
        inc  DI

        dec  CH                                 ; iterate width
        cmp  CH, 00h
        ja   @@LineLoop
        
        mov  CH, AL                             ; reset width

        sub  DI, AX                             ; move DI back to the first byte
        sub  SI, AX                             ; move SI back to the first byte

        add  DI, 80d * 2                        ; next line
        add  SI, 80d * 2                        ; next line

        dec  CL                                 ; iterate height
        cmp  CL, 00h
        ja   @@LineLoop

        ret
endp

;==============================================
; Turns the frame on/off. Draws buffer data 
; on screen or copies a rectangle into it
;
; Expects:
;       CS:ISOn  - On/Off flag
;                  00h = Off
;                  Else = On
;       CS:CURDI - Video offset
;==============================================

SwitchOn proc pascal
USES AX, BX, CX, DI, DS, SI, ES
        mov BH, CS:ISOn                 ; On/Off flag to BH

        mov DI, CS:CURDI                ; set DI to current top-left pos

        mov SI, DI
        add SI, 80 * 25 * 2             ; video page 2

        mov AX, 0B800h                  ; save video segment to ES
        mov ES, AX
        mov DS, AX                      ; DS = ES

        mov CX, 1006h                   ; CX = Width|Height
        
        call CpyBuf

        ret
endp

;----------------------------------------------
;       THE FEATURE
;       Allows you to move frame by 
;       pressing Shift + U/D/L/R
;----------------------------------------------
Res09   proc
        push ES DI CX AX

        xor CX, CX                      ; CX = 0
        in  AL, 60h                     ; read from kbrd buffer
        cmp AL, RSHIFT                  ; if right shift
        jne @@CheckOn

        not CS:ISOn                     ; turn on/off
        call SwitchOn
        jmp @@Fin

@@CheckOn:
        cmp CS:ISOn, 00h                ; if frame is off
        je  @@Fin                       ; do nothing

        cmp AL, LSHIFTD                 ; check if left shift is down
        jne @@CheckLshiftUP

        mov LShDwn, 01h                 ; change L shift flag
        jmp @@LShiftDown

@@CheckLshiftUP:
        cmp AL, LSHIFTU                 ; check L shift is released
        jne @@CheckLshift

        mov LShDwn, 00h                 ; if released, turn flag off
        jmp @@Fin

@@CheckLshift:
        cmp LShDwn, 00h                 ; check if left shift flag 
        je  @@Fin

@@LShiftDown:                           ; if left shift is pressed, check arrow keys
        push CX
        xor CX, CX                      ; CX = 0

        call ChkArr                     ; CX += video offset

        cmp CX, 0000h
        je @@JustShift                  ; if no arrow key pressed, run original int

        not CS:ISOn                     ; when moving: turn the frame off
        call SwitchOn                   ; print buffer to screen

        add CS:CURDI, CX                ; update top-left corner pos
        pop CX

        not CS:ISOn                     ; turn on
        call SwitchOn                   ; save from screen to buffer

        KBRD_ACK
        EOI

        pop AX CX DI ES
        iret

@@JustShift:
        pop CX

@@Fin:
        pop AX CX DI ES
        db 0EAh                         ; longjmp to old 09h
Old09   dd 0

endp

RegVal  db 4 dup ('0'), '$'
HEX     db '0123456789ABCDEFghijklmnop'
BRD	db 0DAh, 0C4h, 0BFh, 0B3h, 0B1h, 0B3h, 0C0h, 0C4h, 0D9h	; std border 1 symbols
CURDI   dw (80 * 2 - 8) * 2
ISOn    db 00h
LShDwn  db 00h


DataEnd:
end _start
