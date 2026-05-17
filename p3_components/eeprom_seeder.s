; eeprom_seeder.s — multi-line EEPROM seeder for the 24LC16B.
;
; Loop:
;   1. Read EEPROM[0..] sequentially until backtick (0x60) or 0xFF, echo to UART
;   2. Print "Enter String (end with `):\r\n"
;   3. Read UART input until backtick:
;        - each typed CR (0x0D) is stored as CRLF (0x0D 0x0A) in the buffer
;        - backtick is stored as the terminator and ends input
;   4. Byte-by-byte write of the buffered content to EEPROM[0..]
;
; Pin assignments:
;   RC3 = SCL, RC4 = SDA (I2C / MSSP1, 24LC16B EEPROM)
;   RC6 = TX,  RC7 = RX  (UART / EUSART1, 9600 8N1)
;
; Buffer at RAM 0x100-0x1FF (256 bytes = one 24LC16B block).

    PROCESSOR 18F45K22

    CONFIG FOSC  = INTIO67
    CONFIG WDTEN = OFF
    CONFIG LVP   = ON

    #include "pic18f45k22.inc"
    #include <xc.inc>

TX_BYTE     EQU 0x00
Delay1      EQU 0x01
Delay2      EQU 0x02
Delay3      EQU 0x03
ADDR        EQU 0x04
RX_BYTE     EQU 0x05
CUR_ADDR    EQU 0x06

WRITE_CTRL  EQU 10100000B
READ_CTRL   EQU 10100001B
TERMINATOR  EQU 0x60            ; backtick — end-of-data marker

PSECT code,abs
    org 00h
    GOTO Start

Start:
    MOVLB   0x0F

    ; Oscillator @ 4 MHz
    BSF     IRCF2
    BCF     IRCF1
    BSF     IRCF0

    CLRF    PORTD, a
    CLRF    TRISD, a
    CLRF    ANSELD, b

    CLRF    ANSELC, b
    BSF     TRISC, 3
    BSF     TRISC, 4
    BCF     TRISC, 6
    BSF     TRISC, 7

    ; I2C Master @ 100 kHz
    MOVLW   0x09
    MOVWF   SSP1ADD
    CLRF    SSP1STAT
    BSF     SSP1STAT, 7
    CLRF    SSP1CON3
    MOVLW   00101000B
    MOVWF   SSP1CON1
    CLRF    SSP1CON2
    BCF     SSP1IF
    BCF     BCL1IF

    ; UART @ 9600 baud
    MOVLW   0x19
    MOVWF   SPBRG1
    CLRF    SPBRGH1
    MOVLW   00100100B
    MOVWF   TXSTA1
    MOVLW   10010000B
    MOVWF   RCSTA1

    MOVLB   0x00

    CALL    DELAY_1S
    CALL    I2C_BUS_RECOVER

    ; Startup delay + banner so the host terminal has time to attach.
    CALL    DELAY_1S
    CALL    DELAY_1S
    CALL    PRINT_READY_BANNER

MainLoop:
    CALL    EEPROM_READ_OUT
    CALL    UART_CRLF
    CALL    PRINT_PROMPT
    CALL    UART_READ_WRITE
    GOTO    MainLoop

; ---- Sequential read of EEPROM[0..] -> UART until backtick or 0xFF or 256 bytes ----

EEPROM_READ_OUT:
    CALL    I2C_START_COND
    MOVLW   WRITE_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    MOVLW   0x00                ; word address 0
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    CALL    I2C_RESTART_COND
    MOVLW   READ_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE

    CLRF    ADDR, a
ERO_LOOP:
    CALL    I2C_READ_BYTE       ; result in TX_BYTE
    MOVF    TX_BYTE, W, a
    XORLW   TERMINATOR
    BZ      ERO_NACK
    MOVF    TX_BYTE, W, a
    XORLW   0xFF
    BZ      ERO_NACK
    MOVF    TX_BYTE, W, a
    CALL    UART_TX
    INCF    ADDR, F, a
    BZ      ERO_NACK            ; wrapped past 256
    CALL    I2C_SEND_ACK
    BRA     ERO_LOOP
