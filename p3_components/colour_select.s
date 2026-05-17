; colour_select.s — standalone colour-select state for prac 3
;
; Inputs:
;   Yellow button (RB0, INT0) — cycle candidate: R -> G -> B -> k -> R ...
;   Red button   (RB1, INT1) — lock current candidate (prints "Locked: X")
;   UART char R / G / B / k  — set RACE_COL directly (prints "Set: X")
;
; Outputs:
;   SSD (PORTA) — shows current colour char (flashing 50% duty for visibility)
;   UART — prints state changes
;   RACE_COL_var — the integration variable both paths converge on
;
; Pin assignments:
;   PORTA = SSD
;   RB0 = yellow button (INT0, rising edge)
;   RB1 = red button   (INT1, rising edge)
;   RC6 = UART TX
;   RC7 = UART RX

    PROCESSOR 18F45K22

    CONFIG  FOSC   = INTIO67
    CONFIG  WDTEN  = OFF
    CONFIG  MCLRE  = EXTMCLR
    CONFIG  LVP    = ON

    #include <xc.inc>
    #include "pic18f45k22.inc"

; ---- Variables ----
Delay1               EQU 0x01
Delay2               EQU 0x02
Delay3               EQU 0x03
RX_BYTE              EQU 0x04
uart_rx_char_var     EQU 0x05
RACE_COL_var         EQU 0x06
yellow_pressed_var   EQU 0x07
red_pressed_var      EQU 0x08
uart_set_var         EQU 0x09       ; flag: UART just set colour, print confirmation
flash_phase_var      EQU 0x0A       ; 0 = SSD off, 1 = SSD on

; ---- Colour values (must match marv.s RACE_COL semantics) ----
RED_COL              EQU 0x01
GREEN_COL            EQU 0x02
BLUE_COL             EQU 0x03
BLACK_COL            EQU 0x04

; ---- SSD 7-seg patterns (common-cathode, segments a-g on bits 0-6) ----
; VERIFY against your physical SSD wiring; tweak if inverted.
;   'r' lowercase: e, g          -> 0x50
;   'G' approx (uppercase G):     a,c,d,e,f -> 0x3D
;   'b' lowercase: c,d,e,f,g     -> 0x7C
;   '-' dash:      g             -> 0x40
SSD_RED              EQU 0x50
SSD_GREEN            EQU 0x3D
SSD_BLUE             EQU 0x7C
SSD_BLACK            EQU 0x40
SSD_BLANK            EQU 0x00


PSECT code,abs
    org 00h
    GOTO Init

    ORG 0x08
    GOTO ISR


;===========================================================================
; ISR — UART RX + INT0 (yellow) + INT1 (red)
;===========================================================================

ISR:
    BTFSC   PIR1, 5, a              ; RC1IF — UART RX byte ready?
    CALL    UART_RX_HANDLER
    BTFSC   INTCON, 1, a            ; INT0IF — yellow button
    CALL    INT0_HANDLER
    BTFSC   INTCON3, 0, a           ; INT1IF — red button
    CALL    INT1_HANDLER
    CALL    CLEAR_INT_FLAGS
    RETFIE  1

CLEAR_INT_FLAGS:
    BCF     INTCON, 1, 0            ; INT0IF
    BCF     INTCON3, 0, 0           ; INT1IF
    RETURN

INT0_HANDLER:                       ; yellow button — cycle candidate
    BSF     yellow_pressed_var, 0, a
    RETURN

INT1_HANDLER:                       ; red button — lock
    ; Spin-wait for release (debounce like marv.s pattern)
INT1_WAIT_RELEASE:
    BTFSC   PORTB, 1, a
    BRA     INT1_WAIT_RELEASE
    BSF     red_pressed_var, 0, a
    RETURN

UART_RX_HANDLER:
    BTFSC   RCSTA1, 1, a            ; OERR?
    BRA     URX_OERR
    MOVF    RCREG1, W, a
    MOVWF   uart_rx_char_var, a

    XORLW   'R'
    BZ      RX_SET_RED
    MOVF    uart_rx_char_var, W, a
    XORLW   'G'
    BZ      RX_SET_GREEN
    MOVF    uart_rx_char_var, W, a
    XORLW   'B'
    BZ      RX_SET_BLUE
    MOVF    uart_rx_char_var, W, a
    XORLW   'k'
    BZ      RX_SET_BLACK
    RETURN
