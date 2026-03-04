# Gyroscope + Accelerometer w/ OLED Screen

This project uses the ATMega 328PB with a breadboard-mounted OLED screen to display the 6-DOF measurements of the BMI160 IMU (inertial measurement unit). Several external libraries are included in main.

[Video demonstration (playlist of four demos)](https://youtube.com/playlist?list=PLR6EhMEj6JEJAi_XseSAabQdlQbqTp7xE&si=NunxaPx3y1HqcXE0)

Using I2C, the IMU communicates with the ATMega 328PB, which then performs some calculations and displays the values on both the OLED screen and a UART terminal connection.