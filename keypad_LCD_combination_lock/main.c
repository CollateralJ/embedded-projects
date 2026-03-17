#define F_CPU 1000000UL
#include <avr/io.h>
#include <util/delay.h>

//definition for the wire connections
#define rs PC0
#define rw PC1
#define en PC2
#define data PORTB

//functions necessary
void lcd_init(); //to initialize lcd.
void lcd_cmd(char cmd_out); //to send command to lcd.
void lcd_data(char data_out); //to send data to lcd.
void lcd_str(char *str); //to send string, basically stripping each character and sending.
char get_keypad();

int main(){
	//set DDR
	DDRB = 0xFF;
	DDRC = 0x07;
	DDRD = 0x0F;
	PORTD = 0xFF;
	lcd_init();
	int state = 0;
	int nextstate = 0;
	int correct = 0;
	char previnput = '\0';
	while(1){
		char input = get_keypad();
		if (input == previnput) continue;
		state = nextstate;
		switch (state) {
			case 0:
				if (input == '\0') nextstate = 0;
				else nextstate = 1;
				if (input == '1') correct++;
				break;
			case 1:
				lcd_cmd(0xC0);
				if (input == '\0') nextstate = 1;
				else nextstate = 2;
				if (input == '2') correct++;
				break;
			case 2:
				if (input == '\0') nextstate = 2;
				else nextstate = 3;
				if (input == '3') correct++;
				break;
			case 3:
				if (input == '\0') nextstate = 3;
				else nextstate = 4;
				if (input == '4') correct++;
				break;
			case 4:
				if (input == '\0') nextstate = 4;
				else if (input == '>') nextstate = 5;
				break;
			case 5:
				if (correct < 4) lcd_str("Incorrect Sequence");
				else lcd_str("Lock Opened");
				correct = 0;
				nextstate = 0;
				break;
		}
		previnput = input;
	}
}

char get_keypad() {
	PORTD = 0xF1;
	_delay_ms(10);
	if ((PIND & 0xF1) == 0x11) return '1';
	else if ((PIND & 0xF1) == 0x21) return '4';
	else if ((PIND & 0xF1) == 0x41) return '7';
	else if ((PIND & 0xF1) == 0x81) return '*';
	PORTD = 0xF2;
	_delay_ms(10);
	if ((PIND & 0xF2) == 0x12) return '2';
	else if ((PIND & 0xF2) == 0x22) return '5';
	else if ((PIND & 0xF2) == 0x42) return '8';
	else if ((PIND & 0xF2) == 0x82) return '0';
	PORTD = 0xF4;
	_delay_ms(10);
	if ((PIND & 0xF4) == 0x14) return '3';
	else if ((PIND & 0xF4) == 0x24) return '6';
	else if ((PIND & 0xF4) == 0x44) return '9';
	else if ((PIND & 0xF4) == 0x84) return '#';
	PORTD = 0xF8;
	_delay_ms(10);
	if ((PIND & 0xF8) == 0x88) return '>';
	return '\0';
}

void lcd_init(){
	PORTC &= ~(1 << en);
	// Initializing to 2 lines & 5x8 font.
	lcd_cmd(0x38);
	_delay_ms(10);
	// Display on, cursor on
	lcd_cmd(0x0E);
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

