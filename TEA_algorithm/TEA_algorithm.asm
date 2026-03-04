;
; DA1.asm
;
; Created: 2/21/2025 1:05:00 PM
; Author : CollateralJ
;

; define locations in sram to find things
.equ v0l = 0x00 
.equ v0h = 0x01
.equ v1l = 0x04
.equ v1h = 0x01
.equ deltal = 0x08
.equ deltah = 0x01
.equ encryptedl = 0x00
.equ encryptedh = 0x02

; Replace with your application code
.ORG 0
	; Initialize the stack pointer
	LDI R20,HIGH(RAMEND)
	OUT SPH,R20
	LDI R20,LOW(RAMEND)
	OUT SPL,R20
	; Initialize X-pointer for EEPROM Key retrieval
	LDI XH,HIGH(0x00)
	LDI XL,LOW(0x00)

	; Initialize the Y-pointer for Decrypted Message starting @ 0x200
	LDI YH,HIGH(0x200)
	LDI YL,LOW(0x200)

	; Initialize the Z-pointer for key starting @ 0x600
	LDI ZH,HIGH(KEY<<1)
	LDI ZL,LOW(KEY<<1)

	; store delta in SRAM
	ldi YH,deltah
	ldi YL,deltal
	ldi r20, 0x9E
	st Y+, r20
	ldi r20, 0x37
	st Y+, r20
	ldi r20, 0x79
	st Y+, r20
	ldi r20, 0xB9
	st Y+, r20

L1:	; store the key in eeprom 0x0000
	LPM r15,Z+ ; increment ZH and ZL
	CALL STORE_IN_EEPROM ; r15 has the EEPROM Data
	INC XL ; increment to next EEPROM Location (note: will reset at 0xff since we are only incrementing low)
	CPI XL, 0x11
	BRNE L1 ; break only if XL = 0x11


	; Initialize the Z-pointer for message starting @ 0x400
	LDI ZH,HIGH(MESSAGE<<1)
	LDI ZL,LOW(MESSAGE<<1)

	clr r17 ; set up counter for tea to run 8x

