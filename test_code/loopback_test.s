; =============================================================================
; loopback_test.s  --  PIC18F45K22 bare-minimum UART echo
;
; Receives any byte and immediately sends it back. No ISR, no state.
; Edit the CONFIG OPTIONS blocks below and reflash to test each combination.
;
; Wiring: RC6 = TX  (to dongle RX)
;         RC7 = RX  (from dongle TX)
; =============================================================================

    PROCESSOR 18F45K22

    CONFIG FOSC  = INTIO67
    CONFIG WDTEN = OFF
    CONFIG LVP   = ON

    #include "pic18f45k22.inc"
    #include <xc.inc>

PSECT code,abs
    org 00h
    goto Start

Start:
    ; --- 4 MHz internal oscillator ---
    BSF     OSCCON, 6, a        ; IRCF2 = 1
    BCF     OSCCON, 5, a        ; IRCF1 = 0  -->  IRCF = 101 = 4 MHz
    BSF     OSCCON, 4, a        ; IRCF0 = 1

    ; --- PORTC digital ---
    MOVLB   0xF
    CLRF    ANSELC, b

    ; --- RC6 TX output, RC7 RX input ---
    BCF     TRISC, 6, a
    BSF     TRISC, 7, a

    ; =========================================================================
    ; CONFIG OPTION 1: Baud rate
    ;   Fosc=4MHz, BRGH=1, BRG16=0  ->  baud = 4000000 / (16*(SPBRG+1))
    ;
    ;   [A] 9600 baud  (SPBRG=25, actual 9615, 0.16% err)  <-- DEFAULT
    MOVLW   25
    MOVWF   SPBRG1, a
    ;
    ;   [B] 19200 baud (SPBRG=12, actual 19231, 0.16% err)
;   MOVLW   12
;   MOVWF   SPBRG1, a
    ;
    ;   [C] 4800 baud  (SPBRG=51, actual 4808, 0.16% err)
;   MOVLW   51
;   MOVWF   SPBRG1, a
    ; =========================================================================

    CLRF    SPBRGH1, a
    MOVLW   00100100B           ; TXEN=1, BRGH=1, SYNC=0
    MOVWF   TXSTA1, a
    BCF     BAUDCON1, 3, a      ; BRG16=0

    ; =========================================================================
    ; CONFIG OPTION 2: TX polarity  (BAUDCON1<4> = TXCKP)
    ;
    ;   [A] Non-inverted TX -- idle HIGH, start LOW  (standard TTL dongle)  <-- DEFAULT
    BCF     BAUDCON1, 4, a      ; TXCKP=0
    ;
    ;   [B] Inverted TX -- idle LOW, start HIGH  (RS-232 / hardware inverter)
;   BSF     BAUDCON1, 4, a      ; TXCKP=1
    ; =========================================================================

    ; =========================================================================
    ; CONFIG OPTION 3: RX polarity  (BAUDCON1<5> = RXDTP)
    ;
    ;   [A] Non-inverted RX -- pin idle HIGH expected  (standard TTL dongle)  <-- DEFAULT
    BCF     BAUDCON1, 5, a      ; RXDTP=0
    ;
    ;   [B] Inverted RX -- pin idle LOW expected  (RS-232 / hardware inverter)
;   BSF     BAUDCON1, 5, a      ; RXDTP=1
    ; =========================================================================

    ; --- Enable serial port + receiver ---
    MOVLW   10010000B           ; SPEN=1, CREN=1
    MOVWF   RCSTA1, a

    MOVLB   0

; -----------------------------------------------------------------------------
; Announce: broadcast '!' every ~0.8 s until Python sends any byte back.
; Python replies with a sync byte; PIC confirms with 'Y' and enters echo loop.
; Timing-independent: Python can connect before or after boot.
; -----------------------------------------------------------------------------
Announce:
    MOVLW   '!'
    CALL    UART_TX
    MOVLW   0x08
    MOVWF   0x10, a
Ann_Outer:
    MOVLW   0xFF
    MOVWF   0x11, a
Ann_Mid:
    MOVLW   0xFF
    MOVWF   0x12, a
Ann_Inner:
    BTFSC   PIR1, 5, a          ; RC1IF: Python sent something?
    BRA     Ann_Got
    DECFSZ  0x12, F, a
    BRA     Ann_Inner
    DECFSZ  0x11, F, a
    BRA     Ann_Mid
    DECFSZ  0x10, F, a
    BRA     Ann_Outer
    BRA     Announce            ; no response -- send '!' again

Ann_Got:
    MOVF    RCREG1, W, a        ; consume Python's sync byte (clears RC1IF)
    MOVLW   'Y'
    CALL    UART_TX             ; confirm: PIC RX is working

; -----------------------------------------------------------------------------
; Main: poll for a byte, echo it, repeat
; -----------------------------------------------------------------------------
Main:
    ; Clear overrun error if it has set (overrun freezes RX)
    BTFSS   RCSTA1, 1, a        ; OERR set?
    BRA     Main_NoOerr
    BCF     RCSTA1, 4, a        ; clear CREN -> clears OERR
    BSF     RCSTA1, 4, a        ; re-enable receiver
Main_NoOerr:

    BTFSS   PIR1, 5, a          ; RC1IF: byte in FIFO?
    BRA     Main                ; no -> keep polling
    MOVF    RCREG1, W, a        ; yes -> read it (clears RC1IF)
    CALL    UART_TX             ; echo back
    BRA     Main

; -----------------------------------------------------------------------------
; UART_TX: transmit byte in W
; -----------------------------------------------------------------------------
UART_TX:
    BTFSS   TXSTA1, 1, a        ; TRMT: shift register empty?
    BRA     UART_TX
    MOVWF   TXREG1, a
    RETURN

    end
