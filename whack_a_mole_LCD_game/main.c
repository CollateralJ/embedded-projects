#define F_CPU 1000000UL
#include <avr/io.h>
#include <util/delay.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <stdio.h>

enum State {
	Idle,
	Peek,
	Pop,
	Hit,
	Concussed,
	Missed
};

//PushButtons wire connections
#define button1 PD0
#define button2 PD1
#define button3 PD2
#define button4 PD3
void pushbutton_init();
int get_pushbutton();

//Life LED wire connections
#define life1 PC3
#define life2 PC4
#define life3 PC5
volatile int life;
void led_init();
	
//LCD display wire connections
#define rs PC0
#define rw PC1
#define en PC2
#define data PORTB

//LCD display functions
void lcd_init(); //to initialize lcd.
void lcd_cmd(char cmd_out); //to send command to lcd.
void lcd_data(char data_out); //to send data to lcd.
void lcd_str(char *str); //to send string, basically stripping each character and sending.

#define seed 4
#define RANDMAX 4
#define RANDOMMAX 100
void delayran(int input);
void timerRand(int input);
volatile int canHit;

// timer functions & things
volatile int canHit;
void timer_init();
void timerRand(int input);
void lose_life(int score);
void game_init();
void game_end(int score);
void holeChange(int hole, int stateToChangeTo);

ISR(TIMER1_COMPA_vect){
	canHit = 0; // disallow hitting (missed)
	cli(); // disable interrupts
}

int main(void) {
	lcd_init();
	led_init();
	pushbutton_init();
	timer_init();
	game_init();
	srand(seed);
	srandom(seed);
	enum State previousState = Idle;
	enum State nextState = Idle;
	enum State currentState = Idle;
	int hole = 0;
	int score = 0;
	int couldHit = 0;
    while (1) {
		int input = get_pushbutton();
		previousState = currentState;
		if (nextState != currentState) {
			currentState = nextState;
		}
		if (input != 0) nextState = Missed;
		if (couldHit != canHit) {
        	if (couldHit == 1) nextState = Missed;
            couldHit = canHit;
        }
		switch (currentState) {
			case Idle:
				holeChange(hole,Idle);
				_delay_ms(400);
				delayran(random()%RANDOMMAX);
				hole = (rand()%RANDMAX) + 1;
				nextState = Peek;
				break;
			case Peek:
				holeChange(hole,Peek);
				_delay_ms(200);
				nextState = Pop;
				break;
			case Pop:
				if (previousState == Pop) break;
				holeChange(hole,Pop);
				timerRand(random()%RANDOMMAX);
				_delay_us(1);
            	while (canHit) {
                	input = get_pushbutton();
                	if (input > 0) {
                    	if (input == hole) {
                        	nextState = Hit;
                    	}
                    	else {
							nextState = Missed;
						}
						canHit = 0;
						break;
                	}
                }
				if (nextState == Pop) nextState = Missed;
				break;
			case Hit:
				holeChange(hole,Hit);
				score += 15;
				_delay_ms(400);
				nextState = Concussed;
				break;
			case Missed:
				holeChange(hole,Missed);
				lose_life(score);
				_delay_ms(400);
				nextState = Idle;
				break;
			case Concussed:
				holeChange(hole,Concussed);
				_delay_ms(400);
				nextState = Idle;
				break;
		}
    }
}

void game_init(){
	lcd_str("Whack-A-Mole");
	_delay_ms(1000);
	lcd_cmd(0x01);
	lcd_cmd(0xC0);
	lcd_str("/_Í/_Í/_Í/_Í");
}

void game_end(int score) {
	lcd_cmd(0x01);
	lcd_cmd(0x80);
	lcd_str("Game Over");
	lcd_cmd(0xC0);
	lcd_str("Score: ");
	char buffer [sizeof(int)*8+1];
	snprintf(buffer,sizeof(buffer),"%d",score);
	lcd_str(buffer);
}

void delayran(int input) {
	// input rand number from 0-99                        // chance
	if      ((0  <= input) && (input < 30))     _delay_ms(300);     // 30% - 1/2 sec
	else if    ((30 <= input) && (input < 50))     _delay_ms(800);     // 20% - 1 sec
	else if    ((50 <= input) && (input < 70))     _delay_ms(550);     // 20% - 3/4 sec
	else if    ((70 <= input) && (input < 85))     _delay_ms(200);     // 15% - 2/5 sec
	else if    ((85 <= input) && (input < 95))     _delay_ms(1800);    // 10% - 2 sec
	else if    ((94 <= input) && (input < 100))    _delay_ms(150);     // 5% - 1/3 sec just above reaction speed
	else                                        _delay_ms(300);
}

