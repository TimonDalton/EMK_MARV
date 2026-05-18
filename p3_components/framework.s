; Prac 3 firmware. CYOC menu cycles C/R/A/S/H candidates; UART chars nav direct.
;
; Pins:
;   PORTA<6:0> SSD, bit 7 DP        PORTB<5:7> RGB display LED
;   RB0 yellow, RB1 red (INT0/1)    RB2 cap-touch (AN8)
;   PORTD<0:2> strobe LEDs          PORTE<0:2> sensors (AN5/6/7)
;   RC1/RC2 motor PWM (CCP2/CCP1)   RC0 IN2, RD3 IN4 (reverse, held low)
;   RC3 SCL, RC4 SDA                RC6 TX, RC7 RX (9600)

    PROCESSOR 18F45K22

    CONFIG  FOSC   = INTIO67
    CONFIG  WDTEN  = OFF
    CONFIG  MCLRE  = EXTMCLR
    CONFIG  LVP    = ON

    #include <xc.inc>
    #include "pic18f45k22.inc"

STROBE_LED_PORT                EQU PORTD
SSD_PORT                       EQU PORTA
DISP_LED_PORT                  EQU PORTB

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

attack_resample_flag_var       EQU 0x39
cal_read_pressed_var           EQU 0x3A
RACE_COL_var                   EQU 0x3B
motor_mode_var                 EQU 0x3C
motor_change_flag_var          EQU 0x3D
colour_change_flag_var         EQU 0x3E

touch_adc_h                    EQU 0x3F
touch_baseline_var             EQU 0x40
touch_count_var                EQU 0x41
touch_timer_var                EQU 0x42
touch_sample1_var              EQU 0x43
touch_sample2_var              EQU 0x44
touch_sample3_var              EQU 0x45

DRIVING_STATE_var                       EQU 0x46
prev_driving_state_var                  EQU 0x47
PERCEIVED_COLOUR_AT_SENSOR_BITS_var     EQU 0x48
has_read_all_black_on_sensor_array_var  EQU 0x49
black_confirm_count_var                 EQU 0x4A

sensor_L_reading_var           EQU 0x11
sensor_C_reading_var           EQU 0x12
sensor_R_reading_var           EQU 0x13
sensor_L_strobe_R_reading_var  EQU 0x14
sensor_L_strobe_G_reading_var  EQU 0x15
sensor_L_strobe_B_reading_var  EQU 0x16
sensor_C_strobe_R_reading_var  EQU 0x17
sensor_C_strobe_G_reading_var  EQU 0x18
sensor_C_strobe_B_reading_var  EQU 0x19
sensor_R_strobe_R_reading_var  EQU 0x1A
sensor_R_strobe_G_reading_var  EQU 0x1B
sensor_R_strobe_B_reading_var  EQU 0x1C
current_strobe_reading_red_var   EQU 0x1D
current_strobe_reading_green_var EQU 0x1E
current_strobe_reading_blue_var  EQU 0x1F

sensor_L_read_colour_enum_var  EQU 0x20
sensor_C_read_colour_enum_var  EQU 0x21
sensor_R_read_colour_enum_var  EQU 0x22

red_floor_sum_delta_var        EQU 0x23
green_floor_sum_delta_var      EQU 0x24
blue_floor_sum_delta_var       EQU 0x25
white_floor_sum_delta_var      EQU 0x26
black_floor_sum_delta_var      EQU 0x27

lowest_diff_enum_colour_var    EQU 0x28
lowest_diff_score_var          EQU 0x29

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

selecting_state_val            EQU 0x10
colour_state_val               EQU 0x11
reference_state_val            EQU 0x12
attack_state_val               EQU 0x13
simulate_state_val             EQU 0x14
hotload_state_val              EQU 0x15

RED_COLOUR_STATE_val           EQU 0x01
GREEN_COLOUR_STATE_val         EQU 0x02
BLUE_COLOUR_STATE_val          EQU 0x03
BLACK_COLOUR_STATE_val         EQU 0x04
WHITE_COLOUR_STATE_val         EQU 0x05
UNKNOWN_COLOUR_val             EQU 0x06

matching_floor_to_strobe_colour_reading_diff_multiplier_val EQU 0x03

PWM_SPEED_FULL_LEFT_val        EQU 16
PWM_SPEED_FULL_RIGHT_val       EQU 15
PWM_SPEED_STOP_val             EQU 0

MOTOR_MODE_STOP_val            EQU 0
MOTOR_MODE_FWD_val             EQU 1
MOTOR_MODE_LEFT_val            EQU 2
MOTOR_MODE_RIGHT_val           EQU 3

LEFT_DRIVING_STATE_val         EQU 0
CENTRE_DRIVING_STATE_val       EQU 1
RIGHT_DRIVING_STATE_val        EQU 2
STOP_DRIVING_STATE_val         EQU 3
LOST_DRIVING_STATE_val         EQU 4

ADC_AN5                        EQU 00010101B
ADC_AN6                        EQU 00011001B
ADC_AN7                        EQU 00011101B

digit_1_SSD                    EQU 0b00000110
digit_2_SSD                    EQU 0b01011011
digit_3_SSD                    EQU 0b01001111
digit_4_SSD                    EQU 0b01100110
digit_5_SSD                    EQU 0b01101101
CLEAR_SSD                      EQU 0x00

