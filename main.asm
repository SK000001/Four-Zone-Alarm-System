; ****************************************************
; EEET2256 - Laboratory 3B (2022) Template
; Author: Dr. Glenn Matthews
; Last Updated:  18/08/2022 10:58:04 AM
; lab3b_template.asm
;*****************************************************
; Define variables.
.def  temp  = r16
.def temp2 = r17
.def passFlg = r25

.equ SP = 0xDF

; Reset Vector.
reset:
   rjmp start

;***********************************************************
; EEET2256 Laboratory 3B
;
; This program reads two numbers from a key pad
;*******************************
; Program starts here after Reset
start:
	LDI  TEMP,  SP		; Init Stack pointer
	OUT  0x3D,  TEMP

    CALL Init           ; Initialise the system.

loop:
	Rcall ReadKP			; Value returned in R16 (temp)
                        	
	Rcall Delay

    RJMP loop

;************************************************************************
;
Init:
; uses:    R16
; returns: nothing
;
;initialise the 16-key keypad connected to Port C
; this assumes that a 16-key alpha numeric keypad is connected to
;port C as follows (see keypad data):
; key pad   function 		   J2 pin
;  1      Row 1, Keys 1, 2, 3, A       1   PC0
;  2      Row 2, Keys 4, 5, 6, B       2   PC1
;  3      Row 3, Keys 7, 8, 9, C       3   PC2
;  4      Row 4, Keys *, 0, #, D       4   PC3
;  5      Column 1, Keys 1, 4, 7, *    5   PC4
;  6      Column 2, Keys 2, 5, 8, 0    6   PC5
;  7      Column 3, Keys 3, 6, 9, #    7   PC6
;  7      Column 4, Keys A, B, C, D    8   PC7

	ldi passFlg, 0x01 

	.equ colIdle = 0xff

	; hex values for columns
	.equ col1 = 0xef
	.equ col2 = 0xdf
	.equ col3 = 0xbf
	.equ col4 = 0x7f

	; first 4 out and last 4 in
	ldi temp, 0xf0
	out DDRC, temp

	ldi temp, 0xff
	out DDRB, temp

	ldi temp, 0x0f
	out PORTC, temp

	out PORTB, temp

	; Set the pull-up resistor values on PORTC.
	ldi temp, colIdle
	out PORTC, temp

  	RET	
;************************************************************************

;
;********************************************************************
; ReadKP will determine which key is pressed and return that key in Temp
; The design of the keypad is such that each row is normally pulled high
; by the internal pullups that are enabled at init time
;
; When a key is pressed contact is made between the corresponding row and column.
; To determine which key is pressed each column is forced low in turn
; and software tests which row has been pulled low at micro input pins
;
; To avoid contact bounce the program must include a delay to allow
; the signals time to settle
;

ReadKP:
	; scan col1
	ldi temp, col1		; r16 = 0xef
	out PORTC, temp		; set PORTC to r16 value
	rcall Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0xef and r17 = 0xee / 0xed / 0xeb / 0xe7 )

	; scan col2
	ldi temp, col2		; r16 = 0xdf
	out PORTC, temp		; set PORTC to r16 value
	rcall Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0xdf and r17 = 0xde / 0xdd / 0xdb / 0xd7 )

	; scan col3
	ldi temp, col3		; r16 = 0xbf
	out PORTC, temp		; set PORTC to r16 value
	rcall Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0xbf and r17 = 0xbe / 0xbd / 0xbb / 0xb7 )

	; scan col4K
	ldi temp, col4		; r16 = 0x7f
	out PORTC, temp		; set PORTC to r16 value
	rcall Delay			; for sync

	in temp2, PINC		; takes input to r17
	CP temp, temp2		; compare r16 and r17
	brne colFound		; jump to colFound if r16 and r17 is not equal ( r16 = 0x7f and r17 = 0x7e / 0x7d / 0x7b / 0x77 )

	rjmp ReadKP

colFound:
	call released
	call H2DEC

	call checkCases

	RET

checkCases:
	ldi r20, 6			; counter

	ldi temp2, 10
	cp temp, temp2		; Zone A sensor trigger
	ldi temp2, 0x08
	breq triggerZone


	ldi temp2, 11
	cp temp, temp2		; Zone B sensor trigger
	ldi temp2, 0x04
	breq triggerZone


	ldi temp2, 12
	cp temp, temp2		; Zone C sensor trigger
	ldi temp2, 0x02
	breq triggerZone


	ldi temp2, 13
	cp temp, temp2		; Zone D sensor trigger
	ldi temp2, 0x01
	breq triggerZone


	ldi temp2, 15
	cp temp, temp2		; arm / disarm the system
	ldi temp2, 0x0F
	breq disarm_Arm

	RET

triggerZone:
	cp r20, r0
	breq toloop

	in temp, PORTB
	eor temp, temp2
	out PORTB, temp
	call Delay

	dec r20
	rjmp triggerZone

toloop:
	rjmp loop

disarm_Arm:
	ldi r20, 3
	ldi r21, 2
	rjmp passcodeEntry

passcodeEntry:
	cp r20, r0

	breq passVerify

	RCALL	ReadKP
	PUSH	temp
	RCALL	ReadKP
	POP  temp2
	RCALL	combine

	dec r20
	rjmp passcodeEntry

combine:
	ldi r22, 16
	mul temp2, r22
	add temp2, temp
	push temp2
	
	RET

passVerify:
	pop temp

	LDI ZL, LOW(passcode << 1)			; r30 to lower pointer of passcode
	LDI ZH, HIGH(passcode << 1)			; r31 to higher pointer of passcode

	ADD ZL, r21					; r30 = r30 + r21

	lpm temp2, Z

	cp temp, temp2
	brne toloop

	cp r21, r0
	breq toloop

	dec r21
	rjmp passVerify

stateChange:
	ldi temp, 0x8F
	out PORTB, temp
	rjmp toloop

Display:
	lpm temp, Z
	out PORTB, temp
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

	lpm temp, Z

	RET

;************************************************************************
;
; Takes whatever is in the Temp register and outputs it to the LEDs
;*************************************
;
; Delay routine
;
; this has an inner loop and an outer loop. The delay is approximately
; equal to 256*256*number of inner loop instruction cycles.
; You can vary this by changing the initial values in the accumulator.
; If you need a much longer delay change one of the loop counters
; to a 16-bit register such as X or Y.
;
;*************************************
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
	.db 0x12, 0x34, 0x56, 0