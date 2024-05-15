.equ T_MS = 33;

ldi r16,HIGH(RAMEND) ; set stack
out SPH,r16 ; for calls
ldi r16,LOW(RAMEND)
out SPL,r16
call INIT
clr r20
IDLE:
	call GET_START
	cpi r21,0
	breq IDLE 
	clr r18
	ldi r18, T_MS ; loads delay time into r18
	asr r18 ; divides r18 by 2
	call DELAY ; now we are synced
	call GET_START
	cpi r21,0
	breq IDLE 
	call DATA_READ



	out PORTB, r20
	call DELAY ; now we are synced
	jmp IDLE
INIT:
	clr r16
	out DDRA,r16
	ldi r16,$FF
	out DDRB,r16
	ret
DELAY:
	sbi PORTB,7
	mov r16, r18 ; Decimal bas (T milliseconds)
delayYttreLoop:
	ldi r17,$1F
delayInreLoop:
	dec r17
	brne delayInreLoop
	dec r16
	brne delayYttreLoop
	cbi PORTB,7
	ret
GET_START:
	clr r21 ; assume not pressed
	sbic PINA,0 ; skip over if not pressed
	dec r21 ; r21=$FF
	ret
DATA_READ:
	clr r19
	ldi r19, $4
	clr r20
dataReadLoop:
	clr r18
	ldi r18, T_MS ; loads delay time into r18
	call DELAY 
	lsl r20
	sbic PINA,0 ; skips over increment if PINA was 0
	inc r20

	dec r19
	brne dataReadLoop
	ret
	