SSD_RED                        EQU 0x50
SSD_GREEN                      EQU 0x3D
SSD_BLUE                       EQU 0x7C
SSD_BLACK                      EQU 0b10000000

WFT_THRESH                     EQU 0x03
WFT_DEBOUNCE                   EQU 0x03
WFT_TIMEOUT                    EQU 0xC8

WRITE_CTRL                     EQU 10100000B
READ_CTRL                      EQU 10100001B
EEPROM_END                     EQU 0x60         ; backtick
COMMIT_KEY                     EQU 0x0D


PSECT code,abs
    org 00h
    GOTO Init

    ORG 0x08
    GOTO ISR


ISR:
    BTFSC   PIR1, 5, a
    CALL    UART_RX_HANDLER
    BTFSC   INTCON, 1, a
    CALL    INT0_HANDLER
    BTFSC   INTCON3, 0, a
    CALL    INT1_HANDLER
    BCF     INTCON, 1, 0
    BCF     INTCON3, 0, 0
    RETFIE  1

UART_RX_HANDLER:
    BTFSC   RCSTA1, 1, a
    BRA     URX_OERR
    MOVF    RCREG1, W, a
    MOVWF   uart_rx_char_var, a

    ; In colour state, R/G/B/k set RACE_COL_var instead of navigating.
    MOVF    current_state_var, W, a
    XORLW   colour_state_val
    BNZ     URX_CHECK_SIM
    MOVF    uart_rx_char_var, W, a
    XORLW   'R'
    BZ      URX_SET_RED
    MOVF    uart_rx_char_var, W, a
    XORLW   'G'
    BZ      URX_SET_GREEN
    MOVF    uart_rx_char_var, W, a
    XORLW   'B'
    BZ      URX_SET_BLUE
    MOVF    uart_rx_char_var, W, a
    XORLW   'k'
    BZ      URX_SET_BLACK
    BRA     URX_NORMAL_DISPATCH          ; M/A/S/H still navigate from colour mode

URX_CHECK_SIM:
    ; In simulate state, F/L/R toggle motor mode instead of navigating.
    MOVF    current_state_var, W, a
    XORLW   simulate_state_val
    BNZ     URX_NORMAL_DISPATCH
    MOVF    uart_rx_char_var, W, a
    XORLW   'F'
    BZ      URX_TOGGLE_FWD
    MOVF    uart_rx_char_var, W, a
    XORLW   'L'
    BZ      URX_TOGGLE_LEFT
    MOVF    uart_rx_char_var, W, a
    XORLW   'R'
    BZ      URX_TOGGLE_RIGHT

URX_NORMAL_DISPATCH:
    MOVF    uart_rx_char_var, W, a
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

URX_TOGGLE_FWD:
    MOVF    motor_mode_var, W, a
    XORLW   MOTOR_MODE_FWD_val
    BZ      URX_MOTOR_STOP
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

URX_SET_RED:
    MOVLW   RED_COLOUR_STATE_val
    MOVWF   RACE_COL_var, a
    BSF     colour_change_flag_var, 0, a
    RETURN
URX_SET_GREEN:
    MOVLW   GREEN_COLOUR_STATE_val
    MOVWF   RACE_COL_var, a
    BSF     colour_change_flag_var, 0, a
    RETURN
URX_SET_BLUE:
    MOVLW   BLUE_COLOUR_STATE_val
    MOVWF   RACE_COL_var, a
    BSF     colour_change_flag_var, 0, a
    RETURN
URX_SET_BLACK:
    MOVLW   BLACK_COLOUR_STATE_val
    MOVWF   RACE_COL_var, a
    BSF     colour_change_flag_var, 0, a
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

INT0_HANDLER:
    MOVF    current_state_var, W, a
    XORLW   selecting_state_val
    BZ      INT0_SEL_PRESS
    MOVF    current_state_var, W, a
    XORLW   reference_state_val
    BZ      INT0_REF_PRESS
    RETURN
INT0_SEL_PRESS:
    BSF     next_displayed_state_click_var, 0, a
    RETURN
INT0_REF_PRESS:
    BSF     cal_read_pressed_var, 0, a
    RETURN

INT1_HANDLER:
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


