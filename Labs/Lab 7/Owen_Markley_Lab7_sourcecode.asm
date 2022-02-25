;***********************************************************
;*
;*	Owen_Markley_Lab7_sourcecode
;*
;*	Enter the description of the program here
;*
;*	This is the skeleton file for Lab 7 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Owen Markley
;*	   Date: 2/18/20
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	cSpeed = r17

.def	waitcnt = r23			; Rest Loop Counter
.def	ilcnt = r24				; Inner Loop Counter
.def	olcnt = r25				; Outer Loop Counter


.equ	WTime = 100				; Time to wait in wait loop

.equ	EngEnR = 4				; right Engine Enable Bit
.equ	EngEnL = 7				; left Engine Enable Bit
.equ	EngDirR = 5				; right Engine Direction Bit
.equ	EngDirL = 6				; left Engine Direction Bit

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

.org	$0002
		rcall IncSpeed
		reti

.org	$0004
		rcall DecSpeed
		reti

.org	$0006
		rcall TopSpeed
		reti

.org	$0008
		rcall MinSpeed
		reti

		; place instructions in interrupt vectors here, if needed

.org	$0046					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	; Initialize the Stack Pointer
		ldi		mpr, low(RAMEND) ;low end of stack pointer initialized
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND) ;high end of stack pointer initialized
		out		SPH, mpr		; Load SPH with high byte of RAMEND

	; Configure I/O ports
		; Initialize Port B for output
		ldi		mpr, 0b11111111	; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low		

		; Initialize Port D for input
		ldi		mpr, $00	; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

	; Configure External Interrupts, if needed

		ldi mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)|(1<<ISC21)|(0<<ISC20)|(1<<ISC31)|(0<<ISC30) ; setting these values allows for the falling edge to trigger
		sts EICRA, mpr ;binary value is loaded into external interrupt control register

		;Set the External Interrupt Mask
		ldi mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)|(1<<INT3) ; last four digits in value are set to 1
		out EIMSK, mpr ; setting the external interrupt mask register allows for signal to go through on these interrupts

		; Configure 8-bit Timer/Counters
		ldi mpr, 0b01111001
		out TCCR0, mpr

		out TCCR2, mpr

								; no prescaling

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL)
		ldi		mpr, MovFwd	; Load Move Backward command
		out		PORTB, mpr	; Send command to port


		; Set initial speed, display on Port B pins 3:0
		ldi cSpeed, 0

		; Enable global interrupts (if any are used)
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		; poll Port D pushbuttons (if needed)
		;rcall	TopSpeed
		;rcall	MinSpeed
								; if pressed, adjust speed
								; also, adjust speed indication

		rjmp	MAIN			; return to top of MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	Template function header
; Desc:	Cut and paste this and fill in the info at the 
;		beginning of your functions
;-----------------------------------------------------------
IncSpeed:

		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi mpr, 0b00000000 ; value of zero is loaded into mpr
		out EIFR, mpr ; filling the flag register with zeroes will clear any requests for interrupts

		ldi		mpr, 15 
		cpse	cSpeed, mpr 
		inc		cSpeed 

		ldi		mpr, 0b11110000
		or		mpr, cSpeed
		out		PORTB, mpr	; Send command to port
		ldi mpr, 17
		mul cSpeed, mpr

		out OCR0, r0
		out OCR2, r0

		ldi mpr, 0b11111111 ; ones are loaded into the mpr
		out EIFR, mpr ; flags are then set to logical high

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		mpr		; Restore mpr
		
		ret				; Return from subroutine

DecSpeed:

		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi mpr, 0b00000000 ; value of zero is loaded into mpr
		out EIFR, mpr ; filling the flag register with zeroes will clear any requests for interrupts

		ldi		mpr, 0 
		cpse	cSpeed, mpr 
		inc		cSpeed 

		ldi		mpr, 0b11110000
		or		mpr, cSpeed
		out		PORTB, mpr	; Send command to port
		ldi mpr, 17
		mul cSpeed, mpr

		out OCR0, r0
		out OCR2, r0

		ldi mpr, 0b11111111 ; ones are loaded into the mpr
		out EIFR, mpr ; flags are then set to logical high

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		mpr		; Restore mpr
		
		ret				; Return from subroutine

TopSpeed:
cli
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi mpr, 0b00000000 ; value of zero is loaded into mpr
		out EIFR, mpr ; filling the flag register with zeroes will clear any requests for interrupts

		ldi cSpeed, 15
		out PORTB, cSpeed

		ldi		mpr, 0b11110000
		or		mpr, cSpeed
		out		PORTB, mpr	; Send command to port
		ldi mpr, 17
		mul cSpeed, mpr

		out OCR0, r0
		out OCR2, r0

		ldi mpr, 0b11111111 ; ones are loaded into the mpr
		out EIFR, mpr ; flags are then set to logical high

		pop		mpr		; Restore program state
		out		SREG, mpr	;
		pop		mpr		; Restore mpr
		ret				; Return from subroutine

MinSpeed:
cli
		push	mpr			; Save mpr register
		in		mpr, SREG	; Save program state
		push	mpr			;

		ldi mpr, 0b00000000 ; value of zero is loaded into mpr
		out EIFR, mpr ; filling the flag register with zeroes will clear any requests for interrupts

		ldi cSpeed, 0
		out PORTB, cSpeed

		ldi mpr, 0b11110000
		or mpr, cSpeed
		out PORTB, mpr

		out OCR0, cSpeed
		out OCR2, cSpeed

		ldi mpr, 0b11111111 ; ones are loaded into the mpr
		out EIFR, mpr ; flags are then set to logical high

		pop		mpr		; Restore program state
		out		SREG, mpr	;
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


;***********************************************************
;*	Stored Program Data
;***********************************************************
		; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
		; There are no additional file includes for this program