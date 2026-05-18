; menu_state.s — prac 3 cycling menu + UART + Hotload + Simulate sensor read
;
; States:
;   1 (digit) COLOUR    — placeholder ("Colour mode")
;   2 (digit) REFERENCE — placeholder ("Reference mode")    [becomes CAL_STATE in framework.s]
;   3 (digit) ATTACK    — placeholder ("Attack mode")       [becomes LLI_STATE  in framework.s]
;   4 (digit) SIMULATE  — strobe RGB LEDs, read sensors, classify, print L/C/R colours
;   5 (digit) HOTLOAD   — re-write slogan to EEPROM via UART; auto-append backtick on Enter
;
; Boot: read slogan from EEPROM, print it + hardcoded menu options, enter cycling menu.
;
; Cycling menu (selecting state):
;   yellow (RB0/INT0) — advance candidate
;   red    (RB1/INT1) — lock current candidate, navigate to it
;
; Anywhere:
;   UART 'M'/'C'/'R'/'A'/'S'/'H' — direct nav, bypasses cycle
;   red button (INT1)            — back to selecting (fallback)
;   In SIMULATE, another 'S'     — re-run sensor read
;
; Pin assignments:
;   PORTA<6:0> = SSD (a-g); bit 7 = DP
;   RB0 = yellow button (INT0), RB1 = red (INT1)
;   PORTD<0:2> = strobe LEDs (R/G/B)
;   PORTE<0:2> = RGB sensors (analog inputs AN5/6/7)
;   RC3 = SCL, RC4 = SDA (I2C/MSSP1, 24LC16B EEPROM)
;   RC6 = TX, RC7 = RX (EUSART1, 9600 8N1)

    PROCESSOR 18F45K22

    CONFIG  FOSC   = INTIO67
    CONFIG  WDTEN  = OFF
    CONFIG  MCLRE  = EXTMCLR
    CONFIG  LVP    = ON

    #include <xc.inc>
    #include "pic18f45k22.inc"

; ---- Port aliases (matches marv.s) ----
STROBE_LED_PORT                EQU PORTD
SSD_PORT                       EQU PORTA

; ---- Variables (access bank 0x00-0x5F) ----
TX_BYTE                        EQU 0x00
Delay1                         EQU 0x01
Delay2                         EQU 0x02
Delay3                         EQU 0x03
ADDR                           EQU 0x04
RX_BYTE                        EQU 0x05
uart_rx_char_var               EQU 0x06
must_navigate_to_var           EQU 0x07
current_state_var              EQU 0x08
current_state_symbol_var       EQU 0x09
SSD_OUT_var                    EQU 0x0A
display_select_state_var       EQU 0x0B
next_displayed_state_click_var EQU 0x0C
temp_var2                      EQU 0x0D
temp_var                       EQU 0x0E
CUR_ADDR                       EQU 0x0F
simulate_rerun_flag_var        EQU 0x10

; sensor live ADC readings
sensor_L_reading_var           EQU 0x11
sensor_C_reading_var           EQU 0x12
sensor_R_reading_var           EQU 0x13

; per-sensor reading under each strobe colour
sensor_L_strobe_R_reading_var  EQU 0x14
sensor_L_strobe_G_reading_var  EQU 0x15
sensor_L_strobe_B_reading_var  EQU 0x16
sensor_C_strobe_R_reading_var  EQU 0x17
sensor_C_strobe_G_reading_var  EQU 0x18
sensor_C_strobe_B_reading_var  EQU 0x19
sensor_R_strobe_R_reading_var  EQU 0x1A
sensor_R_strobe_G_reading_var  EQU 0x1B
sensor_R_strobe_B_reading_var  EQU 0x1C

; working copies used while classifying one sensor
current_strobe_reading_red_var   EQU 0x1D
current_strobe_reading_green_var EQU 0x1E
current_strobe_reading_blue_var  EQU 0x1F

; per-sensor classified colour (enum: 1=R 2=G 3=B 4=K 5=W)
sensor_L_read_colour_enum_var  EQU 0x20
sensor_C_read_colour_enum_var  EQU 0x21
sensor_R_read_colour_enum_var  EQU 0x22

; floor delta sums (one per candidate surface)
red_floor_sum_delta_var        EQU 0x23
green_floor_sum_delta_var      EQU 0x24
blue_floor_sum_delta_var       EQU 0x25
white_floor_sum_delta_var      EQU 0x26
black_floor_sum_delta_var      EQU 0x27

lowest_diff_enum_colour_var    EQU 0x28
lowest_diff_score_var          EQU 0x29

; per-sensor cal data is copied here while classifying (15 cells = 3 strobes × 5 surfaces)
current_sensor_cal_red_on_red_var       EQU 0x2A
current_sensor_cal_red_on_green_var     EQU 0x2B
current_sensor_cal_red_on_blue_var      EQU 0x2C
current_sensor_cal_red_on_white_var     EQU 0x2D
current_sensor_cal_red_on_black_var     EQU 0x2E
current_sensor_cal_green_on_red_var     EQU 0x2F
current_sensor_cal_green_on_green_var   EQU 0x30
current_sensor_cal_green_on_blue_var    EQU 0x31
current_sensor_cal_green_on_white_var   EQU 0x32
current_sensor_cal_green_on_black_var   EQU 0x33
current_sensor_cal_blue_on_red_var      EQU 0x34
current_sensor_cal_blue_on_green_var    EQU 0x35
current_sensor_cal_blue_on_blue_var     EQU 0x36
current_sensor_cal_blue_on_white_var    EQU 0x37
current_sensor_cal_blue_on_black_var    EQU 0x38

