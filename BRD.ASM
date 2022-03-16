.model tiny
.code
org 100h

_start:

GetS	proc	
		mov ah, 0Ah					; get buffered input
		mov dx, offset INBYTES		; buffer ptr
		int 21h

		xor cx, cx
		mov cl, byte ptr INBYTES + 1	; save input len to cl
		add cl, 2						; make neat spaces on the left and right
		mov ch, cl						; save also to the ch
		ret
endp

.data

INBYTES	db 10h, 10h dup(0)	; mem reserved for kbrd input

end _start
