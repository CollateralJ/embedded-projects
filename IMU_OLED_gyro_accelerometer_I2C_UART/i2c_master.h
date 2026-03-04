/*
 * I2C_Master_H_file.h
 * http://www.electronicwings.com
 *
 */ 


#ifndef I2C_MASTER_H_FILE_H_					/* Define library H file if not defined */
#define I2C_MASTER_H_FILE_H_
#define F_I2C			100000UL// clock i2c
#define PSC_I2C			1		// prescaler i2c
#define SET_TWBR		(F_CPU/F_I2C-16UL)/(PSC_I2C*2UL)
#include <avr/io.h>								/* Include AVR std. library file */
#include <util/delay.h>							/* Include delay header file */
#include <math.h>								/* Include math function */
#define SCL_CLK 100000UL							/* Define SCL clock frequency */
#define BITRATE(TWSR0)	((F_CPU/SCL_CLK)-16)/(2*pow(4,(TWSR0&((1<<TWPS0)|(1<<TWPS1))))) /* Define bit rate */

void I2C_Init(void);								/* I2C initialize function */
void  I2C_Start(uint8_t);						/* I2C start function */
void I2C_Stop(void);								/* I2C stop function */
void I2C_Write(uint8_t);						/* I2C write function */
uint8_t I2C_Read_Ack(void);							/* I2C read ack function */
uint8_t I2C_Read_Nack(void);							/* I2C read nack function */


#endif											/* I2C_MASTER_H_FILE_H_ */