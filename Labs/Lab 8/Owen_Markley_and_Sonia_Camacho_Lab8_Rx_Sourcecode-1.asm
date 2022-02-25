;***********************************************************
;*
;*	Lab 8 Robot (Receiver)
;*
;*	Program receives instruction from the remote and instructs
;*  the robot to act according to received instructions
;*
;*
;***********************************************************
;*
;*	 Author: Owen Markley, Alex Molotkov, Sonia Camacho
;*	   Date: 3/1/19
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	data = r17				; Stores data read in from UDR1
.def	lastTrans = r18			; Stores last transmission received
.def	lastDir = r22			; Stores last transmission received after a handshake
.def	freezeCount = r23		; Stores how many times a freeze signal was received

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ WTime = 100			; Time to wait in wait loop ; set to 500 to make 5 s
.def waitcnt = r19			; Wait Loop Counter
.def ilcnt = r20			; Inner Loop Counter
.def olcnt = r21			; Outer Loop Counter

.equ	BotAddress = $1A;(Enter your robot's address here (8 bits))

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0002					;- Left whisker
		rcall HitLeft
		reti

.org	$0004					;- Right whisker
		rcall HitRight
		reti

.org	$003C					;- USART1 receive
		rjmp Receive	
		
.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi mpr, high(RAMEND)		; Load in high bit of stack pointer
	out sph, mpr
	ldi mpr, low(RAMEND)		; Load in low bit of stack pointer
	out spl, mpr

	;I/O Ports B out D in
	;PORTB
	ldi mpr, (1<<EngEnL)|(1<<EngEnR)|(1<<EngDirR)|(1<<EngDirL)	; Enable the four bits to represent the enable and direction bits with LED lights
	out DDRB, mpr
	ldi mpr, (0<<EngEnL)|(0<<EngEnR)|(0<<EngDirR)|(0<<EngDirL)	; Configure port for output
	out PORTB, mpr

	;PORTD
	ldi mpr, (0<<PD2)|(0<<WskrL)|(0<<WskrR)|(1<<PD3)			; PD3 will enable transmission, PD2 the receiver, and WSKRL, and WSKR the buttons representing  the whiskers
	out DDRD, mpr
	ldi mpr, (1<<WskrL)|(1<<WskrR)
	out PORTD, mpr												; PD2 and PD3 are alternative function pins, so we only worry about the direction of WSKRL and WSKRR

	;USART1
	ldi mpr, high(832)											; 832 correlates to a baudrate of 2400bps, and the high bit must be loaded in first
	sts UBRR1H, mpr
	ldi mpr, low(832) ;Set baudrate at 2400bps
	sts UBRR1L, mpr
	
	;Data Frame Formatting
	ldi mpr, (1<<U2X1)											; Enable the double data rate bit
	sts UCSR1A, mpr
	ldi mpr, (1<<TXEN1)|(1<<RXEN1)|(1<<RXCIE1)|(0<<UCSZ12)		; Enable receiver and enable receive interrupts as well as the transmission enable
	sts UCSR1B, mpr
	ldi mpr, (0<<UMSEL1)|(0<<UPM11)|(0<<UPM10)|(1<<USBS1)|(1<<UCSZ10)|(1<<UCSZ11) ;Set frame format: 8 data bits, 2 stop bits, no parity bit, and asynchronous
	sts UCSR1C, mpr
	
	;Define registers
	ldi lastTrans, $00											; Set our registers to zero
	ldi lastDir, $00
	ldi freezeCount, $00
	
	;Global Interrupts
	sei															; enable global interrupts
		
	;External Interrupts
	ldi mpr, $03												;Set the External Interrupt Mask
	out EIMSK, mpr
	ldi mpr, (1<<ISC11)|(0<<ISC10)|(1<<ISC01)|(0<<ISC00)		;Set the Interrupt Sense Control to falling edge detection
	sts EICRA, mpr

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:

	rjmp	MAIN												;Loops infinitely
		

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;------------------------------------------------------------
;Receive - Reads in received data, compares to known commands
;			and instructs robot based on what has been
;			received.
;------------------------------------------------------------
Receive:
				clr mpr											; Upon receive set registers to empty, and load in received data from UDR1
				clr data
				lds data, UDR1
			
checkRecFrZ:	ldi mpr, 0b01010101								; Check to see if a 'Freeze Attack" signal was received
				cp data, mpr
				brne checkHandshake								; If not, skip to checking for a handshake
				inc freezeCount									; Increment the freeze count and check if this was the third
				cpi freezeCount, 3
				breq dis										; If it was the third freeze Disable robot indefinitely
				ldi mpr, Halt									; Put the robot in to a Halted states
				out PORTB, mpr
				;ldi lastDir, Halt
				ldi  waitcnt, WTime								; Wait for ~5 seconds
				rcall Wait
				rcall Wait
				rcall Wait
				out PORTB, lastDir								; Reload the robots state before being frozen
				rjmp end										; End the receive function

dis:			rcall Disable									; Used to call Disable function


checkHandshake: ldi mpr, BotAddress								; Compare the last transmission received to the bot's address
				cp mpr, lastTrans
				brne end										; If the previous signal was not the address, skip to end of function

checkMovFwd:	ldi mpr, 0b10110000								; Check to see a move forward command was received
				cp data, mpr
				brne checkMovBck								; If not, continue on checking for other known signals
				ldi mpr, MovFwd									; Load the move Forwards state
				out PORTB, mpr
				ldi lastDir, MovFwd								; Save this as the last direction received
				rjmp end										; end the funciton call

checkMovBck:	ldi mpr, 0b10000000								; Check to see if a move backwards command was recevied
				cp data, mpr
				brne checkTurnR									; If not, continue on checking for other known signals
				ldi mpr, MovBck									; Load the move backward state
				out PORTB, mpr	
				ldi lastDir, MovBck								; Save this as the last direction received
				rjmp end										; end the function call

checkTurnR:		ldi mpr, 0b10100000								; Check to see if a turn right command was received
				cp data, mpr
				brne checkTurnL									; If not, continue on checking for other known signals
				ldi mpr, TurnR									; Load the turn right state
				out PORTB, mpr
				ldi lastDir, TurnR								; Save this as the last direction received
				rjmp end										; end the function call

checkTurnL:		ldi mpr, 0b10010000								; Check to see if a turn left command was received
				cp data, mpr									
				brne checkHalt									; If not, continue on checking for other known signals
				ldi mpr, TurnL									; Load the turn left state
				out PORTB, mpr
				ldi lastDir, TurnL								; Save this as the last direction received
				rjmp end										; end the function call

checkHalt:		ldi mpr, 0b11001000								; Check to see if a halt command was received
				cp data, mpr
				brne checkSendFrZ								; If not, continue on checking for other known signals
				ldi mpr, Halt									; Load the halt state
				out PORTB, mpr
				ldi lastDir, Halt								; Save this as the last direction received
				rjmp end										; end the function call

checkSendFrZ:	ldi mpr, 0b11111000								; Check to see if a send freeze command was received
				cp data, mpr
				brne end										; If not, end function
				rcall SendFreeze								; Call the send freeze function



end:			mov lastTrans, data								; Record the newly received data as the last transmission received
				reti											; return from interrupt
;------------------------------------------------------------
;Wait - Waits for an amount of time based on WTime
;------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt			; Restore olcnt register
		pop		ilcnt			; Restore ilcnt register
		pop		waitcnt			; Restore wait register
		ret						; Return from subroutine
;------------------------------------------------------------
;HitLeft - Backs up for a second, Turns Right, and returns to
;			previous state (interrupt activated)
;------------------------------------------------------------
HitLeft:
			cli					; temporarily disable gloabl interupts

			push mpr			 ; Save mpr register
			push waitcnt		 ; Save wait register
			in  mpr, SREG		; Save program state
			push mpr   ;

			ldi  mpr, MovBck	; Load Move Backward command
			out  PORTB, mpr ; Send command to port
			ldi  waitcnt, WTime ; Wait for 1 second
			rcall Wait   ; Call wait function

			ldi  mpr, TurnR ; Load Turn Left Command
			out  PORTB, mpr ; Send command to port
			ldi  waitcnt, WTime ; Wait for 1 second
			rcall Wait   ; Call wait function
			
			out PORTB, lastDir ; output the last direction received to port B

			ldi mpr, 0b11111111 
			out EIFR, mpr ;pushes to register 
			
			rcall EmptyUSART
			
			pop  mpr  ; Restore program state
			out  SREG, mpr ;
			pop  waitcnt  ; Restore wait register
			pop  mpr  ; Restore mpr

			sei				; reenable global interrupts
leftEnd:	reti			; return from interrupt

;------------------------------------------------------------
;HitRight - Backs up for a second, Turns Left, and returns to
;			previous state (interrupt activated)
;------------------------------------------------------------
HitRight:
			cli			; temporarily disable gloabl interupts

			push mpr   ; Save mpr register
			push waitcnt   ; Save wait register
			in  mpr, SREG ; Save program state
			push mpr   ;

			ldi  mpr, MovBck ; Load Move Backward command
			out  PORTB, mpr ; Send command to port
			ldi  waitcnt, WTime ; Wait for 1 second
			rcall Wait   ; Call wait function

			ldi  mpr, TurnL ; Load Turn Left Command
			out  PORTB, mpr ; Send command to port
			ldi  waitcnt, WTime ; Wait for 1 second
			rcall Wait   ; Call wait function
			
			out PORTB, lastDir		; output the last direction received to port B

			ldi mpr, 0b11111111 
			out EIFR, mpr ;pushes to register 
			
			rcall EmptyUSART
			
			pop  mpr  ; Restore program state
			out  SREG, mpr ;
			pop  waitcnt  ; Restore wait register
			pop  mpr  ; Restore mpr

			sei					; reenable global interupts
rightEnd:	reti				; return from interrupt

;------------------------------------------------------------
;EmptyUSART - Empties out UDR register
;------------------------------------------------------------
EmptyUSART:
			lds mpr, UCSR1A		; Takes the state of status register one and loads into mpr
			sbrs mpr, RXC1		; checks the state of the RXC1 (receive enable bit)
			ret					; Returns from function
			lds mpr, UDR1		; temporarily stores the UDR1, this will be rewritten upon looping
			rjmp EmptyUSART		; loops back over 

;------------------------------------------------------------
;Disable - Indefinitely flashes all LED's to indicate
;			being disabled, cannot perform other any funtions
;			once initiated
;------------------------------------------------------------
Disable:

infLoop:
			ldi mpr, 0b11110000			; loads 'on' to all enabled LEDS
			out PORTB, mpr
			ldi  waitcnt, WTime			; waits for ~1 s
			rcall Wait
			ldi mpr, 0b00000000			; loads 'off' to all enabled LEDS
			out PORTB, mpr
			ldi  waitcnt, WTime			; waits for ~1s
			rcall Wait
			rjmp infLoop				; loops over indefinitely

			reti

;------------------------------------------------------------
;SendFreeze: - Sends out a freeze transmission from the
;				robot
;------------------------------------------------------------

SendFreeze:	
				ldi mpr, (1<<TXEN1)|(0<<RXEN1)|(1<<RXCIE1)|(0<<UCSZ12)	;Enables the transmitter, and disables the receiver
				sts UCSR1B, mpr

transmitting:
				lds mpr, UCSR1A											; Checks to see if the UDR is empty  
				sbrs mpr, UDRE1
				rjmp transmitting										; Repeats if not
				ldi mpr, 0b01010101										; loads Freeze signal into data register
				sts UDR1, mpr

				ldi waitcnt, 10											; Waits for ~1/10 s
				rcall Wait

				ldi mpr, (1<<TXEN1)|(1<<RXEN1)|(1<<RXCIE1)|(0<<UCSZ12) ;Restore original state of status register
				sts UCSR1B, mpr
				
				ret														; returns from function

;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************