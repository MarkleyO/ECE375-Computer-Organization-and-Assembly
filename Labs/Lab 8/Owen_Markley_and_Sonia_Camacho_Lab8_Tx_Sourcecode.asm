;***********************************************************
;*
;* 
;*title
;*
;*description
;*
;***********************************************************
;*
;*  Author: SONIA CAMACHO AND OWEN MARKLEY
;*    Date: 3/6/2020
;*
;***********************************************************
.include "m128def.inc"    ; Include definition file
;***********************************************************
;* Internal Register Definitions and Constants
;***********************************************************
.def mpr = r16    ; Multi-Purpose Register
.def data = r17    ; USART data
.def waitcnt = r23    ; Wait Loop Counter
.def ilcnt = r24    ; Inner Loop Counter
.def olcnt = r25    ; Outer Loop Counter
.equ EngEnR = 4    ; Right Engine Enable Bit
.equ EngEnL = 7    ; Left Engine Enable Bit
.equ EngDirR = 5    ; Right Engine Direction Bit
.equ EngDirL = 6    ; Left Engine Direction Bit
.equ Button0 = 1 ;setting up the buttons that we will use
.equ Button1 = 2
.equ Button3 = 4    
.equ Button4 = 5    
.equ Button5 = 6    
.equ Button6 = 7
.equ WTime = 100    ; Time to wait in wait loop
.equ robotID = $1A   ; Robot ID for this robot
; Use these action codes between the remote and robot
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1)) ;0b10110000 Move Forward Action Code
.equ MovBck =  ($80|$00)         ;0b10000000 Move Backward Action Code
.equ TurnR =   ($80|1<<(EngDirL-1))       ;0b10100000 Turn Right Action Code
.equ TurnL =   ($80|1<<(EngDirR-1))                ;0b10010000 Turn Left Action Code
.equ Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))   ;0b11001000 Halt Action Code
.equ Freeze =  0b11111000
;***********************************************************
;* Start of Code Segment
;***********************************************************
.cseg       ; Beginning of code segment
;**************************************
;* Interrupt Vectors
;**************************************
.org $0000  
  rjmp INIT
  ;this is the interrupt that will trigger the freeze signal 
.org $0002  
  rcall FreezeSignal
  reti
  ;this is the interrupt that will trigger the stop signal
.org $0004 
  rcall Stop
  reti 
  ;the usually included 
.org $0046    
;***********************************************************
;* Program Initialization
;***********************************************************
INIT:
 ;Stack Pointer (VERY IMPORTANT!!!!)
  ldi  mpr, low(RAMEND)
  out  SPL, mpr  ; Load SPL with low byte of RAMEND
  ldi  mpr, high(RAMEND)
  out  SPH, mpr  ; Load SPH with high byte of RAMEND
 ;I/O Ports
  ;Initialize Port B for output
  ldi mpr, 0b11111111
  out DDRB, mpr ; Set the DDR register for Port B
  ldi mpr, $00
  out PORTB, mpr
  ; Initialize Port D for input
  ldi mpr, (1<<PD3)|(0<<Button0)|(0<<Button1)|(0<<Button3)|(0<<Button4)|(0<<Button5)|(0<<Button6)
  out DDRD, mpr ; Set the DDR register for Port D
  ldi mpr, (1<<Button0)|(1<<Button1)|(1<<Button3)|(1<<Button4)|(1<<Button5)|(1<<Button6)
  out PORTD, mpr
  ; Initialize external interrupts
  ; Set the Interrupt Sense Control to falling edge
  ldi mpr, (1<<ISC01)|(0<<ISC00)|(1<<ISC11)|(0<<ISC10)
  ;EIMSK = 00001010
  sts EICRA, mpr ; Use sts, EICRA in extended I/O space
  ; Set the External Interrupt Mask
  ldi mpr, (1<<INT0)|(1<<INT1)
  out EIMSK, mpr ; Turn on interrupts 
 ;USART1
  ;Initalize USART1
  ldi mpr, (1<<U2X1) ; Set double data rate
  sts UCSR1A, mpr
  ;Set baudrate at 2400bps
  ldi mpr, high(832) ; Load high byte of baudrate
  sts UBRR1H, mpr ; UBRR01 in extended I/O space
  ldi mpr, low(832) ; Load low byte of baudrate
  sts UBRR1L, mpr
  
  ; Set frame format: 8 data, 2 stop bits, asynchronous
  ldi mpr, (0<<UMSEL1 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10)
  sts UCSR1C, mpr ; UCSR0C in extended I/O space
  
  ; Enable transmitter
  ldi mpr, (1<<TXEN1)
  sts UCSR1B, mpr
  sei ; Enable global interrupt
