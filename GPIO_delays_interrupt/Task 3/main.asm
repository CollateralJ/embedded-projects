;
; DA2 Task 3 ASM.asm
;
; Created: 3/9/2025 9:51:25 PM
; Author : CollateralJ
;

.org 0
    jmp	main
.org 0x02
	jmp	INT0_ISR

main:
// initialize SP
	LDI		R16,	HIGH(RAMEND)
    OUT		SPH,	R16
    LDI		R16,	LOW(RAMEND)
    OUT		SPL,	R16

// setup
    ldi		r16,	0x20
    out		DDRB,	r16		// set PB5 as an output
	ldi		r16,	0x02
	out		PORTC,	r16		// activate the pull-up resistor for PC1
	ldi		r16,	0x04
	out		PORTD,	r16		// activate the pull-up resistor for PD2

	LDI R20,0x2;make INT0 falling edge triggered
	STS EICRA,R20 
	LDI R16,1<<INT0 ; Enable INT0
	OUT EIMSK,R16 ; 
	sei						// global interupt enable

	ldi		r16,	0x20	
	out		PORTB,	r16		// turn off led

	while: // wait for switch and then light led for 1.5s
		in		r19,	PINC
		ldi		r20,	0x02
		and		r19,	r20
		brne	else	// if r19 is now 0, switch is pressed

		ldi		r20,	0x00 // set led on
		out		PORTB,	r20

		ldi		r20,	10
		delay3halves: // loop for 1.5s
			call	delay
			dec		r20
			brne	delay3halves

		ldi		r20,	0x20 // set led off
		out		PORTB,	r20

		else:

		jmp		while

// delay by (1)+(4*10)+(5*186*256*10)+(7*186*10) = 2393861 clk cycles 
delay: // (0.15s on 16MHz)
	ldi		r16,	10		// 1 delay * 1
	delayLoop0:
		ldi		r17,	186		// 1 delay * 10
		delayLoop1:		// loop 1
			ldi		r18,	255		// 1 delay * 186 * 10
			delayLoop2: 			// inner loop
				dec		r18			// 1 delay * 186 * 256 * 10
				nop					// 1 delay * 186 * 256 * 10
				nop					// 1 delay * 186 * 256 * 10
				brne	delayLoop2		// 2 delay * 186 * 256 * 10
			dec		r17			// 1 delay * 186 * 10
			nop					// 1 delay * 186 * 10
			nop					// 1 delay * 186 * 10
			nop					// 1 delay * 186 * 10
			brne	delayLoop1		// 2 delay * 186 * 10
		dec		r16
		brne	delayLoop0
	ret

INT0_ISR:

	ldi		r20,	0x00 // set led on
	out		PORTB,	r20

	ldi		r20,	20
	delay3: // loop for 3s
		call	delay
		dec		r20
		brne	delay3

	ldi		r20,	0x20 // set led off
	out		PORTB,	r20
	reti