void timer_init(){
	TIMSK1 |= (1 << OCIE1A); // enable timer 1 compare a ISR
	TCCR1B |= (1 << CS12) | (1 << WGM12); // 256 prescaler - CTC mode (ocr1a top)
}

void timerRand(int input) {
	canHit = 1;
	// input rand number from 0-99              // top value    // chance
	if      ((0  <= input) && (input < 30))     OCR1A = 1171;   // 30% - 300 ms  - 1/2 sec
	else if    ((30 <= input) && (input < 50))     OCR1A = 3124;   // 20% - 800 ms  - 1 sec
	else if    ((50 <= input) && (input < 70))     OCR1A = 2147;   // 20% - 550 ms  - 3/4 sec
	else if    ((70 <= input) && (input < 85))     OCR1A = 780;    // 15% - 200 ms  - 2/5 sec
	else if    ((85 <= input) && (input < 95))     OCR1A = 7030;   // 10% - 1800 ms - 2 sec
	else if    ((94 <= input) && (input < 100))    OCR1A = 585;    // 5%  - 150 ms  - 1/3 sec
	else                                        OCR1A = 1171;   // default: 1/2 sec
	TCNT1 = 0;
  	sei(); // enable for the compare interrupt
}

void holeChange(int hole, int stateToChangeTo) {
	if (hole == 0) return;
	int column = (hole * 3) - 2;
	char top;
	char bottom;
	enum State state = stateToChangeTo;
	switch (state) {
		case Idle:
			top = ' ';
			bottom = '_';
			break;
		case Peek:
			top = ' ';
			bottom = 'o';
			break;
		case Pop:
			top = 'o';
			bottom = '0';
			break;
		case Hit:
			top = '*';
			bottom = '0';
			break;
		case Concussed:
			top = ' ';
			bottom = '*';
			break;
		case Missed:
			top = '!';
			bottom = 'o';
			break;
		default:
			top = ' ';
			bottom = ' ';
	}
	lcd_cmd(0x80 + column);
	lcd_data(top);
	lcd_cmd(0xC0 + column);
	lcd_data(bottom);
}

void pushbutton_init() {
	PORTD |= (1<<button1) | (1<<button2) | (1<<button3) | (1<<button4);
}

int get_pushbutton(){
	if ((PIND & (1<<button1)) == (1<<button1)) return 1;
	if ((PIND & (1<<button2)) == (1<<button2)) return 2;
	if ((PIND & (1<<button3)) == (1<<button3)) return 3;
	if ((PIND & (1<<button4)) == (1<<button4)) return 4;
	return 0;
}

void led_init(){
	DDRC |= 0xE0;
	PORTC |= (1<<life1) | (1<<life2) | (1<<life3);
	life = 3;
}

void lose_life(int score){
	life -= 1;
	switch (life) {
		case 2:
			PORTC &= ~(1<<life3);
			_delay_ms(10);
			break;
		case 1:
			PORTC &= ~(1<<life2);
			_delay_ms(10);
			break;
		default:
			PORTC &= ~(1<<life1);
			_delay_ms(10);
			game_end(score);
			while (1);
			break;
	}
}

void lcd_init(){
	DDRB = 0xFF;
	DDRC |= 0x07;
	PORTC &= ~(1 << en);
	// Initializing to 2 lines & 5x8 font.
	lcd_cmd(0x38);
	_delay_ms(10);
	// Display on, cursor off
	lcd_cmd(0x0C);
	_delay_ms(10);
	// Clear LCD
	lcd_cmd(0x01);
	_delay_ms(10);
	// Set cursor position to top row 0x80
	lcd_cmd(0x80);
	_delay_ms(10);
}

void lcd_cmd(char cmd_out){
	//send the cmd_out to data
	data = cmd_out;
	//set rs = 0 ,rw=0 and en =1
	PORTC &= ~(1<<rs);
	PORTC &= ~(1<<rw);
	PORTC |= (1<<en);
	//wait for small delay 10ms
	_delay_ms(10);
	//set rs = 0 ,rw=0 and en =0
	PORTC &= ~(1<<en);
	//wait for small delay 10ms
	_delay_ms(10);
}

void lcd_data(char data_out){
	//send the data_out to data
	data = data_out;
	//set rs = 1 ,rw=0 and en =1
	PORTC |= (1<<rs);
	PORTC &= ~(1<<rw);
	PORTC |= (1<<en);
	//wait for small delay 10ms
	_delay_ms(10);
	//set rs = 1 ,rw=0 and en =0
	PORTC &= ~(1<<en);
	//wait for small delay 10ms
	_delay_ms(10);
}

void lcd_str(char *str) {
	unsigned int i=0;
	while(str[i]!='\0'){
		lcd_data(str[i]);
		i++;
	}
}






