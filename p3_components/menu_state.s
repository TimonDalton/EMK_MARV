; menu_state.s — standalone test of prac 3 menu state machine
;
; UART RX byte → ISR dispatches by char → sets must_navigate_to_var.
; Each state prints a message + sets SSD digit + loops polling NAV_STATE_IF_REQUIRED.
;
; Commands:
;   M = main menu (CYOC) — prints greeting+menu from EEPROM
;   C = colour state (placeholder — full impl in colour_select.s)
;   R = reference state (placeholder — CAL_STATE wrapper at integration time)
;   A = attack state (DEFAULT on power-on)
;   S = simulate state (placeholder)
;   H = hotload state — overwrites EEPROM with new multi-line content
;
; Requires EEPROM pre-seeded via eeprom_portd_test.s (multi-line + backtick terminator).
; If EEPROM is all 0xFF, greeting print is silent — system still works.
;
; Pin assignments:
;   PORTA<7:0> = SSD (7-seg, common-cathode bit pattern)
;   RB0 = yellow button (INT0, rising edge) — advance candidate in MAIN_MENU
;   RB1 = red button   (INT1, rising edge) — lock candidate / back-to-menu
;   RC3 = SCL, RC4 = SDA (I2C/MSSP1)
;   RC6 = TX,  RC7 = RX  (UART/EUSART1 @ 9600 8N1)

    PROCESSOR 18F45K22

    CONFIG  FOSC   = INTIO67
    CONFIG  WDTEN  = OFF
    CONFIG  MCLRE  = EXTMCLR
    CONFIG  LVP    = ON

    #include <xc.inc>
    #include "pic18f45k22.inc"

; ---- Variables (access bank) ----
TX_BYTE                  EQU 0x00
Delay1                   EQU 0x01
Delay2                   EQU 0x02
Delay3                   EQU 0x03
ADDR                     EQU 0x04
RX_BYTE                  EQU 0x05
CUR_ADDR                 EQU 0x06
uart_rx_char_var         EQU 0x07
must_navigate_to_var     EQU 0x08
current_state_var        EQU 0x09
current_state_symbol_var EQU 0x0A
display_select_state_var EQU 0x0B    ; main-menu: target of red-button lock
yellow_pressed_var       EQU 0x0C    ; main-menu: yellow advanced candidate
candidate_ssd_var        EQU 0x0D    ; main-menu: SSD pattern for current candidate
flash_phase_var          EQU 0x0E    ; main-menu: SSD flash toggle

; ---- State constants ----
main_menu_state_val      EQU 0x10
colour_state_val         EQU 0x11
reference_state_val      EQU 0x12
attack_state_val         EQU 0x13
simulate_state_val       EQU 0x14
hotload_state_val        EQU 0x15

; ---- SSD 7-seg patterns for digits (common-cathode, bits a-g on 0-6) ----
; VERIFY against your physical SSD wiring at integration; adjust if inverted.
SSD_0                    EQU 0x3F
SSD_1                    EQU 0x06
SSD_2                    EQU 0x5B
SSD_3                    EQU 0x4F
SSD_4                    EQU 0x66
SSD_5                    EQU 0x6D

; ---- I2C / EEPROM ----
WRITE_CTRL               EQU 10100000B
READ_CTRL                EQU 10100001B
EEPROM_END               EQU 0x60      ; backtick — end-of-data marker
LINE_FEED                EQU 0x0A
CARR_RET                 EQU 0x0D

PSECT code,abs
    org 00h
    GOTO Init

    ORG 0x08
    GOTO ISR


;===========================================================================
; ISR — UART RX dispatch
;===========================================================================

ISR:
    BTFSC   PIR1, 5, a              ; RC1IF — UART RX byte ready?
    CALL    UART_RX_HANDLER
    BTFSC   INTCON, 1, a            ; INT0IF — yellow button (RB0)
    CALL    INT0_HANDLER
    BTFSC   INTCON3, 0, a           ; INT1IF — red button (RB1)
    CALL    INT1_HANDLER
    BCF     INTCON, 1, 0            ; clear INT0IF
    BCF     INTCON3, 0, 0           ; clear INT1IF
    RETFIE  1

