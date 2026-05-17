; -----------------------------------------------------------------------------
; uart_echo_test.s -- UART byte echo via EEPROM
;   Boot: reads last stored byte from EEPROM[0], sends it
;   Loop: receive byte -> write to EEPROM[0] -> read back -> echo
; Wiring: RC3=SCL, RC4=SDA (24LC16B), RC6=TX, RC7=RX
; -----------------------------------------------------------------------------

    PROCESSOR 18F45K22

    CONFIG FOSC  = INTIO67
    CONFIG WDTEN = OFF
    CONFIG LVP   = ON

    #include "pic18f45k22.inc"
    #include <xc.inc>

DATA_BYTE   EQU 0x00
Delay1      EQU 0x01
Delay2      EQU 0x02

WRITE_ADDR  EQU 0xA0    ; 24LC16B control byte, write (A2=A1=A0=0)
READ_ADDR   EQU 0xA1    ; 24LC16B control byte, read

PSECT code,abs
    org 00h
    goto Start

Start:
    ; --- 4 MHz internal ---
    BSF     OSCCON, 6, a
    BCF     OSCCON, 5, a
    BSF     OSCCON, 4, a

    MOVLB   0xF

    ; RC3=SCL, RC4=SDA inputs (SSP drives open-drain)
    BSF     TRISC, 3
    BSF     TRISC, 4
    ; RC6=TX output, RC7=RX input
    BCF     TRISC, 6
    BSF     TRISC, 7
    CLRF    ANSELC, b

    ; --- I2C Master @ 100 kHz (Fosc=4MHz: SSP1ADD = 4M/(4*100k)-1 = 9) ---
    MOVLW   0x09
    MOVWF   SSP1ADD
    CLRF    SSP1STAT
    BSF     SSP1STAT, 7         ; SMP=1: slew rate disabled
    MOVLW   0x28                ; SSPEN=1, SSPM=1000 (I2C Master)
    MOVWF   SSP1CON1
    CLRF    SSP1CON2

    ; --- UART @ 9600 baud ---
    MOVLW   0x19
    MOVWF   SPBRG1
    CLRF    SPBRGH1
    MOVLW   00100100B           ; TXEN=1, BRGH=1, SYNC=0
    MOVWF   TXSTA1
    BCF     BAUDCON1, 4         ; TXCKP=0
    BCF     BAUDCON1, 5         ; RXDTP=0
    BCF     BAUDCON1, 3         ; BRG16=0
    MOVLW   10010000B           ; SPEN=1, CREN=1
    MOVWF   RCSTA1

    MOVLB   0x00

    ; Diagnostic: 'A' = reached boot, 'B' = EE_READ_BYTE returned.
    ; 'A' only on power-up means I2C hangs (or recovers) before the read returns.
    MOVLW   'A'
    CALL    UART_TX

    ; Boot: read EEPROM[0], echo if not 0xFF (virgin)
    CALL    EE_READ_BYTE        ; returns byte in W
    MOVWF   DATA_BYTE, a
    MOVLW   'B'
    CALL    UART_TX
    MOVF    DATA_BYTE, W, a
    XORLW   0xFF
    BZ      Boot_Skip
    MOVF    DATA_BYTE, W, a
    CALL    UART_TX
Boot_Skip:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX

MainLoop:
    ; Clear OERR if set
    BTFSS   RCSTA1, 1, a
    BRA     ML_NoOerr
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
ML_NoOerr:
    ; Wait for RX byte
    BTFSS   PIR1, 5, a
    BRA     MainLoop
    MOVF    RCREG1, W, a
    MOVWF   DATA_BYTE, a
    ; Diagnostic: 'C' before write, 'D' after read-back, then echo the byte.
    MOVLW   'C'
    CALL    UART_TX
    CALL    EE_WRITE_BYTE
    CALL    EE_READ_BYTE
    MOVWF   DATA_BYTE, a
    MOVLW   'D'
    CALL    UART_TX
    MOVF    DATA_BYTE, W, a
    CALL    UART_TX
    BRA     MainLoop

; ---- UART TX (byte in W) ----
UART_TX:
    BTFSS   TXSTA1, 1, a        ; TRMT: shift register empty?
    BRA     UART_TX
    MOVWF   TXREG1, a
    RETURN

; ---- EEPROM write: DATA_BYTE -> EEPROM[0] ----
EE_WRITE_BYTE:
    CALL    EE_BUS_START
    MOVLW   WRITE_ADDR
    CALL    EE_BUS_SEND
    MOVLW   0x00                ; EEPROM word address = 0
    CALL    EE_BUS_SEND
    MOVF    DATA_BYTE, W, a
    CALL    EE_BUS_SEND
    CALL    EE_BUS_STOP
    CALL    DELAY_10MS          ; 24LC16B write cycle max 5 ms
    RETURN

; ---- EEPROM read: EEPROM[0] -> W ----
; On any I2C timeout, returns 0xFF (looks like virgin EEPROM).
EE_READ_BYTE:
    ; Dummy write to set internal address pointer to 0
    CALL    EE_BUS_START
    MOVLW   WRITE_ADDR
    CALL    EE_BUS_SEND
    MOVLW   0x00
    CALL    EE_BUS_SEND
    ; Repeated START, switch to read
    BSF     SSP1CON2, 1         ; RSEN
    SETF    Delay1, a
    MOVLW   0x0A
    MOVWF   Delay2, a
