; -----------------------------------------------------------------------------
; EMK310
; EUSART RX/TX Code example
; Lecturer: Prof T Hanekom
; Contributors: Dylan Brown, Natalie Hanekom
; Date of last revision: April 2024
;-------------------------------------------------------------------------------
; Example to implement RS232 RX/TX 
;-------------------------------------------------------------------------------
    
;--- Device definition ---
    PROCESSOR   18F45K22
    
;--- Configuration bits ---
    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
    CONFIG  LVP = OFF             ; Single-Supply ICSP Enable bit (Single-Supply ICSP disabled)    
    
;--- Header files ---
    #include    "pic18f45K22.inc"
    #include	<xc.inc>
    
;--- Register definitions ---   
    count	    EQU 0x0
    RCFlag	    EQU	0x1
    ERRORFlag	    EQU 0x2
    DelayCount	    EQU 0x3    
    
;--- Vectors ---
PSECT code,abs
    org	    00h
    goto    Start
    org	    08h
    goto    ISR
 
;---------- Configuration ------------------------------------------------------
Start:	
    ;Initialize variables
    CLRF    count
    CLRF    RCFlag
    CLRF    ERRORFlag
    CLRF    DelayCount
    
    ; Set up oscillator
    BSF	    IRCF0
    BCF	    IRCF1
    BSF	    IRCF2
    
    ; Port D configuration
    MOVLB   0xF
    CLRF    TRISD
    CLRF    LATD
    
       
    ; Baud rate setup (Datasheet RX#1)
    MOVLW   12			; 19200 BAUD @ 4 MHz
				; table 18-5 of datasheet
    ;MOVLW   25			; 9600 BAUD @ 4 MHz
    MOVWF   SPBRG1	  	; load baudrate register
    CLRF    SPBRGH1
    BSF     TXSTA1,2		; Enable high BAUDrate
    BCF	    BAUDCON1,3		; Use 8 bit baud generator
        
    ; Port C RX/TX pin configuration (Datasheet RX#2)
    MOVLW   11000000B		; Setup port C for serial port.
                        	; TRISC<7>=1 and TRISC<6>=1.
    MOVWF   TRISC
    
    ; Enable asynchronous serial port
    BCF     TXSTA1,4		; Enable asynchronous transmission
    BSF	    RCSTA1,7		; Enable Serial Port (Datasheet RX#3)
    
    ; Transmit setup (TX)
    BSF	    BAUDCON1,4		; Inverted polarity
    BSF	    TXSTA1,5		; Enable transmit
    
    ; set up interrupts
    BCF    RCIF			; Clear RCIF Interrupt Flag
    BSF    RCIE			; Set RCIE Interrupt Enable (Datasheet RX#4)
    BSF    PEIE			; Enable peripheral interrupts
    BSF    GIE			; Enable global interrupts
    
    ; Receive setup (RX)
    BSF	    BAUDCON1,5		; Inverted polarity (Datasheet RX#5)
    BSF	    RCSTA1,4		; Enable continuous reception (Datasheet RX#6)
    
    MOVLB   0x0
    
;---------- Main loop sending data to terminal ---------------------------------
Main:

    ; Wait for Port to stabilize
    CALL    DELAY    
    CALL    DELAY  
    CALL    DELAY  
     
TRANSMIT:
    ; Transmit "tesT"
    CALL    TRANSMIT_tesT
    
    ; Receive four characters
    MOVLW   0x04
    MOVWF   count    
RECEIVE:
    BTFSS   RCFlag,0
    GOTO    RECEIVE
    BCF	    RCFlag,0
    DECFSZ  count,f
    GOTO    RECEIVE
    
    movlw   ' '    ;space
    CALL    BYTE_TX
    
    BRA    TRANSMIT
    
;---------- Subroutines --------------------------------------------------------
;--- Transmit Sequence ---
TRANSMIT_tesT:
    movlw   't'
    CALL BYTE_TX
    
    movlw   'e'
    CALL BYTE_TX
    
    movlw   's'
    CALL BYTE_TX
    
    movlw   'T'
    CALL BYTE_TX
     
    movlw   0x0D    ;CR
    CALL BYTE_TX
    
    RETURN
    
;--- OERR overrun error bit is set ---
ErrSerialOverr:	bcf	RCSTA1,4	;reset the receiver logic
		bsf	RCSTA1,4	;enable reception again
		bsf	ERRORFlag,0
		return

;--- FERR framing error bit is set ---
ErrSerialFrame:	movf	RCREG1,W	;discard received data that has error
		bsf	ERRORFlag,0
		return
		
;--- Delay ---		
DELAY:			
    MOVLW   0xFF
    MOVWF   DelayCount		
LOOP:	
    DECFSZ  DelayCount,f	
    BRA	    LOOP		
    RETURN

;--- Tx Byte (Byte must be pre-loaded in WREG) ---
BYTE_TX:
    MOVWF   TXREG1
POLL_TX:
    BTFSS   TXSTA1,1
    GOTO    POLL_TX
    MOVWF   PORTD
    RETURN
    
;---------- RX Interrupt service routine ---------------------------------------
ISR:
    ;BCF    RC1IF	; Cannot clear RC1IF in firmware (Read only bit)
			; Need to read RC1REG to clear RC1IF
    MOVF    RCREG1,0,0	; write received byte to W
			; Note: You have to read RCREG1 in ISR to clear RC1IF
			; RC1IF is read only, i.e. you cannot clear it in firmware
    MOVF    RCSTA1	; Read RCSTA (Datasheet RX#7)
    BSF	    RCFlag,0
    
    ; Error handling : overrun error
    BTFSC   RCSTA1,1		;if overrun error occurred
    BRA	    ErrSerialOverr	;then go handle error
    ; Error handling : framing error
    BTFSC   RCSTA1,2		
    BRA	    ErrSerialFrame	
    ; Test if error occured
    BTFSC   ERRORFlag,0	
    BRA	    EXIT_NO_RC
    
    ; If byte was received, write byte to PORTD and ECHO to terminal
EXIT_RC:    
    MOVF    RCREG1,0		
    MOVWF   PORTD
    CALL    BYTE_TX ;ECHO to terminal
    CLRF    RCREG1       
    RETFIE
        
    ; If byte was not received, i.e. error occured, clear PORTD
EXIT_NO_RC:
    CLRF    PORTD
    CLRF    ERRORFlag
    CLRF    RCREG1
    RETFIE
    
;--- End of code ---
    end