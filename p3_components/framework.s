; framework.s
; Prac 3 integrated skeleton. Sections are indexed and currently stubbed —
; bodies get filled in at integration time, once each component in
; p3_components/ works in isolation.
;
; To jump to a section: search for "SECTION NN".
; Companion doc: marv_index.md (line-range map of marv.s for copy-paste).
;
; Component files (each works standalone before being pasted in):
;   - colour_select.s    -> SECTION 10b
;   - menu_state.s       -> SECTION 10a + ISR additions in SECTION 06
;   - eeprom_portd_test.s (proven) -> SECTIONS 11, 12 wholesale
;   - simulate_state.s   -> SECTION 10e (optional)
;
; This skeleton compiles as-is (empty stubs). Build to verify before adding code.

;===========================================================================
; SECTION 01: PROCESSOR / CONFIG / INCLUDES
;===========================================================================

    PROCESSOR 18F45K22

    CONFIG  FOSC   = INTIO67
    CONFIG  WDTEN  = OFF
    CONFIG  MCLRE  = EXTMCLR
    CONFIG  LVP    = ON

    #include <xc.inc>
    #include "pic18f45k22.inc"


;===========================================================================
; SECTION 02: PORT MAPPING CONSTANTS
; SOURCE: marv.s lines 16-23 (SSD_PORT etc.)
; ADD: RC3=SCL, RC4=SDA, RC6=TX, RC7=RX (I2C + UART)
;===========================================================================
;<editor-fold defaultstate="collapsed" desc="SECTION 02: PORT MAP">

; PASTE here: marv.s lines 16-23
; ANNOTATE: PORTC bits — RC3 SCL, RC4 SDA, RC6 TX, RC7 RX

;</editor-fold>


;===========================================================================
; SECTION 03: VARIABLE EQUs — access bank (0x00-0x5F)
; SOURCE: marv.s lines 32-135 (state, sensor, cal, motor, touch vars)
; ADD (prac 3 specific):
;   uart_rx_char_var  EQU 0x??   ; ISR scratch for received byte
;   eeprom_addr_var   EQU 0x??   ; running EEPROM address
;   eeprom_count_var  EQU 0x??   ; byte count for read/write loops
;   tx_byte_var       EQU 0x??   ; I2C TX scratch (was TX_BYTE in eeprom_portd_test)
; BUFFER: 0x100-0x1FF reserved for EEPROM string buffer (bank 1, FSR0 access)
;===========================================================================
;<editor-fold defaultstate="collapsed" desc="SECTION 03: VARS (access bank)">

; PASTE here: marv.s lines 32-135
; APPEND: prac 3 vars listed above

;</editor-fold>