;***********************************************************
;* Main Program
;***********************************************************
MAIN:
 ;checking to see if our forward button has been hit and if so call the function 
 sbis PIND, 7
 rjmp Forward ;calling the forward function
 ;checking to see if the backwards button has been hit and if so call the function
 sbis PIND, 6
 rjmp Back ;calling the back function
 ;checking to see if the left button has been hit and if so call the function
 sbis PIND, 5
 rjmp Left ;calling the left function
 ;checking to see if the right button has been hit and if so call the function
 sbis PIND, 4 
 rjmp Right ;calling the function
  rjmp MAIN ;loop back into main
;***********************************************************
;
;* Functions and Subroutines
;
;***********************************************************
;***********************************************************
;* FORWARD
;* Forward will transmit the forward command
;***********************************************************
Forward:
  ldi mpr, 0b10011001 ;display this pattern onto the LED of the transmitter
  out PORTB, mpr
;Transmit robotid
fwd1:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp fwd1 ;send back into the loop
  ldi  data, robotID ;load the robot ID
  sts UDR1, data ; Move data to transmit data buffer
;Transmit move code
fwd2:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp fwd2  ;send back into the loop
  ldi  data, MovFwd ;load in the actual move forward action code to be transmitted which is 0b10110000
  sts UDR1, data ; Move data to transmit data buffer
rjmp MAIN ;big loop into main

;***********************************************************
;* BACK
;* Back will transmit the backwards command
;***********************************************************
Back:
  ldi mpr, 0b01100110 ;display this pattern to the LEDs on the transmitter board
  out PORTB, mpr
;Transmit robotid
bwd1:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp bwd1 ;send back into the loop
  ldi  data, robotID ;load the robot ID
  sts UDR1, data ; Move data to transmit data buffer
;Transmit move code
bwd2:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1;skip if bit in register set
  rjmp bwd2 ;jump back into the loop
  ldi  data, MovBck ;here we are sending the different action code which will be for moving backwards
  sts UDR1, data ; Move data to transmit data buffer
rjmp MAIN ;go back to main
;***********************************************************
;* LEFT
;* LEFT will transmit the left moving command
;***********************************************************
Left:
  ldi mpr, 0b11000000 ;display this onto the LED
  out PORTB, mpr
;Transmit robotid
lft1:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp lft1 ;send back into the loop
  ldi  data, robotID ;load the robot ID
  sts UDR1, data ; Move data to transmit data buffer

;Transmit move code
lft2:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp lft2  ;send back into the loop
  ldi  data, TurnL ;sending in the left turning action code to the robot
  sts UDR1, data ; Move data to transmit data buffer
rjmp MAIN ;go back into main

;***********************************************************
;* RIGHT
;* RIGHT will transmit the right moving command
;***********************************************************
Right:
  ldi mpr, 0b00000011 ;opposite of the left turn we will display this on the LED's
  out PORTB, mpr
;Transmit robotid
rht1:
 lds mpr, UCSR1A ; Loop until UDR1 is empty
 sbrs mpr, UDRE1 ; skip if bit in register set 
 rjmp rht1 ;send back into the loop
 ldi  data, robotID ;load the robot ID
 sts UDR1, data ; Move data to transmit data buffer
;Transmit move code
rht2:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set
  rjmp rht2 ;send back into the loop
  ldi  data, TurnR ;load the right turning action code so that the robot will recieve the same thing
  sts UDR1, data ; Move data to transmit data buffer
rjmp MAIN ;go into main
 

;***********************************************************
;* STOP
;* STOP will transmit the halt non moving command
;***********************************************************
Stop:
  ldi mpr, 0b00000000 ;display this onto the LED of transmitter board
  out PORTB, mpr
;Transmit robotid
hlt:
 lds mpr, UCSR1A ; Loop until UDR1 is empty
 sbrs mpr, UDRE1 ; skip if bit in register set 
 rjmp hlt ;send back into the loop
 ldi  data, 0b01010101 ;load the freeze commanbd 
 sts UDR1, data ; Move data to transmit data buffer
;Transmit move code
hlt2:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp hlt2 ;send back into the loop
  ldi  data, Halt ;load up the halt to be sent over to the robot 
  sts UDR1, data ; Move data to transmit data buffer
ret

;***********************************************************
;* FreezeSignal
;* this will transmit the freeze signal 
;***********************************************************
FreezeSignal:
  ldi mpr, 0b01010101 ;display on LED
  out PORTB, mpr
;Transmit robotid
frze:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
 sbrs mpr, UDRE1 ; skip if bit in register set 
 rjmp frze ;send back into the loop
 ldi  data, robotID ;load the robot ID
 sts UDR1, data ; Move data to transmit data buffer
;Transmit move code
frze2:
  lds mpr, UCSR1A ; Loop until UDR1 is empty
  sbrs mpr, UDRE1 ; skip if bit in register set 
  rjmp frze2 ;send back into the loop
  ldi  data, Freeze ;load in the actual command to freezeeeee
  sts UDR1, data ; Move data to transmit data buffer
ret
;tis the end