URX_OERR:
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
    RETURN
RX_SET_RED:
    MOVLW   RED_COL
    MOVWF   RACE_COL_var, a
    BSF     uart_set_var, 0, a
    RETURN
RX_SET_GREEN:
    MOVLW   GREEN_COL
    MOVWF   RACE_COL_var, a
    BSF     uart_set_var, 0, a
    RETURN
RX_SET_BLUE:
    MOVLW   BLUE_COL
    MOVWF   RACE_COL_var, a
    BSF     uart_set_var, 0, a
    RETURN
RX_SET_BLACK:
    MOVLW   BLACK_COL
    MOVWF   RACE_COL_var, a
    BSF     uart_set_var, 0, a
    RETURN


;===========================================================================
; Init
;===========================================================================

Init:
    MOVLB   0x0F

    ; Oscillator @ 4 MHz
    BSF     OSCCON, 6, a
    BCF     OSCCON, 5, a
    BSF     OSCCON, 4, a

    ; PORTA: SSD output
    CLRF    PORTA, a
    CLRF    TRISA, a
    CLRF    ANSELA, b

    ; PORTB: buttons input on RB0, RB1
    CLRF    PORTB, a
    CLRF    LATB, a
    CLRF    ANSELB, b
    BSF     TRISB, 0, a             ; RB0 input (yellow)
    BSF     TRISB, 1, a             ; RB1 input (red)

    ; PORTC: UART
    CLRF    ANSELC, b
    BCF     TRISC, 6                ; TX output
    BSF     TRISC, 7                ; RX input

    ; UART @ 9600 baud
    MOVLW   0x19
    MOVWF   SPBRG1
    CLRF    SPBRGH1
    MOVLW   00100100B               ; TXEN=1, BRGH=1
    MOVWF   TXSTA1
    MOVLW   10010000B               ; SPEN=1, CREN=1
    MOVWF   RCSTA1

    ; Interrupt config
    BSF     INTCON2, 6, 0           ; INTEDG0 = 1 (RB0 rising)
    BSF     INTCON2, 5, 0           ; INTEDG1 = 1 (RB1 rising)
    BCF     INTCON, 1, 0            ; INT0IF clear
    BCF     INTCON3, 0, 0           ; INT1IF clear
    BSF     INTCON, 4, 0            ; INT0IE
    BSF     INTCON3, 3, 0           ; INT1IE
    BCF     PIR1, 5, a              ; RC1IF clear
    BSF     PIE1, 5, a              ; RC1IE
    BSF     INTCON, 6, a            ; PEIE
    BSF     INTCON, 7, a            ; GIE

    MOVLB   0x00

    ; Defaults
    MOVLW   RED_COL
    MOVWF   RACE_COL_var, a
    CLRF    yellow_pressed_var, a
    CLRF    red_pressed_var, a
    CLRF    uart_set_var, a
    CLRF    flash_phase_var, a

    CALL    DELAY_1S
    CALL    PRINT_BANNER
    CALL    PRINT_CURRENT


;===========================================================================
; Main loop — flash SSD + poll input flags
;===========================================================================

Main:
    ; Flash phase toggle: alternate SSD ON/OFF each pass
    BTG     flash_phase_var, 0, a
    BTFSS   flash_phase_var, 0, a
    BRA     MAIN_SSD_OFF
    CALL    SET_SSD_TO_RACE_COL
    BRA     MAIN_POLL
MAIN_SSD_OFF:
    MOVLW   SSD_BLANK
    MOVWF   PORTA, a

MAIN_POLL:
    CALL    DELAY_200MS

    ; Yellow button — cycle
    BTFSC   yellow_pressed_var, 0, a
    CALL    HANDLE_YELLOW
    ; Red button — lock
    BTFSC   red_pressed_var, 0, a
    CALL    HANDLE_RED
    ; UART set — print confirmation
    BTFSC   uart_set_var, 0, a
    CALL    HANDLE_UART_SET

    BRA     Main


