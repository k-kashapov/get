.model tiny
.code
org 100h

;##############################################
; Runs Bad Apple on DOS
; Regs:
;   AH = AL - byte just read
;   BH - color
;   BL - curr printed byte
;   CX - print counter
;   ES - videosec
;   DI - byte to print to
;   SI - bytes array
;##############################################

WID     equ 74
HGT     equ 19
PIX1    equ 20h                 ; white
PIX0    equ 03h                 ; black

_start:
    mov si, 0000h               ; bytes array
    mov ax, 0B800h              ; videosec
    mov es, ax

    mov AX, 0000h
    mov DS, AX
    
    xor di, di
    mov bh, 07h                 ; black on white

LdByte:
    mov bl, PIX1
    lodsb                       ; al = [si]
    mov ah, al
    and al, 1                   ; test if lowest byte is 1
    jnz FlagChk

    mov bl, PIX0

;----------------------------------------------
; Check if len is < 64
;----------------------------------------------
FlagChk:
    xor cx, cx

    mov cl, ah
    shr cx, 2h          ; check if top 6 bytes != 0
    jnz Print           ; if != 0, start printing

    jb TwoAdd
;----------------------------------------------
; Get next byte as printing len. CX initially = 0
;----------------------------------------------
    lodsb
    mov cl, al          ; cx = next byte value

    jmp Print

;----------------------------------------------
; Get next 2 bytes as printing len. CX initially = 0
;----------------------------------------------
TwoAdd:                 ; cx = [si] + 256d * [si + 1]
    lodsw
    mov cx, ax

    jmp Print

Print:
    mov es:[di], bl         ; print to videomem char
    inc di
    mov es:[di], bh         ; print to videomem color
    inc di

    inc dx
    dec cx

    cmp dx, 75d             ; check if line ended
    jb Print2               ; if not, proceed

    xor dx, dx
    add di, 5d * 2d         ; if > 75, change line

Print2:
    cmp di, 80d * 20d * 2d - 1  ; check if frame ended
    ja  FrameEnd

    jcxz LdByte
    jmp Print

FrameEnd:
    xor di, di
    mov di, cx

    mov cx, 0FFFFh

FrameWait1:
    loop FrameWait1
    
    mov cx, 0FFFFh

FrameWait2:
    nop
    nop
    nop
    loop FrameWait2

    mov cx, di
    xor di, di

    jmp Print

ProcEnd:
    mov ax, 4C00h
    int 21h

WAIT_FLAG db 00h
DATA_END db 1 dup(?)

end _start