tea:
	; set up the variables
	; y = text[0] in r10-r13, MSB highest
	LPM r13,Z+
	LPM r12,Z+
	LPM r11,Z+
	LPM r10,Z+

	; store y in SRAM, MSB first
	ldi YH,v0h
	ldi YL,v0l
	st Y+, r13
	st Y+, r12
	st Y+, r11
	st Y+, r10

	; z = text[1] in r10-r13, MSB highest
	LPM r13,Z+
	LPM r12,Z+
	LPM r11,Z+
	LPM r10,Z+

	; store z in SRAM, MSB first
	ldi YH,v1h
	ldi YL,v1l
	st Y+, r13
	st Y+, r12
	st Y+, r11
	st Y+, r10

	; use r2-r5 for temp random (eor segments, delta)
	; use r10-r13 for y/z
	; use r18-r21 as temp storage for the EOR products
	; store sum = 0 in r6-r9
	clr r9
	clr r8
	clr r7
	clr r6

	; n in r16
	clr r16

	for:

	; adding delta to sum (r6-r9)
	; load delta from SRAM to temp (r2-r5) MSB highest
	ldi YH, deltah
	ldi YL, deltal
	ld r5, Y+
	ld r4, Y+
	ld r3, Y+
	ld r2, Y+
	; delta loaded

	; sum += delta
	add r6, r2
	adc r7, r3
	adc r8, r4
	adc r9, r5
	; done adding delta to sum

	; loading key0 (bottom 1/4 of key)
	; reset X for loading from EEPROM
	LDI XH,HIGH(0x00)
	LDI XL,LOW(0x00)

	call LOAD_FROM_EEPROM
	mov r25, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r24, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r23, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r22, r15
	inc XL
	; done loading key0

	; get (z << 4)
	; z already loaded from setup
	; shifting z left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; shifting z left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; shifting z left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; shifting z left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; done getting (z << 4) in y/z

	; do ((z<<4)+k0)		(r28-r31) + (r22-r25)
	add r10, r22
	adc r11, r23
	adc r12, r24
	adc r13, r25
	; ((z<<4)+k0) in y/z
	; load it into eor products
	mov r10, r18
	mov r11, r19
	mov r12, r20
	mov r13, r21

	; get (z+sum)
	; load z
	ldi YH, v1h
	ldi YL, v1l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; add sum to z
	add r10, r6
	adc r11, r7
	adc r12, r8
	adc r13, r9
	; got (z+sum) in y/z

	;xor: eor products = ((z<<4)+k0) ^ (z+sum)
	eor r18, r10
	eor r19, r11
	eor r20, r12
	eor r21, r13

	; get ((z>>5)+k1)
	; load key1
	; continue where X left off for loading from EEPROM
	call LOAD_FROM_EEPROM
	mov r25, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r24, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r23, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r22, r15
	inc XL
	; done loading key1

	; get (z>>5)
	; load z
	ldi YH, v1h
	ldi YL, v1l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; shift z right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift z right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift z right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift z right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift z right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; got (z>>5)

	; add k1 to y/z to get ((z>>5)+k1)
	add r10, r22
	adc r11, r23
	adc r12, r24
	adc r13, r25
	; got ((z>>5)+k1)

	; final xor: ((z<<4)+k0) ^ (z+sum) ^ ((z>>5)+k1)
	eor r18, r10
	eor r19, r11
	eor r20, r12
	eor r21, r13

	; load y into y/z
	ldi YH, v0h
	ldi YL, v0l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; adding r18-r21 to y (END OF Y MODIFACTION)
	add r10, r18
	adc r11, r19
	adc r12, r20
	adc r13, r21

	; store updated y
	ldi YH,v0h
	ldi YL,v0l
	st Y+, r13
	st Y+, r12
	st Y+, r11
	st Y+, r10

	; loading key2
	call LOAD_FROM_EEPROM
	mov r25, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r24, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r23, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r22, r15
	inc XL
	; done loading key2

	; get (y << 4)
	; y already loaded from last step
	; shifting y left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; shifting y left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; shifting y left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; shifting y left by 1
	lsl r10
	rol r11
	rol r12
	rol r13
	; done getting (y << 4) in y/z

	; do ((y<<4)+k2)
	add r10, r22
	adc r11, r23
	adc r12, r24
	adc r13, r25
	; ((y<<4)+k2) is in y/z
	; load it into eor products
	mov r10, r18
	mov r11, r19
	mov r12, r20
	mov r13, r21
	
	; get (y+sum)
	; load y
	ldi YH, v0h
	ldi YL, v0l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; add sum to y
	add r10, r6
	adc r11, r7
	adc r12, r8
	adc r13, r9
	; got (y+sum) in y/z

	;xor: eor products = ((y<<4)+k1) ^ (y+sum)
	eor r18, r10
	eor r19, r11
	eor r20, r12
	eor r21, r13

	; get ((y>>5)+k3)
	; load key3
	; continue where X left off for loading from EEPROM
	call LOAD_FROM_EEPROM
	mov r25, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r24, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r23, r15
	inc XL
	call LOAD_FROM_EEPROM
	mov r22, r15
	inc XL
	; done loading key3

	; get (y>>5)
	; load y
	ldi YH, v0h
	ldi YL, v0l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; shift y right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift y right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift y right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift y right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; shift y right by one
	lsr r13
	ror r12
	ror r11
	ror r10
	; got (y>>5)

	; add k3 to y/z to get ((y>>5)+k3)
	add r10, r22
	adc r11, r23
	adc r12, r24
	adc r13, r25
	; got ((y>>5)+k3)

	; final xor: ((y<<4)+k3) ^ (y+sum) ^ ((y>>5)+k3)
	eor r18, r10
	eor r19, r11
	eor r20, r12
	eor r21, r13

	; load z into y/z
	ldi YH, v1h
	ldi YL, v1l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; adding r18-r21 to z (END OF Z MODIFACTION)
	add r10, r18
	adc r11, r19
	adc r12, r20
	adc r13, r21

	; store updated z
	ldi YH,v1h
	ldi YL,v1l
	st Y+, r13
	st Y+, r12
	st Y+, r11
	st Y+, r10

	inc r16 ; n++

	; compare n to 32 and leave only if it is equal to
	cpi r16, 0x20
	breq endfor
	rjmp for

	endfor:

	; store new numbers in sram

	; load updated y
	ldi YH, v0h
	ldi YL, v0l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	; store
	ldi YH, encryptedh
	ldi YL, encryptedl
	mov r19, r17 ; get the iteration for shifting
	lsl r19 ;  (n << 3)
	lsl r19
	lsl r19
	add YL, r19 ; starts at 0x0200 + (n << 3) to allow space for blocks of 8 + 0 offset
	ldi r18, 0x00
	adc YH, r18
	st Y+, r13
	st Y+, r12
	st Y+, r11
	st Y+, r10

	; load updated z
	ldi YH, v1h
	ldi YL, v1l
	ld r13, Y+
	ld r12, Y+
	ld r11, Y+
	ld r10, Y+

	ldi YH, encryptedh
	ldi YL, encryptedl
	mov r19, r17 ; get the iteration for shifting
	lsl r19 ;  (n << 3)
	lsl r19
	lsl r19
	ldi r18, 0x04
	add YL, r18 ; 4 offset since its storing text[1]
	add YL, r19 ; starts at 0x0200 + (n << 3) to allow space for blocks of 8 + 4 offset
	ldi r18, 0x00
	adc YH, r18
	st Y+, r13
	st Y+, r12
	st Y+, r11
	st Y+, r10

	inc r17 ; i++
	cpi r17, 0x08
	breq endtea ; leave after 8th iteration
	rjmp tea