;===========================================================================
; SECTION 04: STATE / COLOUR / SSD CONSTANT EQUs
; SOURCE: marv.s lines 200-302 (existing state_val, colour_val, SSD chars)
; ADD (prac 3 menu states):
;   main_menu_state_val   EQU 0x10   ; SSD "0"
;   colour_state_val      EQU 0x11   ; SSD "1"  (NEW menu-driven)
;   reference_state_val   EQU 0x12   ; SSD "2"  (wraps CAL_STATE)
;   attack_state_val      EQU 0x13   ; SSD "3"  (wraps LLI_STATE)
;   simulate_state_val    EQU 0x14   ; SSD "4"
;   hotload_state_val     EQU 0x15   ; SSD "5"
; (Pick values that don't collide with marv.s existing state vals.)
;===========================================================================
;<editor-fold defaultstate="collapsed" desc="SECTION 04: STATE/COLOUR/SSD CONSTS">

; PASTE here: marv.s lines 200-302
; APPEND: prac 3 menu state vals + EEPROM control byte EQUs

WRITE_CTRL  EQU 10100000B
READ_CTRL   EQU 10100001B
TERMINATOR  EQU 0x0D

;</editor-fold>


;===========================================================================
; SECTION 05: RESET VECTOR + ISR ENTRY
; PATTERN: marv.s lines 303-326
;===========================================================================

    PSECT code,abs
    org 00h
    GOTO Init

    ORG 0x08
    GOTO ISR


;===========================================================================
; SECTION 06: ISR HANDLERS
; SOURCE: marv.s lines 311-402 (ISR dispatch, INT0_HANDLER, INT1_HANDLER)
; ADD: UART RX handler — checks RC1IF, reads RCREG1, dispatches by char,
;      sets must_navigate_to_var per match (see menu_state.s)
;===========================================================================

ISR:
;<editor-fold defaultstate="collapsed" desc="SECTION 06: ISR">
    ; PASTE: marv.s ISR dispatch (lines 311-326), add RC1IF check + UART_RX_HANDLER call
    RETFIE 1
;</editor-fold>

CLEAR_ISR:
    ; PASTE: marv.s lines 328-331
    RETURN

INT0_HANDLER:
    ; PASTE: marv.s lines 333-365 (yellow button)
    RETURN

INT1_HANDLER:
    ; PASTE: marv.s lines 366-402 (red button — navigation trigger)
    RETURN

UART_RX_HANDLER:
    ; NEW — from menu_state.s
    ; Read RCREG1, save to uart_rx_char_var, XORLW-BZ chain for M/C/R/A/S/H,
    ; set must_navigate_to_var on match. See menu_state.s for full logic.
    RETURN


;===========================================================================
; SECTION 07: INIT / SETUP
; SOURCE: marv.s lines 406-624 (oscillator, ports, ADC, PWM, INT0/1, cal defaults)
; ADD:
;   - UART init (SPBRG1, TXSTA1, RCSTA1)
;   - I2C init (SSP1ADD, SSP1STAT, SSP1CON1, SSP1CON3) — from eeprom_portd_test.s
;   - RC1IE enable (PIE1 bit 5) for UART RX interrupt
;   - PEIE enable (INTCON bit 6) so peripheral interrupts route to ISR
;===========================================================================

Init:
;<editor-fold defaultstate="collapsed" desc="SECTION 07: INIT">
    ; PASTE: marv.s lines 406-624
    ; APPEND: UART init, I2C init, RC1IE, PEIE
    GOTO Main
;</editor-fold>


;===========================================================================
; SECTION 08: MAIN ENTRY + STATE_SELECT_LOOP
; SOURCE: marv.s lines 631-731 (Main, STATE_SELECT_LOOP, STATE_SELECT_INPUT)
; MODIFY: STATE_SELECT_LOOP cycles thru the prac 3 menu states (M/C/R/A/S/H)
;         instead of marv.s's cal/feedback/LLI/osc cycle. Or: drop the
;         button-cycle entirely and have main loop just sit waiting for
;         must_navigate_to_var from the UART ISR.
;===========================================================================

Main:
    GOTO STATE_SELECT_LOOP

STATE_SELECT_LOOP:
;<editor-fold defaultstate="collapsed" desc="SECTION 08: STATE SELECT LOOP">
    ; PASTE: marv.s lines 641-679, modified for prac 3 menu states
    GOTO STATE_SELECT_LOOP
;</editor-fold>

STATE_SELECT_INPUT:
    ; PASTE: marv.s lines 682-731 (if keeping button cycling)
    RETURN


;===========================================================================
; SECTION 09: STATE DISPATCH (STATE_NAV + NAV_STATE_IF_REQUIRED)
; SOURCE: marv.s lines 749-803
; MODIFY: STATE_NAV XORLW-BZ chain to dispatch the prac 3 menu states
;===========================================================================

STATE_NAV:
;<editor-fold defaultstate="collapsed" desc="SECTION 09: STATE_NAV">
    ; PASTE: marv.s lines 749-783, add branches:
    ;   to_main_menu  -> MAIN_MENU_STATE
    ;   to_colour     -> COLOUR_STATE
    ;   to_reference  -> REFERENCE_STATE
    ;   to_attack     -> ATTACK_STATE
    ;   to_simulate   -> SIMULATE_STATE
    ;   to_hotload    -> HOTLOAD_STATE
    RETURN
;</editor-fold>

NAV_STATE_IF_REQUIRED:
    ; PASTE: marv.s lines 787-803 (unchanged)
    RETURN


;===========================================================================
; SECTION 10: STATE IMPLEMENTATIONS
;===========================================================================

; ---- 10a: MAIN_MENU_STATE -----------------------------------------------
; NEW. Outputs greeting (EEPROM line 0) + menu (EEPROM lines 1-5). SSD="0".
; Source: menu_state.s
MAIN_MENU_STATE:
    ; CALL EEPROM_PRINT_LINE (line 0 = greeting)
    ; CALL EEPROM_PRINT_LINES (1..5 = menu)
    ; SSD = '0'
    ; Loop polling NAV_STATE_IF_REQUIRED
    RETURN

; ---- 10b: COLOUR_STATE --------------------------------------------------
; NEW menu-driven (NOT marv.s's sensor-based FEEDBACK_COLOUR_STATE). SSD="1".
; UART chars R/G/B/k OR button cycle yellow+red set RACE_COL_var.
; Source: colour_select.s
COLOUR_STATE:
    RETURN

; ---- 10c: REFERENCE_STATE -----------------------------------------------
; Wraps marv.s CAL_STATE (line 808). SSD="2".
REFERENCE_STATE:
    ; PASTE: marv.s lines 808-955 (or just CALL CAL_STATE if labels preserved)
    RETURN

; ---- 10d: ATTACK_STATE --------------------------------------------------
; Wraps marv.s LLI_STATE (line 1052). SSD="3" idle / colour char while racing.
ATTACK_STATE:
    ; PASTE: marv.s lines 1052-1222
    RETURN

; ---- 10e: SIMULATE_STATE — OPTIONAL -------------------------------------
; Submenu S/F/L/R per P3.2.2.2. SSD="4". Source: simulate_state.s
SIMULATE_STATE:
    RETURN

; ---- 10f: HOTLOAD_STATE -------------------------------------------------
; Reuse eeprom_portd_test.s's UART_READ_WRITE: prompt, read user input,
; write to EEPROM (slogan address). SSD="5". After write, return to main menu.
HOTLOAD_STATE:
    ; PASTE: from eeprom_portd_test.s — UART_READ_WRITE + return to main menu
    RETURN


;===========================================================================
; SECTION 11: UART SUBROUTINES
; SOURCE: eeprom_portd_test.s — UART_TX (TXIF-based), UART_RX_BLOCKING (if
;         kept for HOTLOAD), UART_CRLF, PRINT_PROMPT
; ADD: PRINT_GREETING, PRINT_MENU (read from EEPROM and stream to UART)
;===========================================================================

UART_TX:
    ; PASTE: eeprom_portd_test.s UART_TX (uses PIR1.4 TXIF — proven good)
    RETURN

UART_RX_BLOCKING:
    ; PASTE: eeprom_portd_test.s UART_RX (only used by HOTLOAD; main UART
    ; input path is via the ISR in SECTION 06)
    RETURN

UART_CRLF:
    ; PASTE: eeprom_portd_test.s UART_CRLF
    RETURN


;===========================================================================
; SECTION 12: I2C / EEPROM SUBROUTINES
; SOURCE: eeprom_portd_test.s — wholesale paste, proven good:
;   I2C_BUS_RECOVER, I2C_START_COND, I2C_RESTART_COND, I2C_STOP_COND,
;   I2C_WRITE, I2C_READ_BYTE, I2C_SEND_ACK, I2C_SEND_NACK,
;   EEPROM_READ_OUT, UART_READ_WRITE
;===========================================================================

;<editor-fold defaultstate="collapsed" desc="SECTION 12: I2C/EEPROM">

; PASTE: eeprom_portd_test.s — all I2C primitives + EEPROM read/write loops

;</editor-fold>


;===========================================================================
; SECTION 13: SSD / DISPLAY HELPERS
; SOURCE: marv.s lines 2062-2110 (FLASH_SSD, SET_SSD, BLINK_*, FLASH_RGB_*)
;===========================================================================

SET_SSD:
    ; PASTE: marv.s SET_SSD
    RETURN


;===========================================================================
; SECTION 14: DELAYS + BIT-BANG HELPERS
; SOURCE: eeprom_portd_test.s (DELAY_5US, DELAY_10MS, DELAY_1S) and/or marv.s
; equivalents. Pick whichever variable naming aligns with rest of file.
;===========================================================================

DELAY_5US:
    RETURN
DELAY_10MS:
    RETURN
DELAY_1S:
    RETURN


    end
