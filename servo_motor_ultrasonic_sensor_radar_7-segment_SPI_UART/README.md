# Servo-mounted Ultrasonic Sensor w/ 7-segment Display

This project uses the ATMega 328PB with a multi-functional shield to radially measure distance with an ultrasonic sensor!

[Video demonstration](https://youtu.be/iDaG5vbqBpA)

A PWM signal controls the servo motor to continuously sweep 180 degrees with the ultrasonic sensor mounted on it. These values are sent to the 7-segment display via hardware SPI mode in the clockwise direction, and sent via UART to a terminal in the counter-clockwise direction.
