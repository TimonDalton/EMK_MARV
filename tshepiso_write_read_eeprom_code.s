; -----------------------------------------------------------------------------
; EMK310 - 24LC16B EEPROM Read/Write over UART (9600 8N1)
;   Boot: dump stored sentence from EEPROM
;   Loop: read a new sentence from the user, write it to EEPROM, read back
; Storage layout in EEPROM:
;   addr 0x00 = length byte (0..63; 0xFF / >63 treated as "empty")
;   addr 0x01..0x3F = sentence bytes
; -----------------------------------------------------------------------------

    PROCESSOR 18F45K22

    CONFIG FOSC = INTIO67
    CONFIG WDTEN = OFF
    CONFIG LVP = ON

    #include "pic18f45k22.inc"
    #include <xc.inc>

;--- Variables ---
TX_BYTE      EQU 0x00
EEPROM_ADDR  EQU 0x01
COUNT        EQU 0x02
TEMP         EQU 0x03
Delay1       EQU 0x04
Delay2       EQU 0x05
DATA_BYTE    EQU 0x06
LENGTH       EQU 0x07
RX_CHAR      EQU 0x08
; Input buffer (RAM): 0x20..0x5E  (up to 63 chars)

WRITE_ADDR   EQU 0xA0       ; I2C control byte, write
READ_ADDR    EQU 0xA1       ; I2C control byte, read
MAX_LEN_VAL  EQU 0x3F       ; 63 bytes max sentence

;-------------------------------------------------------------------------------
PSECT code,abs
    org 00h
    goto Start

;-------------------------------------------------------------------------------
Start:
    MOVLB 0x0F

    ; --- Oscillator @ 4 MHz ---
    BSF IRCF2
    BCF IRCF1
    BSF IRCF0

    ; --- Ports ---
    CLRF TRISA,a
    CLRF ANSELA,b
    CLRF PORTA,a

    ; I2C pins (RC3 = SCL, RC4 = SDA) must be inputs (open-drain via SSP)
    BSF TRISC,3
    BSF TRISC,4

    ; UART pins: RC6 = TX (output), RC7 = RX (input)
    BCF TRISC,6
    BSF TRISC,7
    CLRF ANSELC,b

    ; --- I2C Master @ 100 kHz ---
    MOVLW 0x09
    MOVWF SSP1ADD
    CLRF SSP1STAT
    BSF SSP1STAT,7
    MOVLW 0x28
    MOVWF SSP1CON1
    CLRF SSP1CON2

    ; --- UART @ 9600 (BRGH=1, SPBRG1=25 -> 9615 baud, 0.16% error) ---
    MOVLW 25
    MOVWF SPBRG1
    BSF TXSTA1,2     ; BRGH = 1
    BCF TXSTA1,4     ; SYNC = 0 (async)
    BSF RCSTA1,7     ; SPEN = 1 (serial port on)
    BSF TXSTA1,5     ; TXEN = 1 (transmit enable)
    BSF RCSTA1,4     ; CREN = 1 (continuous receive)
    CALL DELAY_100MS

    MOVLB 0x00

Main:
    ; Boot dump of stored sentence
    CALL PRINT_CRLF
    CALL PRINT_STORED_LABEL
    CALL EE_READ_AND_PRINT_SENTENCE
    CALL PRINT_CRLF

LoopPrompt:
    CALL PRINT_ENTER_LABEL
    CALL UART_READ_LINE          ; fills buffer at 0x20, LENGTH = count
    CALL PRINT_CRLF

    CALL EE_WRITE_SENTENCE       ; writes LENGTH + sentence to EEPROM

    CALL PRINT_STORED_LABEL
    CALL EE_READ_AND_PRINT_SENTENCE
    CALL PRINT_CRLF
    GOTO LoopPrompt

;-------------------------------------------------------------------------------
; UART_READ_LINE: read characters into buffer at 0x20, echoing each one.
;   Terminates on CR (0x0D) or LF (0x0A).
;   Backspace (0x08 / 0x7F) deletes the previous character.
;   Caps at MAX_LEN_VAL bytes; further input ignored until terminator.
; Out: LENGTH = number of bytes stored
;-------------------------------------------------------------------------------
UART_READ_LINE:
    CLRF LENGTH
    MOVLW 0x20
    MOVWF FSR0L
    CLRF FSR0H
