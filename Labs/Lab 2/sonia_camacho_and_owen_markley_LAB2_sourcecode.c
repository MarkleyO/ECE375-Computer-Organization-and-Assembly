/*
SONIA CAMACHO OWEN MARKLEY 1/14/2020
This code will cause a TekBot connected to the AVR board to
move forward and when it touches an obstacle, it will reverse
and turn away from the obstacle and resume forward motion.

PORT MAP
Port B, Pin 4 -> Output -> Right Motor Enable
Port B, Pin 5 -> Output -> Right Motor Direction
Port B, Pin 7 -> Output -> Left Motor Enable
Port B, Pin 6 -> Output -> Left Motor Direction
Port D, Pin 1 -> Input -> Left Whisker
Port D, Pin 0 -> Input -> Right Whisker



*/

#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

int main(void)
{
	//from the starter code
	DDRB = 0b11110000;      // configure Port B pins for input/output
	PORTB = 0b11110000;     // set initial value for Port B outputs
	// (initially, disable both motors)

	//from the port map we see that port D has to be able to handle input 
	//so we set it to all zeros so this represents input because the DDRX is responsible for the input and output features
	DDRD = 0b00000000;
	//setting the pull up resistor
	PORTD = 0b11111111;
	
	//for the B making sure that it is all outputs 
	DDRB = 0b11111111;
	

	
	
	while (1) // loop forever
	{
		//this makes it so that PORTB is constantly moving
		PORTB = 0b01100000;
		
		//this is to see if the left has been hit
		//and check to see if they are both being hit
		if((PIND == 0b11111101 )||( PIND == 0b11111100)) //if it was hit this is from the TA slides
		{
			//modified source code
			PORTB = 0b00000000;     // move backward
			_delay_ms(500);         // wait for 500 ms
			PORTB = 0b01000000;		//turn right
 			_delay_ms(1000);        // wait for 1 s
			 PORTB = 0b00100000;	//move it forward
			
		}
		//if the right has been hit
		if(PIND == 0b11111110) 
		{
			//modified source code
			PORTB = 0b00000000;     // move backward
			_delay_ms(500);         // wait for 500 ms
			PORTB = 0b00100000;     // turn left
			_delay_ms(1000);        // wait for 1 s
			 PORTB = 0b00010000;	//move it forward
			
		}
	}
}