endtea:
	rjmp endtea

LOAD_FROM_EEPROM:
	; check for completion of ongoing writes
	SBIC EECR, EEPE
	RJMP LOAD_FROM_EEPROM

	; ee prom address register high/low, set them to X
	OUT EEARH,XH
	OUT EEARL,XL

	SBI EECR,EERE	; read enable
	IN r15,EEDR ; input from ee data reg
	RET

STORE_IN_EEPROM:
	; check for completion of ongoing writes
	SBIC EECR, EEPE ; ee prom write enable
	RJMP STORE_IN_EEPROM

	; ee prom address register high/low, set them to X
	OUT EEARH,XH
	OUT EEARL,XL

	OUT EEDR,r15 ; output to ee data reg
	SBI EECR,EEMPE ; master write enable
	SBI EECR,EEPE ; write enable
	RET

; Message: "This is my sample code for Design Assignment 1. Perfectly intact"

.ORG 0x200
MESSAGE:
.DB 0x54, 0x68, 0x69, 0x73, 0x20, 0x69, 0x73, 0x20, 0x6d, 0x79, 0x20, 0x73, 0x61, 0x6d, 0x70, 0x6c
.DB 0x65, 0x20, 0x63, 0x6f, 0x64, 0x65, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x44, 0x65, 0x73, 0x69, 0x67
.DB 0x6e, 0x20, 0x41, 0x73, 0x73, 0x69, 0x67, 0x6e, 0x6d, 0x65, 0x6e, 0x74, 0x20, 0x31, 0x2e, 0x20
.DB 0x50, 0x65, 0x72, 0x66, 0x65, 0x63, 0x74, 0x6c, 0x79, 0x20, 0x69, 0x6e, 0x74, 0x61, 0x63, 0x74

; example:
; Message: "jiLSTLNdaRrxrmiElGjSeiZBNSIrXEOInKAljICoLQvnCSTuTqApIrpqhyjBNAYy"
; MESSAGE: .DB 0x6a, 0x69, 0x4c, 0x53, 0x54, 0x4c, 0x4e, 0x64, 0x61, 0x52, 0x72, 0x78, 0x72, 0x6d, 0x69, 0x45
;.DB 6c, 47, 6a, 53, 65, 69, 5a, 42, 4e, 53, 49, 72, 58, 45, 4f, 49
;.DB 6e, 4b, 41, 6c, 6a, 49, 43, 6f, 4c, 51, 76, 6e, 43, 53, 54, 75
;.DB 54, 71, 41, 70, 49, 72, 70, 71, 68, 79, 6a, 42, 4e, 41, 59, 79


; KEY: "GoodEnoughForMe!"
.ORG 0x300
KEY:
.DB 0x47, 0x6f, 0x6f, 0x64, 0x45, 0x6e, 0x6f, 0x75, 0x67, 0x68, 0x46, 0x6f, 0x72, 0x4d, 0x65, 0x21

; example:
; KEY: "YKTFgWnvaloBflrr"
;.ORG 0x300
; KEY:.DB 0x59, 0x4b, 0x54, 0x46, 0x67, 0x57, 0x6e, 0x76, 0x61, 0x6c, 0x6f, 0x42, 0x66, 0x6c, 0x72, 0x72