URL_Loop:
    CALL UART_RECV_BYTE
    MOVWF RX_CHAR

    ; CR ends input
    MOVLW 0x0D
    CPFSEQ RX_CHAR
    BRA URL_NotCR
    RETURN
URL_NotCR:

    ; LF also ends input
    MOVLW 0x0A
    CPFSEQ RX_CHAR
    BRA URL_NotLF
    RETURN
URL_NotLF:

    ; Backspace (BS = 0x08)?
    MOVLW 0x08
    XORWF RX_CHAR,W
    BZ URL_Backspace
    ; DEL (0x7F)?
    MOVLW 0x7F
    XORWF RX_CHAR,W
    BZ URL_Backspace
    BRA URL_NotBS

URL_Backspace:
    MOVF LENGTH,W
    BZ URL_Loop                  ; buffer empty: ignore
    DECF LENGTH,F
    DECF FSR0L,F
    ; Erase on terminal: BS, space, BS
    MOVLW 0x08
    CALL UART_SEND_BYTE
    MOVLW ' '
    CALL UART_SEND_BYTE
    MOVLW 0x08
    CALL UART_SEND_BYTE
    BRA URL_Loop

URL_NotBS:
    ; Drop non-printable bytes silently (keep < 0x20 out unless tab)
    MOVLW 0x20
    CPFSLT RX_CHAR               ; skip if RX_CHAR < 0x20
    BRA URL_Printable
    BRA URL_Loop
URL_Printable:

    ; Refuse to store past the cap
    MOVLW MAX_LEN_VAL
    CPFSLT LENGTH                ; skip if LENGTH < MAX_LEN_VAL
    BRA URL_Loop                 ; full -- ignore until terminator

    ; Store and echo
    MOVF RX_CHAR,W
    MOVWF INDF0
    INCF FSR0L,F
    INCF LENGTH,F
    MOVF RX_CHAR,W
    CALL UART_SEND_BYTE
    BRA URL_Loop

;-------------------------------------------------------------------------------
; EE_WRITE_SENTENCE: write LENGTH at EEPROM 0, then LENGTH bytes from buf 0x20.
; Uses byte writes (5 ms cycle each + safety margin).
;-------------------------------------------------------------------------------
EE_WRITE_SENTENCE:
    ; Byte 0 of EEPROM = length
    CLRF EEPROM_ADDR
    MOVF LENGTH,W
    MOVWF DATA_BYTE
    CALL EE_WRITE_BYTE

    ; If LENGTH == 0, nothing more to write
    MOVF LENGTH,W
    BZ EWS_Done

    MOVF LENGTH,W
    MOVWF COUNT
    MOVLW 0x20
    MOVWF FSR0L
    CLRF FSR0H
    MOVLW 0x01
    MOVWF EEPROM_ADDR
EWS_Loop:
    MOVF INDF0,W
    MOVWF DATA_BYTE
    CALL EE_WRITE_BYTE
    INCF FSR0L,F
    INCF EEPROM_ADDR,F
    DECFSZ COUNT,F
    GOTO EWS_Loop
EWS_Done:
    RETURN

;-------------------------------------------------------------------------------
; EE_WRITE_BYTE: write DATA_BYTE to EEPROM at EEPROM_ADDR (block 0).
;-------------------------------------------------------------------------------
EE_WRITE_BYTE:
    CALL EE_BUS_START
    MOVLW WRITE_ADDR
    CALL EE_BUS_SEND
    MOVF EEPROM_ADDR,W
    CALL EE_BUS_SEND
    MOVF DATA_BYTE,W
    CALL EE_BUS_SEND
    CALL EE_BUS_STOP
    CALL DELAY_10MS              ; 24LC16B write cycle: 5 ms max
    RETURN

