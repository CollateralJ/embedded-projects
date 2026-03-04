#define F_CPU 16000000UL	// Define CPU Frequency

			// includes
#include <avr/io.h>			// Include AVR std. library file
#include <util/delay.h>		// Include Delay header file
#include <avr/interrupt.h>	// interrupt library
#include <stdio.h>			// for snprintf

			// defines
// servo
#define SERVO_MIN 250		// 1 ms
#define SERVO_MAX 500		// 2 ms
#define PWM_TOP 4999		// 20 ms (50 hz)
#define MAX_DEG 180
volatile int lowest = 9999;	// for showing the lowest value recorded in CW turn
// ultrasonic
#define TRIGGER PC3			// atmega to ultrasonic signal
#define ECHO PC4			// ultrasonic to atmega signal
// spi/sevenseg
#define DATA (1<<PB3)		//MOSI (SI)
#define LATCH (1<<PB2)		//SS   (RCK)
#define CLOCK (1<<PB5)		//SCK  (SCK)
#define dl 25				// delay for seven seg (ms)
const uint8_t SEGMENT_MAP[] = // Segment byte maps for numbers 0 to 9
{0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0X80, 0X90};
const uint8_t SEGMENT_SELECT[] = {0xF1, 0xF2, 0xF4, 0xF8}; // Byte maps to select digit 1 to 4

			// functions
// servo
void servo_init();							// Initialize timer1
void rotate_to(int degrees);				// Move servo to degree
void sweep(int CW);							// Move servo from one side to the other slowly
// usart
void usart_init(unsigned long BAUDRATE);	// Initialize usart connection
void usart_char (unsigned char ch);			// Send 1 character through usart
void usart_str(char* str);					// Send a string through usart
// ultrasonic
void dist_init();
int ping();
// 7seg/spi
void init_IO(void);
void init_SPI(void);
void spi_send(unsigned char byte);
void send_char(unsigned char byte, uint8_t segment);
void seven_send(int num);

ISR(TIMER3_OVF_vect)
{
	//usart_str("Overflow\r\n");
}

// -------------------------------------------------------------------
					// MAIN
// -------------------------------------------------------------------

int main(void)
{
	servo_init();
	usart_init(9600);
	usart_str("USART Connected.\r\n");
	dist_init();
	init_IO();
	init_SPI();
	while(1) 
	{
		sweep(1);	// CW
		sweep(0);	// CCW
	}
}

// -------------------------------------------------------------------
					// SERVO FUNCTIONS
// -------------------------------------------------------------------

void servo_init()
{ // timer for the servo motor PWM
	TCCR1A |= (1<<COM1A1) | (1<<WGM11);							// OCR1A set bottom, clear on match
	TCCR1B |= (1<<WGM13) | (1<<WGM12) | (1<<CS11) | (1<<CS10);	// ICR1 top, 64 prescaler, fast pwm (14)
	ICR1 = PWM_TOP;												// set top value
	DDRB |= (1 << PB1);											// PWM Pin as Out (OC1A)
	OCR1A = SERVO_MIN;											// init to 0 deg
}

void rotate_to(int degrees)
{ // doesnt include a delay, use carefully
	// get the degree ratio
	float ratio = ((float)degrees)/180.0;
	OCR1A = (SERVO_MIN) + ((SERVO_MAX-SERVO_MIN)*(ratio));
}

void sweep(int CW)
{ // sweep from 0-180 (1) or 180-0 (0)
	char str[20];
	int end_val = CW ? MAX_DEG : 0;
	lowest = CW ? 9999 : lowest;
	DDRB |= (1 << PB4);
	if (CW) PORTB |= (1 << PB4);
	else PORTB &= ~(1 << PB4);
	for(int i = CW ? 0 : MAX_DEG; i != end_val; i = CW ? i + 2 : i - 2)
	{ // rotate in 2 degree increments
		rotate_to(i);
		// display degrees and distance
		int dist = ping();
		snprintf(str, 20, "%d, %d (mm)\r\n", i, dist);
		usart_str(str);			// send through usart
		if (CW) 
		{
			seven_send(dist);		// display on 7seg
			lowest = (dist < lowest) ? dist : lowest;	// update lowest recorded value
		} else
		{ // CCW
			seven_send(lowest);
		}
		_delay_ms(10);
	}
}