;===========================================================================
; Input handlers (called from main when flags are set)
;===========================================================================

HANDLE_YELLOW:
    BCF     yellow_pressed_var, 0, a
    ; Cycle: 1 -> 2 -> 3 -> 4 -> 1
    INCF    RACE_COL_var, F, a
    MOVLW   0x05
    CPFSEQ  RACE_COL_var, a
    BRA     HY_PRINT
    MOVLW   RED_COL
    MOVWF   RACE_COL_var, a
HY_PRINT:
    GOTO    PRINT_CURRENT

HANDLE_RED:
    BCF     red_pressed_var, 0, a
    CALL    PRINT_LOCKED
    RETURN

HANDLE_UART_SET:
    BCF     uart_set_var, 0, a
    CALL    PRINT_SET
    RETURN


;===========================================================================
; SSD update — write 7-seg pattern for current RACE_COL_var to PORTA
;===========================================================================

SET_SSD_TO_RACE_COL:
    MOVF    RACE_COL_var, W, a
    XORLW   RED_COL
    BZ      SSD_R
    MOVF    RACE_COL_var, W, a
    XORLW   GREEN_COL
    BZ      SSD_G
    MOVF    RACE_COL_var, W, a
    XORLW   BLUE_COL
    BZ      SSD_B
    MOVF    RACE_COL_var, W, a
    XORLW   BLACK_COL
    BZ      SSD_K
    RETURN
SSD_R:
    MOVLW   SSD_RED
    MOVWF   PORTA, a
    RETURN
SSD_G:
    MOVLW   SSD_GREEN
    MOVWF   PORTA, a
    RETURN
SSD_B:
    MOVLW   SSD_BLUE
    MOVWF   PORTA, a
    RETURN
SSD_K:
    MOVLW   SSD_BLACK
    MOVWF   PORTA, a
    RETURN


;===========================================================================
; UART subroutines + print strings
;===========================================================================

UART_TX:
    BTFSS   PIR1, 4, a              ; TX1IF
    BRA     UART_TX
    MOVWF   TXREG1, a
    RETURN

UART_CRLF:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX
    RETURN

; "Colour select: R/G/B/k"
PRINT_BANNER:
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   's'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    GOTO    UART_CRLF

; "Current: X\r\n"
PRINT_CURRENT:
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    CALL    PRINT_COL_CHAR
    GOTO    UART_CRLF

; "Set: X\r\n"
PRINT_SET:
    MOVLW   'S'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    CALL    PRINT_COL_CHAR
    GOTO    UART_CRLF

; "Locked: X\r\n"
PRINT_LOCKED:
    MOVLW   'L'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   'k'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    CALL    PRINT_COL_CHAR
    GOTO    UART_CRLF

; Print 'R', 'G', 'B', or 'k' depending on RACE_COL_var
PRINT_COL_CHAR:
    MOVF    RACE_COL_var, W, a
    XORLW   RED_COL
    BZ      PCC_R
    MOVF    RACE_COL_var, W, a
    XORLW   GREEN_COL
    BZ      PCC_G
    MOVF    RACE_COL_var, W, a
    XORLW   BLUE_COL
    BZ      PCC_B
    MOVF    RACE_COL_var, W, a
    XORLW   BLACK_COL
    BZ      PCC_K
    MOVLW   '?'
    GOTO    UART_TX
PCC_R:
    MOVLW   'R'
    GOTO    UART_TX
PCC_G:
    MOVLW   'G'
    GOTO    UART_TX
PCC_B:
    MOVLW   'B'
    GOTO    UART_TX
PCC_K:
    MOVLW   'k'
    GOTO    UART_TX


;===========================================================================
; Delays
;===========================================================================

; ~200 ms at 4 MHz
DELAY_200MS:
    MOVLW   0xA0
    MOVWF   Delay2, a
D200_L1:
    MOVLW   0xFF
    MOVWF   Delay1, a
D200_L2:
    DECFSZ  Delay1, F, a
    BRA     D200_L2
    DECFSZ  Delay2, F, a
    BRA     D200_L1
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