ERO_NACK:
    CALL    I2C_SEND_NACK
    CALL    I2C_STOP_COND
    ; If nothing was output, print "[EMPTY]" so the seeder state is obvious
    MOVF    ADDR, W, a
    BNZ     ERO_DONE
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'E'
    CALL    UART_TX
    MOVLW   'M'
    CALL    UART_TX
    MOVLW   'P'
    CALL    UART_TX
    MOVLW   'T'
    CALL    UART_TX
    MOVLW   'Y'
    CALL    UART_TX
    MOVLW   ']'
    CALL    UART_TX
ERO_DONE:
    RETURN

; ---- Read UART into buffer until backtick, then byte-by-byte write to EEPROM ----

UART_READ_WRITE:
    LFSR    0, 0x100            ; buffer base
    CLRF    ADDR, a             ; count of bytes received
URW_READ:
    CALL    UART_RX
    MOVWF   RX_BYTE, a
    ; CR (0x0D) -> store CRLF; backtick (0x60) -> store and commit; else -> store
    MOVF    RX_BYTE, W, a
    XORLW   0x0D
    BZ      URW_STORE_CRLF
    MOVF    RX_BYTE, W, a
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
    BZ      URW_DONE_READING    ; 256-byte wrap forces commit
    MOVF    RX_BYTE, W, a
    XORLW   TERMINATOR
    BZ      URW_DONE_READING
    BRA     URW_READ
URW_STORE_CRLF:
    MOVLW   0x0D
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
    BZ      URW_DONE_READING
    MOVLW   0x0A
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
    BZ      URW_DONE_READING
    BRA     URW_READ
URW_DONE_READING:

    ; Byte-by-byte write of ADDR bytes from buffer 0x100 to EEPROM[0..]
    LFSR    0, 0x100
    CLRF    CUR_ADDR, a
URW_BYTE_LOOP:
    CALL    I2C_START_COND
    MOVLW   WRITE_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    MOVF    CUR_ADDR, W, a
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    MOVF    POSTINC0, W, a
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    CALL    I2C_STOP_COND
    CALL    DELAY_10MS
    INCF    CUR_ADDR, F, a
    MOVF    CUR_ADDR, W, a
    CPFSEQ  ADDR, a
    BRA     URW_BYTE_LOOP
    RETURN

; ---- "Enter String (end with `):\r\n" ----

PRINT_PROMPT:
    MOVLW   'E'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'S'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'i'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   'g'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   '('
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'w'
    CALL    UART_TX
    MOVLW   'i'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'h'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   0x60                ; backtick
    CALL    UART_TX
    MOVLW   ')'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    GOTO    UART_CRLF

; ---- UART (EUSART1) ----

UART_TX:
    BTFSS   PIR1, 4, a          ; TX1IF: TXREG empty?
    BRA     UART_TX
    MOVWF   TXREG1, a
    RETURN

UART_RX:
    BTFSC   RCSTA1, 1, a        ; OERR?
    BRA     URX_OERR
    BTFSS   PIR1, 5, a          ; RCIF?
    BRA     UART_RX
    MOVF    RCREG1, W, a
    RETURN
URX_OERR:
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
    BRA     UART_RX

UART_CRLF:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX
    RETURN

; "[READY]\r\n"
PRINT_READY_BANNER:
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   'E'
    CALL    UART_TX
    MOVLW   'A'
    CALL    UART_TX
    MOVLW   'D'
    CALL    UART_TX
    MOVLW   'Y'
    CALL    UART_TX
    MOVLW   ']'
    CALL    UART_TX
    GOTO    UART_CRLF

; ---- I2C bus recovery ----

I2C_BUS_RECOVER:
    BCF     SSP1CON1, 5, a
    BSF     LATC, 3, a
    BSF     LATC, 4, a
    BCF     TRISC, 3, a
    BCF     TRISC, 4, a

    MOVLW   0x09
    MOVWF   Delay1, a