// -------------------------------------------------------------------
					// USART FUNCTIONS
// -------------------------------------------------------------------

void usart_init(unsigned long BAUDRATE)
{
	UCSR0B |= (1 << RXEN0) | (1 << TXEN0);			// Enable USART transmitter and receiver
	UCSR0C |= (1 << UCSZ00) | (1 << UCSZ01);		// Write USCRC for 8 bit data and 1 stop bit
	UBRR0 = ((F_CPU / (BAUDRATE * 16UL)) - 1);		// Load UBRR0 with prescale value
}

void usart_char (unsigned char ch)
{
	while (! (UCSR0A & (1<<UDRE0)));	// wait until UDR0 is empty
	UDR0 = ch;                      	//transmit ch
}

void usart_str(char* str)
{
	int i=0;
	while (str[i]!=0)
	{
		usart_char(str[i]);				// Send each char of string till the NULL
		i++;
	}
}

// -------------------------------------------------------------------
					// ULTRASONIC FUNCTIONS
// -------------------------------------------------------------------

void dist_init()
{
	DDRC |= (1 << TRIGGER);	// output
	DDRC &= ~(1 << ECHO);	// input
	PORTC |= (1 << ECHO);	// pullup resistors
	PORTC &= ~(1 << TRIGGER); // start trigger off
	_delay_ms(60);
	
	TCCR3A = 0x00;
	TCCR3B = 0x00;
	TIMSK3 |= (1 << TOIE3); // ovf int
	sei();
}

int ping()
{ // return the distance from sensor
	// tell it to send out a wave
	PORTC |= (1 << TRIGGER);
	_delay_us(10);
	PORTC &= ~(1 << TRIGGER);
	
	TCCR3B = 0x01;									// start the timer
	while((PINC & (1 << ECHO)) != (1 << ECHO));	// wait for the echo to start
	TCNT3 = 0;										// reset count
	while((PINC & (1 << ECHO)) == (1 << ECHO));	// wait for the echo to end

	int time_us = TCNT3/15;		// 1us = 15 tcnt on 16MHz
// 	char str[10];
// 	snprintf(str, 10, "%d, ", time_us);
// 	usart_str(str);
	TCCR3B = 0x00;				// turn off timer
	int dist_mm = (time_us*10)/58;	// dist_cm = (time_us)/58
	return dist_mm;			// return it in mm
}

// -------------------------------------------------------------------
					// 7SEG/SPI FUNCTIONS
// -------------------------------------------------------------------

void init_IO(void)
{	//Setup IO
	DDRB |= (DATA | LATCH | CLOCK);	//Set control pins as outputs
	PORTB &= ~(DATA | LATCH | CLOCK);		//Set control pins low
}

void init_SPI(void)
{	// Setup SPI
	SPCR0 = (1<<SPE) | (1<<MSTR);	//Start SPI as Master
}

void spi_send(unsigned char byte)
{ // sends
	SPDR0 = byte;			//Shift in some data
	while(!(SPSR0 & (1<<SPIF)));	//Wait for SPI process to finish
}

void send_char(unsigned char byte, uint8_t segment)
{ // sends a number 0-9 at segment 0-3
	spi_send((unsigned char)SEGMENT_MAP[byte]);
	spi_send((unsigned char)SEGMENT_SELECT[segment]);
	PORTB |= LATCH;
	PORTB &= ~LATCH;
	_delay_ms(dl);
}

void seven_send(int num)
{ // up to 4 digit num accepted and displayed on sevenseg
	PORTB &= ~LATCH;
	unsigned char to_send = 0x00;
	to_send = (unsigned char)(num / 1000);
	send_char(to_send, 0);						// send 1st digit
	num = num % 1000;							// toss higher digits
	to_send = (unsigned char)(num / 100);
	send_char(to_send, 1);						// send 2nd digit
	num = num % 100;							// toss higher digits
	to_send = (unsigned char)(num / 10);
	send_char(to_send, 2);						// send 3rd digit
	num = num % 10;								// toss higher digits
	to_send = (unsigned char)(num);
	send_char(to_send, 3);						// send 4th digit
}