Init:
    MOVLB   0x0F

    BSF     OSCCON, 6, a
    BCF     OSCCON, 5, a
    BSF     OSCCON, 4, a

    CLRF    ANSELA, b
    CLRF    ANSELB, b
    CLRF    ANSELC, b
    CLRF    ANSELD, b
    MOVLW   00000111B
    MOVWF   ANSELE, b
    MOVLB   0x00

    ; PORTA: SSD output
    CLRF    PORTA, a
    CLRF    TRISA, a

    CLRF    PORTB, a
    CLRF    LATB, a
    BSF     TRISB, 0, a
    BSF     TRISB, 1, a
    BCF     TRISB, 5, a
    BCF     TRISB, 6, a
    BCF     TRISB, 7, a

    BSF     TRISC, 3
    BSF     TRISC, 4
    BCF     TRISC, 6
    BSF     TRISC, 7

    CLRF    PORTD, a
    CLRF    TRISD, a

    MOVLW   00000111B
    MOVWF   TRISE, a
    CLRF    PORTE, a

    MOVLW   ADC_AN5
    MOVWF   ADCON0, a
    CLRF    ADCON1, a
    MOVLW   00101011B
    MOVWF   ADCON2, a

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

    MOVLW   0x19
    MOVWF   SPBRG1
    CLRF    SPBRGH1
    MOVLW   00100100B
    MOVWF   TXSTA1
    MOVLW   10010000B
    MOVWF   RCSTA1

    BSF     INTCON2, 6, 0
    BSF     INTCON2, 5, 0
    BCF     INTCON, 1, 0
    BCF     INTCON3, 0, 0
    BSF     INTCON, 4, 0
    BSF     INTCON3, 3, 0

    CALL    LOAD_DEFAULT_CAL

    CALL    DELAY_1S
    CALL    DELAY_1S
    CALL    DELAY_1S
    CALL    I2C_BUS_RECOVER

    MOVLW   19
    MOVWF   PR2, a
    BCF     TRISC, 0, a
    BCF     TRISC, 1, a
    BCF     TRISC, 2, a
    BCF     LATC, 0, a
    CLRF    T2CON, a
    CLRF    TMR2, a
    BSF     CCP1CON, 3, a
    BSF     CCP1CON, 2, a
    BCF     CCP1CON, 1, a
    BCF     CCP1CON, 0, a
    BSF     CCP2CON, 3, a
    BSF     CCP2CON, 2, a
    BCF     CCP2CON, 1, a
    BCF     CCP2CON, 0, a
    BSF     T2CON, 2, a
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a

    CALL    UART_RX_DRAIN
    BCF     RCSTA1, 4, a
    BSF     RCSTA1, 4, a

    BCF     PIR1, 5, a
    BSF     PIE1, 5, a
    BSF     INTCON, 6, a
    BSF     INTCON, 7, a

    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
    CLRF    current_state_var, a
    CLRF    SSD_OUT_var, a
    CLRF    simulate_rerun_flag_var, a
    CLRF    cal_read_pressed_var, a
    CLRF    motor_mode_var, a
    CLRF    motor_change_flag_var, a
    CLRF    colour_change_flag_var, a
    MOVLW   RED_COLOUR_STATE_val
    MOVWF   RACE_COL_var, a

Main:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     Main


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
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a
    CLRF    motor_mode_var, a
    POP
    GOTO    STATE_NAV


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


COLOUR_STATE:
    MOVLW   colour_state_val
    MOVWF   current_state_var, a
    CALL    PRINT_COLOUR_MSG
    CALL    PRINT_COLOUR_OPTIONS
    CALL    SET_SSD_FOR_RACE_COL
    CALL    SET_DISP_TO_RACE_COL
    CALL    PRINT_COLOUR_CURRENT
    CLRF    colour_change_flag_var, a
COL_LOOP:
    BTFSC   colour_change_flag_var, 0, a
    CALL    HANDLE_COLOUR_CHANGE
    CALL    NAV_STATE_IF_REQUIRED
    BRA     COL_LOOP

HANDLE_COLOUR_CHANGE:
    BCF     colour_change_flag_var, 0, a
    CALL    SET_SSD_FOR_RACE_COL
    CALL    SET_DISP_TO_RACE_COL
    GOTO    PRINT_COLOUR_SET

REFERENCE_STATE:
    MOVLW   reference_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_2_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_REF_MSG
    CLRF    cal_read_pressed_var, a

    CALL    set_disp_rgb_red
    CALL    PRINT_CAL_RED_PROMPT
    CALL    WAIT_FOR_YELLOW_CAL
    CALL    STROBE_SAVE_CAL_RED_FLOOR
    CALL    PRINT_CAL_READINGS
    CALL    PRINT_CAL_DONE

    CALL    set_disp_rgb_green
    CALL    PRINT_CAL_GREEN_PROMPT
    CALL    WAIT_FOR_YELLOW_CAL
    CALL    STROBE_SAVE_CAL_GREEN_FLOOR
    CALL    PRINT_CAL_READINGS
    CALL    PRINT_CAL_DONE

    CALL    set_disp_rgb_blue
    CALL    PRINT_CAL_BLUE_PROMPT
    CALL    WAIT_FOR_YELLOW_CAL
    CALL    STROBE_SAVE_CAL_BLUE_FLOOR
    CALL    PRINT_CAL_READINGS
    CALL    PRINT_CAL_DONE

    CALL    set_disp_rgb_white
    CALL    PRINT_CAL_WHITE_PROMPT
    CALL    WAIT_FOR_YELLOW_CAL
    CALL    STROBE_SAVE_CAL_WHITE_FLOOR
    CALL    PRINT_CAL_READINGS
    CALL    PRINT_CAL_DONE

    CALL    set_disp_rgb_black
    CALL    PRINT_CAL_BLACK_PROMPT
    BSF     SSD_OUT_var, 7, a
    CALL    SET_SSD
    CALL    WAIT_FOR_YELLOW_CAL
    CALL    STROBE_SAVE_CAL_BLACK_FLOOR
    BCF     SSD_OUT_var, 7, a
    CALL    SET_SSD
    CALL    PRINT_CAL_READINGS
    CALL    PRINT_CAL_DONE

    CALL    set_disp_rgb_black
    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
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
    CALL    PRINT_TOUCH_WAITING
    CALL    WAIT_FOR_TOUCH
    CALL    PRINT_TOUCH_DETECTED
    CALL    SET_SSD_FOR_RACE_COL
    CALL    SET_DISP_TO_RACE_COL

    MOVLW   LOST_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    MOVWF   prev_driving_state_var, a
    CLRF    black_confirm_count_var, a

