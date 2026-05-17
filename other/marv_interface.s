    PROCESSOR 18F45K22

CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; MARV Interface Demo — UART + internal EEPROM + SSD
;
; PORT MAPPING
;   UART:
;     TX  -> RC6   RX  -> RC7
;   SSD (common-anode on PORTA, 1 = segment on via inverting driver):
;     a -> RA0   b -> RA1   c -> RA2   d -> RA3
;     e -> RA4   f -> RA5   g -> RA6
;   EEPROM: internal data EEPROM — no external wiring required
;     (accessed via EEADR / EEDATA / EECON1 / EECON2 SFRs)

; ---- CYOC command: 'M' + Enter returns to main menu ----

; ---- Internal EEPROM layout (256 bytes) ----
; 0x00       : sentinel byte (0xA5 = initialised)
; 0x01-0x28  : user greeting, null-terminated, max 39 chars
; 0x29-0xA0  : menu options block, null-terminated, max 120 chars
EE_SENTINEL_ADDR    EQU 0x00
EE_GREETING_ADDR    EQU 0x01
EE_MENU_ADDR        EQU 0x29
EE_SENTINEL_VAL     EQU 0xA5
EE_GREETING_MAX     EQU 0x28    ; last valid address for greeting (incl.)

; ---- State constants ----
STATE_MAIN   EQU 0x00   ; SSD "0"
STATE_COL    EQU 0x01   ; SSD "1"
STATE_REF    EQU 0x02   ; SSD "2"
STATE_ATK    EQU 0x03   ; SSD "3"  (power-on default)
STATE_SIM    EQU 0x04   ; SSD "4"
STATE_HOT    EQU 0x05   ; SSD "5"

; ---- SSD patterns (1 = segment on, adjust if display wiring differs) ----
SSD_0    EQU 0x3F    ; abcdef
SSD_1    EQU 0x06    ; bc
SSD_2    EQU 0x5B    ; abdeg
SSD_3    EQU 0x4F    ; abcdg
SSD_4    EQU 0x66    ; bcfg
SSD_5    EQU 0x6D    ; acdfg

; ---- SSD race-colour letters (while racing) ----
r_SSD    EQU 0b00110001    ; Red   (matches marv.s)
G_SSD    EQU 0b01111101    ; Green
b_SSD    EQU 0b01111100    ; Blue  (lowercase b)
k_SSD    EQU 0b01110110    ; blacK (H-like approximation)

; ---- RAM variables (bank 0 access, 0x00-0x5F) ----
delay1          EQU 0x00
delay2          EQU 0x01
uart_rx_var     EQU 0x02    ; last received UART byte
state_var       EQU 0x03    ; current operating state
temp_var        EQU 0x04    ; general scratch
ee_addr_var     EQU 0x05    ; EEPROM address for current operation
ssd_out_var     EQU 0x06    ; SSD segment pattern
race_col_var    EQU 0x07    ; 'R' 'G' 'B' or 'k' (ASCII race colour)

; ---- Macro: load TBLPTR with 24-bit program-memory address ----
LOAD_TBLPTR MACRO addr
    MOVLW   LOW(addr)
    MOVWF   TBLPTRL, a
    MOVLW   HIGH(addr)
    MOVWF   TBLPTRH, a
    CLRF    TBLPTRU, a
    ENDM

; ============================================================
    PSECT code, abs
    org 0x00
    GOTO    Init

    org 0x08
    RETFIE  1               ; no interrupts used in standalone

; ============================================================
Init:
    BSF     OSCCON, 6, a    ; 4 MHz internal oscillator
    BCF     OSCCON, 5, a
    BSF     OSCCON, 4, a

    ; PORTA — all outputs (SSD)
    MOVLB   0xF
    CLRF    ANSELA, b
    MOVLB   0x0
    CLRF    TRISA, a
    CLRF    PORTA, a

    ; PORTB — disable analog
    MOVLB   0xF
    CLRF    ANSELB, b
    MOVLB   0x0

    ; PORTC — RC7 = RX input; EUSART controls RC6 (TX)
    MOVLB   0xF
    CLRF    ANSELC, b
    MOVLB   0x0
    BSF     TRISC, 7, a

    ; PORTE — not used
    MOVLB   0xF
    CLRF    ANSELE, b
    MOVLB   0x0

    ; EUSART1 @ 9600 baud, 8N1  (SPBRG=25, BRGH=1 → 9615 baud, 0.16% error)
    MOVLW   0x24            ; TXEN=1, BRGH=1, SYNC=0
    MOVWF   TXSTA, a
    MOVLW   0x90            ; SPEN=1, CREN=1
    MOVWF   RCSTA, a
    CLRF    BAUDCON, a      ; BRG16=0
    MOVLW   25
    MOVWF   SPBRG, a

    ; First-run EEPROM init
    MOVLW   EE_SENTINEL_ADDR
    CALL    EE_READ
    XORLW   EE_SENTINEL_VAL
    BZ      _INIT_EE_SKIP
    CALL    EE_WRITE_DEFAULTS
