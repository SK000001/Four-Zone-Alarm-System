; Define variables.
.def  temp  = r16
.def temp2 = r17
.def t = r18
.def output = r19
.def flg = r20
.def count = r24
.def flag = r25

.equ SP = 0xDF

; Reset Vector.
reset:
   rjmp start

start:
	LDI  temp,  SP		; Init Stack pointer
	OUT  0x3D,  temp

Init:
	.equ colIdle = 0xff

	; hex values for columns
	.equ col1 = 0xef
	.equ col2 = 0xdf
	.equ col3 = 0xbf
	.equ col4 = 0x7f

	ldi temp, 0xff
	out DDRB, temp

	ldi temp, 0xf0
	out DDRC, temp

	ldi temp, 0x0f
	out PORTC, temp

	; Set the pull-up resistor values on PORTC.
	ldi temp, colIdle
	out PORTC, temp

	in temp, PINC
	ldi output, 0x80
	out PORTB, output		; disarmed state

	call initPasscodeInput
	jmp loadPasscodeInputLoop

initPasscodeInput:
	LDI ZH, high(passcode << 1)			; Load the high-byte address
	LDI ZL, low(passcode << 1)			; Load the low-byte address

	clr r27
	ldi r26, 0x60
	ldi count, 6
	ret

loadPasscodeInputLoop:
	lpm temp, Z+
	st X+, temp
	dec count
	brne loadPasscodeInputLoop

loop:
	in output, PINB

	ldi count, 0
	ldi flg, 0
	cpi output, 0x80
	breq passcodeEntryDisarm

	ldi flg, 1
	cpi output, 0x40
	brge passcodeEntryArm

    JMP loop

passcodeEntryDisarm:
	cpi count, 6
	breq prePasscodeVerification

	call ReadKp

	cpi output, 15
	breq prePasscodeReset

	cpi output, 10
	brge disarmedState

	push output				; push to passcode Input
	inc count

	jmp passcodeEntryDisarm

disarmedState:
	ldi output, 0x80
	out PORTB, output
	jmp loop

prePasscodeReset:
	ldi count, 6

passcodeResetEntry:
	call ReadKP

	cpi output, 10
	brsh error

	push output

	dec count
	brne passcodeReset

	CLR R27									; Clear the high byte of X.
	LDI R26, 0x65							; Set the base address of RAM.

passcodeReset:
	pop output
	st X, output

	cpi XL, 60
	rjmp loop
	dec XL

passcodeEntryArm:
	in t, PINB
	ldi temp, 16
	mul t, temp
	clr temp

	cpi count, 6
	breq prePasscodeVerification

	call ReadKp

	cpi output, 14
	brge error

	ldi temp2, 0
	cpi output, 10
	breq PreTriggerZone

	ldi temp2, 1
	cpi output, 11
	breq PreTriggerZone

	ldi temp2, 2
	cpi output, 12
	breq PreTriggerZone

	ldi temp2, 3
	cpi output, 13
	breq PreTriggerZone

	push output // push to passcode Input
	inc count

	jmp passcodeEntryArm

error:
	cpi count, 0
	breq toloop

	pop temp
	dec count
	jmp error

toloop:
	jmp loop

prePasscodeVerification:
	call initPasscodeInput

	LDI R26, 0x65							; Set the base address of RAM.

passcodeVerification:
	pop output

	ld r0, X
	cp r0, output
	brne error

	cpi XL, 60
	jmp postPasscodeVerification
	dec XL

postPasscodeVerification:
	ldi flag, 0
	cpi flg, 0
	breq armedState

	jmp disarmedState

armedState:
	ldi output, 0x40
	out PORTB, output
	jmp loop

PreTriggerZone:				; t = prevZones and temp2 = Zone
	cpi flag, 1
	breq TriggerZone

	ldi flag, 0x20
	in output, PORTB
	eor output, flag
	out PORTB, output

	ldi flag, 1

TriggerZone:
	ldi count, 10
	call triggerStrobe
	
	ldi count, 0xF0
	in output, PORTB
	and output, count

	lsr t
	lsr t
	lsr t
	lsr t

	or output, temp

	ldi count, 1

TriggerCertainZone:
	cpi temp2, 0
	breq postTriggerZone

	lsl count

	dec temp2
	jmp TriggerCertainZone

postTriggerZone:
	eor output, count
	out PORTB, output

	in output, PINB
	
	jmp loop

triggerStrobe:
	in output, PORTB
	push flag
	ldi flag, 16

	eor output, flag
	out PORTB, output

	pop flag

	call Delay

	dec count
	cpi count, 1
	brne triggerStrobe
	RET
	

ReadKP:
	; scan col1
	ldi temp, col1		; r16 = 0xef
	out PORTC, temp		; set PORTC to r16 value
	call Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0xef and r17 = 0xee / 0xed / 0xeb / 0xe7 )

	; scan col2
	ldi temp, col2		; r16 = 0xdf
	out PORTC, temp		; set PORTC to r16 value
	call Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0xdf and r17 = 0xde / 0xdd / 0xdb / 0xd7 )

	; scan col3
	ldi temp, col3		; r16 = 0xbf
	out PORTC, temp		; set PORTC to r16 value
	call Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0xbf and r17 = 0xbe / 0xbd / 0xbb / 0xb7 )

	; scan col4K
	ldi temp, col4		; r16 = 0x7f
	out PORTC, temp		; set PORTC to r16 value
	call Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0x7f and r17 = 0x7e / 0x7d / 0x7b / 0x77 )

	jmp ReadKP

colFound:
	call released
	call H2DEC

	RET

released:
	in temp, PINC
	cp temp, temp2
	breq released
	RET

H2Dec:
	LDI ZL, LOW(tbl << 1)			; r30 to lower pointer of tbl
	LDI ZH, HIGH(tbl << 1)			; r31 to higher pointer of tbl

	ADD ZL, temp2					; r30 = r30 + r17
	ADC ZH, r0						; r31 = r31 + r0 + carryflg

	lpm output, Z

	in temp, PORTB
	ldi temp2, 0xF0
	and temp, temp2
	out PORTB, temp
	nop
	in temp, PORTB
	or temp, output
	out PORTB, temp

	RET

Delay:
	PUSH R16			; Save R16 and 17 as we're going to use them
	PUSH R17			; as loop counters
	PUSH R0			; we'll also use R0 as a zero value
	CLR R0
	CLR R16			; Init inner counter
	CLR R17			; and outer counter
L1: 
	DEC R16         ; Counts down from 0 to FF to 0
	CPSE R16, R0    ; equal to zero?
	RJMP L1			; If not, do it again
	CLR R16			; reinit inner counter
L2: 
	DEC R17
    CPSE R17, R0    ; Is it zero yet?
    RJMP L1			; back to inner counter

	POP R0          ; Done, clean up and return
	POP R17
	POP R16
    RET

cols:
	.db 0xef, 0xdf, 0xbf, 0x7f
		
tbl:
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
  .db 255, 255, 255, 255, 255, 255, 255, 13, 255, 255, 255,   12, 255, 11, 10,  255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
  .db 255, 255, 255, 255, 255, 255, 255, 15, 255, 255, 255,    9, 255, 6, 3,   255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
  .db 255, 255, 255, 255, 255, 255, 255, 0, 255, 255, 255,    8, 255, 5, 2,   255
  .db 255, 255, 255, 255, 255, 255, 255, 14, 255, 255, 255,    7, 255, 4, 1,   255
.db 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255

passcode:
	.db 1, 2, 3, 4, 5, 6