; ---- Banked-only calibration storage (matches marv.s 0x60-0x8C) ----
; LEFT sensor
CAL_L_RED_ON_WHITE_var                  EQU 0x60
CAL_L_GREEN_ON_WHITE_var                EQU 0x61
CAL_L_BLUE_ON_WHITE_var                 EQU 0x62
CAL_L_RED_ON_RED_var                    EQU 0x63
CAL_L_GREEN_ON_RED_var                  EQU 0x64
CAL_L_BLUE_ON_RED_var                   EQU 0x65
CAL_L_RED_ON_GREEN_var                  EQU 0x66
CAL_L_GREEN_ON_GREEN_var                EQU 0x67
CAL_L_BLUE_ON_GREEN_var                 EQU 0x68
CAL_L_RED_ON_BLUE_var                   EQU 0x69
CAL_L_GREEN_ON_BLUE_var                 EQU 0x6A
CAL_L_BLUE_ON_BLUE_var                  EQU 0x6B
CAL_L_RED_ON_BLACK_var                  EQU 0x6C
CAL_L_GREEN_ON_BLACK_var                EQU 0x6D
CAL_L_BLUE_ON_BLACK_var                 EQU 0x6E
; CENTRE sensor
CAL_C_RED_ON_WHITE_var                  EQU 0x6F
CAL_C_GREEN_ON_WHITE_var                EQU 0x70
CAL_C_BLUE_ON_WHITE_var                 EQU 0x71
CAL_C_RED_ON_RED_var                    EQU 0x72
CAL_C_GREEN_ON_RED_var                  EQU 0x73
CAL_C_BLUE_ON_RED_var                   EQU 0x74
CAL_C_RED_ON_GREEN_var                  EQU 0x75
CAL_C_GREEN_ON_GREEN_var                EQU 0x76
CAL_C_BLUE_ON_GREEN_var                 EQU 0x77
CAL_C_RED_ON_BLUE_var                   EQU 0x78
CAL_C_GREEN_ON_BLUE_var                 EQU 0x79
CAL_C_BLUE_ON_BLUE_var                  EQU 0x7A
CAL_C_RED_ON_BLACK_var                  EQU 0x7B
CAL_C_GREEN_ON_BLACK_var                EQU 0x7C
CAL_C_BLUE_ON_BLACK_var                 EQU 0x7D
; RIGHT sensor
CAL_R_RED_ON_WHITE_var                  EQU 0x7E
CAL_R_GREEN_ON_WHITE_var                EQU 0x7F
CAL_R_BLUE_ON_WHITE_var                 EQU 0x80
CAL_R_RED_ON_RED_var                    EQU 0x81
CAL_R_GREEN_ON_RED_var                  EQU 0x82
CAL_R_BLUE_ON_RED_var                   EQU 0x83
CAL_R_RED_ON_GREEN_var                  EQU 0x84
CAL_R_GREEN_ON_GREEN_var                EQU 0x85
CAL_R_BLUE_ON_GREEN_var                 EQU 0x86
CAL_R_RED_ON_BLUE_var                   EQU 0x87
CAL_R_GREEN_ON_BLUE_var                 EQU 0x88
CAL_R_BLUE_ON_BLUE_var                  EQU 0x89
CAL_R_RED_ON_BLACK_var                  EQU 0x8A
CAL_R_GREEN_ON_BLACK_var                EQU 0x8B
CAL_R_BLUE_ON_BLACK_var                 EQU 0x8C

; ---- State constants ----
selecting_state_val            EQU 0x10
colour_state_val               EQU 0x11
reference_state_val            EQU 0x12
attack_state_val               EQU 0x13
simulate_state_val             EQU 0x14
hotload_state_val              EQU 0x15

; ---- Colour enum (matches marv.s) ----
RED_COLOUR_STATE_val           EQU 0x01
GREEN_COLOUR_STATE_val         EQU 0x02
BLUE_COLOUR_STATE_val          EQU 0x03
BLACK_COLOUR_STATE_val         EQU 0x04
WHITE_COLOUR_STATE_val         EQU 0x05
UNKNOWN_COLOUR_val             EQU 0x06

matching_floor_to_strobe_colour_reading_diff_multiplier_val EQU 0x03

; ---- ADC channel constants (sensors on PORTE) ----
ADC_AN5                        EQU 00010101B    ; AN5 = RE0 = left sensor
ADC_AN6                        EQU 00011001B    ; AN6 = RE1 = centre sensor
ADC_AN7                        EQU 00011101B    ; AN7 = RE2 = right sensor

; ---- SSD glyph patterns (bit n = 1 means segment ON; bit 0=a, bit 6=g, bit 7=DP)
digit_1_SSD                    EQU 0b00000110   ; b,c
digit_2_SSD                    EQU 0b01011011   ; a,b,d,e,g
digit_3_SSD                    EQU 0b01001111   ; a,b,c,d,g
digit_4_SSD                    EQU 0b01100110   ; b,c,f,g
digit_5_SSD                    EQU 0b01101101   ; a,c,d,f,g
CLEAR_SSD                      EQU 0x00

; ---- I2C / EEPROM ----
WRITE_CTRL                     EQU 10100000B
READ_CTRL                      EQU 10100001B
EEPROM_END                     EQU 0x60         ; backtick — slogan terminator
COMMIT_KEY                     EQU 0x0D         ; Enter ends UART slogan entry


PSECT code,abs
    org 00h
    GOTO Init

    ORG 0x08
    GOTO ISR


;===========================================================================
; ISR — UART RX + INT0 (yellow) + INT1 (red)
;===========================================================================

ISR:
    BTFSC   PIR1, 5, a                   ; RC1IF — UART RX byte ready?
    CALL    UART_RX_HANDLER
    BTFSC   INTCON, 1, a                 ; INT0IF
    CALL    INT0_HANDLER
    BTFSC   INTCON3, 0, a                ; INT1IF
    CALL    INT1_HANDLER
    BCF     INTCON, 1, 0
    BCF     INTCON3, 0, 0
    RETFIE  1

UART_RX_HANDLER:
    BTFSC   RCSTA1, 1, a                 ; OERR?
    BRA     URX_OERR
    MOVF    RCREG1, W, a
    MOVWF   uart_rx_char_var, a

    XORLW   'M'
    BZ      RX_GO_SELECTING
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
    RETURN

URX_OERR:
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
    RETURN

RX_GO_SELECTING:
    MOVLW   selecting_state_val
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
    ; If already in simulate, also flag for re-run
    MOVF    current_state_var, W, a
    XORLW   simulate_state_val
    BNZ     RGS_DONE
    BSF     simulate_rerun_flag_var, 0, a
RGS_DONE:
    RETURN
RX_GO_HOTLOAD:
    MOVLW   hotload_state_val
    MOVWF   must_navigate_to_var, a
    RETURN

INT0_HANDLER:                            ; yellow: cycle in selecting only
    MOVF    current_state_var, W, a
    XORLW   selecting_state_val
    BZ      INT0_SEL_PRESS
    RETURN