LLI_NAV_LOOP:
    CALL    poll_sensors_for_detected_colour
    CALL    set_bits_on_colour_perception_array
    CALL    set_driving_state_from_perception

    MOVF    DRIVING_STATE_var, W, a
    XORLW   LEFT_DRIVING_STATE_val
    BZ      set_LLI_left
    MOVF    DRIVING_STATE_var, W, a
    XORLW   CENTRE_DRIVING_STATE_val
    BZ      set_LLI_centre
    MOVF    DRIVING_STATE_var, W, a
    XORLW   RIGHT_DRIVING_STATE_val
    BZ      set_LLI_right
    MOVF    DRIVING_STATE_var, W, a
    XORLW   LOST_DRIVING_STATE_val
    BZ      set_LLI_lost
    MOVF    DRIVING_STATE_var, W, a
    XORLW   STOP_DRIVING_STATE_val
    BZ      has_read_all_black

    CALL    NAV_STATE_IF_REQUIRED
    CLRF    black_confirm_count_var, a
    GOTO    LLI_NAV_LOOP

has_read_all_black:
    INCF    black_confirm_count_var, F, a
    MOVLW   0x20
    CPFSLT  black_confirm_count_var, a
    BRA     LLI_NAV_STOP
    CALL    NAV_STATE_IF_REQUIRED
    GOTO    LLI_NAV_LOOP

LLI_NAV_STOP:
    CLRF    black_confirm_count_var, a
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a
LLI_STOP_WAIT:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     LLI_STOP_WAIT

set_LLI_left:
    MOVLW   LEFT_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR2L, a
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   CCPR1L, a
    CALL    NAV_STATE_IF_REQUIRED
    GOTO    LLI_NAV_LOOP

set_LLI_centre:
    MOVLW   CENTRE_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    MOVLW   PWM_SPEED_FULL_LEFT_val
    MOVWF   CCPR2L, a
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   CCPR1L, a
    CALL    NAV_STATE_IF_REQUIRED
    GOTO    LLI_NAV_LOOP

set_LLI_right:
    MOVLW   RIGHT_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    MOVLW   PWM_SPEED_FULL_LEFT_val
    MOVWF   CCPR2L, a
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    CALL    NAV_STATE_IF_REQUIRED
    GOTO    LLI_NAV_LOOP

set_LLI_lost:
    MOVLW   LOST_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    CALL    NAV_STATE_IF_REQUIRED
    GOTO    LLI_NAV_LOOP

set_bits_on_colour_perception_array:
    CLRF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, a
    CLRF    has_read_all_black_on_sensor_array_var, a

    MOVF    RACE_COL_var, W, a
    XORWF   sensor_L_read_colour_enum_var, W, a
    BNZ     SBP_CHECK_C
    BSF     PERCEIVED_COLOUR_AT_SENSOR_BITS_var, 2, a
SBP_CHECK_C:
    MOVF    RACE_COL_var, W, a
    XORWF   sensor_C_read_colour_enum_var, W, a
    BNZ     SBP_CHECK_R
    BSF     PERCEIVED_COLOUR_AT_SENSOR_BITS_var, 1, a
SBP_CHECK_R:
    MOVF    RACE_COL_var, W, a
    XORWF   sensor_R_read_colour_enum_var, W, a
    BNZ     SBP_CHECK_ALL_BLACK
    BSF     PERCEIVED_COLOUR_AT_SENSOR_BITS_var, 0, a

SBP_CHECK_ALL_BLACK:
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    BNZ     SBP_DONE
    MOVF    sensor_L_read_colour_enum_var, W, a
    XORLW   BLACK_COLOUR_STATE_val
    BNZ     SBP_DONE
    MOVF    sensor_C_read_colour_enum_var, W, a
    XORLW   BLACK_COLOUR_STATE_val
    BNZ     SBP_DONE
    MOVF    sensor_R_read_colour_enum_var, W, a
    XORLW   BLACK_COLOUR_STATE_val
    BNZ     SBP_DONE
    BSF     has_read_all_black_on_sensor_array_var, 0, a
SBP_DONE:
    RETURN

set_driving_state_from_perception:
    BTFSC   has_read_all_black_on_sensor_array_var, 0, a
    BRA     SDS_STOP

    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    XORLW   0b00000001
    BZ      SDS_RIGHT
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    XORLW   0b00000011
    BZ      SDS_RIGHT
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    XORLW   0b00000010
    BZ      SDS_CENTRE
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    XORLW   0b00000100
    BZ      SDS_LEFT
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    XORLW   0b00000110
    BZ      SDS_LEFT
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var, W, a
    XORLW   0b00000111
    BZ      SDS_CENTRE
    BRA     SDS_LOST

SDS_RIGHT:
    MOVLW   RIGHT_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    RETURN
SDS_CENTRE:
    MOVLW   CENTRE_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    RETURN
SDS_LEFT:
    MOVLW   LEFT_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    RETURN
SDS_LOST:
    MOVLW   LOST_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    RETURN
SDS_STOP:
    MOVLW   STOP_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a
    RETURN

