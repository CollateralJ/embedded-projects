/*
 * DA3.c
 *
 * Created: 3/26/2025 7:33:31 PM
 * Author : CollateralJ
 */

#define F_CPU 16000000UL

#include<avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>

int count0; // this will go to 12k
int count3; // this will go to 8k
int count4; // this will go to 8k

int main(void)
{
	// TIMER 0 STUFF
	count0 = 0;
	DDRB |= (1 << DDB5); //PB5 as output
	TCCR0A = 0; // Normal mode
	TCNT0 = 0x06; // floor is 6
	TCCR0B = (1 << CS01); // set prescaler to 8
	
	// TIMER 3 STUFF
	count3 = 0;
	DDRB |= (1 << DDB4); //PB4 as output
	OCR3A = 499; // top is 499
	TIMSK3 = (1 << OCIE3A); // interrupt on compare a
	TCCR3B = (1 << WGM32) | (1 << CS31); // 8 prescalar, ctc mode
	
	
	// TIMER 4 STUFF
	count4 = 0;
	DDRB |= (1 << DDB3); //PB3 as output
	TIMSK4 = (1 << TOIE4); // enable overflow interrupt
	TCNT4 = 65336; // top - 200
	TCCR4B = (1 << CS41); // normal mode prescaler 8
	
	
	sei(); // enable interrupts
	while (1)
	{
		// wait for the overflow event
		while ((TIFR0 & 0x01) == 0);
		count0++;
		if (count0 >= 12000){
			PORTB ^= (1 << DDB5);
			count0 = 0;
		}
		
		TCNT0=0x06;
		TIFR0=0x01; // reset the overflow flag
	}
}

ISR (TIMER3_COMPA_vect) // timer3 compare a interrupt
{
	count3++; // inc count
	if (count3 >= 8000){
		PORTB ^= (1 << DDB4); // flip led
		count3 = 0; // reset count
	}
}

ISR (TIMER4_OVF_vect) // timer4 overflow interrupt
{
	count4++;
	TCNT4 = 65336; // top - 200
	if (count4 >= 10000){
		PORTB ^= (1 << DDB3); // flip led
		count4 = 0; // reset count
	}
}

/*
T_0 = (8*250)/(16000000) = 0.125ms
count T_0 (1.5/0.000125) times = 12000 times
T_3 = (8*500)/(16000000) = 0.250ms
count T_3 (2/0.000250) times = 8000 times
T_4 = (8*200)/(16000000) = 0.100ms
count T_4 (1/0.0001) times = 10000 times
*/