INT0_SEL_PRESS:
    BSF     next_displayed_state_click_var, 0, a
    RETURN

INT1_HANDLER:                            ; red: lock in selecting / back-to-menu elsewhere
INT1_WAIT_RELEASE:
    BTFSC   PORTB, 1, a
    BRA     INT1_WAIT_RELEASE
    MOVLW   selecting_state_val
    CPFSEQ  current_state_var, a
    BRA     INT1_BACK_TO_MENU
    MOVFF   display_select_state_var, must_navigate_to_var
    RETURN
INT1_BACK_TO_MENU:
    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
    RETURN


;===========================================================================
; Init
;===========================================================================

Init:
    MOVLB   0x0F

    ; Oscillator @ 4 MHz (IRCF = 101)
    BSF     OSCCON, 6, a
    BCF     OSCCON, 5, a
    BSF     OSCCON, 4, a

    ; All-digital, sensors-analog on PORTE
    CLRF    ANSELA, b
    CLRF    ANSELB, b
    CLRF    ANSELC, b
    CLRF    ANSELD, b
    MOVLW   00000111B
    MOVWF   ANSELE, b                    ; RE0/RE1/RE2 analog
    MOVLB   0x00

    ; PORTA: SSD output
    CLRF    PORTA, a
    CLRF    TRISA, a

    ; PORTB: RB0/RB1 inputs (buttons)
    CLRF    PORTB, a
    CLRF    LATB, a
    BSF     TRISB, 0, a
    BSF     TRISB, 1, a

    ; PORTC: I2C + UART
    BSF     TRISC, 3                     ; SCL input (MSSP drives open-drain)
    BSF     TRISC, 4                     ; SDA input
    BCF     TRISC, 6                     ; TX output
    BSF     TRISC, 7                     ; RX input

    ; PORTD: strobe LEDs <0:2> outputs (rest unused)
    CLRF    PORTD, a
    CLRF    TRISD, a

    ; PORTE: sensors RE0-RE2 inputs
    MOVLW   00000111B
    MOVWF   TRISE, a
    CLRF    PORTE, a

    ; ADC setup
    MOVLW   ADC_AN5
    MOVWF   ADCON0, a
    CLRF    ADCON1, a                    ; Vref+=VDD, Vref-=VSS
    MOVLW   00101011B                    ; Left-justify, 8 Tad, Fosc/32
    MOVWF   ADCON2, a

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
    MOVLW   00100100B                    ; TXEN=1, BRGH=1
    MOVWF   TXSTA1
    MOVLW   10010000B                    ; SPEN=1, CREN=1
    MOVWF   RCSTA1

    ; INT0/INT1 rising edges + enables
    BSF     INTCON2, 6, 0
    BSF     INTCON2, 5, 0
    BCF     INTCON, 1, 0
    BCF     INTCON3, 0, 0
    BSF     INTCON, 4, 0
    BSF     INTCON3, 3, 0

    ; UART RX interrupt enable
    BCF     PIR1, 5, a
    BSF     PIE1, 5, a
    BSF     INTCON, 6, a                 ; PEIE
    BSF     INTCON, 7, a                 ; GIE

    ; Hardcoded calibration defaults (real measurements from marv.s)
    ; Lets Simulate produce meaningful output without first running REFERENCE.
    CALL    LOAD_DEFAULT_CAL

    CALL    DELAY_1S
    CALL    I2C_BUS_RECOVER

    ; Default state = selecting (cycling menu)
    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
    CLRF    current_state_var, a
    CLRF    SSD_OUT_var, a
    CLRF    simulate_rerun_flag_var, a

Main:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     Main


;===========================================================================
; State dispatch
;===========================================================================

STATE_NAV:
    MOVFF   must_navigate_to_var, current_state_var

    MOVF    current_state_var, W, a
    XORLW   selecting_state_val
    BZ      to_selecting
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
    GOTO    ENTER_SELECTING

to_selecting:  GOTO ENTER_SELECTING
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
    POP
    GOTO    STATE_NAV


;===========================================================================
; Selecting state — print slogan + menu, then cycle candidates
;===========================================================================

ENTER_SELECTING:
    MOVLW   selecting_state_val
    MOVWF   current_state_var, a
    CALL    EEPROM_PRINT_SLOGAN
    CALL    UART_CRLF
    CALL    PRINT_MENU_OPTIONS

STATE_SELECT_LOOP:
    MOVLW   colour_state_val
    MOVWF   display_select_state_var, a
    MOVLW   digit_1_SSD
    MOVWF   current_state_symbol_var, a
    CALL    STATE_SELECT_INPUT

    MOVLW   reference_state_val
    MOVWF   display_select_state_var, a
    MOVLW   digit_2_SSD
    MOVWF   current_state_symbol_var, a
    CALL    STATE_SELECT_INPUT

    MOVLW   attack_state_val
    MOVWF   display_select_state_var, a
    MOVLW   digit_3_SSD
    MOVWF   current_state_symbol_var, a
    CALL    STATE_SELECT_INPUT

    MOVLW   simulate_state_val
    MOVWF   display_select_state_var, a
    MOVLW   digit_4_SSD
    MOVWF   current_state_symbol_var, a
    CALL    STATE_SELECT_INPUT

    MOVLW   hotload_state_val
    MOVWF   display_select_state_var, a
    MOVLW   digit_5_SSD
    MOVWF   current_state_symbol_var, a
    CALL    STATE_SELECT_INPUT

    BRA     STATE_SELECT_LOOP

STATE_SELECT_INPUT:
    CLRF    next_displayed_state_click_var, a
    MOVLW   0x01
    MOVWF   temp_var2, a
    MOVLW   0x60
    MOVWF   Delay1, a
SSI_OUTER:
    MOVLW   0xFF
    MOVWF   Delay2, a
SSI_INNER:
    BTFSC   next_displayed_state_click_var, 0, a
    RETURN
    CALL    NAV_STATE_IF_REQUIRED

    BTFSC   temp_var2, 0, a
    BRA     SSI_BLOCK_ON
    MOVLW   CLEAR_SSD
    BRA     SSI_BLOCK_WRITE
SSI_BLOCK_ON:
    MOVLW   0x30
    CPFSGT  Delay1, a
    CLRF    temp_var2, a
    MOVF    current_state_symbol_var, W, a