;-------------------------------------------------------------------------------
; EE_READ_AND_PRINT_SENTENCE:
;   Set EEPROM ptr to 0, read length byte, then read+print that many bytes.
;   If length > MAX_LEN_VAL (e.g. 0xFF on virgin EEPROM), prints "(empty)".
;-------------------------------------------------------------------------------
EE_READ_AND_PRINT_SENTENCE:
    ; Dummy write to set internal EEPROM address pointer to 0
    CALL EE_BUS_START
    MOVLW WRITE_ADDR
    CALL EE_BUS_SEND
    MOVLW 0x00
    CALL EE_BUS_SEND

    ; Repeated START, switch to read mode
    BSF SSP1CON2,1
ERAP_WaitRS:
    BTFSC SSP1CON2,1
    BRA ERAP_WaitRS
    MOVLW READ_ADDR
    CALL EE_BUS_SEND

    ; First byte = length
    CALL EE_READ_BYTE_ACK
    MOVWF LENGTH

    ; Validate
    MOVLW MAX_LEN_VAL
    CPFSGT LENGTH                ; skip if LENGTH > MAX_LEN_VAL
    BRA ERAP_LenOK
    ; Invalid -> consume one more byte with NACK then stop
    CALL EE_READ_BYTE_NACK
    CALL EE_BUS_STOP
    CALL PRINT_EMPTY
    RETURN

ERAP_LenOK:
    MOVF LENGTH,W
    BZ ERAP_Empty
    MOVWF COUNT

ERAP_Loop:
    ; If COUNT == 1, last byte -> NACK + STOP
    MOVF COUNT,W
    XORLW 0x01
    BZ ERAP_Last
    CALL EE_READ_BYTE_ACK
    CALL UART_SEND_BYTE
    DECF COUNT,F
    BRA ERAP_Loop
ERAP_Last:
    CALL EE_READ_BYTE_NACK
    CALL EE_BUS_STOP
    CALL UART_SEND_BYTE
    RETURN

ERAP_Empty:
    CALL EE_READ_BYTE_NACK
    CALL EE_BUS_STOP
    CALL PRINT_EMPTY
    RETURN

;-------------------------------------------------------------------------------
; I2C byte receive helpers
;-------------------------------------------------------------------------------
EE_READ_BYTE_ACK:
    BCF PIR1,3
    BSF SSP1CON2,3               ; RCEN = 1
ERBA_Wait:
    BTFSS PIR1,3
    BRA ERBA_Wait
    BCF PIR1,3
    MOVF SSP1BUF,W
    MOVWF TX_BYTE
    BCF SSP1CON2,5               ; ACKDT = 0 (ACK)
    BSF SSP1CON2,4               ; ACKEN = 1
ERBA_WaitAck:
    BTFSC SSP1CON2,4
    BRA ERBA_WaitAck
    MOVF TX_BYTE,W
    RETURN

EE_READ_BYTE_NACK:
    BCF PIR1,3
    BSF SSP1CON2,3
ERBN_Wait:
    BTFSS PIR1,3
    BRA ERBN_Wait
    BCF PIR1,3
    MOVF SSP1BUF,W
    MOVWF TX_BYTE
    BSF SSP1CON2,5               ; ACKDT = 1 (NACK)
    BSF SSP1CON2,4               ; ACKEN = 1
ERBN_WaitAck:
    BTFSC SSP1CON2,4
    BRA ERBN_WaitAck
    MOVF TX_BYTE,W
    RETURN

;-------------------------------------------------------------------------------
; I2C primitives
;-------------------------------------------------------------------------------
EE_BUS_START:
    BSF SSP1CON2,0
EBS_Wait:
    BTFSC SSP1CON2,0
    BRA EBS_Wait
    RETURN

EE_BUS_STOP:
    BSF SSP1CON2,2
EBP_Wait:
    BTFSC SSP1CON2,2
    BRA EBP_Wait
    RETURN

EE_BUS_SEND:
    BCF PIR1,3
    MOVWF SSP1BUF
EBW_Wait:
    BTFSS PIR1,3
    BRA EBW_Wait
    BCF PIR1,3
    RETURN

