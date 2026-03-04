// includes
#include <avr/io.h>
#include "lcd.h"			// uses Sylaina's OLED library, linked in venki's slides http://rb.gy/aej2n
#include "util/delay.h"		// delay library
#include "MPU6050_def.h"	// Venki's include, modified for BMI160. comes with a different I2C lib
#include <stdio.h>			// Include standard io file
#include <stdlib.h>			// Include standard library file
#include "i2c_master.h"

// defines, cpu freq defined in project properties.
// bmi160
#define ACC_SCALE		16384.0
#define GYRO_SCALE		262.4

#define BMI160_ADDR		0x68
#define BMI160_CHIP_ID	0x00
#define BMI160_CMD_REG	0x7E
#define BMI160_ACC_MODE	0x11
#define BMI160_GYR_MODE	0x15
#define BMI160_PWR_CONF 0x7C
#define BMI160_PWR_CTRL	0x7D

#define BMI160_ACC_DATA	0x12
#define BMI160_GYR_DATA	0x0C

#define READ 1
#define WRITE 0
#define dt 0.01		// 10 ms sample rate!

// usart
#define BAUD_RATE		9600
float Acc_x,Acc_y,Acc_z,Gyro_x,Gyro_y,Gyro_z, roll, pitch, yaw;

// functions
// usart
void usart_init(unsigned long BAUDRATE);	// Initialize usart connection
void usart_char (unsigned char ch);			// Send 1 character through usart
void usart_str(char* str);					// Send a string through usart
// bmi160
void print_values(float, float, float, float, float, float, float, float, float);
void bmi_gyro_data();
void bmi_accel_data();
int16_t bmi_read_from(uint8_t addr);
void ComplementaryFilter();
void BMI160_Init();
void display_values();