SSI_BLOCK_WRITE:
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD

    DECFSZ  Delay2, F, a
    BRA     SSI_INNER
    DECFSZ  Delay1, F, a
    BRA     SSI_OUTER
    BRA     STATE_SELECT_INPUT


;===========================================================================
; Per-state handlers
;===========================================================================

COLOUR_STATE:
    MOVLW   colour_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_1_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_COLOUR_MSG
COL_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     COL_LOOP

REFERENCE_STATE:
    MOVLW   reference_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_2_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_REF_MSG
REF_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     REF_LOOP

ATTACK_STATE:
    MOVLW   attack_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_3_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_ATTACK_MSG
ATK_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     ATK_LOOP

SIMULATE_STATE:
    MOVLW   simulate_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_4_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_SIM_MSG
    BCF     simulate_rerun_flag_var, 0, a
    CALL    poll_sensors_for_detected_colour
    CALL    PRINT_SENSOR_COLOURS
SIM_LOOP:
    BTFSC   simulate_rerun_flag_var, 0, a
    BRA     SIM_RERUN
    CALL    NAV_STATE_IF_REQUIRED
    BRA     SIM_LOOP
SIM_RERUN:
    BCF     simulate_rerun_flag_var, 0, a
    CALL    poll_sensors_for_detected_colour
    CALL    PRINT_SENSOR_COLOURS
    BRA     SIM_LOOP

HOTLOAD_STATE:
    MOVLW   hotload_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_5_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_HOTLOAD_MSG
    CALL    HOTLOAD_READ_WRITE           ; reads UART, writes EEPROM, returns when committed
    CALL    UART_CRLF
    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
HL_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     HL_LOOP


;===========================================================================
; Sensor + classification (lifted from marv.s)
;===========================================================================

poll_sensors_for_detected_colour:
    CALL    strobe_and_save_sensor_readings
    CALL    calc_perceived_colour_L
    CALL    calc_perceived_colour_C
    CALL    calc_perceived_colour_R
    RETURN

strobe_and_save_sensor_readings:
    CALL    set_strobe_leds_red
    CALL    TIMEOUT_LED_WAIT_LED_GET_HIGH
    CALL    read_and_save_sensor_array_perception
    CALL    save_sensor_reading_to_strobe_red

    CALL    set_strobe_leds_green
    CALL    TIMEOUT_LED_WAIT_LED_GET_HIGH
    CALL    read_and_save_sensor_array_perception
    CALL    save_sensor_reading_to_strobe_green

    CALL    set_strobe_leds_blue
    CALL    TIMEOUT_LED_WAIT_LED_GET_HIGH
    CALL    read_and_save_sensor_array_perception
    CALL    save_sensor_reading_to_strobe_blue

    CALL    set_strobe_leds_off
    RETURN

save_sensor_reading_to_strobe_red:
    MOVFF   sensor_L_reading_var, sensor_L_strobe_R_reading_var
    MOVFF   sensor_C_reading_var, sensor_C_strobe_R_reading_var
    MOVFF   sensor_R_reading_var, sensor_R_strobe_R_reading_var
    RETURN
save_sensor_reading_to_strobe_green:
    MOVFF   sensor_L_reading_var, sensor_L_strobe_G_reading_var
    MOVFF   sensor_C_reading_var, sensor_C_strobe_G_reading_var
    MOVFF   sensor_R_reading_var, sensor_R_strobe_G_reading_var
    RETURN
save_sensor_reading_to_strobe_blue:
    MOVFF   sensor_L_reading_var, sensor_L_strobe_B_reading_var
    MOVFF   sensor_C_reading_var, sensor_C_strobe_B_reading_var
    MOVFF   sensor_R_reading_var, sensor_R_strobe_B_reading_var
    RETURN

read_and_save_sensor_array_perception:
    MOVLW   ADC_AN5
    CALL    read_wreg_selected_adc_to_wreg
    MOVWF   sensor_L_reading_var, a
    MOVLW   ADC_AN6
    CALL    read_wreg_selected_adc_to_wreg
    MOVWF   sensor_C_reading_var, a
    MOVLW   ADC_AN7
    CALL    read_wreg_selected_adc_to_wreg
    MOVWF   sensor_R_reading_var, a
    RETURN

read_wreg_selected_adc_to_wreg:
    MOVWF   ADCON0, a
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    BSF     ADCON0, 1, a
    wait_adc:
        BTFSC   ADCON0, 1, a
        BRA     wait_adc
    MOVF    ADRESH, W, a
    RETURN

set_strobe_leds_red:
    BSF     STROBE_LED_PORT, 0, a
    BCF     STROBE_LED_PORT, 1, a
    BCF     STROBE_LED_PORT, 2, a
    RETURN
set_strobe_leds_green:
    BCF     STROBE_LED_PORT, 0, a
    BSF     STROBE_LED_PORT, 1, a
    BCF     STROBE_LED_PORT, 2, a
    RETURN
set_strobe_leds_blue:
    BCF     STROBE_LED_PORT, 0, a
    BCF     STROBE_LED_PORT, 1, a
    BSF     STROBE_LED_PORT, 2, a
    RETURN
set_strobe_leds_white:
    BSF     STROBE_LED_PORT, 0, a
    BSF     STROBE_LED_PORT, 1, a
    BSF     STROBE_LED_PORT, 2, a
    RETURN
set_strobe_leds_off:
    BCF     STROBE_LED_PORT, 0, a
    BCF     STROBE_LED_PORT, 1, a
    BCF     STROBE_LED_PORT, 2, a
    RETURN

TIMEOUT_LED_WAIT_LED_GET_HIGH:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    RETURN

calc_perceived_colour_L:
    CALL    set_current_strobe_to_L
    CALL    set_current_sensor_cal_to_L
    CALL    calculate_diff_sums
    CALL    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF   sensor_L_read_colour_enum_var, a
    RETURN
calc_perceived_colour_C:
    CALL    set_current_strobe_to_C
    CALL    set_current_sensor_cal_to_C
    CALL    calculate_diff_sums
    CALL    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF   sensor_C_read_colour_enum_var, a
    RETURN
calc_perceived_colour_R:
    CALL    set_current_strobe_to_R
    CALL    set_current_sensor_cal_to_R
    CALL    calculate_diff_sums
    CALL    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF   sensor_R_read_colour_enum_var, a
    RETURN

