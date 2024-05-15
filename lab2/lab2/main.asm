;
; lab2.asm
;
; Created: 2024-04-15 15:08:00
; Author : ferpe211
;


.equ T = 10
.equ N = 150

ldi r16,HIGH(RAMEND) ; set stack
out SPH,r16 ; for rcalls
ldi r16,LOW(RAMEND)
out SPL,r16
rcall INIT
clr r20
.def zero= r2
clr zero



; r18 : T
; r17, r16 : DELAY 
; r20, N
; r21, CHAR FROM TEXT
; r22, CURRENT MORSE

IDLE: 
    ; Iterate through the TEXT string
    ldi ZH, HIGH(TEXT*2) ; Load address of TEXT into Z register
    ldi ZL, LOW(TEXT*2)
IDLE_LOOP:
	rcall NO_BEEP
	rcall NO_BEEP
    lpm r21, Z+ ; ladda text med post increment (så den går upp 1 index varje iteration)
    tst r21 ; ifall slutet på text
    breq END_IDLE ; ifall r16 är zero är Z flag 0, då branchar vi

	cpi r21, $20
	breq PLAY_SPACE

    rcall LOOKUP
	; beep here
	rcall BEEP_CHAR
	rjmp IDLE_LOOP
END_IDLE:
    rjmp IDLE


INIT:
	clr r16
	out DDRA,r16
	ldi r16,$FF
	out DDRB,r16
	ret


BEEP_CHAR:
	cpi r22, $80
	breq BEEP_RET
	lsl r22
	brcc BEEP_1N ; beep 3 ggr
	rcall BEEP
	rcall BEEP
BEEP_1N:
	rcall BEEP ; beep 1 ggr
BEEP_DONE:
	rcall NO_BEEP
	rjmp BEEP_CHAR
BEEP_RET:
	ret

	
PLAY_SPACE:
	rcall NO_BEEP
	rcall NO_BEEP
	rcall NO_BEEP
	rcall NO_BEEP
	rcall NO_BEEP
	rjmp IDLE_LOOP


LOOKUP:
	push ZH ; Save Z register
    push ZL

	subi r21, 'A'
	ldi ZH, HIGH(BTAB*2)
	ldi ZL, LOW(BTAB*2)
	; add r21 till ZL
	; addera carry på ZH ifall wrap around 
	; r0 är 0, om då ZL + r21 skapar en carry läggs den på när adc ZH, 0 (+ carry)
	add ZL, r21
	adc ZH,zero
	lpm r22, Z

    pop ZL ; Restore Z register
    pop ZH
	ret



BEEP: ; load r20 with N
	ldi r20, N
BEEP_LOOP:
	sbi PORTB,7
	ldi r18, T
	rcall DELAY
	cbi PORTB,7
	ldi r18, T
	rcall DELAY
	dec r20
	brne BEEP_LOOP
	ret	
NO_BEEP: ; load r20 with N
	ldi r20, N
NO_BEEP_LOOP:
	cbi PORTB,7
	ldi r18, T
	rcall DELAY
	cbi PORTB,7
	ldi r18, T
	rcall DELAY
	dec r20
	brne NO_BEEP_LOOP
	ret		
	
	
DELAY:
	mov r16, r18 ; Decimal bas (T milliseconds)
delayYttreLoop:
	ldi r17,$1F
delayInreLoop:
	dec r17
	brne delayInreLoop
	dec r16
	brne delayYttreLoop
	ret


TEXT: 
	.db "DATORTEKNIK LAB TWO", $00
BTAB: 
	.db $60, $88, $A8,$90, $40, $28, $D0, $08, $20, $78, $B0, $48, $E0, $A0, $F0, $68, $D8, $50, $10, $C0, $30, $18, $70, $98, $B8, $C8