; Yellow button: in MAIN_MENU advances candidate; ignored elsewhere
INT0_HANDLER:
    MOVF    current_state_var, W, a
    XORLW   main_menu_state_val
    BZ      INT0_MAIN_MENU
    RETURN
INT0_MAIN_MENU:
    BSF     yellow_pressed_var, 0, a
    RETURN

; Red button: in MAIN_MENU locks current candidate; elsewhere navs back to main menu
INT1_HANDLER:
INT1_WAIT_RELEASE:
    BTFSC   PORTB, 1, a             ; wait for release (debounce)
    BRA     INT1_WAIT_RELEASE
    MOVF    current_state_var, W, a
    XORLW   main_menu_state_val
    BZ      INT1_LOCK_CANDIDATE
    ; In a non-main state: red = CYOC equivalent
    MOVLW   main_menu_state_val
    MOVWF   must_navigate_to_var, a
    RETURN
INT1_LOCK_CANDIDATE:
    MOVF    display_select_state_var, W, a
    MOVWF   must_navigate_to_var, a
    RETURN

UART_RX_HANDLER:
    BTFSC   RCSTA1, 1, a            ; OERR set?
    BRA     URX_OERR
    MOVF    RCREG1, W, a            ; read byte (clears RCIF)
    MOVWF   uart_rx_char_var, a

    XORLW   'M'
    BZ      RX_GO_MAIN
    MOVF    uart_rx_char_var, W, a
    XORLW   'C'
    BZ      RX_GO_COLOUR
    MOVF    uart_rx_char_var, W, a
    XORLW   'R'
    BZ      RX_GO_REFERENCE
    MOVF    uart_rx_char_var, W, a
    XORLW   'A'
    BZ      RX_GO_ATTACK
    MOVF    uart_rx_char_var, W, a
    XORLW   'S'
    BZ      RX_GO_SIMULATE
    MOVF    uart_rx_char_var, W, a
    XORLW   'H'
    BZ      RX_GO_HOTLOAD
    RETURN                          ; unrecognised char (e.g. CR from Enter) — ignore

URX_OERR:
    BCF     RCSTA1, 4, a            ; CREN=0 — clears OERR
    BSF     RCSTA1, 4, a            ; CREN=1 — re-enable
    RETURN

RX_GO_MAIN:
    MOVLW   main_menu_state_val
    MOVWF   must_navigate_to_var, a
    RETURN
RX_GO_COLOUR:
    MOVLW   colour_state_val
    MOVWF   must_navigate_to_var, a
    RETURN
RX_GO_REFERENCE:
    MOVLW   reference_state_val
    MOVWF   must_navigate_to_var, a
    RETURN
RX_GO_ATTACK:
    MOVLW   attack_state_val
    MOVWF   must_navigate_to_var, a
    RETURN
RX_GO_SIMULATE:
    MOVLW   simulate_state_val
    MOVWF   must_navigate_to_var, a
    RETURN
RX_GO_HOTLOAD:
    MOVLW   hotload_state_val
    MOVWF   must_navigate_to_var, a
    RETURN


;===========================================================================
; Init
;===========================================================================

