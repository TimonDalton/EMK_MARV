; -----------------------------------------------------------------------------
; EMK310 
; MARVelous Micros Code Example 22
; Lecturer: Prof T Hanekom
; Date of last revision: May 2022
;-------------------------------------------------------------------------------
; Description:
; Example to use CCP module as PWM 
; -----------------------------------------------------------------------------
; Notes:
; Add break inside Main loop, step and observe CCP1 in logic analyser 
; -----------------------------------------------------------------------------

    PROCESSOR	18F45K22

;========== Configuration bits ==========
;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
    CONFIG  CCP2MX = PORTC1 ;this is what makes CCP2 on RC1 if want to change replace with PORTB3
    #include	<xc.inc>
    #include	"pic18f45k22.inc"
  
;========== Reset vector ==========
PSECT code, abs
    org 	00h
    goto 	Setup

;========== Setup ==========
Setup:       
    ; Set oscillator speed at 4 MHz
    bsf 	OSCCON,6,a
    bcf		OSCCON,5,a
    bsf		OSCCON,4,a 
    
    ; Set up period of PWM: 20  us = 50 kHz, this is fine
    ; See HoPE p. 564 
    movlw	19
    movwf	PR2,a   
       
    ; Set the CCP1 pin as an output (Initialize Port C) CCPR1L
    clrf	PORTC,a
    clrf	LATC,a
    bcf		TRISC,2,a		; RC2/CCP1 an output
    bcf		TRISC,1,a		; RC1/CCP1 an output, an alternative for this would be RB3
    ;initialize PORTB and RB3 for CCP2 out for PWM motor.
    
    ; Set up Timer 2: no pre-or post scalers for this example
    clrf	T2CON,a
    clrf	TMR2,a
    
    ; Configure CCP1CON for PWM Motor 1    
    ; CCP1M<3:0> = 11XX for PWM
    BSF		CCP1CON,3,a
    BSF		CCP1CON,2,a
    BCF		CCP1CON,1,a
    BCF		CCP1CON,0,a
    
    ; Example 1: Set duty cycle at 25%
    ; See HoPE p. 566
    ; CCPRL1 = 0.25 x (PR2+1) = 0.25 x 20 = 5
    movlw	16
    
    movwf	CCPR1L,a ;for motor 1(left)
   
    
    ; Configure CCP2CON for PWM Motor 2    
    ; CCP1M<3:0> = 11XX for PWM
    BSF		CCP2CON,3,a
    BSF		CCP2CON,2,a
    BCF		CCP2CON,1,a
    BCF		CCP2CON,0,a
    
    ; Example 1: Set duty cycle at 25%
    ; See HoPE p. 566
    ; CCPRL1 = 0.25 x (PR2+1) = 0.25 x 20 = 5
    movlw	15
    movwf	CCPR2L,a	; for motor 2(right)
    ;movwf	CCPR1L,a ;for motor 1(left)
    
    ; Start timer 2
    bsf		T2CON,2,a
    
	
;========== Main program ==========
Main:
    ; Check PWM output in logic analyser
    nop
    nop
    nop
    nop
    goto 	Main


    
    end