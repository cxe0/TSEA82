.dseg
.org SRAM_START
TIME: .byte 4 ; time in BCD format
POS: .byte 1 ; 7-seg position
	.cseg
		.org	$0000
		jmp MAIN ; Reset Handler
		.org INT0addr;INT0addr - D2
		jmp MUX ; INT0 Handler
		.org INT1addr;IN1addr - D3
		jmp BCD ; INT1 Handler
; ----- Memory layout in SRAM

.macro PUSHZ
	push ZH
	push ZL
.endmacro

.macro POPZ
	pop ZL
	pop ZH
.endmacro

.macro PUSHX
	push XH
	push XL
.endmacro

.macro POPX
	pop XL
	pop XH
.endmacro

.macro PUSH_SREG
	push r16
	in r16, SREG
	push r16
.endmacro

.macro POP_SREG
	pop r16
	out SREG, r16
	pop r16
.endmacro
.def zero= r2

.equ one = 1


MAIN:
	;PORT CONFIG
	ser r16
	clr zero
	out PORTD, r16
	ldi r16, $FF
	out DDRB, r16

	ldi r16, $FF
	out DDRA, r16

	;INT0 INT1 CONFIG
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16

	ldi r16, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)
	out MCUCR, r16
	ldi r16, (1<<INT1)|(1<<INT0)
	out GICR, r16

	;Clears TIME
	ldi ZH, HIGH(TIME)
	ldi ZL, LOW(TIME)

	st Z+, zero
	st Z+, zero
	st Z+, zero
	st Z+, zero


	sei

MAIN_WAIT:
	jmp MAIN_WAIT

MUX:
	PUSHZ
	PUSH_SREG
	PUSHX
	ldi ZH, HIGH(POS)
	ldi ZL, LOW(POS)
	ldi r23, one
	ld r18, Z
	add r18, r23
	cpi r18, $04
	brne MUX_NEXT
	clr r18
MUX_NEXT:
	st Z,r18
	ldi ZH, HIGH(TIME)
	ldi ZL, LOW(TIME)

	add ZL, r18
	adc ZH, zero

	ld r19, Z

	ldi ZH, HIGH(DISPLAY*2)
	ldi ZL, LOW(DISPLAY*2)

	add ZL, r19
	adc ZH, zero

	lpm r20, Z

	ldi r16,$00
	out PORTB, r16
	
	out PORTA, r18

	out PORTB, r20

MUX_EXIT:
	POPX
	POP_SREG
	POPZ
	reti

BCD:
	PUSHZ
	PUSH_SREG
	PUSHX
	ldi XH, HIGH(TIME)
	ldi XL, LOW(TIME)
	ldi r23, one
	ldi r24, 0
	ldi ZH, HIGH(TIME_FORMAT*2)
	ldi ZL, LOW(TIME_FORMAT*2)
BCD_LOOP: ;r18 current number
    lpm r25, Z
	add ZL, r23
	adc ZH,zero
	
	add r24, r23

	ld r18, X
	add r18, r23
	cp r18, r25
	brne BCD_EXIT
	clr r18
	st X,r18

	add XL, r23
	adc XH, zero

	cpi r24, $04
	brne BCD_LOOP
BCD_CLEAR_INIT:
	ldi ZH, HIGH(TIME)
	ldi ZL, LOW(TIME)
	ldi r26, 0 
BCD_CLEAR_LOOP:
	add r24, r23
	st Z+, zero
	cpi r24, $04
	brne BCD_CLEAR_LOOP
BCD_EXIT:
	st X, r18
	POPX
	POP_SREG
	POPZ
	reti

DISPLAY: 
	.db $3F, $06, $5B, $4F, $66, $6D, $7D, $07, $7F, $6F, $77, $7C, $39, $5E, $79, $71

TIME_FORMAT:
	.db $0A, $06, $0A, $06