Init:
    MOVLB   0x0F

    ; Oscillator @ 4 MHz (IRCF = 101)
    BSF     OSCCON, 6, a            ; IRCF2 = 1
    BCF     OSCCON, 5, a            ; IRCF1 = 0
    BSF     OSCCON, 4, a            ; IRCF0 = 1

    ; PORTA: SSD output
    CLRF    PORTA, a
    CLRF    TRISA, a
    CLRF    ANSELA, b

    ; PORTB: buttons (RB0 = yellow / INT0, RB1 = red / INT1)
    CLRF    PORTB, a
    CLRF    LATB, a
    CLRF    ANSELB, b
    BSF     TRISB, 0, a
    BSF     TRISB, 1, a

    ; PORTC: I2C + UART (digital)
    CLRF    ANSELC, b
    BSF     TRISC, 3                ; SCL input (MSSP drives open-drain)
    BSF     TRISC, 4                ; SDA input
    BCF     TRISC, 6                ; TX output
    BSF     TRISC, 7                ; RX input

    ; I2C Master @ 100 kHz
    MOVLW   0x09
    MOVWF   SSP1ADD
    CLRF    SSP1STAT
    BSF     SSP1STAT, 7             ; SMP=1
    CLRF    SSP1CON3
    MOVLW   00101000B               ; SSPEN=1, master mode
    MOVWF   SSP1CON1
    CLRF    SSP1CON2
    BCF     SSP1IF
    BCF     BCL1IF

    ; UART @ 9600 baud
    MOVLW   0x19
    MOVWF   SPBRG1
    CLRF    SPBRGH1
    MOVLW   00100100B               ; TXEN=1, BRGH=1
    MOVWF   TXSTA1
    MOVLW   10010000B               ; SPEN=1, CREN=1
    MOVWF   RCSTA1

    ; INT0/INT1 (button) edges + enable
    BSF     INTCON2, 6, 0           ; INTEDG0 = 1 (RB0 rising)
    BSF     INTCON2, 5, 0           ; INTEDG1 = 1 (RB1 rising)
    BCF     INTCON, 1, 0            ; INT0IF clear
    BCF     INTCON3, 0, 0           ; INT1IF clear
    BSF     INTCON, 4, 0            ; INT0IE
    BSF     INTCON3, 3, 0           ; INT1IE

    ; UART RX interrupt enable
    BCF     PIR1, 5, a              ; clear RC1IF
    BSF     PIE1, 5, a              ; RC1IE = 1
    BSF     INTCON, 6, a            ; PEIE = 1
    BSF     INTCON, 7, a            ; GIE = 1

    MOVLB   0x00

    CALL    DELAY_1S
    CALL    I2C_BUS_RECOVER

    ; Print power-on greeting (line 0 from EEPROM)
    CALL    EEPROM_PRINT_LINE_0
    CALL    UART_CRLF

    ; Default startup state = ATTACK
    MOVLW   attack_state_val
    MOVWF   must_navigate_to_var, a
    CLRF    current_state_var, a    ; mismatch -> NAV will dispatch on first poll

Main:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     Main


;===========================================================================
; State dispatch
;===========================================================================

STATE_NAV:
    MOVFF   must_navigate_to_var, current_state_var

    MOVF    current_state_var, W, a
    XORLW   main_menu_state_val
    BZ      to_main_menu
    MOVF    current_state_var, W, a
    XORLW   colour_state_val
    BZ      to_colour
    MOVF    current_state_var, W, a
    XORLW   reference_state_val
    BZ      to_reference
    MOVF    current_state_var, W, a
    XORLW   attack_state_val
    BZ      to_attack
    MOVF    current_state_var, W, a
    XORLW   simulate_state_val
    BZ      to_simulate
    MOVF    current_state_var, W, a
    XORLW   hotload_state_val
    BZ      to_hotload
    ; Unknown — default to attack
    GOTO    ATTACK_STATE

to_main_menu:  GOTO MAIN_MENU_STATE
to_colour:     GOTO COLOUR_STATE
to_reference:  GOTO REFERENCE_STATE
to_attack:     GOTO ATTACK_STATE
to_simulate:   GOTO SIMULATE_STATE
to_hotload:    GOTO HOTLOAD_STATE

NAV_STATE_IF_REQUIRED:
    MOVF    must_navigate_to_var, W, a
    CPFSEQ  current_state_var, a
    BRA     NSIR_DISPATCH
    RETURN
NSIR_DISPATCH:
    POP                             ; remove caller's return — we GOTO from here
    GOTO    STATE_NAV


;===========================================================================
; State implementations
;===========================================================================

; MAIN_MENU_STATE: prints greeting+menu, then cycles candidate states (C/R/A)
; on the SSD with flashing. Yellow advances candidate; red locks (via INT1_HANDLER
; setting must_navigate_to_var = display_select_state_var).
; No nested CALLs in the loop — uses BRA-only between candidates to keep stack
; clean when NAV_STATE_IF_REQUIRED pops out.
MAIN_MENU_STATE:
    CALL    EEPROM_PRINT_ALL
    CALL    UART_CRLF
    CLRF    flash_phase_var, a

MM_CANDIDATE_COLOUR:
    MOVLW   colour_state_val
    MOVWF   display_select_state_var, a
    MOVLW   SSD_1
    MOVWF   candidate_ssd_var, a
    BRA     MM_FLASH_INIT