IBR_LOOP:
    BCF     LATC, 3, a
    CALL    DELAY_5US
    BSF     LATC, 3, a
    CALL    DELAY_5US
    DECFSZ  Delay1, F, a
    BRA     IBR_LOOP

    BCF     LATC, 4, a
    CALL    DELAY_5US
    BSF     LATC, 3, a
    CALL    DELAY_5US
    BSF     LATC, 4, a
    CALL    DELAY_5US

    BSF     TRISC, 3, a
    BSF     TRISC, 4, a
    CALL    DELAY_5US
    BCF     SSP1CON1, 5, a
    CLRF    SSP1CON2
    CLRF    SSP1STAT
    BSF     SSP1STAT, 7
    CLRF    SSP1CON3
    MOVLW   0x09
    MOVWF   SSP1ADD
    MOVLW   00101000B
    MOVWF   SSP1CON1
    BCF     SSP1IF
    BCF     BCL1IF
    RETURN

DELAY_5US:
    MOVLW   0x06
    MOVWF   Delay2, a
D5_LOOP:
    DECFSZ  Delay2, F, a
    BRA     D5_LOOP
    RETURN

; ---- I2C primitives ----

I2C_START_COND:
    BCF     SSP1IF
    BSF     SSP1CON2, 0
Wait_START:
    BTFSC   SSP1CON2, 0
    BRA     Wait_START
    RETURN

I2C_RESTART_COND:
    BCF     SSP1IF
    BSF     SSP1CON2, 1
Wait_RESTART:
    BTFSC   SSP1CON2, 1
    BRA     Wait_RESTART
    RETURN

I2C_STOP_COND:
    BCF     SSP1IF
    BSF     SSP1CON2, 2
Wait_STOP:
    BTFSC   SSP1CON2, 2
    BRA     Wait_STOP
    RETURN

I2C_WRITE:
    BTFSC   SSP1STAT, 0
    GOTO    I2C_WRITE
    BCF     SSP1IF
    MOVF    TX_BYTE, W, a
    MOVWF   SSP1BUF
Wait_WRITE:
    BTFSS   SSP1IF
    BRA     Wait_WRITE
    RETURN

I2C_READ_BYTE:                  ; receive byte to TX_BYTE; does NOT send ACK/NACK
    BCF     SSP1IF
    BSF     SSP1CON2, 3         ; RCEN
Wait_RX:
    BTFSS   SSP1IF
    BRA     Wait_RX
    BTFSS   SSP1STAT, 0
    GOTO    Wait_RX
    MOVF    SSP1BUF, W
    MOVWF   TX_BYTE, a
    BCF     SSP1IF
    RETURN

I2C_SEND_ACK:
    BCF     SSP1CON2, 5         ; ACKDT=0 (ACK)
    BSF     SSP1CON2, 4         ; ACKEN
Wait_ACK:
    BTFSC   SSP1CON2, 4
    BRA     Wait_ACK
    RETURN

I2C_SEND_NACK:
    BSF     SSP1CON2, 5         ; ACKDT=1 (NACK)
    BSF     SSP1CON2, 4
Wait_NACK:
    BTFSC   SSP1CON2, 4
    BRA     Wait_NACK
    RETURN

; ---- Delays ----

DELAY_10MS:
    MOVLW   0x0D
    MOVWF   Delay2, a
D10_L1:
    MOVLW   0xFF
    MOVWF   Delay1, a
D10_L2:
    DECFSZ  Delay1, F, a
    BRA     D10_L2
    DECFSZ  Delay2, F, a
    BRA     D10_L1
    RETURN

DELAY_1S:
    MOVLW   0x3
    MOVWF   Delay3, a
D1S_L1:
    MOVLW   0xFF
    MOVWF   Delay2, a
D1S_L2:
    MOVLW   0xFF
    MOVWF   Delay1, a
D1S_L3:
    DECFSZ  Delay1, F, a
    BRA     D1S_L3
    DECFSZ  Delay2, F, a
    BRA     D1S_L2
    DECFSZ  Delay3, F, a
    BRA     D1S_L1
    RETURN

    end