set_current_strobe_to_L:
    MOVFF   sensor_L_strobe_R_reading_var, current_strobe_reading_red_var
    MOVFF   sensor_L_strobe_G_reading_var, current_strobe_reading_green_var
    MOVFF   sensor_L_strobe_B_reading_var, current_strobe_reading_blue_var
    RETURN
set_current_strobe_to_C:
    MOVFF   sensor_C_strobe_R_reading_var, current_strobe_reading_red_var
    MOVFF   sensor_C_strobe_G_reading_var, current_strobe_reading_green_var
    MOVFF   sensor_C_strobe_B_reading_var, current_strobe_reading_blue_var
    RETURN
set_current_strobe_to_R:
    MOVFF   sensor_R_strobe_R_reading_var, current_strobe_reading_red_var
    MOVFF   sensor_R_strobe_G_reading_var, current_strobe_reading_green_var
    MOVFF   sensor_R_strobe_B_reading_var, current_strobe_reading_blue_var
    RETURN

set_current_sensor_cal_to_L:
    MOVFF   CAL_L_RED_ON_RED_var,     current_sensor_cal_red_on_red_var
    MOVFF   CAL_L_RED_ON_GREEN_var,   current_sensor_cal_red_on_green_var
    MOVFF   CAL_L_RED_ON_BLUE_var,    current_sensor_cal_red_on_blue_var
    MOVFF   CAL_L_RED_ON_WHITE_var,   current_sensor_cal_red_on_white_var
    MOVFF   CAL_L_RED_ON_BLACK_var,   current_sensor_cal_red_on_black_var
    MOVFF   CAL_L_GREEN_ON_RED_var,   current_sensor_cal_green_on_red_var
    MOVFF   CAL_L_GREEN_ON_GREEN_var, current_sensor_cal_green_on_green_var
    MOVFF   CAL_L_GREEN_ON_BLUE_var,  current_sensor_cal_green_on_blue_var
    MOVFF   CAL_L_GREEN_ON_WHITE_var, current_sensor_cal_green_on_white_var
    MOVFF   CAL_L_GREEN_ON_BLACK_var, current_sensor_cal_green_on_black_var
    MOVFF   CAL_L_BLUE_ON_RED_var,    current_sensor_cal_blue_on_red_var
    MOVFF   CAL_L_BLUE_ON_GREEN_var,  current_sensor_cal_blue_on_green_var
    MOVFF   CAL_L_BLUE_ON_BLUE_var,   current_sensor_cal_blue_on_blue_var
    MOVFF   CAL_L_BLUE_ON_WHITE_var,  current_sensor_cal_blue_on_white_var
    MOVFF   CAL_L_BLUE_ON_BLACK_var,  current_sensor_cal_blue_on_black_var
    RETURN
set_current_sensor_cal_to_C:
    MOVFF   CAL_C_RED_ON_RED_var,     current_sensor_cal_red_on_red_var
    MOVFF   CAL_C_RED_ON_GREEN_var,   current_sensor_cal_red_on_green_var
    MOVFF   CAL_C_RED_ON_BLUE_var,    current_sensor_cal_red_on_blue_var
    MOVFF   CAL_C_RED_ON_WHITE_var,   current_sensor_cal_red_on_white_var
    MOVFF   CAL_C_RED_ON_BLACK_var,   current_sensor_cal_red_on_black_var
    MOVFF   CAL_C_GREEN_ON_RED_var,   current_sensor_cal_green_on_red_var
    MOVFF   CAL_C_GREEN_ON_GREEN_var, current_sensor_cal_green_on_green_var
    MOVFF   CAL_C_GREEN_ON_BLUE_var,  current_sensor_cal_green_on_blue_var
    MOVFF   CAL_C_GREEN_ON_WHITE_var, current_sensor_cal_green_on_white_var
    MOVFF   CAL_C_GREEN_ON_BLACK_var, current_sensor_cal_green_on_black_var
    MOVFF   CAL_C_BLUE_ON_RED_var,    current_sensor_cal_blue_on_red_var
    MOVFF   CAL_C_BLUE_ON_GREEN_var,  current_sensor_cal_blue_on_green_var
    MOVFF   CAL_C_BLUE_ON_BLUE_var,   current_sensor_cal_blue_on_blue_var
    MOVFF   CAL_C_BLUE_ON_WHITE_var,  current_sensor_cal_blue_on_white_var
    MOVFF   CAL_C_BLUE_ON_BLACK_var,  current_sensor_cal_blue_on_black_var
    RETURN
set_current_sensor_cal_to_R:
    MOVFF   CAL_R_RED_ON_RED_var,     current_sensor_cal_red_on_red_var
    MOVFF   CAL_R_RED_ON_GREEN_var,   current_sensor_cal_red_on_green_var
    MOVFF   CAL_R_RED_ON_BLUE_var,    current_sensor_cal_red_on_blue_var
    MOVFF   CAL_R_RED_ON_WHITE_var,   current_sensor_cal_red_on_white_var
    MOVFF   CAL_R_RED_ON_BLACK_var,   current_sensor_cal_red_on_black_var
    MOVFF   CAL_R_GREEN_ON_RED_var,   current_sensor_cal_green_on_red_var
    MOVFF   CAL_R_GREEN_ON_GREEN_var, current_sensor_cal_green_on_green_var
    MOVFF   CAL_R_GREEN_ON_BLUE_var,  current_sensor_cal_green_on_blue_var
    MOVFF   CAL_R_GREEN_ON_WHITE_var, current_sensor_cal_green_on_white_var
    MOVFF   CAL_R_GREEN_ON_BLACK_var, current_sensor_cal_green_on_black_var
    MOVFF   CAL_R_BLUE_ON_RED_var,    current_sensor_cal_blue_on_red_var
    MOVFF   CAL_R_BLUE_ON_GREEN_var,  current_sensor_cal_blue_on_green_var
    MOVFF   CAL_R_BLUE_ON_BLUE_var,   current_sensor_cal_blue_on_blue_var
    MOVFF   CAL_R_BLUE_ON_WHITE_var,  current_sensor_cal_blue_on_white_var
    MOVFF   CAL_R_BLUE_ON_BLACK_var,  current_sensor_cal_blue_on_black_var
    RETURN