_INIT_EE_SKIP:

    ; Default state = ATTACK; show greeting; update SSD
    MOVLW   'R'
    MOVWF   race_col_var, a         ; default race colour = Red
    CALL    UART_TX_CRLF
    MOVLW   EE_GREETING_ADDR
    CALL    UART_TX_EE_STR
    CALL    UART_TX_CRLF
    CALL    ENTER_ATTACK_MODE

; ============================================================
Main_Loop:
    CALL    UART_RX
    MOVWF   uart_rx_var, a

    ; 'M' — CYOC: back to main menu (works from any state)
    MOVLW   'M'
    CPFSEQ  uart_rx_var, a
    BRA     _ML_NOT_M
    CALL    ENTER_MAIN_MODE
    BRA     Main_Loop
_ML_NOT_M:

    ; Commands only active from MAIN menu
    MOVLW   STATE_MAIN
    CPFSEQ  state_var, a
    BRA     _ML_SUBMENU

    MOVLW   'C'
    CPFSEQ  uart_rx_var, a
    BRA     _ML_TRY_R
    CALL    ENTER_COL_MODE
    BRA     Main_Loop
_ML_TRY_R:
    MOVLW   'R'
    CPFSEQ  uart_rx_var, a
    BRA     _ML_TRY_A
    CALL    ENTER_REF_MODE
    BRA     Main_Loop
_ML_TRY_A:
    MOVLW   'A'
    CPFSEQ  uart_rx_var, a
    BRA     _ML_TRY_S
    CALL    ENTER_ATTACK_MODE
    BRA     Main_Loop
_ML_TRY_S:
    MOVLW   'S'
    CPFSEQ  uart_rx_var, a
    BRA     _ML_TRY_H
    CALL    ENTER_SIM_MODE
    BRA     Main_Loop
_ML_TRY_H:
    MOVLW   'H'
    CPFSEQ  uart_rx_var, a
    BRA     Main_Loop               ; unknown command, ignore
    CALL    ENTER_HOT_MODE
    BRA     Main_Loop

_ML_SUBMENU:
    ; Sub-commands inside non-menu states
    MOVLW   STATE_COL
    CPFSEQ  state_var, a
    BRA     _ML_TRY_SIM
    CALL    HANDLE_COLOUR_CMD
    BRA     Main_Loop
_ML_TRY_SIM:
    MOVLW   STATE_SIM
    CPFSEQ  state_var, a
    BRA     Main_Loop
    CALL    HANDLE_SIM_CMD
    BRA     Main_Loop

; ============================================================
; ---- State entry routines ----

ENTER_MAIN_MODE:
    MOVLW   STATE_MAIN
    MOVWF   state_var, a
    MOVLW   SSD_0
    CALL    SET_SSD
    CALL    UART_TX_CRLF
    MOVLW   EE_GREETING_ADDR
    CALL    UART_TX_EE_STR
    CALL    UART_TX_CRLF
    MOVLW   EE_MENU_ADDR
    CALL    UART_TX_EE_STR
    RETURN

ENTER_ATTACK_MODE:
    MOVLW   STATE_ATK
    MOVWF   state_var, a
    MOVLW   SSD_3
    CALL    SET_SSD
    LOAD_TBLPTR UART_STR_ATK
    CALL    UART_TX_ROM_STR
    MOVF    race_col_var, W, a
    CALL    UART_TX               ; print race colour letter
    CALL    UART_TX_CRLF
    RETURN

ENTER_COL_MODE:
    MOVLW   STATE_COL
    MOVWF   state_var, a
    MOVLW   SSD_1
    CALL    SET_SSD
    LOAD_TBLPTR UART_STR_COL
    CALL    UART_TX_ROM_STR
    RETURN

ENTER_REF_MODE:
    MOVLW   STATE_REF
    MOVWF   state_var, a
    MOVLW   SSD_2
    CALL    SET_SSD
    LOAD_TBLPTR UART_STR_REF
    CALL    UART_TX_ROM_STR
    RETURN

ENTER_SIM_MODE:
    MOVLW   STATE_SIM
    MOVWF   state_var, a
    MOVLW   SSD_4
    CALL    SET_SSD
    LOAD_TBLPTR UART_STR_SIM
    CALL    UART_TX_ROM_STR
    RETURN

ENTER_HOT_MODE:
    MOVLW   STATE_HOT
    MOVWF   state_var, a
    MOVLW   SSD_5
    CALL    SET_SSD
    CALL    DO_HOTLOAD
    ; Return to main menu automatically after hotload
    CALL    ENTER_MAIN_MODE
    RETURN