SIMULATE_STATE:
    MOVLW   simulate_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_4_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_SIM_MSG
    CALL    PRINT_SIM_HELP
    BCF     simulate_rerun_flag_var, 0, a
    CLRF    motor_mode_var, a
    CLRF    motor_change_flag_var, a
    BCF     TRISC, 0, a
    BCF     TRISC, 1, a
    BCF     TRISC, 2, a
    BCF     LATC, 0, a
    BCF     LATD, 3, a
    BSF     T2CON, 2, a
    CALL    HANDLE_SIM_RERUN
SIM_LOOP:
    BTFSC   motor_change_flag_var, 0, a
    CALL    APPLY_MOTOR_STATE
    BTFSC   simulate_rerun_flag_var, 0, a
    CALL    HANDLE_SIM_RERUN
    CALL    NAV_STATE_IF_REQUIRED
    BRA     SIM_LOOP

HANDLE_SIM_RERUN:
    BCF     simulate_rerun_flag_var, 0, a
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a
    MOVWF   CCPR2L, a
    CALL    poll_sensors_for_detected_colour
    CALL    PRINT_SENSOR_COLOURS
    CALL    WRITE_MOTOR_PWM
    RETURN

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

PRINT_SIM_HELP:
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
    MOVLW   'w'
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

HOTLOAD_STATE:
    MOVLW   hotload_state_val
    MOVWF   current_state_var, a
    MOVLW   digit_5_SSD
    MOVWF   SSD_OUT_var, a
    CALL    SET_SSD
    CALL    PRINT_HOTLOAD_MSG
    CALL    HOTLOAD_READ_WRITE
    CALL    UART_CRLF
    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
HL_LOOP:
    CALL    NAV_STATE_IF_REQUIRED
    BRA     HL_LOOP


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


SET_SSD:
    MOVFF   SSD_OUT_var, SSD_PORT
    RETURN

set_disp_rgb_red:
    BSF     DISP_LED_PORT, 5, a
    BCF     DISP_LED_PORT, 6, a
    BCF     DISP_LED_PORT, 7, a
    RETURN
set_disp_rgb_green:
    BCF     DISP_LED_PORT, 5, a
    BSF     DISP_LED_PORT, 6, a
    BCF     DISP_LED_PORT, 7, a
    RETURN
set_disp_rgb_blue:
    BCF     DISP_LED_PORT, 5, a
    BCF     DISP_LED_PORT, 6, a
    BSF     DISP_LED_PORT, 7, a
    RETURN
set_disp_rgb_white:
    BSF     DISP_LED_PORT, 5, a
    BSF     DISP_LED_PORT, 6, a
    BSF     DISP_LED_PORT, 7, a
    RETURN
set_disp_rgb_black:
    BCF     DISP_LED_PORT, 5, a
    BCF     DISP_LED_PORT, 6, a
    BCF     DISP_LED_PORT, 7, a
    RETURN

SET_SSD_FOR_RACE_COL:
    MOVF    RACE_COL_var, W, a
    XORLW   RED_COLOUR_STATE_val
    BZ      SSR_R
    MOVF    RACE_COL_var, W, a
    XORLW   GREEN_COLOUR_STATE_val
    BZ      SSR_G
    MOVF    RACE_COL_var, W, a
    XORLW   BLUE_COLOUR_STATE_val
    BZ      SSR_B
    MOVF    RACE_COL_var, W, a
    XORLW   BLACK_COLOUR_STATE_val
    BZ      SSR_K
    MOVLW   CLEAR_SSD
    MOVWF   SSD_OUT_var, a
    GOTO    SET_SSD
SSR_R:
    MOVLW   SSD_RED
    MOVWF   SSD_OUT_var, a
    GOTO    SET_SSD
SSR_G:
    MOVLW   SSD_GREEN
    MOVWF   SSD_OUT_var, a
    GOTO    SET_SSD
SSR_B:
    MOVLW   SSD_BLUE
    MOVWF   SSD_OUT_var, a
    GOTO    SET_SSD
SSR_K:
    MOVLW   SSD_BLACK
    MOVWF   SSD_OUT_var, a
    GOTO    SET_SSD

SET_DISP_TO_RACE_COL:
    MOVF    RACE_COL_var, W, a
    XORLW   RED_COLOUR_STATE_val
    BZ      SDR_R
    MOVF    RACE_COL_var, W, a
    XORLW   GREEN_COLOUR_STATE_val
    BZ      SDR_G
    MOVF    RACE_COL_var, W, a
    XORLW   BLUE_COLOUR_STATE_val
    BZ      SDR_B
    GOTO    set_disp_rgb_black
SDR_R:
    GOTO    set_disp_rgb_red
SDR_G:
    GOTO    set_disp_rgb_green
SDR_B:
    GOTO    set_disp_rgb_blue


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

UART_RX_BLOCKING:
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

UART_RX_DRAIN:
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

PRINT_COLOUR_OPTIONS:
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'G'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'G'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'B'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'B'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'k'
    CALL    UART_TX
    MOVLW   '='
    CALL    UART_TX
    MOVLW   'b'
    CALL    UART_TX
    MOVLW   'l'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   'K'
    CALL    UART_TX
    GOTO    UART_CRLF

PRINT_COLOUR_CURRENT:
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVF    RACE_COL_var, W, a
    CALL    PRINT_COLOUR_LETTER
    GOTO    UART_CRLF

PRINT_COLOUR_SET:
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
    MOVF    RACE_COL_var, W, a
    CALL    PRINT_COLOUR_LETTER
    GOTO    UART_CRLF