calculate_diff_sums:
    ; RED floor diff
    MOVF    current_sensor_cal_red_on_red_var, W, a
    SUBWF   current_strobe_reading_red_var, W, a
    CALL    abs_val_subtraction_in_wreg
    MOVWF   red_floor_sum_delta_var, a
    MOVLW   matching_floor_to_strobe_colour_reading_diff_multiplier_val
    MULWF   red_floor_sum_delta_var, a
    MOVFF   PRODL, red_floor_sum_delta_var
    TSTFSZ  PRODH, a
    SETF    red_floor_sum_delta_var, a
    MOVF    current_sensor_cal_green_on_red_var, W, a
    SUBWF   current_strobe_reading_green_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   red_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    red_floor_sum_delta_var, a
    MOVF    current_sensor_cal_blue_on_red_var, W, a
    SUBWF   current_strobe_reading_blue_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   red_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    red_floor_sum_delta_var, a

    ; GREEN floor diff
    MOVF    current_sensor_cal_green_on_green_var, W, a
    SUBWF   current_strobe_reading_green_var, W, a
    CALL    abs_val_subtraction_in_wreg
    MOVWF   green_floor_sum_delta_var, a
    MOVLW   matching_floor_to_strobe_colour_reading_diff_multiplier_val
    MULWF   green_floor_sum_delta_var, a
    MOVFF   PRODL, green_floor_sum_delta_var
    TSTFSZ  PRODH, a
    SETF    green_floor_sum_delta_var, a
    MOVF    current_sensor_cal_red_on_green_var, W, a
    SUBWF   current_strobe_reading_red_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   green_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    green_floor_sum_delta_var, a
    MOVF    current_sensor_cal_blue_on_green_var, W, a
    SUBWF   current_strobe_reading_blue_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   green_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    green_floor_sum_delta_var, a

    ; BLUE floor diff
    MOVF    current_sensor_cal_blue_on_blue_var, W, a
    SUBWF   current_strobe_reading_blue_var, W, a
    CALL    abs_val_subtraction_in_wreg
    MOVWF   blue_floor_sum_delta_var, a
    MOVLW   matching_floor_to_strobe_colour_reading_diff_multiplier_val
    MULWF   blue_floor_sum_delta_var, a
    MOVFF   PRODL, blue_floor_sum_delta_var
    TSTFSZ  PRODH, a
    SETF    blue_floor_sum_delta_var, a
    MOVF    current_sensor_cal_red_on_blue_var, W, a
    SUBWF   current_strobe_reading_red_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   blue_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    blue_floor_sum_delta_var, a
    MOVF    current_sensor_cal_green_on_blue_var, W, a
    SUBWF   current_strobe_reading_green_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   blue_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    blue_floor_sum_delta_var, a

    ; WHITE floor diff
    MOVF    current_sensor_cal_red_on_white_var, W, a
    SUBWF   current_strobe_reading_red_var, W, a
    CALL    abs_val_subtraction_in_wreg
    MOVWF   white_floor_sum_delta_var, a
    MOVF    current_sensor_cal_green_on_white_var, W, a
    SUBWF   current_strobe_reading_green_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   white_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    white_floor_sum_delta_var, a
    MOVF    current_sensor_cal_blue_on_white_var, W, a
    SUBWF   current_strobe_reading_blue_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   white_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    white_floor_sum_delta_var, a
    MOVF    white_floor_sum_delta_var, W, a
    CALL    MUL1375_WREG
    MOVWF   white_floor_sum_delta_var, a

    ; BLACK floor diff
    MOVF    current_sensor_cal_red_on_black_var, W, a
    SUBWF   current_strobe_reading_red_var, W, a
    CALL    abs_val_subtraction_in_wreg
    MOVWF   black_floor_sum_delta_var, a
    MOVF    current_sensor_cal_green_on_black_var, W, a
    SUBWF   current_strobe_reading_green_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   black_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    black_floor_sum_delta_var, a
    MOVF    current_sensor_cal_blue_on_black_var, W, a
    SUBWF   current_strobe_reading_blue_var, W, a
    CALL    abs_val_subtraction_in_wreg
    ADDWF   black_floor_sum_delta_var, F, a
    BTFSC   STATUS, 0, a
    SETF    black_floor_sum_delta_var, a
    MOVF    black_floor_sum_delta_var, W, a
    CALL    MUL1375_WREG
    MOVWF   black_floor_sum_delta_var, a
    RETURN

calc_lowest_diff_sum_colour_index_to_wreg:
    MOVFF   red_floor_sum_delta_var, lowest_diff_score_var
    MOVLW   RED_COLOUR_STATE_val
    MOVWF   lowest_diff_enum_colour_var, a

    MOVF    lowest_diff_score_var, W, a
    CPFSLT  green_floor_sum_delta_var, a
    BRA     LDS_BLUE
    MOVFF   green_floor_sum_delta_var, lowest_diff_score_var
    MOVLW   GREEN_COLOUR_STATE_val
    MOVWF   lowest_diff_enum_colour_var, a
LDS_BLUE:
    MOVF    lowest_diff_score_var, W, a
    CPFSLT  blue_floor_sum_delta_var, a
    BRA     LDS_WHITE
    MOVFF   blue_floor_sum_delta_var, lowest_diff_score_var
    MOVLW   BLUE_COLOUR_STATE_val
    MOVWF   lowest_diff_enum_colour_var, a
LDS_WHITE:
    MOVF    lowest_diff_score_var, W, a
    CPFSLT  white_floor_sum_delta_var, a
    BRA     LDS_BLACK
    MOVFF   white_floor_sum_delta_var, lowest_diff_score_var
    MOVLW   WHITE_COLOUR_STATE_val
    MOVWF   lowest_diff_enum_colour_var, a
LDS_BLACK:
    MOVF    lowest_diff_score_var, W, a
    CPFSLT  black_floor_sum_delta_var, a
    BRA     LDS_END
    MOVFF   black_floor_sum_delta_var, lowest_diff_score_var
    MOVLW   BLACK_COLOUR_STATE_val
    MOVWF   lowest_diff_enum_colour_var, a
LDS_END:
    MOVF    lowest_diff_enum_colour_var, W, a
    RETURN

abs_val_subtraction_in_wreg:
    BTFSC   STATUS, 0, a
    RETURN
    COMF    WREG, a
    INCF    WREG, a
    RETURN

