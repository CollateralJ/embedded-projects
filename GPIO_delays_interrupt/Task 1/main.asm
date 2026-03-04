;
; DA2.asm
;
; Created: 3/9/2025 7:25:47 PM
; Author : CollateralJ
;

.org 0
    rjmp	main
	
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
	out		PORTC,	r16		// set PC1 as an input
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