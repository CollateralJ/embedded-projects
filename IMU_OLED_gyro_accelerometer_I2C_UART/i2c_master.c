/*
 * I2C_Master_C_file.c
 * http://www.electronicwings.com
 *
 */ 


#include "i2c_master.h"								/* Include I2C header file */

void I2C_Init(void)												/* I2C initialize function */
{
	// set clock
	switch (PSC_I2C) {
		case 4:
		TWSR0 = 0x1;
		break;
		case 16:
		TWSR0 = 0x2;
		break;
		case 64:
		TWSR0 = 0x3;
		break;
		default:
		TWSR0 = 0x00;
		break;
	}
	TWBR0 = (uint8_t)SET_TWBR;
	// enable
	TWCR0 = (1 << TWEN);
}

void I2C_Start(uint8_t slave_write_address)						/* I2C start function */
{
									/* Declare variable */
	TWCR0 = (1<<TWSTA)|(1<<TWEN)|(1<<TWINT);				/* Enable TWI, generate start condition and clear interrupt flag */
	while (!(TWCR0 & (1<<TWINT)));							/* Wait until TWI finish its current job (start condition) */
	TWDR0 = slave_write_address;							/* If yes then write SLA+W in TWI data register */
	TWCR0 = (1<<TWEN)|(1<<TWINT);							/* Enable TWI and clear interrupt flag */
	while (!(TWCR0 & (1<<TWINT)));							/* Wait until TWI finish its current job (Write operation) */
}

void I2C_Stop(void)												/* I2C stop function */
{
	TWCR0=(1<<TWSTO)|(1<<TWINT)|(1<<TWEN);					/* Enable TWI, generate stop condition and clear interrupt flag */
	while(TWCR0 & (1<<TWSTO));								/* Wait until stop condition execution */ 
}

void I2C_Write(uint8_t data)								/* I2C write function */
{
	TWDR0 = data;											/* Copy data in TWI data register */
	TWCR0 = (1<<TWEN)|(1<<TWINT);							/* Enable TWI and clear interrupt flag */
	while (!(TWCR0 & (1<<TWINT)));							/* Wait until TWI finish its current job (Write operation) */
}

uint8_t I2C_Read_Ack(void)										/* I2C read ack function */
{
	TWCR0=(1<<TWEN)|(1<<TWINT)|(1<<TWEA);					/* Enable TWI, generation of ack and clear interrupt flag */
	while (!(TWCR0 & (1<<TWINT)));							/* Wait until TWI finish its current job (read operation) */
	return TWDR0;											/* Return received data */
}	

uint8_t I2C_Read_Nack(void)										/* I2C read nack function */
{
	TWCR0=(1<<TWEN)|(1<<TWINT);								/* Enable TWI and clear interrupt flag */
	while (!(TWCR0 & (1<<TWINT)));							/* Wait until TWI finish its current job (read operation) */
	return TWDR0;											/* Return received data */
}	