; ============================================================
; HANDLE_COLOUR_CMD — process R/G/B/k in colour selection state
HANDLE_COLOUR_CMD:
    MOVLW   'R'
    CPFSEQ  uart_rx_var, a
    BRA     _HCC_TRY_G
    MOVLW   'R'
    MOVWF   race_col_var, a
    BRA     _HCC_ACK
_HCC_TRY_G:
    MOVLW   'G'
    CPFSEQ  uart_rx_var, a
    BRA     _HCC_TRY_B
    MOVLW   'G'
    MOVWF   race_col_var, a
    BRA     _HCC_ACK
_HCC_TRY_B:
    MOVLW   'B'
    CPFSEQ  uart_rx_var, a
    BRA     _HCC_TRY_K
    MOVLW   'B'
    MOVWF   race_col_var, a
    BRA     _HCC_ACK
_HCC_TRY_K:
    MOVLW   'k'
    CPFSEQ  uart_rx_var, a
    RETURN                          ; unknown — ignore
    MOVLW   'k'
    MOVWF   race_col_var, a
_HCC_ACK:
    LOAD_TBLPTR UART_STR_COL_ACK
    CALL    UART_TX_ROM_STR
    MOVF    race_col_var, W, a
    CALL    UART_TX
    CALL    UART_TX_CRLF
    RETURN

; ============================================================
; HANDLE_SIM_CMD — S/F/L/R sub-commands in simulate state
HANDLE_SIM_CMD:
    MOVLW   'S'
    CPFSEQ  uart_rx_var, a
    BRA     _HSC_TRY_F
    LOAD_TBLPTR UART_STR_SIM_S
    CALL    UART_TX_ROM_STR
    RETURN
_HSC_TRY_F:
    MOVLW   'F'
    CPFSEQ  uart_rx_var, a
    BRA     _HSC_TRY_L
    LOAD_TBLPTR UART_STR_SIM_F
    CALL    UART_TX_ROM_STR
    RETURN
_HSC_TRY_L:
    MOVLW   'L'
    CPFSEQ  uart_rx_var, a
    BRA     _HSC_TRY_R
    LOAD_TBLPTR UART_STR_SIM_L
    CALL    UART_TX_ROM_STR
    RETURN
_HSC_TRY_R:
    MOVLW   'R'
    CPFSEQ  uart_rx_var, a
    RETURN
    LOAD_TBLPTR UART_STR_SIM_R
    CALL    UART_TX_ROM_STR
    RETURN

; ============================================================
; DO_HOTLOAD — read new slogan from UART, write to EEPROM 0x01
DO_HOTLOAD:
    LOAD_TBLPTR UART_STR_HOT_PROMPT
    CALL    UART_TX_ROM_STR
    MOVLW   EE_GREETING_ADDR
    MOVWF   ee_addr_var, a
_DHL_LOOP:
    CALL    UART_RX
    XORLW   0x0D                    ; CR?
    BZ      _DHL_DONE
    XORLW   0x0D                    ; restore char in W
    ; check max length before writing
    MOVF    ee_addr_var, W, a
    SUBLW   EE_GREETING_MAX
    BZ      _DHL_DONE               ; at max address — stop silently
    MOVF    uart_rx_var, W, a       ; reload char (UART_RX put it there)
    CALL    UART_TX                 ; echo
    CALL    EE_WRITE                ; W = char, ee_addr_var = dest address
    INCF    ee_addr_var, f, a
    BRA     _DHL_LOOP
_DHL_DONE:
    MOVLW   0x00                    ; write null terminator
    CALL    EE_WRITE
    CALL    UART_TX_CRLF
    LOAD_TBLPTR UART_STR_HOT_DONE
    CALL    UART_TX_ROM_STR
    RETURN

; ============================================================
; UART routines
; ============================================================

; UART_TX: transmit byte in W
UART_TX:
    BTFSS   PIR1, 4, a              ; TX1IF — TXREG empty?
    BRA     UART_TX
    MOVWF   TXREG, a
    RETURN

; UART_RX: receive byte into W (blocking)
UART_RX:
    BTFSS   PIR1, 5, a              ; RC1IF — byte received?
    BRA     UART_RX
    MOVF    RCREG, W, a
    MOVWF   uart_rx_var, a
    RETURN

; UART_TX_CRLF: transmit CR LF
UART_TX_CRLF:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX
    RETURN

; UART_TX_ROM_STR: print null-terminated string from TBLPTR
UART_TX_ROM_STR:
    TBLRD*+
    MOVF    TABLAT, W, a
    BZ      _UTRS_DONE
    CALL    UART_TX
    BRA     UART_TX_ROM_STR
_UTRS_DONE:
    RETURN

; UART_TX_EE_STR: print null-terminated string from EEPROM (W = start addr)
UART_TX_EE_STR:
    MOVWF   ee_addr_var, a