PRINT_TOUCH_WAITING:
    MOVLW   'W'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'i'
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'i'
    CALL    UART_TX
    MOVLW   'n'
    CALL    UART_TX
    MOVLW   'g'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'f'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   't'
    CALL    UART_TX
    MOVLW   'o'
    CALL    UART_TX
    MOVLW   'u'
    CALL    UART_TX
    MOVLW   'c'
    CALL    UART_TX
    MOVLW   'h'
    CALL    UART_TX
    MOVLW   '.'
    CALL    UART_TX
    MOVLW   '.'
    CALL    UART_TX
    MOVLW   '.'
    CALL    UART_TX
    GOTO    UART_CRLF

; "[TOUCH]\r\n"
PRINT_TOUCH_DETECTED:
    MOVLW   '['
    CALL    UART_TX
    MOVLW   'T'
    CALL    UART_TX
    MOVLW   'O'
    CALL    UART_TX
    MOVLW   'U'
    CALL    UART_TX
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   'H'
    CALL    UART_TX
    MOVLW   ']'
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


HOTLOAD_READ_WRITE:
    BCF     PIE1, 5, a
    CALL    UART_RX_DRAIN
    LFSR    0, 0x100
    CLRF    ADDR, a
HRW_READ:
    CALL    UART_RX_BLOCKING
    MOVWF   RX_BYTE, a
    MOVF    RX_BYTE, W, a
    XORLW   COMMIT_KEY
    BZ      HRW_APPEND_TERM
    MOVF    RX_BYTE, W, a
    XORLW   0x0A
    BZ      HRW_READ
    MOVF    RX_BYTE, W, a
    MOVWF   POSTINC0, a
    INCF    ADDR, F, a
    BZ      HRW_DONE_READING
    BRA     HRW_READ
HRW_APPEND_TERM:
    MOVLW   EEPROM_END
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

    CALL    UART_RX_DRAIN
    BCF     PIR1, 5, a
    BSF     PIE1, 5, a
    RETURN


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

DELAY_300MS_WITH_NAV_CHECK:
    MOVLW   0x05
    MOVWF   Delay3, a
D300_OUTER:
    MOVLW   0xFF
    MOVWF   Delay2, a
D300_INNER:
    MOVLW   0x40
    MOVWF   Delay1, a
D300_TIGHT:
    DECFSZ  Delay1, F, a
    BRA     D300_TIGHT
    DECFSZ  Delay2, F, a
    BRA     D300_INNER
    CALL    NAV_STATE_IF_REQUIRED
    DECFSZ  Delay3, F, a
    BRA     D300_OUTER
    RETURN


WAIT_FOR_YELLOW_CAL:
    CALL    NAV_STATE_IF_REQUIRED
    BTFSS   cal_read_pressed_var, 0, a
    BRA     WAIT_FOR_YELLOW_CAL
WAIT_FOR_YELLOW_RELEASE_CAL:
    BTFSC   PORTB, 0, a
    BRA     WAIT_FOR_YELLOW_RELEASE_CAL
    BCF     cal_read_pressed_var, 0, a
    RETURN

STROBE_SAVE_CAL_RED_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var, CAL_L_RED_ON_RED_var
    MOVFF   sensor_L_strobe_G_reading_var, CAL_L_GREEN_ON_RED_var
    MOVFF   sensor_L_strobe_B_reading_var, CAL_L_BLUE_ON_RED_var
    MOVFF   sensor_C_strobe_R_reading_var, CAL_C_RED_ON_RED_var
    MOVFF   sensor_C_strobe_G_reading_var, CAL_C_GREEN_ON_RED_var
    MOVFF   sensor_C_strobe_B_reading_var, CAL_C_BLUE_ON_RED_var
    MOVFF   sensor_R_strobe_R_reading_var, CAL_R_RED_ON_RED_var
    MOVFF   sensor_R_strobe_G_reading_var, CAL_R_GREEN_ON_RED_var
    MOVFF   sensor_R_strobe_B_reading_var, CAL_R_BLUE_ON_RED_var
    RETURN

STROBE_SAVE_CAL_GREEN_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var, CAL_L_RED_ON_GREEN_var
    MOVFF   sensor_L_strobe_G_reading_var, CAL_L_GREEN_ON_GREEN_var
    MOVFF   sensor_L_strobe_B_reading_var, CAL_L_BLUE_ON_GREEN_var
    MOVFF   sensor_C_strobe_R_reading_var, CAL_C_RED_ON_GREEN_var
    MOVFF   sensor_C_strobe_G_reading_var, CAL_C_GREEN_ON_GREEN_var
    MOVFF   sensor_C_strobe_B_reading_var, CAL_C_BLUE_ON_GREEN_var
    MOVFF   sensor_R_strobe_R_reading_var, CAL_R_RED_ON_GREEN_var
    MOVFF   sensor_R_strobe_G_reading_var, CAL_R_GREEN_ON_GREEN_var
    MOVFF   sensor_R_strobe_B_reading_var, CAL_R_BLUE_ON_GREEN_var
    RETURN

