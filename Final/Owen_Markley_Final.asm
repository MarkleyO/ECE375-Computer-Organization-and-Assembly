;***********************************************************
;*	This is the final exam template for ECE375 Winter 2020
;***********************************************************
;*	 Author: Owen Markley
;*   Date: March 16th, 2020
;***********************************************************
.include "m128def.inc"			; Include definition file
;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	rlo = r0				; Low byte of MUL result
.def	rhi = r1				; High byte of MUL result
.def	zero = r2				; Used to help add carry bit to a second register in 16 bit addition
.def	A = r3					; Contains X coordinate of Current Treasure
.def	B = r4					; Contains Y coordinate of Current Treasure
.def	mpr = r16				; Multipurpose register 
.def	loopcnt = r17			; Used to count iterations of loops
.def	sqrtcounter = r18		; Stores calculated distance of Current Treasure
.def	added = r19				; Low bit of the added squared values
.def	added2 = r20			; High bit of the addes squared values
.def	bestPick = r21			; Holds current best choice
.def	bestDist = r22			; Holds distance of current best choice

;***********************************************************
;*	Data segment variables
;***********************************************************
.dseg
.org	$0100						; Data memory allocation for operands
operand1:		.byte 2				; Allocate 2 bytes for a variable named op1

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment
;-----------------------------------------------------------
; Interrupt Vectors
;-----------------------------------------------------------
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt
.org	$0046					; End of Interrupt Vectors
;-----------------------------------------------------------
; Program Initialization
;-----------------------------------------------------------
INIT:	; The initialization routine
		clr		loopcnt				; Set loop count to 0
		CLR		zero				; Ensure that Zero Register is set to 0
		clr		XL					; Set path distance total to 0
		clr		XH
		LDI ZH, high(Treasure1<<1)	; Goes through stored operands, we can index straight through since all inupt data is in sequencial memory
		LDI ZL, low(Treasure1<<1)	; Load low bit of Treasure to memory, There are bit shifts are what move us forwards at the start
		LDI YH, high(Result1)		; Load in the starting address of where we want to store our data
		LDI YL, low(Result1)		; Loading in low bit of results address

;***********************************************************
;*	Procedures and Subroutines
;***********************************************************
Main:

Loop:
			INC loopcnt ; Keeps track of which treasure is being looked at

			
			; LOAD IN OPERANDS (X AND Y COORDS)
			LPM A, Z+ ; Load the first location in program memory this is the first operand, (post increment to move fwd)
			LPM B, Z+ ; Load in second operand 

			; SQUARE BOTH OPERANDS // Squares by using signed multiplication, adds results together as they are computed
			MOV mpr, A			; Copy to mpr, low registers don't like certain functions
			MULS mpr, mpr		; Perform signed multipication on itself
			ST Y+, rlo			; Take low result from its register and output to results space, (increment to move forwards)
			MOV added, rlo		; Store result in added for later
			ST Y+, rhi			; Take high byte from register and output to results space
			MOV added2, rhi		; store result in added2 for later

			MOV mpr, B			; Copy second operand to mpr
			MULS mpr, mpr		; Multiply by self
			ST Y+, rlo			; Store low byte of result to where Y is now pointed
			ADD added, rlo		; Added is combined with rlo, and now added holds the sum of low bytes of the squared coordinates
			ST Y+, rhi			; Store high byte of result to where Y is now pointed
			ADC added2, rhi		; Added2 is combined with rhi, and now added2 holds the sum of high bytes of the squared coordinates

			; STORE THE ADDED NUMBERS
			ST Y+, added		; Low byte of sum of squares is stored 
			ST Y+, added2		; High byte of sum of squares is stored

			; CALCULATE SQUARE ROOT / DISTANCE // Calculates by comparing the square of an increasing counter to the sum
			LDI sqrtcounter, 0				; Set counter to zero
			RJMP SqrtSt						; Skips Incrementing on first iteration to account for taking sqrt(0)
SqrtCnt:	INC sqrtcounter					; Counter is incremented on each iteration of loop
SqrtSt:		MUL sqrtcounter, sqrtcounter	; Square the counter value
			CP added2, rhi					; Compate high bit of the sum to the high bit of the squared value
			BRLO WriteSqrt					; If its the sum is lower, we know we have hit the proper Square Root and write
			BREQ LowCheck					; If the sum is equal, we then examine the lower bit
			RJMP SqrtCnt					; If this line is reached, the sum must be greater, and we need to keep incrementing the counter to get higher squares
LowCheck:	CP rlo, added					; Now, we look at the lower bit
			BRLO SqrtCnt					; Only is the bit is lower, then we repeat
WriteSqrt:	ST Y+, sqrtcounter				; If this point is reached, either both pairs of bits are equal, or the high bit is greater, or the high bits are equal the the square is larger on the lower bit
			ADD XL, sqrtcounter				; The newly calculated square root is then added to a net distance register. This is later used for average
			ADC XH, zero					; Adding the Carry Bit from previous addition to upper 8 bits 

			; DETERMINE SHORTEST DISTANCE // Records current shortest distance through comparisons, as new Treasures are computed
			CPI loopcnt, 1				; Compare the Treasure we're on to 1
			BRNE NotFirst				; If it is not the first treasure, continue to other comparisons
			MOV bestPick, loopcnt		; If it is the first treasure, store its index as bestPick
			MOV bestDist, sqrtcounter	; And its distance as bestDist
			RJMP LoopCheck				; After storing these jump to repeat the Main Loop
