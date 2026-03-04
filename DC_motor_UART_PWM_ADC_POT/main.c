#define F_CPU 16000000UL /* Define CPU Frequency e.g. here its 8MHz */

#include <avr/interrupt.h>
#include <avr/io.h>
#include <avr/pgmspace.h>
#include <stdio.h>
#include <util/delay.h>
#include <stdbool.h>

// capture Flag
volatile uint8_t Flag;
volatile uint8_t Direction = 0;


#define BAUD_PRESCALE (((F_CPU / (BAUDRATE * 16UL))) - 1)	/* Define prescale value */

void USART_Init(unsigned long);
void usart_send(unsigned char);
void usart_print(char*);
char USART_RxChar();
void ADC_Init();
int ADC_Read();
void InitTimer1(void);
void StartTimer1(void);
int output_adc();

// INT0 interrupt
ISR(INT0_vect) {
	// Use for Motor direction one trigger for forward, another for reverse
}

// INT1 interrupt
ISR(INT1_vect) {
	// Use for Motor direction one trigger for stop and go
}

volatile uint32_t revTick; // Ticks per revolution
volatile uint32_t revCtr;  // Total elapsed revolutions
volatile uint16_t T1Ovs2;  // Overflows for small rotations
volatile uint32_t tickv, ticks;
volatile uint32_t revTickAvg;

// capture ISR
ISR(TIMER1_CAPT_vect) {
	tickv = ICR1; // save duration of last revolution
	revTickAvg = (uint32_t)(tickv) + ((uint32_t)T1Ovs2 * 0x10000L); // ticks per pulse
	revCtr++;  // add to revolution count
	TCNT1 = 0; // restart timer for next revolution
	T1Ovs2 = 0;
}

// Overflow ISR
ISR(TIMER1_OVF_vect) {
	// increment overflow counter
	T1Ovs2++;
}

int main(void) {
	char outs[72];
	USART_Init(57600);
	usart_print("Connected!\r\n"); // we're alive!
	InitTimer1();
	StartTimer1();
	usart_print("TIMER1 ICP Running \r\n");
	/* set PD2 and PD3 as input */
	DDRD &= ~(1 << DDD2);                            /* Make INT0 pin as Input */
	DDRD &= ~(1 << DDD3);                            /* Make INT1 pin as Input */
	PORTD |= (1 << DDD2) | (1 << DDD3);              // turn On the Pull-up
	DDRD |= (1 << DDD6) | (1 << DDD4) | (1 << DDD5); /* Make OC0 pin as Output */
	// We are manually setting the direction
	PORTD |= (1 << DDD4);               // CW Direction Set
	PORTD &= ~(1 << DDD5);              // CW Direction Set
	EIMSK |= (1 << INT0) | (1 << INT1); /* enable INT0 and INT1 */
	//MCUCR |= (1 << ISC01) | (1 << ISC11) |
	//(1 << ISC10); /* INT0 - falling edge, INT1 - raising edge */
	sei();                 /* Enable Global Interrupt */
	// WE are not using the ADC for speed - just manually setting the value
	ADC_Init(); /* Initialize ADC */
	TCNT0 = 0;  /* Set timer0 count zero */
	TCCR0A |= (1 << WGM00) | (1 << WGM01) | (1 << COM0A1); // fast PWM mode w/ non-inverting wave
	TCCR0B |= 0x05; /* Set Timer0 prescaler as 1024 */
	OCR0A = 200;
	bool custom = true;
	do
	{
		usart_print("0: pot, 1: 0%, 2: 50%, 3: 100%\r\n");
		char selection = USART_RxChar();
		switch(selection)
		{
			case '0':
				custom = false;
				break;
			case '1':
				OCR0A = 1;
				break;
			case '2':
				OCR0A = 160;
				break;
			case '3':
				OCR0A = 250;
				break;
			default:
				custom = false;
				break;
		}
	} while(custom); // stay here til 0 input
	
	/* ready start value */
	while (1) {
		if (!custom) OCR0A = output_adc();
		_delay_ms(100);

		// Convert ticks to RPM
		// send Speed value to LCD or USART
		//usart_print("Tick;Period;Frequency  ");
		//snprintf(outs, sizeof(outs), "%lu", revTickAvg); // print it
		/*uint32_t rpm = (16*1000000)/(revtickavg*625/10);
		usart_print("rpm: ");
        ltoa(rpm, outs, 10);
		usart_print(outs);
		usart_print("\r\n");*/
	}
}

void USART_Init(unsigned long BAUDRATE)				/* USART initialize function */
{
	UCSR0B |= (1 << RXEN0) | (1 << TXEN0);				/* Enable USART transmitter and receiver */
	UCSR0C |= (1 << UCSZ00) | (1 << UCSZ01);	/* Write USCRC for 8 bit data and 1 stop bit */
	UBRR0 = ((F_CPU / (BAUDRATE * 16UL)) - 1);			/* Load UBRR0 with prescale value */
}

char USART_RxChar()									/* Data receiving function */
{
	while (!(UCSR0A & (1 << RXC0)));					/* Wait until new data receive */
	return(UDR0);									/* Get and return received data */
}

void usart_send (unsigned char ch)
{
	while (! (UCSR0A & (1<<UDRE0)));     //wait until UDR0 is empty
	UDR0 = ch;                            //transmit ch
}

void usart_print(char* str)
{
	int i=0;																	
	while (str[i]!=0)
	{
		usart_send(str[i]);						/* Send each char of string till the NULL */
		i++;
	}
}

// Initialize timer
void InitTimer1(void) {
	// Set PB0 as input
	DDRB &= ~(1 << DDB0);
	PORTB |= (1 << DDB0);

	// Set Initial Timer value
	TCNT1 = 0;
	////First capture on rising edge
	TCCR1A = 0;
	TCCR1B = (0 << ICNC1) | (0 << ICES1);
	TCCR1C = 0;
	// Interrupt setup
	// ICIE1: Input capture
	// TOIE1: Timer1 overflow
	TIFR1 = (1 << ICF1) | (1 << TOV1);    // clear pending
	TIMSK1 = (1 << ICIE1) | (1 << TOIE1); // and enable
}

void StartTimer1(void) {
	// Start timer without pre-scaler
	TCCR1B |= (1 << CS10);
	// Enable global interrupts
	sei();
}

void ADC_Init() /* ADC Initialization function */
{
	DDRC = 0x00;   /* Make ADC port as input */
	ADCSRA = 0x87; /* Enable ADC, with freq/128  */
	ADMUX = 0x40;  /* Vref: Avcc, ADC channel: 0 */
}

int ADC_Read() /* ADC Read function */
{
	ADCSRA |= (1 << ADSC);           /* Start ADC conversion */
	while (!(ADCSRA & (1 << ADIF))); /* Wait until end of conversion by polling ADC interrupt flag */
	ADCSRA |= (1 << ADIF); /* Clear interrupt flag */
	_delay_us(1);          /* Wait a little bit */
	return ADC;           /* Return ADC word */
}

int output_adc()
{
	int adc_val = ADC_Read();
	adc_val = adc_val/4; // get in range of our motor
	char adc_str[3];
	snprintf(adc_str,4,"%d",adc_val);
	usart_print(adc_str);
	usart_print("\r\n");
	return adc_val;
}