_UTES_LOOP:
    MOVF    ee_addr_var, W, a
    CALL    EE_READ
    BZ      _UTES_DONE
    CALL    UART_TX
    INCF    ee_addr_var, f, a
    BRA     _UTES_LOOP
_UTES_DONE:
    RETURN

; ============================================================
; EEPROM routines
; ============================================================

; EE_READ: W = address -> W = data byte
EE_READ:
    MOVWF   EEADR, a
    BCF     EECON1, 7, a            ; EEPGD = 0 (data EEPROM)
    BCF     EECON1, 6, a            ; CFGS = 0
    BSF     EECON1, 0, a            ; RD = 1 (initiate read)
    MOVF    EEDATA, W, a
    RETURN

; EE_WRITE: W = data, ee_addr_var = destination address
EE_WRITE:
    MOVWF   EEDATA, a
    MOVF    ee_addr_var, W, a
    MOVWF   EEADR, a
    BCF     EECON1, 7, a            ; EEPGD = 0
    BCF     EECON1, 6, a            ; CFGS = 0
    BSF     EECON1, 2, a            ; WREN = 1
    BCF     INTCON, 7, a            ; GIE = 0 (required during unlock)
    MOVLW   0x55
    MOVWF   EECON2, a
    MOVLW   0xAA
    MOVWF   EECON2, a
    BSF     EECON1, 1, a            ; WR = 1 (start write)
    BSF     INTCON, 7, a            ; GIE = 1
_EEW_WAIT:
    BTFSC   EECON1, 1, a            ; wait for WR = 0 (write complete)
    BRA     _EEW_WAIT
    BCF     EECON1, 2, a            ; WREN = 0
    RETURN

; EE_WRITE_ROM_STR: write null-terminated string from TBLPTR to EEPROM
;   starting at ee_addr_var (null terminator is also written, addr advances)
EE_WRITE_ROM_STR:
    TBLRD*+
    MOVF    TABLAT, W, a
    MOVWF   temp_var, a             ; save byte
    CALL    EE_WRITE                ; write (including final null)
    INCF    ee_addr_var, f, a
    TSTFSZ  temp_var, a             ; was null? if so, done
    BRA     EE_WRITE_ROM_STR
    RETURN

; EE_WRITE_DEFAULTS: write sentinel + default strings on first boot
EE_WRITE_DEFAULTS:
    MOVLW   EE_SENTINEL_ADDR
    MOVWF   ee_addr_var, a
    MOVLW   EE_SENTINEL_VAL
    CALL    EE_WRITE

    MOVLW   EE_GREETING_ADDR
    MOVWF   ee_addr_var, a
    LOAD_TBLPTR DEFAULT_GREETING
    CALL    EE_WRITE_ROM_STR

    MOVLW   EE_MENU_ADDR
    MOVWF   ee_addr_var, a
    LOAD_TBLPTR DEFAULT_MENU
    CALL    EE_WRITE_ROM_STR
    RETURN

; ============================================================
; SSD routine
; ============================================================

; SET_SSD: write pattern in W to PORTA (SSD)
SET_SSD:
    MOVWF   ssd_out_var, a
    MOVFF   ssd_out_var, PORTA
    RETURN

; ============================================================
; String data in program memory
; ============================================================
    org 0x0800

; Default EEPROM greeting (written on first boot)
DEFAULT_GREETING:
    db  "Will I dream of electric sheep?", 0

; Default EEPROM menu text (written on first boot)
DEFAULT_MENU:
    db  "Choose your MARV mode...\r\n"
    db  "(C)colour\r\n"
    db  "(R)eference\r\n"
    db  "(A)ttack\r\n"
    db  "(S)imulate race\r\n"
    db  "(H)otload EEPROM\r\n", 0

UART_STR_ATK:
    db  "Attack ", 0               ; caller appends race colour letter + CRLF

UART_STR_COL:
    db  "\r\nColour mode. Enter R/G/B/k: ", 0

UART_STR_COL_ACK:
    db  "Race colour set to: ", 0

UART_STR_REF:
    db  "\r\nReference mode — calibration active\r\n", 0

UART_STR_SIM:
    db  "\r\nSimulate mode. S=sensor F=fwd L=left R=right\r\n", 0

UART_STR_SIM_S:
    db  "Sensor: [stub — integrate COLOUR_READ here]\r\n", 0

UART_STR_SIM_F:
    db  "Forward\r\n", 0

UART_STR_SIM_L:
    db  "Left\r\n", 0

UART_STR_SIM_R:
    db  "Right\r\n", 0

UART_STR_HOT_PROMPT:
    db  "\r\nEnter new slogan then press Enter:\r\n", 0

UART_STR_HOT_DONE:
    db  "Slogan saved to EEPROM.\r\n", 0

    end
