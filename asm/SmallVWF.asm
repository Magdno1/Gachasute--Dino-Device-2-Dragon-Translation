 ; Dino Device 2 VWF by Normmatt

.gba				; Set the architecture to GBA
.open "rom/output.gba",0x08000000		; Open input.gba for output.
					; 0x08000000 will be used as the
					; header size
					
.macro adr,destReg,Address
here:
	.if (here & 2) != 0
		add destReg, r15, (Address-here)-2
	.else
		add destReg, r15, (Address-here)
	.endif
.endmacro

.org 0x0800D244
	bl putChar
	b 0x0800D26C
	
.org 0x0800D2A8
	.word unkCmd0
	
.org 0x0800D308
	.word NewLine       ; New Line function address
	
.org 0x0800D318
	.word EndTextBox    ; End Textbox function address
	
.org 0x0800D324
	.word EndText       ; End Text function address
	
.org 0x0800E0F6
	bl NewTextBox       ; New Textbox function

.org 0x083C0000 ; should be free space to put code
.definelabel Copy1BppCharacter,0x0800BD70

; r0 - destination
; r1 - character
; r2 - character color
; r3 - bg color
putChar:
	PUSH    {R4-R7,LR}
    ADD     SP, #-0x24
    ADD     R4, R0, #0      ; r4 = Destination
    ADD     R0, R1, #0      ; r0 = Character to print
    ADD     R1, R2, #0      ; r1 = character colour (1 is default, 8 is blue)
    ADD     R2, R3, #0      ; r2 = bg colour
    LDR     R3, [SP,#0x38]  ; r3 = shadow colour
    LSL     R0, R0, #0x10   ; casting to u16
    LSR     R0, R0, #0x10
    LSL     R1, R1, #0x18   ; casting to u8
    LSR     R1, R1, #0x18
    LSL     R2, R2, #0x18   ; casting to u8
    LSR     R2, R2, #0x18
    LSL     R3, R3, #0x18   ; casting to u8
    LSR     R3, R3, #0x18
    ADD     R5, SP, #4
    STR     R5, [SP]        ; r5 = buffer?
	
	mov     r6, r0 ;store character for a second
	mov     r7, r2 ;store bg color
    BL      Copy1BppCharacter
	
	;mov r2, #5	; r2 = width, replace this with lookup table
	ldr r2, =WidthTable
	ldrb r2, [r2,r6]
	
	bl GetNextTileAddress
	mov r3, r4
	mov r4, r0
	
	ldr r6, [overflow]
	ldrb r1, [r6]
	mov r5, r1	; r5 = current overflow
	add r1, r1, r2	; r1 will be new overflow, r2 is spare after this
	cmp r1, #8
	ble NoNewTile	; if overflow >8 move to next tile
    mov r2, #8
	sub r1, r1, r2
	; clear next tile
	mov r0, r4
	
	ldr r2, [mask]
	mul r2, r7 ; times 0x11111111 by the bg color pallete index
	str r2, [r0, #0]
	str r2, [r0, #4]
	str r2, [r0, #8]
	str r2, [r0, #12]
	str r2, [r0, #16]
	str r2, [r0, #20]
	str r2, [r0, #24]
	str r2, [r0, #28]
	
	; original code to increment stuff
	LDR     R2, =0x200471C
	LDR     R0, [R2,#0x30]
	ADD     R0, #1          ; increment map address
	STR     R0, [R2,#0x30]
	;LDR     R0, [R2,#0x34]
	BL      GetNextTile
	STR     R0, [R2,#0x34]

NoNewTile:
	strb r1, [r6]

	lsl r5, r5, 2	; *4, for 4bpp
	mov r6, #0x20	; i feel like this code should be somewhere else
	sub r6, r6, r5	; r6 is to shift the existing background

	mov r0, sp
	add r0, #4
	;r0 = font, r3 = VRAM, r4 = overflow tile, r5 will be shift

	bl PrintHalfChar

UpdateMapTile:
	LDR     R4, =0x200471C
	ADD     R0, R4, #0
	ADD     R0, #0x8C
	LDR     R5, [R0]
	
	LDR     R3, [R4,#0x30]
	LDR     R0, [R4,#0x10]
	LSL     R2, R3, #1
	ADD     R2, R2, R0
	LDRB    R0, [R5,#0x16]
	LSL     R0, R0, #0xC
	LDR     R1, [R4,#0x34]
	ORR     R0, R1
	STRH    R0, [R2]
	
	; r0 should return tile address
	;LDR     R0, [R3,#0x44]
	
putChar_Exit:
	ADD  	SP,#0x24
	POP     {R4-R7,PC}
	
PrintHalfChar:
	mov r7, 0	; r7 = loop counter

PrintHalfChar_loop:
	ldr r1, [r0,r7] ; sp = character data
	ldr r2, [r3,r7]
	lsl r1,r5
	lsl r2,r6	; shift out part of background to be overwritten
	lsr r2,r6	
	orr r1,r2
	str r1, [r3,r7]

	ldr r1, [r0,r7] ; now do overflow tile
	ldr r2, [r4,r7]
	lsr r1,r6	; swap shifts (i think this will work)
	lsr r2,r5
	lsl r2,r5	
	orr r1,r2
	str r1, [r4,r7]

	add r7,r7,4	; each row = 4 bytes
	cmp r7, #0x20	; are 8 rows printed?
	bne PrintHalfChar_loop
	bx r14
	
GetNextTile:
	push {r1-r3}
	LDR     R2, =0x200471C
	LDR     R0, [R2,#0x34]
	ADD     R0, #1          ; increment tile address
	
	ADD     R1, R2, #0
	ADD     R1, #0x8C
	LDR     R3, [R1]

	;Handle case where tile address wraps around
	LDRH    R1, [R3,#0x10]
	CMP     R0, R1
	BLS     GetNextTile_skip

	LDRH    R0, [R3,#0xE]

GetNextTile_skip:
	pop {r1-r3}
	bx lr
	
GetNextTileAddress:
	push {r1-r3}
	LDR     R2, =0x200471C
	LDR     R0, [R2,#0x34]
	ADD     R0, #1          ; increment tile address
	
	ADD     R1, R2, #0
	ADD     R1, #0x8C
	LDR     R3, [R1]

	;Handle case where tile address wraps around
	LDRH    R1, [R3,#0x10]
	CMP     R0, R1
	BLS     GetNextTileAddress_skip

	LDRH    R0, [R3,#0xE]
	
GetNextTileAddress_skip:	
	LSL     R0, R0, #5
	LDR     R1, [R2,#0xC]
	ADD     R0, R0, R1      ; dest
	pop {r1-r3}
	bx lr

ResetOverflow:
	; reset overflow
	mov r0, #0
	ldr r1, [overflow]
	str r0, [r1]
	bx lr

 ;Reset overflow on unkCmd0 call
unkCmd0:
	bl ResetOverflow
	ldr r0, [unkCmd0_returnAdr]
	bx r0
	
 ;Reset overflow on new textbox call
NewTextBox:
	mov r0, #0
	ldr r1, [overflow]
	str r0, [r1]
	
	LDR     R0, =0x200471C
	LDR     R0, [R0]
	bx lr
	
 ;Reset overflow on end textbox call	
EndText:
	bl ResetOverflow
	ldr r0, [EndText_returnAdr]
	bx r0
	
 ;Reset overflow on end textbox call	
EndTextBox:
	bl ResetOverflow
	ldr r0, [EndTextBox_returnAdr]
	bx r0
	
 ;Handle New Line
 ;r0 and r1 are free
NewLine:
	bl ResetOverflow
	; original code to increment stuff
	LDR     R1, =0x200471C
	LDR     R0, [R1,#0x30]
	ADD     R0, #1          ; increment map address
	STR     R0, [R1,#0x30]
	LDR     R0, [R1,#0x34]
	ADD     R0, #1          ; increment tile address
	STR     R0, [R1,#0x34]
	
	ldr r0, [NewLine_returnAdr]
	bx r0
    
.align 4
EndText_returnAdr:      .word 0x0800D328+1
EndTextBox_returnAdr:   .word 0x0800D34A+1
NewLine_returnAdr:      .word 0x0800D340+1
unkCmd0_returnAdr:      .word 0x0800D350+1
overflow:  .word 0x03000000  ; my notes say this is free
mask:      .word 0x11111111  ; mask
.pool

WidthTable:
.incbin asm/bin/smallWidthTable.bin

.close

 ; make sure to leave an empty line at the end
