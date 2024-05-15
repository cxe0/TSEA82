	
	; --- lab4spel.asm

	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 150	; inter-run delay (millisecs)
	.equ	PRESCALE    = 3		; AD-prescaler value
	.equ	BEEP_PITCH  = 1	; Victory beep pitch
	.equ	BEEP_LENGTH = 30	; Victory beep length
	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random

	; ---------------------------------------
	; --- Macros for inc/dec-rementing
	; --- a byte in SRAM
	.macro INCSRAM	; inc byte in SRAM
		lds	r16,@0
		inc	r16
		sts	@0,r16
	.endmacro

	.macro DECSRAM	; dec byte in SRAM
		lds	r16,@0
		dec	r16
		sts	@0,r16
	.endmacro


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

	; ---------------------------------------
	; --- Code
	.cseg
	.org 	$0
	jmp	START
	.org	INT0addr
	jmp	MUX




START:

	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16
	call	HW_INIT	
	call	WARM
RUN:
	call	JOYSTICK
	call	ERASE_VMEM
	call	UPDATE

	ldi r18, GAME_SPEED
	call DELAY


	lds r16, POSX
	lds r17, TPOSX
	cp r16, r17
	brne	NO_HIT	
	lds r16, POSY
	lds r17, TPOSY
	cp r16, r17
	brne	NO_HIT	

	ldi	r16,BEEP_LENGTH
	call	BEEP
	call	WARM
NO_HIT:
	jmp	RUN

	; ---------------------------------------
	; --- Multiplex display
MUX:	
	PUSHZ
	PUSHX
	PUSH_SREG
	push r16
	push r17
	push r18

	ldi ZH, HIGH(VMEM)
	ldi ZL, LOW(VMEM)

	lds r16, LINE

	ldi r17, $00
	out PORTB, r17

	inc r16

	cpi r16, $05
	brne NO_RESET
	ldi r16, $00
NO_RESET:
	sts LINE, r16

	ldi r17,0

	add ZL, r16
	adc ZH, r17

	mov r17, r16
	lsl r17
	lsl r17

	ld r16, Z
	out PORTB, r16



	out PORTA, r17

	INCSRAM SEED

	pop r18
	pop r17
	pop r16
	POP_SREG
	POPX
	POPZ
	reti
		
	; ---------------------------------------
	; --- JOYSTICK Sense stick and update POSX, POSY
	; --- Uses r16
JOYSTICK:	
	PUSH_SREG
JOY_X:
	; X POS, PORTA0
	ldi r16,(1<<REFS0) ; kanal 0, AVCC ref, ADLAR=0
	call ADC10
CHECK_DEC_JOY_X:
	cpi r17, $03
	brne CHECK_INC_JOY_X
	; decrease x
	DECSRAM POSX
CHECK_INC_JOY_X:
	cpi r17, $00
	brne JOY_Y
	; inc x
	INCSRAM POSX

JOY_Y:
	ldi r16,(1<<REFS1)|(1<<MUX0) ; kanal 1, AVCC ref, ADLAR=0
	call ADC10
CHECK_DEC_JOY_Y:
	cpi r17, $00
	brne CHECK_INC_JOY_Y
	; decrease y
	DECSRAM POSY
CHECK_INC_JOY_Y:
	cpi r17, $03
	brne JOY_LIM
	; inc y
	INCSRAM POSY


JOY_LIM:
	call	LIMITS		; don't fall off world!
	POP_SREG
	ret

	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses r16,r17
LIMITS:
	lds	r16,POSX	; variable
	ldi	r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSX,r16
	lds	r16,POSY	; variable
	ldi	r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts	POSY,r16
	ret

POS_LIM:
	ori	r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp	r16,r17		; past edge
	brne	POS_OK
	subi	r16,2
POS_LESS:
	inc	r16	
POS_OK:
	ret