MM_CANDIDATE_REFERENCE:
    MOVLW   reference_state_val
    MOVWF   display_select_state_var, a
    MOVLW   SSD_2
    MOVWF   candidate_ssd_var, a
    BRA     MM_FLASH_INIT

MM_CANDIDATE_ATTACK:
    MOVLW   attack_state_val
    MOVWF   display_select_state_var, a
    MOVLW   SSD_3
    MOVWF   candidate_ssd_var, a
    ; fall through

MM_FLASH_INIT:
    CLRF    yellow_pressed_var, a
MM_FLASH_LOOP:
    BTFSC   yellow_pressed_var, 0, a
    BRA     MM_ADVANCE
    CALL    NAV_STATE_IF_REQUIRED
    ; Flash: alternate SSD on/off each tick
    BTG     flash_phase_var, 0, a
    BTFSS   flash_phase_var, 0, a
    BRA     MM_SSD_OFF
    MOVF    candidate_ssd_var, W, a
    MOVWF   PORTA, a
    BRA     MM_TICK_DELAY
MM_SSD_OFF:
    MOVLW   SSD_0                   ; main-menu mode indicator alternates with candidate
    MOVWF   PORTA, a
MM_TICK_DELAY:
    CALL    DELAY_200MS
    BRA     MM_FLASH_LOOP

MM_ADVANCE:
    MOVF    display_select_state_var, W, a
    XORLW   colour_state_val
    BZ      MM_TO_REF
    MOVF    display_select_state_var, W, a
    XORLW   reference_state_val
    BZ      MM_TO_ATK
    BRA     MM_CANDIDATE_COLOUR     ; was attack -> wrap to colour
MM_TO_REF:
    BRA     MM_CANDIDATE_REFERENCE
MM_TO_ATK:
    BRA     MM_CANDIDATE_ATTACK

COLOUR_STATE:
    MOVLW   SSD_1
    MOVWF   current_state_symbol_var, a
    CALL    SET_SSD
    CALL    PRINT_COLOUR_MSG
COL_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     COL_LOOP

REFERENCE_STATE:
    MOVLW   SSD_2
    MOVWF   current_state_symbol_var, a
    CALL    SET_SSD
    CALL    PRINT_REF_MSG
REF_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     REF_LOOP

ATTACK_STATE:
    MOVLW   SSD_3
    MOVWF   current_state_symbol_var, a
    CALL    SET_SSD
    CALL    PRINT_ATTACK_MSG
ATK_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     ATK_LOOP

SIMULATE_STATE:
    MOVLW   SSD_4
    MOVWF   current_state_symbol_var, a
    CALL    SET_SSD
    CALL    PRINT_SIM_MSG
SIM_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     SIM_LOOP

HOTLOAD_STATE:
    MOVLW   SSD_5
    MOVWF   current_state_symbol_var, a
    CALL    SET_SSD
    CALL    PRINT_HOTLOAD_MSG
    CALL    UART_READ_WRITE         ; overwrite EEPROM with new multi-line content
    CALL    UART_CRLF
    MOVLW   main_menu_state_val
    MOVWF   must_navigate_to_var, a
HL_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     HL_LOOP


;===========================================================================
; Print messages (verbose but simple)
;===========================================================================

PRINT_COLOUR_MSG:
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
    MOVLW   'm'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_REF_MSG:
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'f'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'm'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_ATTACK_MSG:
    MOVLW   'A'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   'k'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'm'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_SIM_MSG:
    MOVLW   'S'
    CALL    UART_TX
    MOVLW   'i'
    CALL    UART_TX
    MOVLW   'm'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'm'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_HOTLOAD_MSG:
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
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'w'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   ','
    CALL    UART_TX
    MOVLW   ' '
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
    MOVLW   '/'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   0x60
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    GOTO    UART_CRLF


;===========================================================================
; UART subroutines
;===========================================================================

UART_TX:
    BTFSS   PIR1, 4, a              ; TX1IF — TXREG empty?
    BRA     UART_TX
    MOVWF   TXREG1, a
    RETURN

UART_CRLF:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX
    RETURN

UART_RX_BLOCKING:                   ; used by HOTLOAD (UART_READ_WRITE)
    BTFSC   RCSTA1, 1, a
    BRA     URXB_OERR
    BTFSS   PIR1, 5, a
    BRA     UART_RX_BLOCKING
    MOVF    RCREG1, W, a
    RETURN