MUL1375_WREG:
    MOVWF   temp_var, a
    MOVWF   temp_var2, a
    MOVF    temp_var, W, a
    BCF     STATUS, 0, a
    RRCF    WREG, F, a
    BCF     STATUS, 0, a
    RRCF    WREG, F, a
    ADDWF   temp_var2, F, a
    BTFSC   STATUS, 0, a
    SETF    temp_var2, a
    MOVF    temp_var, W, a
    BCF     STATUS, 0, a
    RRCF    WREG, W, a
    BCF     STATUS, 0, a
    RRCF    WREG, W, a
    BCF     STATUS, 0, a
    RRCF    WREG, W, a
    ADDWF   temp_var2, F, a
    BTFSC   STATUS, 0, a
    SETF    temp_var2, a
    MOVF    temp_var2, W, a
    RETURN


;===========================================================================
; Default cal data (from marv.s real-measurement defaults)
;===========================================================================

LOAD_DEFAULT_CAL:
    ; RED surface — L: R=10 G=23 B=8  C: R=39 G=50 B=29  R: R=30 G=17 B=6
    MOVLW   10
    MOVWF   CAL_L_RED_ON_RED_var, b
    MOVLW   23
    MOVWF   CAL_L_GREEN_ON_RED_var, b
    MOVLW   8
    MOVWF   CAL_L_BLUE_ON_RED_var, b
    MOVLW   39
    MOVWF   CAL_C_RED_ON_RED_var, b
    MOVLW   50
    MOVWF   CAL_C_GREEN_ON_RED_var, b
    MOVLW   29
    MOVWF   CAL_C_BLUE_ON_RED_var, b
    MOVLW   30
    MOVWF   CAL_R_RED_ON_RED_var, b
    MOVLW   17
    MOVWF   CAL_R_GREEN_ON_RED_var, b
    MOVLW   6
    MOVWF   CAL_R_BLUE_ON_RED_var, b
    ; GREEN surface — L: R=3 G=28 B=24  C: R=14 G=60 B=54  R: R=9 G=45 B=12
    MOVLW   3
    MOVWF   CAL_L_RED_ON_GREEN_var, b
    MOVLW   28
    MOVWF   CAL_L_GREEN_ON_GREEN_var, b
    MOVLW   24
    MOVWF   CAL_L_BLUE_ON_GREEN_var, b
    MOVLW   14
    MOVWF   CAL_C_RED_ON_GREEN_var, b
    MOVLW   60
    MOVWF   CAL_C_GREEN_ON_GREEN_var, b
    MOVLW   54
    MOVWF   CAL_C_BLUE_ON_GREEN_var, b
    MOVLW   9
    MOVWF   CAL_R_RED_ON_GREEN_var, b
    MOVLW   45
    MOVWF   CAL_R_GREEN_ON_GREEN_var, b
    MOVLW   12
    MOVWF   CAL_R_BLUE_ON_GREEN_var, b
    ; BLUE surface — L: R=1 G=10 B=15  C: R=1 G=18 B=28  R: R=2 G=17 B=13
    MOVLW   1
    MOVWF   CAL_L_RED_ON_BLUE_var, b
    MOVLW   10
    MOVWF   CAL_L_GREEN_ON_BLUE_var, b
    MOVLW   15
    MOVWF   CAL_L_BLUE_ON_BLUE_var, b
    MOVLW   1
    MOVWF   CAL_C_RED_ON_BLUE_var, b
    MOVLW   18
    MOVWF   CAL_C_GREEN_ON_BLUE_var, b
    MOVLW   28
    MOVWF   CAL_C_BLUE_ON_BLUE_var, b
    MOVLW   2
    MOVWF   CAL_R_RED_ON_BLUE_var, b
    MOVLW   17
    MOVWF   CAL_R_GREEN_ON_BLUE_var, b
    MOVLW   13
    MOVWF   CAL_R_BLUE_ON_BLUE_var, b
    ; WHITE surface — L: R=16 G=57 B=43  C: R=53 G=120 B=111  R: R=38 G=75 B=30
    MOVLW   16
    MOVWF   CAL_L_RED_ON_WHITE_var, b
    MOVLW   57
    MOVWF   CAL_L_GREEN_ON_WHITE_var, b
    MOVLW   43
    MOVWF   CAL_L_BLUE_ON_WHITE_var, b
    MOVLW   53
    MOVWF   CAL_C_RED_ON_WHITE_var, b
    MOVLW   120
    MOVWF   CAL_C_GREEN_ON_WHITE_var, b
    MOVLW   111
    MOVWF   CAL_C_BLUE_ON_WHITE_var, b
    MOVLW   38
    MOVWF   CAL_R_RED_ON_WHITE_var, b
    MOVLW   75
    MOVWF   CAL_R_GREEN_ON_WHITE_var, b
    MOVLW   30
    MOVWF   CAL_R_BLUE_ON_WHITE_var, b
    ; BLACK surface — L: R=1 G=4 B=4  C: R=3 G=7 B=7  R: R=1 G=4 B=3
    MOVLW   1
    MOVWF   CAL_L_RED_ON_BLACK_var, b
    MOVLW   4
    MOVWF   CAL_L_GREEN_ON_BLACK_var, b
    MOVLW   4
    MOVWF   CAL_L_BLUE_ON_BLACK_var, b
    MOVLW   3
    MOVWF   CAL_C_RED_ON_BLACK_var, b
    MOVLW   7
    MOVWF   CAL_C_GREEN_ON_BLACK_var, b
    MOVLW   7
    MOVWF   CAL_C_BLUE_ON_BLACK_var, b
    MOVLW   1
    MOVWF   CAL_R_RED_ON_BLACK_var, b
    MOVLW   4
    MOVWF   CAL_R_GREEN_ON_BLACK_var, b
    MOVLW   3
    MOVWF   CAL_R_BLUE_ON_BLACK_var, b
    RETURN


;===========================================================================
; SSD helper
;===========================================================================

SET_SSD:
    MOVFF   SSD_OUT_var, SSD_PORT
    RETURN


;===========================================================================
; UART (EUSART1)
;===========================================================================

UART_TX:
    BTFSS   PIR1, 4, a
    BRA     UART_TX
    MOVWF   TXREG1, a
    RETURN

