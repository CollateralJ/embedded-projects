/*
 * DA2 Task 3 C.c
 *
 * Created: 3/9/2025 10:02:19 PM
 * Author : CollateralJ
 */ 

#define F_CPU 16000000L
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

ISR(INT0_vect){
	PORTB = 0x00;
	_delay_ms(3000);
	PORTB = 0x20;
}

int main(void)
{
DDRB = 0x20; // set PB5 as an output
PORTC = 0x02; // set PC1 as an input
EICRA = 0x02; // make INT0 falling edge triggered
EIMSK = 0x01; // enable INT0
sei();
PORTB = 0x20; // turn off led
while (1)
{
	if ((PINC & 0x02) == 0x00){
		PORTB = 0x00;
		_delay_ms(1500);
		PORTB = 0x20;
	}
}
}