URXB_OERR:
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
    BRA     UART_RX_BLOCKING


;===========================================================================
; EEPROM read variants
;===========================================================================

; Stream EEPROM[0..] to UART until EEPROM_END (backtick) or 0xFF.
EEPROM_PRINT_ALL:
    CALL    I2C_START_COND
    MOVLW   WRITE_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    MOVLW   0x00
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    CALL    I2C_RESTART_COND
    MOVLW   READ_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    CLRF    ADDR, a
EPA_LOOP:
    CALL    I2C_READ_BYTE
    MOVF    TX_BYTE, W, a
    XORLW   EEPROM_END
    BZ      EPA_NACK
    MOVF    TX_BYTE, W, a
    XORLW   0xFF
    BZ      EPA_NACK
    MOVF    TX_BYTE, W, a
    CALL    UART_TX
    INCF    ADDR, F, a
    BZ      EPA_NACK
    CALL    I2C_SEND_ACK
    BRA     EPA_LOOP
EPA_NACK:
    CALL    I2C_SEND_NACK
    CALL    I2C_STOP_COND
    RETURN

; Stream EEPROM[0..] to UART until first LINE_FEED (0x0A) OR end-of-data.
; Used for power-on greeting (just first line).
EEPROM_PRINT_LINE_0:
    CALL    I2C_START_COND
    MOVLW   WRITE_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    MOVLW   0x00
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    CALL    I2C_RESTART_COND
    MOVLW   READ_CTRL
    MOVWF   TX_BYTE, a
    CALL    I2C_WRITE
    CLRF    ADDR, a
EPL0_LOOP:
    CALL    I2C_READ_BYTE
    MOVF    TX_BYTE, W, a
    XORLW   LINE_FEED
    BZ      EPL0_NACK
    MOVF    TX_BYTE, W, a
    XORLW   EEPROM_END
    BZ      EPL0_NACK
    MOVF    TX_BYTE, W, a
    XORLW   0xFF
    BZ      EPL0_NACK
    MOVF    TX_BYTE, W, a
    CALL    UART_TX
    INCF    ADDR, F, a
    BZ      EPL0_NACK
    CALL    I2C_SEND_ACK
    BRA     EPL0_LOOP
EPL0_NACK:
    CALL    I2C_SEND_NACK
    CALL    I2C_STOP_COND
    RETURN


;===========================================================================
; HOTLOAD writer (mirrors eeprom_portd_test.s seeder)
;===========================================================================

UART_READ_WRITE:
    LFSR    0, 0x100
    CLRF    ADDR, a
URW_READ:
    CALL    UART_RX_BLOCKING
    MOVWF   RX_BYTE, a
    MOVF    RX_BYTE, W, a
    XORLW   CARR_RET
    BZ      URW_HANDLE_ENTER
    MOVF    RX_BYTE, W, a
    CALL    UART_TX
    MOVF    RX_BYTE, W, a
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
    BZ      URW_DONE_READING
    MOVF    RX_BYTE, W, a
    XORLW   EEPROM_END
    BNZ     URW_READ
    BRA     URW_DONE_READING
URW_HANDLE_ENTER:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX
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
    CALL    UART_CRLF

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


;===========================================================================
; SSD helper
;===========================================================================

SET_SSD:
    MOVF    current_state_symbol_var, W, a
    MOVWF   PORTA, a
    RETURN


;===========================================================================
; I2C primitives + bus recovery (copied from eeprom_portd_test.s)
;===========================================================================

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

I2C_READ_BYTE:
    BCF     SSP1IF
    BSF     SSP1CON2, 3              ; RCEN
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
    BCF     SSP1CON2, 5              ; ACKDT=0 (ACK)
    BSF     SSP1CON2, 4              ; ACKEN
Wait_ACK:
    BTFSC   SSP1CON2, 4
    BRA     Wait_ACK
    RETURN

I2C_SEND_NACK:
    BSF     SSP1CON2, 5              ; ACKDT=1 (NACK)
    BSF     SSP1CON2, 4
Wait_NACK:
    BTFSC   SSP1CON2, 4
    BRA     Wait_NACK
    RETURN


;===========================================================================
; Delays
;===========================================================================

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