ERB_WaitRS:
    BTFSS   SSP1CON2, 1
    BRA     ERB_RSDone
    DECFSZ  Delay1, F, a
    BRA     ERB_WaitRS
    DECFSZ  Delay2, F, a
    BRA     ERB_WaitRS
    BRA     ERB_Fail
ERB_RSDone:
    MOVLW   READ_ADDR
    CALL    EE_BUS_SEND
    ; Receive one byte with NACK (only byte, so no ACK)
    BCF     PIR1, 3, a          ; clear SSP1IF
    BSF     SSP1CON2, 3         ; RCEN=1
    SETF    Delay1, a
    MOVLW   0x0A
    MOVWF   Delay2, a
ERB_WaitRX:
    BTFSC   PIR1, 3, a
    BRA     ERB_RXDone
    DECFSZ  Delay1, F, a
    BRA     ERB_WaitRX
    DECFSZ  Delay2, F, a
    BRA     ERB_WaitRX
    BRA     ERB_Fail
ERB_RXDone:
    BTFSS   SSP1STAT, 0, a      ; wait for BF=1 (buffer full)
    BRA     ERB_RXDone
    BCF     PIR1, 3, a
    MOVF    SSP1BUF, W, a
    MOVWF   DATA_BYTE, a
    BSF     SSP1CON2, 5         ; ACKDT=1 (NACK)
    BSF     SSP1CON2, 4         ; ACKEN=1
    SETF    Delay1, a
    MOVLW   0x0A
    MOVWF   Delay2, a
ERB_WaitAck:
    BTFSS   SSP1CON2, 4
    BRA     ERB_AckDone
    DECFSZ  Delay1, F, a
    BRA     ERB_WaitAck
    DECFSZ  Delay2, F, a
    BRA     ERB_WaitAck
    BRA     ERB_Fail
ERB_AckDone:
    CALL    EE_BUS_STOP
    MOVF    DATA_BYTE, W, a
    RETURN
ERB_Fail:
    CALL    I2C_RECOVER
    MOVLW   0xFF
    MOVWF   DATA_BYTE, a
    MOVF    DATA_BYTE, W, a
    RETURN

; ---- I2C primitives (bounded — won't hang if bus is dead) ----
; ~10 ms worst-case wait per primitive at 4 MHz; on timeout, reset MSSP and return.

EE_BUS_START:
    BSF     SSP1CON2, 0         ; SEN
    SETF    Delay1, a
    MOVLW   0x0A
    MOVWF   Delay2, a
EE_BUS_START_Wait:
    BTFSS   SSP1CON2, 0
    RETURN                       ; SEN cleared → START done
    DECFSZ  Delay1, F, a
    BRA     EE_BUS_START_Wait
    DECFSZ  Delay2, F, a
    BRA     EE_BUS_START_Wait
    BRA     I2C_RECOVER          ; tail call — recovers MSSP and returns

EE_BUS_STOP:
    BSF     SSP1CON2, 2         ; PEN
    SETF    Delay1, a
    MOVLW   0x0A
    MOVWF   Delay2, a
EE_BUS_STOP_Wait:
    BTFSS   SSP1CON2, 2
    RETURN
    DECFSZ  Delay1, F, a
    BRA     EE_BUS_STOP_Wait
    DECFSZ  Delay2, F, a
    BRA     EE_BUS_STOP_Wait
    BRA     I2C_RECOVER

EE_BUS_SEND:                       ; byte in W -> SSP1BUF, wait for SSP1IF
    BTFSC   SSP1STAT, 0, a      ; wait for BF=0 (buffer empty)
    BRA     EE_BUS_SEND
    BCF     PIR1, 3, a          ; clear SSP1IF
    MOVWF   SSP1BUF
    SETF    Delay1, a
    MOVLW   0x0A
    MOVWF   Delay2, a
EE_BUS_SEND_Wait:
    BTFSC   PIR1, 3, a
    BRA     EE_BUS_SEND_Done
    DECFSZ  Delay1, F, a
    BRA     EE_BUS_SEND_Wait
    DECFSZ  Delay2, F, a
    BRA     EE_BUS_SEND_Wait
    BRA     I2C_RECOVER
EE_BUS_SEND_Done:
    BCF     PIR1, 3, a
    RETURN

; Reset MSSP module — recovers from a stuck I2C transaction.
I2C_RECOVER:
    BCF     SSP1CON1, 5         ; SSPEN = 0
    CLRF    SSP1CON2
    MOVLW   0x28                ; SSPEN=1, SSPM=1000 (I2C Master)
    MOVWF   SSP1CON1
    RETURN

; ---- Delay ~10 ms at 4 MHz ----
DELAY_10MS:
    MOVLW   0x0D
    MOVWF   Delay2, a
D10_L1:
    MOVLW   0xFF
    MOVWF   Delay1, a
D10_L2:
    DECFSZ  Delay1, F, a
    GOTO    D10_L2
    DECFSZ  Delay2, F, a
    GOTO    D10_L1
    RETURN

    end