STROBE_SAVE_CAL_BLUE_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var, CAL_L_RED_ON_BLUE_var
    MOVFF   sensor_L_strobe_G_reading_var, CAL_L_GREEN_ON_BLUE_var
    MOVFF   sensor_L_strobe_B_reading_var, CAL_L_BLUE_ON_BLUE_var
    MOVFF   sensor_C_strobe_R_reading_var, CAL_C_RED_ON_BLUE_var
    MOVFF   sensor_C_strobe_G_reading_var, CAL_C_GREEN_ON_BLUE_var
    MOVFF   sensor_C_strobe_B_reading_var, CAL_C_BLUE_ON_BLUE_var
    MOVFF   sensor_R_strobe_R_reading_var, CAL_R_RED_ON_BLUE_var
    MOVFF   sensor_R_strobe_G_reading_var, CAL_R_GREEN_ON_BLUE_var
    MOVFF   sensor_R_strobe_B_reading_var, CAL_R_BLUE_ON_BLUE_var
    RETURN

STROBE_SAVE_CAL_WHITE_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var, CAL_L_RED_ON_WHITE_var
    MOVFF   sensor_L_strobe_G_reading_var, CAL_L_GREEN_ON_WHITE_var
    MOVFF   sensor_L_strobe_B_reading_var, CAL_L_BLUE_ON_WHITE_var
    MOVFF   sensor_C_strobe_R_reading_var, CAL_C_RED_ON_WHITE_var
    MOVFF   sensor_C_strobe_G_reading_var, CAL_C_GREEN_ON_WHITE_var
    MOVFF   sensor_C_strobe_B_reading_var, CAL_C_BLUE_ON_WHITE_var
    MOVFF   sensor_R_strobe_R_reading_var, CAL_R_RED_ON_WHITE_var
    MOVFF   sensor_R_strobe_G_reading_var, CAL_R_GREEN_ON_WHITE_var
    MOVFF   sensor_R_strobe_B_reading_var, CAL_R_BLUE_ON_WHITE_var
    RETURN

STROBE_SAVE_CAL_BLACK_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var, CAL_L_RED_ON_BLACK_var
    MOVFF   sensor_L_strobe_G_reading_var, CAL_L_GREEN_ON_BLACK_var
    MOVFF   sensor_L_strobe_B_reading_var, CAL_L_BLUE_ON_BLACK_var
    MOVFF   sensor_C_strobe_R_reading_var, CAL_C_RED_ON_BLACK_var
    MOVFF   sensor_C_strobe_G_reading_var, CAL_C_GREEN_ON_BLACK_var
    MOVFF   sensor_C_strobe_B_reading_var, CAL_C_BLUE_ON_BLACK_var
    MOVFF   sensor_R_strobe_R_reading_var, CAL_R_RED_ON_BLACK_var
    MOVFF   sensor_R_strobe_G_reading_var, CAL_R_GREEN_ON_BLACK_var
    MOVFF   sensor_R_strobe_B_reading_var, CAL_R_BLUE_ON_BLACK_var
    RETURN


PRINT_READ:
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   'a'
    CALL    UART_TX
    MOVLW   'd'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    return

PRINT_PRESS_BY:
    CALL    UART_TX
    MOVLW   'p'
    CALL    UART_TX
    MOVLW   'r'
    CALL    UART_TX
    MOVLW   'e'
    CALL    UART_TX
    MOVLW   's'
    CALL    UART_TX
    MOVLW   's'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'B'
    CALL    UART_TX
    MOVLW   'Y'
    CALL    UART_TX
    return

PRINT_CAL_RED_PROMPT:
    call    PRINT_READ
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   ','
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    CALL    PRINT_PRESS_BY
    GOTO    UART_CRLF

PRINT_CAL_GREEN_PROMPT:
    call    PRINT_READ
    MOVLW   'G'
    CALL    UART_TX
    MOVLW   ','
    CALL    UART_TX
    call    PRINT_PRESS_BY
    GOTO    UART_CRLF

PRINT_CAL_BLUE_PROMPT:
    call    PRINT_READ
    MOVLW   'B'
    CALL    UART_TX
    MOVLW   ','
    CALL    UART_TX
    call    PRINT_PRESS_BY
    GOTO    UART_CRLF

PRINT_CAL_WHITE_PROMPT:
    call    PRINT_READ
    MOVLW   'W'
    CALL    UART_TX
    MOVLW   ','
    CALL    UART_TX
    call    PRINT_PRESS_BY
    GOTO    UART_CRLF

PRINT_CAL_BLACK_PROMPT:
    call    PRINT_READ
    MOVLW   'K'
    CALL    UART_TX
    MOVLW   ','
    CALL    UART_TX
    call    PRINT_PRESS_BY
    GOTO    UART_CRLF

PRINT_CAL_DONE:
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   'A'
    CALL    UART_TX
    MOVLW   'L'
    CALL    UART_TX
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'D'
    CALL    UART_TX
    MOVLW   'O'
    CALL    UART_TX
    MOVLW   'N'
    CALL    UART_TX
    MOVLW   'E'
    CALL    UART_TX
    GOTO    UART_CRLF

; "L:HH,HH,HH C:HH,HH,HH R:HH,HH,HH\r\n"
; Prints the 9 readings just captured into sensor_*_strobe_*_reading_var
; (also copied into CAL_*_var by STROBE_SAVE_CAL_*_FLOOR).
PRINT_CAL_READINGS:
    MOVLW   'L'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVF    sensor_L_strobe_R_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ','
    CALL    UART_TX
    MOVF    sensor_L_strobe_G_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ','
    CALL    UART_TX
    MOVF    sensor_L_strobe_B_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'C'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVF    sensor_C_strobe_R_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ','
    CALL    UART_TX
    MOVF    sensor_C_strobe_G_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ','
    CALL    UART_TX
    MOVF    sensor_C_strobe_B_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ' '
    CALL    UART_TX
    MOVLW   'R'
    CALL    UART_TX
    MOVLW   ':'
    CALL    UART_TX
    MOVF    sensor_R_strobe_R_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ','
    CALL    UART_TX
    MOVF    sensor_R_strobe_G_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    MOVLW   ','
    CALL    UART_TX
    MOVF    sensor_R_strobe_B_reading_var, W, a
    CALL    PRINT_HEX_BYTE
    GOTO    UART_CRLF