ADC10:
	out ADMUX,r16
	ldi r16,(1<<ADEN) ; A/D enable, ADPSx=111
	ori r16,(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
	out ADCSRA,r16
ADC10_CONVERT:
	in r16,ADCSRA
	ori r16,(1<<ADSC)
	out ADCSRA,r16 ; starta omvandling
ADC10_WAIT:
	in r16,ADCSRA
	sbrc r16,ADSC ; om 0-st�lld, klar
	rjmp ADC10_WAIT ; annars v�nta
	in r16,ADCL ; obs, l�s l�g byte f�rst
	in r17,ADCH ; h�g byte sedan
	ret



	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses r16, r17
UPDATE:	
	clr	ZH 
	ldi	ZL,LOW(POSX)
	call 	SETPOS
	clr	ZH
	ldi	ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses r16, r17
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
SETPOS:
	ld	r17,Z+  	; r17=POSX
	call	SETBIT		; r16=bitpattern for VMEM+POSY
	ld	r17,Z		; r17=POSY Z to POSY
	ldi	ZL,LOW(VMEM)
	add	ZL,r17		; *(VMEM+T/POSY) ZL=VMEM+0..4
	ld	r17,Z		; current line in VMEM
	or	r17,r16		; OR on place
	st	Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses r16, r17
SETBIT:
	ldi	r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret

	; ---------------------------------------
	; --- Hardware init
	; --- Uses r16
HW_INIT:
	ser r16
	out PORTD, r16

	ldi r16, $FF
	out DDRB, r16

	ldi r16, 0b11111100
	out DDRA, r16


	ldi r16, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)
	out MCUCR, r16
	ldi r16, (0<<INT1)|(1<<INT0)
	out GICR, r16

	sei			; display on
	ret

	; ---------------------------------------
	; --- WARM start. Set up a new game
WARM:
	ldi r16, 0
	sts POSX, r16

	ldi r16, 2
	sts POSY, r16

	push	r0		
	push	r0		
	call	RANDOM		; RANDOM returns x,y on stack

	pop r16 ; x
	pop r17 ; y

	ldi ZH, HIGH(TPOSX)
	ldi ZL, LOW(TPOSX)
	st Z, r16

	ldi ZH, HIGH(TPOSY)
	ldi ZL, LOW(TPOSY)
	st Z, r17

	call	ERASE_VMEM
	ret

	; ---------------------------------------
	; --- RANDOM generate TPOSX, TPOSY
	; --- in variables passed on stack.
	; --- Usage as:
	; ---	push r0 
	; ---	push r0 
	; ---	call RANDOM
	; ---	pop TPOSX 
	; ---	pop TPOSY
	; --- Uses r16
RANDOM:
	clr r0
	in	r16,SPH
	mov	ZH,r16
	in	r16,SPL
	mov	ZL,r16
	lds	r16,SEED
	mov r17, r16
	andi r16, 0b00000111
	andi r17, 0b00001110
	lsr r17

	; r16 for TPOSX
	; r17 for TPOSY
	cpi r16, 4
	brlt NORMAL_X
	subi r16, 4
NORMAL_X:
	cpi r17, 4
	brlt NORMAL_Y
	subi r17, 4
NORMAL_Y:
	ldi r18, 2
	add r16, r18

	ldi r18, 3
	; add r16 to highest r0 in stack
	add ZL, r18
	adc ZH, r0
	st Z, r16

	ldi r18, 1
	add ZL, r18
	adc ZH, r0
	st Z, r17
	ret


	; ---------------------------------------
	; --- Erase Videomemory bytes
	; --- Clears VMEM..VMEM+4
	
ERASE_VMEM:
	ldi ZH, HIGH(VMEM)
	ldi ZL, LOW(VMEM)

	ldi r16, 0
	ldi r17, VMEM_SZ  // Initialize counter
EREASE_VMEM_LOOP:
	st Z+, r16
	dec r17
	brne EREASE_VMEM_LOOP

	ret

BEEP:
	ldi r20, BEEP_LENGTH
BEEP_LOOP:
	sbi PORTB,7
	ldi r18, BEEP_PITCH
	rcall DELAY
	cbi PORTB,7
	ldi r18, BEEP_PITCH
	rcall DELAY
	dec r20
	brne BEEP_LOOP
	ret

DELAY:
	mov r16, r18 
delayYttreLoop:
	ldi r17,$FF
delayInreLoop:
	dec r17
	brne delayInreLoop
	dec r16
	brne delayYttreLoop
	ret

			