NotFirst:	CP bestDist, sqrtcounter	; If it is not the first Treasure, compare it's distance to the recorded best
			BRLO LoopCheck				; If the recorded is lower, skip onwards and loop again
			BREQ Tie					; If they are equal, there are more comparisons to be made
			MOV bestPick, loopcnt		; Should the recorded distance be greater than our current, the index of Treasure is recorded
			MOV bestDist, sqrtcounter	; The distance of the current treasure is recorded as well
			RJMP LoopCheck				; After recording, a jump is made to the end of the loop
Tie:		LDI mpr, -2					; In the situation of a (distance) tie, we see if there has been a previous tie (indicated by a -2)
			CP mpr, bestPick			; A comparison is made in two lines, since the reversing the order of the previously used CPI statement made for more efficient code
			BRGE Prev					; If -2 is either equal to or greater than our previous choice, this means we can simply decrement -2 to a -3, indicating our 3-way tie
			LDI bestPick, -2			; Otherwise, we know this is a two way tie, and we need to set the bestPick value to -2
			RJMP LoopCheck				; Should the value have just been set to 2, the decrement statement is skipped
Prev:		DEC bestPick				; Decrementing if the value is already -2 in bestPick

			; LOOP UNTIL ALL TREASURES ANALYZED
LoopCheck:	CPI loopcnt, 3	; Compare loopcnt/treasure index to 3
			BRLT LOOP		; If three treasures have not been calculated continue looping

			; STORE THE SHORTEST PATH
			ST Y+, bestPick	; The Treasure with shortest path length has it's index stored after the Results 1-3

			; CALCULATE AVERAGE PATH LENGTH // Calculated by counting how many times 3 can be subtracted from total distance
			CLC				; Carry bit is cleared since it is used to check when to break loop
			CLR loopcnt		; Loopcnt is reset, it will represent the quotient
Divide3:	BRCS Round		; If the carry bit is cleared the solution will be rounded (subtracting past 0 will set this bit)
			SBIW X, 3		; Three is subtracted from the word X which hold the total distance
			INC loopcnt		; Every subtraction from total distance will increment the loop count (represents one more time that 3 fits into the dividend
			RJMP Divide3	; Loop back around and continue subtracting
Round:		CPI XL, $FF		; Remainders are subtracted past, possible remainders are [0, 1, 2] only 2 requires rounding up, subtracting 3 from 2 evaluates to $FF
			BREQ StoreAvg	; Check to see if is the contents of X after dividing
			DEC loopcnt		; Since we count going past the remainder, we must return (quotient - 1) if we have a remainder of 0 or 1

			; STORE AVERAGE PATH LENGTH
StoreAvg:	ST Y+, loopcnt	; After completion of Divide3, loopcnt will hold a rounded upwards Average length, and this is stored along after BestChoice

			; PROGRAM IS COMPLETE
			RJMP Grading	; End of my program	

;***end of your code***end of your code***end of your code***end of your code***end of your code***
;******************************* Do not change below this point************************************
;******************************* Do not change below this point************************************
;******************************* Do not change below this point************************************

Grading:
		nop					; Check the results and number of cycles (The TA will set a breakpoint here)
rjmp Grading


;***********************************************************
;*	Stored Program Data
;***********************************************************

; Contents of program memory will be changed during testing
; The label names (Treasure1, Treasure2, etc) are not changed
Treasure1:	.DB	0xF9, 0xFD				; X, Y coordinate of treasure 1 (-7 in decimal), (-3 in decimal)
Treasure2:	.DB	0x03, 0x04				; X, Y coordinate of treasure 2 (+3 in decimal), (+4 in decimal)
Treasure3:	.DB	0x81, 0x76				; X, Y coordinate of treasure 3 (-127 in decimal), (+118 in decimal)

;***********************************************************
;*	Data Memory Allocation for Results
;***********************************************************
.dseg
.org	$0E00						; data memory allocation for results - Your grader only checks $0E00 - $0E16
Result1:		.byte 7				; x_squared, y_squared, x2_plus_y2, square_root (for treasure 1)
Result2:		.byte 7				; x_squared, y_squared, x2_plus_y2, square_root (for treasure 2)
Result3:		.byte 7				; x_squared, y_squared, x2_plus_y2, square_root (for treasure 3)
BestChoice:		.byte 1				; which treasure is closest? (indicate this with a value of 1, 2, or 3)
									; see the PDF for an explanation of the special case when 2 or more treasures
									; have an equal (rounded) distance
AvgDistance:	.byte 1				; the average distance to a treasure chest (rounded to the nearest integer)

;***********************************************************
;*	Additional Program Includes
;***********************************************************
; There are no additional file includes for this program