;-------------------------------------------------------------------------------
; UART
;-------------------------------------------------------------------------------
UART_SEND_BYTE:
    BTFSS TXSTA1,1               ; TRMT == 1 -> transmit shift register empty
    BRA UART_SEND_BYTE
    MOVWF TXREG1
    RETURN

UART_RECV_BYTE:
    ; Clear OERR if set (overrun freezes RX otherwise)
    BTFSS RCSTA1,1
    BRA URB_NoOerr
    BCF RCSTA1,4
    BSF RCSTA1,4
URB_NoOerr:
    BTFSS PIR1,5                 ; RC1IF = receive ready
    BRA UART_RECV_BYTE
    MOVF RCREG1,W
    RETURN

PRINT_CRLF:
    MOVLW 0x0D
    CALL UART_SEND_BYTE
    MOVLW 0x0A
    CALL UART_SEND_BYTE
    RETURN

;-------------------------------------------------------------------------------
; Prompt printers (char-by-char to keep things simple)
;-------------------------------------------------------------------------------
PRINT_STORED_LABEL:
    MOVLW 'S'
    CALL UART_SEND_BYTE
    MOVLW 't'
    CALL UART_SEND_BYTE
    MOVLW 'o'
    CALL UART_SEND_BYTE
    MOVLW 'r'
    CALL UART_SEND_BYTE
    MOVLW 'e'
    CALL UART_SEND_BYTE
    MOVLW 'd'
    CALL UART_SEND_BYTE
    MOVLW ':'
    CALL UART_SEND_BYTE
    MOVLW ' '
    CALL UART_SEND_BYTE
    RETURN

PRINT_ENTER_LABEL:
    MOVLW 'E'
    CALL UART_SEND_BYTE
    MOVLW 'n'
    CALL UART_SEND_BYTE
    MOVLW 't'
    CALL UART_SEND_BYTE
    MOVLW 'e'
    CALL UART_SEND_BYTE
    MOVLW 'r'
    CALL UART_SEND_BYTE
    MOVLW ' '
    CALL UART_SEND_BYTE
    MOVLW 's'
    CALL UART_SEND_BYTE
    MOVLW 'e'
    CALL UART_SEND_BYTE
    MOVLW 'n'
    CALL UART_SEND_BYTE
    MOVLW 't'
    CALL UART_SEND_BYTE
    MOVLW 'e'
    CALL UART_SEND_BYTE
    MOVLW 'n'
    CALL UART_SEND_BYTE
    MOVLW 'c'
    CALL UART_SEND_BYTE
    MOVLW 'e'
    CALL UART_SEND_BYTE
    MOVLW ':'
    CALL UART_SEND_BYTE
    MOVLW ' '
    CALL UART_SEND_BYTE
    RETURN

PRINT_EMPTY:
    MOVLW '('
    CALL UART_SEND_BYTE
    MOVLW 'e'
    CALL UART_SEND_BYTE
    MOVLW 'm'
    CALL UART_SEND_BYTE
    MOVLW 'p'
    CALL UART_SEND_BYTE
    MOVLW 't'
    CALL UART_SEND_BYTE
    MOVLW 'y'
    CALL UART_SEND_BYTE
    MOVLW ')'
    CALL UART_SEND_BYTE
    RETURN

;-------------------------------------------------------------------------------
; Delays
;-------------------------------------------------------------------------------
DELAY_100MS:                     ; ~197 ms at 4 MHz, fine for warm-up
    MOVLW 0xFF
    MOVWF Delay2
L1: MOVLW 0xFF
    MOVWF Delay1
L2: DECFSZ Delay1,F
    GOTO L2
    DECFSZ Delay2,F
    GOTO L1
    RETURN

DELAY_10MS:                      ; ~10 ms (covers EEPROM 5 ms write cycle)
    MOVLW 0x0D                   ; 13 outer * ~770 cycles = ~10000 cycles
    MOVWF Delay2
D10_L1:
    MOVLW 0xFF
    MOVWF Delay1
D10_L2:
    DECFSZ Delay1,F
    GOTO D10_L2
    DECFSZ Delay2,F
    GOTO D10_L1
    RETURN

    end
