;***********************************************************
;* Owen_Markley_Lab4_sourcecode.asm
;*	
;* Basic Bumpbot program has been reconfigured to respond to interupt
;* as opposed to polling for inputs. Each time a bump occurs and a whisker
;* is triggered, a counter will increment on the LCD Display either representing
;* the count of collisions on the left or right whisker.
;*
;* Lab 6
;*
;***********************************************************

.include "m128def.inc"				; Include definition file

;************************************************************
;* Variable and Constant Declarations
;************************************************************
.def	rightcnt = r1			; right interrupt counter
.def	leftcnt = r2			; left interrupt counter
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r23			; Rest Loop Counter
.def	ilcnt = r24				; Inner Loop Counter
.def	olcnt = r25				; Outer Loop Counter


.equ	WTime = 100				; Time to wait in wait loop

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	MovBck = $00				; Move Backward Command
.equ	TurnR = (1<<EngDirL)			; Turn Right Command
.equ	TurnL = (1<<EngDirR)			; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command

;**************************************************************
;* Beginning of code segment
;**************************************************************
.cseg

;--------------------------------------------------------------
; Interrupt Vectors
;--------------------------------------------------------------
.org	$0000				; Reset and Power On Interrupt
		rjmp	INIT		; Jump to program initialization

.org	$0002 ;{IRQ0 => pin0, PORTD} 
		rcall HitRight		; Calls the hit right function on interrupt
		reti

.org	$0004 ;{IRQ1 => pin1, PORTD}
		rcall HitLeft		; Calls the hit left function on interrupt
		reti

.org	$0006 ;{IRQ2 => pin2, PORTD}
		rcall RightClear	; calls the clear funciton on interrupt
		reti

.org	$0008 ;{IRQ3 => pin3, PORTD}
		rcall LeftClear		; calls the right clear function in interrupt
		reti

.org	$0046				; End of Interrupt Vectors
;--------------------------------------------------------------
; Program Initialization
;--------------------------------------------------------------
INIT:
    ; Initialize the Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND) ;low end of stack pointer initialized
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND) ;high end of stack pointer initialized
		out		SPH, mpr		; Load SPH with high byte of RAMEND

    ; Initialize Port B for output
		ldi		mpr, (1<<EngEnL)|(1<<EngEnR)|(1<<EngDirR)|(1<<EngDirL)	; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

	; Initialize Port D for input
		ldi		mpr, (0<<WskrL)|(0<<WskrR)		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, (1<<WskrL)|(1<<WskrR)		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State
	;Initialize external interrupts
		;Set the Interupts Sense control to falling edge
	ldi mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10) ; setting these values allows for the falling edge to trigger
	sts EICRA, mpr ;binary value is loaded into external interrupt control register

	;Set the External Interrupt Mask
	ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)|(1<<INT3) ; last four digits in value are set to 1
	out EIMSK, mpr ; setting the external interrupt mask register allows for signal to go through on these interrupts

	;intitialise the counters
	clr leftcnt ; counter set to zero
	clr rightcnt ; right counter set to zero

	;Inititalize LCD
	rcall LCDInit ; LCD display is initialized using provided driver
	

	sei ; global interrupt enable

;---------------------------------------------------------------
; Main Program
;---------------------------------------------------------------
MAIN:
	;Move Robot Forwards
	ldi mpr, MovFwd ; both engine bits enabled and forwards, value loaded into mpr
	out PORTB, mpr ; output to LED's

	rjmp MAIN ; loop forever

;****************************************************************
;* Subroutines and Functions
;****************************************************************

;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitRight:

		inc rightcnt ; add one to right bumper hit count

		mov mpr, rightcnt ; rightcnt is loaded into mpr to prepare for BIN2ASCII function
		ldi XL, low(LCDLn1Addr) ; output will be placed into low and high of lcd line 1 Addr
		ldi XH, high(LCDLn1Addr)
		rcall Bin2ASCII ; converts the bin value to to an ascii and stores it into the lcd line 1 address
		rcall LCDWrLn1 ; writes value in line address to the the the top line of lcd display

		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi mpr, 0b00000000 ; value of zero is loaded into mpr
		out EIFR, mpr ; filling the flag register with zeroes will clear any requests for interrupts

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Rest for 1 second
		rcall	Rest			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Rest for 1 second
		rcall	Rest			; Call wait function

		ldi mpr, 0b11111111 ; ones are loaded into the mpr
		out EIFR, mpr ; flags are then set to logical high

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the left whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:
		inc leftcnt ; left counter is incremented by one

		mov mpr, leftcnt ; leftcnt loaded into mpr for bin2ascii
		ldi XL, low(LCDLn2Addr) ; address of line two is loaded into X
		ldi XH, high(LCDLn2Addr)
		rcall Bin2ASCII ; converts binary value to ascii string
		rcall LCDWrLn2 ; writes the converted string to the string

		push	mpr			; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi mpr, 0b00000000 ; zeroes are loaded into mpr
		out EIFR, mpr ; flags are set to zero, preventing more signals for the moment

		; Move Backwards for a second
		ldi		mpr, MovBck	; Load Move Backward command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Rest for 1 second
		rcall	Rest			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR	; Load Turn Left Command
		out		PORTB, mpr	; Send command to port
		ldi		waitcnt, WTime	; Rest for 1 second
		rcall	Rest			; Call wait function

		ldi mpr, 0b11111111 ; ones are loaded into the mpr
		out EIFR, mpr ; flags are then set to logical high

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		waitcnt		; Restore wait register
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	Rest
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Rest:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Rest loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine

;----------------------------------------------------------------
; Sub:	RightClear
; Desc:	Clears the counter on the LCD display top line for the amount
;		of times that the right whisker has been triggered by the 
;		interrupt
;----------------------------------------------------------------
RightClear:

	ldi mpr, 0b00000000 ; repeats same process as above to prevent other interrupts from occurring at same time
	out EIFR, mpr

	clr rightcnt ; clears the right count, resets to zero
	rcall LCDClrLn1 ; clears the first line of the lcd, doesn't really work and clears whole screen

	ldi mpr, 0b11111111
	out EIFR, mpr

;----------------------------------------------------------------
; Sub:	LeftClear
; Desc:	Clears the counter on the LCD display bottom line for the amount
;		of times that the left whisker has been triggered by the 
;		interrupt
;----------------------------------------------------------------
LeftClear:

	ldi mpr, 0b00000000 ; repeats same process as above to prevent other interrupts from occurring at same time
	out EIFR, mpr

	clr leftcnt ; clears the right count, resets to zero
	rcall LCDClrLn2 ; clears the first line of the lcd, doesn't really work and clears whole screen

	ldi mpr, 0b11111111
	out EIFR, mpr

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
