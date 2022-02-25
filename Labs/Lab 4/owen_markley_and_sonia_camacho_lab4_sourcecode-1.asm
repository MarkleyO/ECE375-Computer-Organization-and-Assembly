;***********************************************************
;*
;* sonia_camacho_owen_markley_lab4_sourcecode
;*
;*	Enter the description of the program here
;*
;*	This is the skeleton file for Lab 4 of ECE 375
;*
;***********************************************************
;*
;*	 Author: SONIA CAMACHO OWEN MARKLEY
;*	   Date: 01/28/2020
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is
.def	i = r23					; required for LCD Driver
.DEF	J =R25
.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp INIT				; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; Initialize Stack Pointer
		ldi		mpr, low(RAMEND)	; initialize Stack Pointer
		out		SPL, mpr			
		ldi		mpr, high(RAMEND)
		out		SPH, mpr

		rcall LCDInit ; Initialize LCD Display
		
		; NOTE that there is no RET or RJMP from INIT, this
		; is because the next instruction executed is the
		; first instruction of the main program

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:	

	
		in		mpr, PIND		; Get whisker input from Port D
;**************************************************************************************************
;checking for the far right button
		cpi		mpr, (0b11111110)	; Check for Right Whisker input (Recall Active Low)
		brne	NEXT			; Continue with next check

		ldi i , $20
			ldi YL, low(LCDLn1Addr)
			ldi YH, high(LCDLn1Addr)
			ldi ZL ,low( STRING1_BEG << 1)
			ldi ZH ,high( STRING1_BEG << 1)
			;do the loop from the lab slides
		loop: 	
			lpm r16,Z+
			ST Y+, r16
			dec i
			brne loop		
		rcall	LCDWrite			; Call subroutine HitLeft

;**************************************************************************************************
;checking for the left button
NEXT:	cpi		mpr, (0b11111101)
		brne	NEXT1			; No Whisker input, continue program
		ldi J , $10
		;load the string 2 to the first line
			ldi YL, low(LCDLn1Addr)
			ldi YH, high(LCDLn1Addr)
			ldi ZL ,low( STRING2_BEG<< 1)
			ldi ZH ,high( STRING2_BEG << 1)
			; do the loop from the lab slides
		loop2: 	
			lpm r16,Z+
			ST Y+, r16
			DEC J
			brne loop2	
			;load the frist string but notice we are not reseting the pointer because the pointer will now be on the second line
			ldi J, $10
			ldi ZL ,low( STRING1_BEG<< 1)
			ldi ZH ,high( STRING1_BEG << 1)
			;loop again 
		loop2pointo: 	
			lpm r16,Z+
			ST Y+, r16
			DEC J
			brne loop2pointo	
			;now we can write it 
		rcall	LCDWrite			; Call subroutine HitLeft
		rjmp	MAIN					; jump back to main and create an infinite
								; while loop.  Generally, every main program is an
								; infinite while loop, never let the main program
								; just run off
;**************************************************************************************************
;checking to see if we are clearing it
NEXT1:

		cpi mpr, (0b01111111)
		brne	MAIN			; No Whisker input, continue program
		rcall	LCDClr			; Call subroutine HitLeft
		rjmp	MAIN	


;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the 
;		beginning of your functions
;-----------------------------------------------------------
FUNC:							; Begin a function with a label
		; Save variables by pushing them to the stack

		; Execute the function here
		
		; Restore variables by popping them from the stack,
		; in reverse order

		ret						; End a function with RET

;***********************************************************
;*	Stored Program Data
;***********************************************************

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING1_BEG:
.DB		"(: sonia camacho"		; Declaring data in ProgMemSTRING2_BEG:
STRING1_END:

STRING2_BEG:
.DB		"sonia camacho :0"
STRING2_END:



;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver
