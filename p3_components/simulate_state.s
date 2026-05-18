; simulate_state.s — standalone Simulate mode test (P3.2.2.2 S-mode).
;
; Behaviour:
;   - Boot: print "[SIM]\r\n", SSD shows "4".
;   - Strobe R/G/B LEDs in sequence, read sensors L/C/R under each strobe,
;     classify each sensor to one of {R,G,B,W,K} using marv.s's lowest-delta
;     algorithm against hardcoded cal data.
;   - Print 3-letter result (L C R) followed by CRLF.
;   - On each UART 'S' character, re-run the sensor read + print.
;
; Hardcoded calibration (real measurements from marv.s defaults) so the test
; works without first running a REFERENCE/CAL pass.
;
; Pin assignments:
;   PORTA<6:0> = SSD (a-g), bit 7 = DP
;   PORTD<0:2> = strobe LEDs (R/G/B)
;   PORTE<0:2> = RGB sensors (analog AN5/6/7)
;   RC6 = UART TX, RC7 = UART RX (EUSART1 @ 9600 8N1)

    PROCESSOR 18F45K22

    CONFIG  FOSC   = INTIO67
    CONFIG  WDTEN  = OFF
    CONFIG  MCLRE  = EXTMCLR
    CONFIG  LVP    = ON

    #include <xc.inc>
    #include "pic18f45k22.inc"

STROBE_LED_PORT                EQU PORTD
SSD_PORT                       EQU PORTA

; ---- Variables (access bank) ----
Delay1                         EQU 0x00
Delay2                         EQU 0x01
Delay3                         EQU 0x02
temp_var                       EQU 0x03
temp_var2                      EQU 0x04
rerun_flag_var                 EQU 0x05
motor_mode_var                 EQU 0x2E       ; 0=stop, 1=fwd, 2=left, 3=right
motor_change_flag_var          EQU 0x2F

sensor_L_reading_var           EQU 0x06
sensor_C_reading_var           EQU 0x07
sensor_R_reading_var           EQU 0x08

sensor_L_strobe_R_reading_var  EQU 0x09
sensor_L_strobe_G_reading_var  EQU 0x0A
sensor_L_strobe_B_reading_var  EQU 0x0B
sensor_C_strobe_R_reading_var  EQU 0x0C
sensor_C_strobe_G_reading_var  EQU 0x0D
sensor_C_strobe_B_reading_var  EQU 0x0E
sensor_R_strobe_R_reading_var  EQU 0x0F
sensor_R_strobe_G_reading_var  EQU 0x10
sensor_R_strobe_B_reading_var  EQU 0x11

current_strobe_reading_red_var   EQU 0x12
current_strobe_reading_green_var EQU 0x13
current_strobe_reading_blue_var  EQU 0x14

sensor_L_read_colour_enum_var  EQU 0x15
sensor_C_read_colour_enum_var  EQU 0x16
sensor_R_read_colour_enum_var  EQU 0x17

red_floor_sum_delta_var        EQU 0x18
green_floor_sum_delta_var      EQU 0x19
blue_floor_sum_delta_var       EQU 0x1A
white_floor_sum_delta_var      EQU 0x1B
black_floor_sum_delta_var      EQU 0x1C

lowest_diff_enum_colour_var    EQU 0x1D
lowest_diff_score_var          EQU 0x1E

current_sensor_cal_red_on_red_var       EQU 0x1F
current_sensor_cal_red_on_green_var     EQU 0x20
current_sensor_cal_red_on_blue_var      EQU 0x21
current_sensor_cal_red_on_white_var     EQU 0x22
current_sensor_cal_red_on_black_var     EQU 0x23
current_sensor_cal_green_on_red_var     EQU 0x24
current_sensor_cal_green_on_green_var   EQU 0x25
current_sensor_cal_green_on_blue_var    EQU 0x26
current_sensor_cal_green_on_white_var   EQU 0x27
current_sensor_cal_green_on_black_var   EQU 0x28
current_sensor_cal_blue_on_red_var      EQU 0x29
current_sensor_cal_blue_on_green_var    EQU 0x2A
current_sensor_cal_blue_on_blue_var     EQU 0x2B
current_sensor_cal_blue_on_white_var    EQU 0x2C
current_sensor_cal_blue_on_black_var    EQU 0x2D

; ---- Banked CAL storage (0x60-0x8C) — matches marv.s ----
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

; ---- Constants ----
RED_COLOUR_STATE_val           EQU 0x01
GREEN_COLOUR_STATE_val         EQU 0x02
BLUE_COLOUR_STATE_val          EQU 0x03
BLACK_COLOUR_STATE_val         EQU 0x04
WHITE_COLOUR_STATE_val         EQU 0x05

matching_floor_to_strobe_colour_reading_diff_multiplier_val EQU 0x03

ADC_AN5                        EQU 00010101B
ADC_AN6                        EQU 00011001B
ADC_AN7                        EQU 00011101B

; SSD glyph: digit "4" — bits b,c,f,g
digit_4_SSD                    EQU 0b01100110

; Motor speeds (from marv.s; tuned for the TC1508A driver)
PWM_SPEED_FULL_LEFT_val        EQU 16
PWM_SPEED_FULL_RIGHT_val       EQU 15
PWM_SPEED_STOP_val             EQU 0

; Motor mode enum
MOTOR_MODE_STOP_val            EQU 0
MOTOR_MODE_FWD_val             EQU 1
MOTOR_MODE_LEFT_val            EQU 2
MOTOR_MODE_RIGHT_val           EQU 3


PSECT code,abs
    org 00h
    GOTO Init

    ORG 0x08
    GOTO ISR


;===========================================================================
; ISR — UART RX only
;===========================================================================

ISR:
    BTFSC   PIR1, 5, a
    CALL    UART_RX_HANDLER
    RETFIE  1

UART_RX_HANDLER:
    BTFSC   RCSTA1, 1, a
    BRA     URX_OERR
    MOVF    RCREG1, W, a
    MOVWF   temp_var, a
    XORLW   'S'
    BZ      URX_RERUN
    MOVF    temp_var, W, a
    XORLW   'F'
    BZ      URX_TOGGLE_FWD
    MOVF    temp_var, W, a
    XORLW   'L'
    BZ      URX_TOGGLE_LEFT
    MOVF    temp_var, W, a
    XORLW   'R'
    BZ      URX_TOGGLE_RIGHT
    RETURN
URX_OERR:
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a
    RETURN
URX_RERUN:
    BSF     rerun_flag_var, 0, a
    RETURN
URX_TOGGLE_FWD:
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_FWD_val
    BZ      URX_MOTOR_STOP               ; already forward → stop
    MOVLW   MOTOR_MODE_FWD_val
    MOVWF   motor_mode_var, a
    BSF     motor_change_flag_var, 0, a
    RETURN
URX_TOGGLE_LEFT:
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_LEFT_val
    BZ      URX_MOTOR_STOP
    MOVLW   MOTOR_MODE_LEFT_val
    MOVWF   motor_mode_var, a
    BSF     motor_change_flag_var, 0, a
    RETURN
URX_TOGGLE_RIGHT:
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_RIGHT_val
    BZ      URX_MOTOR_STOP
    MOVLW   MOTOR_MODE_RIGHT_val
    MOVWF   motor_mode_var, a
    BSF     motor_change_flag_var, 0, a
    RETURN
URX_MOTOR_STOP:
    CLRF    motor_mode_var, a
    BSF     motor_change_flag_var, 0, a
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

    ; PORTE: sensors analog
    CLRF    ANSELA, b
    CLRF    ANSELB, b
    CLRF    ANSELC, b
    CLRF    ANSELD, b
    MOVLW   00000111B
    MOVWF   ANSELE, b

    MOVLB   0x00

    ; PORTA: SSD
    CLRF    PORTA, a
    CLRF    TRISA, a

    ; PORTC: UART
    BCF     TRISC, 6
    BSF     TRISC, 7

    ; PORTD: strobe LEDs <0:2>
    CLRF    PORTD, a
    CLRF    TRISD, a

    ; PORTE: RE0-2 inputs
    MOVLW   00000111B
    MOVWF   TRISE, a
    CLRF    PORTE, a

    ; ADC
    MOVLW   ADC_AN5
    MOVWF   ADCON0, a
    CLRF    ADCON1, a
    MOVLW   00101011B
    MOVWF   ADCON2, a

    ; UART @ 9600 baud
    MOVLW   0x19
    MOVWF   SPBRG1
    CLRF    SPBRGH1
    MOVLW   00100100B
    MOVWF   TXSTA1
    MOVLW   10010000B
    MOVWF   RCSTA1

    ; PWM motor setup — CCP1 on RC2 (right IN3), CCP2 on RC1 (left IN1)
    ; IN2 (RC0) and IN4 (RD3) are reverse-direction pins, held low (forward only).
    ; Hardware note: marv.s used RC3 for IN4 but it conflicts with I2C SCL; the
    ; user moved IN4 to RD3 — TRISD already cleared earlier so RD3 is output-low.
    MOVLW   19
    MOVWF   PR2, a                       ; 50 kHz PWM at 4 MHz Fosc
    BCF     TRISC, 0, a                  ; RC0 = output (left IN2 reverse)
    BCF     TRISC, 1, a                  ; RC1/CCP2 = output (left IN1 PWM)
    BCF     TRISC, 2, a                  ; RC2/CCP1 = output (right IN3 PWM)
    BCF     LATC, 0, a                   ; IN2 low (no reverse)
    CLRF    T2CON, a
    CLRF    TMR2, a
    BSF     CCP1CON, 3, a                ; CCP1 PWM mode (1100)
    BSF     CCP1CON, 2, a
    BCF     CCP1CON, 1, a
    BCF     CCP1CON, 0, a
    BSF     CCP2CON, 3, a                ; CCP2 PWM mode (1100)
    BSF     CCP2CON, 2, a
    BCF     CCP2CON, 1, a
    BCF     CCP2CON, 0, a
    BSF     T2CON, 2, a                  ; Timer2 ON
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a

    CLRF    rerun_flag_var, a
    CLRF    motor_mode_var, a
    CLRF    motor_change_flag_var, a

    CALL    LOAD_DEFAULT_CAL

    ; Long startup delay so the host terminal has time to attach before banner.
    CALL    DELAY_1S
    CALL    DELAY_1S
    CALL    DELAY_1S

    ; SSD digit "4"
    MOVLW   digit_4_SSD
    MOVWF   SSD_PORT, a

    ; First banner + classification BEFORE enabling RX interrupts — so even if
    ; the RX line picks up noise at boot, the initial output is unaffected.
    CALL    PRINT_BANNER
    CALL    poll_sensors_for_detected_colour
    CALL    PRINT_SENSOR_COLOURS

    ; Now arm the RX interrupt so 'S' triggers re-runs.
    BCF     PIR1, 5, a
    BCF     RCSTA1, 4, a                 ; CREN=0 (drop any pending RX state)
    BSF     RCSTA1, 4, a                 ; CREN=1 (re-enable)
    BSF     PIE1, 5, a
    BSF     INTCON, 6, a
    BSF     INTCON, 7, a

Main:
    BTFSC   motor_change_flag_var, 0, a
    CALL    APPLY_MOTOR_STATE
    BTFSC   rerun_flag_var, 0, a
    CALL    HANDLE_RERUN
    BRA     Main

HANDLE_RERUN:
    BCF     rerun_flag_var, 0, a
    ; Pause motors during sensor read so PWM noise + smearing-while-moving don't
    ; corrupt the readings, then restore the current motor mode silently.
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a
    CALL    poll_sensors_for_detected_colour
    CALL    PRINT_SENSOR_COLOURS
    CALL    WRITE_MOTOR_PWM              ; restore PWM duties for motor_mode_var
    RETURN

; Set CCPR1L/CCPR2L from motor_mode_var. No UART output.
WRITE_MOTOR_PWM:
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_FWD_val
    BZ      WMP_FWD
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_LEFT_val
    BZ      WMP_LEFT
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_RIGHT_val
    BZ      WMP_RIGHT
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a
    RETURN
WMP_FWD:
    MOVLW   PWM_SPEED_FULL_LEFT_val
    MOVWF   CCPR2L, a
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   CCPR1L, a
    RETURN
WMP_LEFT:
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR2L, a
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   CCPR1L, a
    RETURN
WMP_RIGHT:
    MOVLW   PWM_SPEED_FULL_LEFT_val
    MOVWF   CCPR2L, a
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    RETURN

; Apply motor PWM duty + report the new mode on UART.
APPLY_MOTOR_STATE:
    BCF     motor_change_flag_var, 0, a
    CALL    WRITE_MOTOR_PWM
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_FWD_val
    BZ      PRINT_MOTOR_FWD
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_LEFT_val
    BZ      PRINT_MOTOR_LEFT
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_RIGHT_val
    BZ      PRINT_MOTOR_RIGHT
    GOTO    PRINT_MOTOR_STOP


;===========================================================================
; Sensor + classification (from marv.s)
;===========================================================================

poll_sensors_for_detected_colour:
    CALL    strobe_and_save_sensor_readings
    CALL    calc_perceived_colour_L
    CALL    calc_perceived_colour_C
    CALL    calc_perceived_colour_R
    RETURN

strobe_and_save_sensor_readings:
    CALL    set_strobe_leds_red
    CALL    LED_HIGH_WAIT
    CALL    read_and_save_sensor_array_perception
    MOVFF   sensor_L_reading_var, sensor_L_strobe_R_reading_var
    MOVFF   sensor_C_reading_var, sensor_C_strobe_R_reading_var
    MOVFF   sensor_R_reading_var, sensor_R_strobe_R_reading_var

    CALL    set_strobe_leds_green
    CALL    LED_HIGH_WAIT
    CALL    read_and_save_sensor_array_perception
    MOVFF   sensor_L_reading_var, sensor_L_strobe_G_reading_var
    MOVFF   sensor_C_reading_var, sensor_C_strobe_G_reading_var
    MOVFF   sensor_R_reading_var, sensor_R_strobe_G_reading_var

    CALL    set_strobe_leds_blue
    CALL    LED_HIGH_WAIT
    CALL    read_and_save_sensor_array_perception
    MOVFF   sensor_L_reading_var, sensor_L_strobe_B_reading_var
    MOVFF   sensor_C_reading_var, sensor_C_strobe_B_reading_var
    MOVFF   sensor_R_reading_var, sensor_R_strobe_B_reading_var

    CALL    set_strobe_leds_off
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
set_strobe_leds_off:
    BCF     STROBE_LED_PORT, 0, a
    BCF     STROBE_LED_PORT, 1, a
    BCF     STROBE_LED_PORT, 2, a
    RETURN

LED_HIGH_WAIT:                       ; ~20us — let LEDs reach steady brightness
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
    MOVFF   sensor_L_strobe_R_reading_var, current_strobe_reading_red_var
    MOVFF   sensor_L_strobe_G_reading_var, current_strobe_reading_green_var
    MOVFF   sensor_L_strobe_B_reading_var, current_strobe_reading_blue_var
    CALL    LOAD_CAL_L
    CALL    calculate_diff_sums
    CALL    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF   sensor_L_read_colour_enum_var, a
    RETURN

calc_perceived_colour_C:
    MOVFF   sensor_C_strobe_R_reading_var, current_strobe_reading_red_var
    MOVFF   sensor_C_strobe_G_reading_var, current_strobe_reading_green_var
    MOVFF   sensor_C_strobe_B_reading_var, current_strobe_reading_blue_var
    CALL    LOAD_CAL_C
    CALL    calculate_diff_sums
    CALL    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF   sensor_C_read_colour_enum_var, a
    RETURN

calc_perceived_colour_R:
    MOVFF   sensor_R_strobe_R_reading_var, current_strobe_reading_red_var
    MOVFF   sensor_R_strobe_G_reading_var, current_strobe_reading_green_var
    MOVFF   sensor_R_strobe_B_reading_var, current_strobe_reading_blue_var
    CALL    LOAD_CAL_R
    CALL    calculate_diff_sums
    CALL    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF   sensor_R_read_colour_enum_var, a
    RETURN

LOAD_CAL_L:
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

LOAD_CAL_C:
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

LOAD_CAL_R:
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
; Default cal data (real measurements from marv.s)
;===========================================================================

LOAD_DEFAULT_CAL:
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
; UART + printing
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

PRINT_BANNER:
    ; "Simulate mode\r\n"
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
    CALL    UART_CRLF
    ; "S=Sensors  F=Forward  L=Left  R=Right (toggle)\r\n"
    MOVLW   'S'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'S'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   's'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   's'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'F'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'F'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'w'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'L'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'L'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'f'
    CALL    UART_TX
    MOVLW   't'
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
    MOVLW   'i'
    CALL    UART_TX
    MOVLW   'g'
    CALL    UART_TX
    MOVLW   'h'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   '('
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'g'
    CALL    UART_TX
    MOVLW   'g'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   ')'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_MOTOR_FWD:
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'F'
    CALL    UART_TX
    MOVLW   ']'
    CALL    UART_TX
    GOTO    UART_CRLF
PRINT_MOTOR_LEFT:
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'L'
    CALL    UART_TX
    MOVLW   ']'
    CALL    UART_TX
    GOTO    UART_CRLF
PRINT_MOTOR_RIGHT:
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   ']'
    CALL    UART_TX
    GOTO    UART_CRLF
PRINT_MOTOR_STOP:
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'X'
    CALL    UART_TX
    MOVLW   ']'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_SENSOR_COLOURS:
    MOVF    sensor_L_read_colour_enum_var, W, a
    CALL    PRINT_COLOUR_LETTER
    MOVF    sensor_C_read_colour_enum_var, W, a
    CALL    PRINT_COLOUR_LETTER
    MOVF    sensor_R_read_colour_enum_var, W, a
    CALL    PRINT_COLOUR_LETTER
    GOTO    UART_CRLF

PRINT_COLOUR_LETTER:
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
; Delay
;===========================================================================

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