int main(void){
	usart_init(BAUD_RATE);			// init usart
	I2C_Init();						// init I2C for BMI
	BMI160_Init();					// init BMI
	lcd_init(LCD_DISP_ON);			// init lcd/oled and turn on
	lcd_puts("Hello World\r\n");
	usart_str("Hello World\r\n");
	_delay_ms(200);
	//lcd_clrscr();

	float Xa,Ya,Za;
	float Xg=0,Yg=0,Zg=0;


	while(1){
		bmi_accel_data();			// gather accel data
		bmi_gyro_data();			// gather gyro data
		
		Xa = Acc_x/ACC_SCALE;		/* Divide raw value by sensitivity scale factor to get real values */
		Ya = Acc_y/ACC_SCALE;
		Za = Acc_z/ACC_SCALE;
					
		Xg = Gyro_x/GYRO_SCALE;
		Yg = Gyro_y/GYRO_SCALE;
		Zg = Gyro_z/GYRO_SCALE;
		ComplementaryFilter();		// filter values
		print_values(Xg, Yg, Zg, Xa, Ya, Za, roll, pitch, yaw);
		display_values();
		//_delay_ms(500);
	}
	return 0;
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
// BMI160 FUNCTIONS
// -------------------------------------------------------------------

void BMI160_Init()										/* Gyro initialization function */
{
	_delay_ms(100);										/* give time to power on */
	
	I2C_Start(BMI160_ADDR << 1 | WRITE);				
	I2C_Write(BMI160_CMD_REG);							// command register 0x7E
	I2C_Write(0xB6);									// send reset command
	I2C_Stop();
	
	_delay_ms(100);

	I2C_Start(BMI160_ADDR << 1 | WRITE);
	I2C_Write(BMI160_CMD_REG);							// command register 0x7E
	I2C_Write(BMI160_ACC_MODE);							// accel config
	I2C_Stop();
	
	_delay_ms(100);

	I2C_Start(BMI160_ADDR << 1 | WRITE);
	I2C_Write(BMI160_CMD_REG);							// command register 0x7E
	I2C_Write(BMI160_GYR_MODE);							// gyr config
	I2C_Stop();	
	
	_delay_ms(100);
}

int16_t bmi_read_from(uint8_t addr)
{	// reads from a low+high register and returns (input low addr)
	I2C_Start(BMI160_ADDR << 1 | WRITE);			// start in write mode
	I2C_Write(addr);								// declare address
	//I2C_Stop();									// end write mode
	I2C_Start(BMI160_ADDR << 1 | READ);				// start in read mode
	int16_t reading = ((int)I2C_Read_Ack());		// read low byte
	reading = reading | ((int)I2C_Read_Nack()<<8);	// add high byte 
	I2C_Stop();										// end read mode
	return reading;
}

void bmi_gyro_data()
{
	Gyro_x = bmi_read_from(0x0C);//(((int)I2C_Read_Ack()<<8) | (int)I2C_Read_Ack());
	Gyro_y = bmi_read_from(0x0E);//(((int)I2C_Read_Ack()<<8) | (int)I2C_Read_Ack());
	Gyro_z = bmi_read_from(0x10);//(((int)I2C_Read_Ack()<<8) | (int)I2C_Read_Nack());
}

void bmi_accel_data()
{
	Acc_x = bmi_read_from(0x12);//(((int)I2C_Read_Ack()<<8) | (int)I2C_Read_Ack());
	Acc_y = bmi_read_from(0x14);//(((int)I2C_Read_Ack()<<8) | (int)I2C_Read_Ack());
	Acc_z = bmi_read_from(0x16);//(((int)I2C_Read_Ack()<<8) | (int)I2C_Read_Nack());
}

void print_values(float Xg, float Yg, float Zg, float Xa, float Ya, float Za, float roll, float pitch, float yaw)
{
	char output[100], buffer[10];
	dtostrf(Xa, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s, ", buffer);
	dtostrf(Ya, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(Za, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(Xg, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(Yg, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(Zg, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(roll, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(pitch, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, ", output, buffer);
	dtostrf(yaw, 3, 2, buffer);
	snprintf(output, sizeof(output), "%s%s, \r\n", output, buffer);
	usart_str(output);
}


void ComplementaryFilter()
{
	float pitchAcc, rollAcc;
	
	// Integrate the gyroscope data -> int(angularSpeed) = angle
	pitch += (Gyro_x / GYRO_SCALE) * dt; // Angle around the X-axis
	roll -= (Gyro_y / GYRO_SCALE) * dt;    // Angle around the Y-axis
	yaw -= (Gyro_z / GYRO_SCALE) * dt;    // Angle around the Z-axis
	
	// Compensate for drift with accelerometer data if !bullshit
	// Sensitivity = -2 to 2 G at 16Bit -> 2G = 32768 && 0.5G = 8192
	int forceMagnitudeApprox = abs(Acc_x) + abs(Acc_y) + abs(Acc_z);
	if (forceMagnitudeApprox > 8192 && forceMagnitudeApprox < 32768)
	{
		// Turning around the X axis results in a vector on the Y-axis
		pitchAcc = atan2f(Acc_y, Acc_z) * 180 / M_PI;
		pitch = pitch * 0.98 + pitchAcc * 0.02;
		
		// Turning around the Y axis results in a vector on the X-axis
		rollAcc = atan2f(Acc_x, Acc_z) * 180 / M_PI;
		roll = roll * 0.98 + rollAcc * 0.02;
		
		// no magnetometer
	}
}

void display_values()
{
	char buffer[10];
	lcd_clrscr();
	lcd_puts("Roll: \r\n");

	dtostrf(roll, 3, 2, buffer);
	lcd_puts(buffer);
	
	lcd_puts("\r\nPitch: \r\n");
	dtostrf(pitch, 3, 2, buffer);
	lcd_puts(buffer);
	
	lcd_puts("\r\nYaw: \r\n");
	dtostrf(yaw, 3, 2, buffer);
	lcd_puts(buffer);
}