UART_CRLF:
    MOVLW   0x0D
    CALL    UART_TX
    MOVLW   0x0A
    CALL    UART_TX
    RETURN

UART_RX_BLOCKING:                        ; used by HOTLOAD_READ_WRITE
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

UART_RX_DRAIN:                           ; non-blocking drain (consume pending byte)
    BTFSC   RCSTA1, 1, a
    BRA     URXD_CLR_OERR
    BTFSS   PIR1, 5, a
    RETURN
    MOVF    RCREG1, W, a
    BRA     UART_RX_DRAIN
URXD_CLR_OERR:
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
    RETURN


;===========================================================================
; Print messages
;===========================================================================

; "M=Menu  C=Colour  R=Reference  A=Attack  S=Simulate  H=Hotload\r\n"
PRINT_MENU_OPTIONS:
    MOVLW   'M'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'M'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
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
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
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
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'A'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
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
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'S'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
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
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'H'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'H'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    GOTO    UART_CRLF

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
    MOVLW   's'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'g'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    GOTO    UART_CRLF

; Print the 3 classified sensor colours (L C R) as 3 letters + CRLF.
; Mapping: 1=R, 2=G, 3=B, 4=K (black), 5=W. Anything else = '?'.
PRINT_SENSOR_COLOURS:
    MOVF    sensor_L_read_colour_enum_var, W, a
    CALL    PRINT_COLOUR_LETTER
    MOVF    sensor_C_read_colour_enum_var, W, a
    CALL    PRINT_COLOUR_LETTER
    MOVF    sensor_R_read_colour_enum_var, W, a
    CALL    PRINT_COLOUR_LETTER
    GOTO    UART_CRLF

PRINT_COLOUR_LETTER:                     ; W = colour enum
    MOVWF   temp_var, a
    XORLW   RED_COLOUR_STATE_val
    BZ      PCL_R
    MOVF    temp_var, W, a
    XORLW   GREEN_COLOUR_STATE_val
    BZ      PCL_G
    MOVF    temp_var, W, a
    XORLW   BLUE_COLOUR_STATE_val
    BZ      PCL_B
    MOVF    temp_var, W, a
    XORLW   BLACK_COLOUR_STATE_val
    BZ      PCL_K
    MOVF    temp_var, W, a
    XORLW   WHITE_COLOUR_STATE_val
    BZ      PCL_W
    MOVLW   '?'
    GOTO    UART_TX
PCL_R:
    MOVLW   'R'
    GOTO    UART_TX
PCL_G:
    MOVLW   'G'
    GOTO    UART_TX
PCL_B:
    MOVLW   'B'
    GOTO    UART_TX
PCL_K:
    MOVLW   'K'
    GOTO    UART_TX
PCL_W:
    MOVLW   'W'
    GOTO    UART_TX


;===========================================================================
; EEPROM slogan read (stops at backtick / 0xFF / 256-byte wrap)
;===========================================================================

EEPROM_PRINT_SLOGAN:
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
EPS_LOOP:
    CALL    I2C_READ_BYTE
    MOVF    TX_BYTE, W, a
    XORLW   EEPROM_END
    BZ      EPS_NACK
    MOVF    TX_BYTE, W, a
    XORLW   0xFF
    BZ      EPS_NACK
    MOVF    TX_BYTE, W, a
    CALL    UART_TX
    INCF    ADDR, F, a
    BZ      EPS_NACK
    CALL    I2C_SEND_ACK
    BRA     EPS_LOOP
EPS_NACK:
    CALL    I2C_SEND_NACK
    CALL    I2C_STOP_COND
    RETURN


;===========================================================================
; Hotload write — read UART until Enter, append backtick, byte-by-byte write
;===========================================================================

HOTLOAD_READ_WRITE:
    CALL    UART_RX_DRAIN
    LFSR    0, 0x100
    CLRF    ADDR, a
HRW_READ:
    CALL    UART_RX_BLOCKING
    MOVWF   RX_BYTE, a
    MOVF    RX_BYTE, W, a
    XORLW   COMMIT_KEY                   ; Enter ends input (not stored)
    BZ      HRW_APPEND_TERM
    MOVF    RX_BYTE, W, a
    XORLW   0x0A                         ; skip LF (CR+LF terminals)
    BZ      HRW_READ
    MOVF    RX_BYTE, W, a
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
    BZ      HRW_DONE_READING
    BRA     HRW_READ
HRW_APPEND_TERM:
    MOVLW   EEPROM_END                   ; backtick
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
HRW_DONE_READING:

    LFSR    0, 0x100
    CLRF    CUR_ADDR, a
HRW_BYTE_LOOP:
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
    BRA     HRW_BYTE_LOOP
    RETURN


;===========================================================================
; I2C primitives + bus recovery
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
W_START:
    BTFSC   SSP1CON2, 0
    BRA     W_START
    RETURN

I2C_RESTART_COND:
    BCF     SSP1IF
    BSF     SSP1CON2, 1
W_RESTART:
    BTFSC   SSP1CON2, 1
    BRA     W_RESTART
    RETURN

I2C_STOP_COND:
    BCF     SSP1IF
    BSF     SSP1CON2, 2
W_STOP:
    BTFSC   SSP1CON2, 2
    BRA     W_STOP
    RETURN

I2C_WRITE:
    BTFSC   SSP1STAT, 0
    GOTO    I2C_WRITE
    BCF     SSP1IF
    MOVF    TX_BYTE, W, a
    MOVWF   SSP1BUF
W_WRITE:
    BTFSS   SSP1IF
    BRA     W_WRITE
    RETURN

I2C_READ_BYTE:
    BCF     SSP1IF
    BSF     SSP1CON2, 3
W_RX:
    BTFSS   SSP1IF
    BRA     W_RX
    BTFSS   SSP1STAT, 0
    GOTO    W_RX
    MOVF    SSP1BUF, W
    MOVWF   TX_BYTE, a
    BCF     SSP1IF
    RETURN

I2C_SEND_ACK:
    BCF     SSP1CON2, 5
    BSF     SSP1CON2, 4
W_ACK:
    BTFSC   SSP1CON2, 4
    BRA     W_ACK
    RETURN

I2C_SEND_NACK:
    BSF     SSP1CON2, 5
    BSF     SSP1CON2, 4
W_NACK:
    BTFSC   SSP1CON2, 4
    BRA     W_NACK
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