; W = byte → prints two ASCII hex digits (e.g. 0x2F → "2F")
PRINT_HEX_BYTE:
    MOVWF   temp_var, a
    SWAPF   temp_var, W, a
    CALL    HEX_NIBBLE_TO_ASCII
    CALL    UART_TX
    MOVF    temp_var, W, a
    CALL    HEX_NIBBLE_TO_ASCII
    GOTO    UART_TX

; W = nibble (low 4 bits) → W = ASCII '0'-'9' or 'A'-'F'
HEX_NIBBLE_TO_ASCII:
    ANDLW   0x0F
    MOVWF   temp_var2, a
    MOVLW   0x0A
    CPFSLT  temp_var2, a
    BRA     HN_LETTER
    MOVLW   '0'
    ADDWF   temp_var2, W, a
    RETURN
HN_LETTER:
    MOVLW   'A' - 10
    ADDWF   temp_var2, W, a
    RETURN


WAIT_FOR_TOUCH:
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    MOVWF   touch_baseline_var, a
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_baseline_var, F, a
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_baseline_var, F, a
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_baseline_var, F, a
    RRNCF   touch_baseline_var, F, a
    RRNCF   touch_baseline_var, F, a
    MOVLW   0x3F
    ANDWF   touch_baseline_var, F, a
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a

WFT_POLL:
    CLRF    touch_sample1_var, a
    CLRF    touch_sample2_var, a
    MOVLW   0x10
    MOVWF   touch_sample3_var, a
WFT_AVG:
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_sample2_var, F, a
    MOVLW   0x00
    ADDWFC  touch_sample1_var, F, a
    DECFSZ  touch_sample3_var, F, a
    BRA     WFT_AVG
    SWAPF   touch_sample2_var, F, a
    MOVLW   0x0F
    ANDWF   touch_sample2_var, F, a
    SWAPF   touch_sample1_var, W, a
    ANDLW   0xF0
    IORWF   touch_sample2_var, F, a
    MOVFF   touch_sample2_var, touch_adc_h

    MOVF    touch_adc_h, W, a
    SUBWF   touch_baseline_var, W, a
    BN      WFT_DRIFT_UP

    MOVWF   touch_sample3_var, a
    MOVLW   WFT_THRESH
    CPFSGT  touch_sample3_var, a
    BRA     WFT_NO_TOUCH

    INCF    touch_count_var, F, a
    INCF    touch_timer_var, F, a
    MOVLW   WFT_TIMEOUT
    CPFSLT  touch_timer_var, a
    BRA     WFT_TIMEOUT_RST
    MOVLW   WFT_DEBOUNCE
    CPFSGT  touch_count_var, a
    BRA     WFT_POLL

    MOVLB   0xF
    BCF     ANSELB, 2, b
    MOVLB   0x0
    CLRF    ADCON1, a
    MOVLW   00101011B
    MOVWF   ADCON2, a
    RETURN

WFT_DRIFT_UP:
    INCF    touch_baseline_var, F, a
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a
    BRA     WFT_POLL

WFT_NO_TOUCH:
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a
    MOVF    touch_adc_h, W, a
    CPFSGT  touch_baseline_var, a
    BRA     WFT_BL_LOW
    DECF    touch_baseline_var, F, a
    BRA     WFT_POLL
WFT_BL_LOW:
    CPFSLT  touch_baseline_var, a
    BRA     WFT_POLL
    INCF    touch_baseline_var, F, a
    BRA     WFT_POLL

WFT_TIMEOUT_RST:
    MOVFF   touch_adc_h, touch_baseline_var
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a
    BRA     WFT_POLL


CAP_TOUCH_ROUTINE:
    MOVLB   0xF
    BCF     ANSELB, 2, b
    MOVLB   0x0
    BCF     TRISB, 2, a
    BCF     LATB, 2, a
    NOP
    NOP
    NOP

    BSF     TRISB, 2, a
    MOVLB   0xF
    BSF     ANSELB, 2, b
    MOVLB   0x0

    MOVLW   0x21
    MOVWF   ADCON0, a
    CLRF    ADCON1, a
    MOVLW   00100110B
    MOVWF   ADCON2, a

    MOVLB   0xF
    MOVLW   00000001B
    MOVWF   CTMUICON, b
    MOVLW   10000000B
    MOVWF   CTMUCONH, b
    MOVLW   00000001B
    MOVWF   CTMUCONL, b
    MOVLB   0x0

    BSF     ADCON0, 1, a
CAP_ADC_POLL:
    BTFSC   ADCON0, 1, a
    BRA     CAP_ADC_POLL

    MOVLB   0xF
    CLRF    CTMUCONL, b
    CLRF    CTMUCONH, b
    MOVLB   0x0

    MOVFF   ADRESH, touch_adc_h
    RETURN

    end
