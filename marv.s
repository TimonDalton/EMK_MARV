PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67   ; Internal oscillator, RA6/RA7 as I/O
CONFIG  WDTEN  = OFF       ; Watchdog timer off
CONFIG  MCLRE  = EXTMCLR   ; MCLR pin enabled (required for programmer)
CONFIG  LVP    = ON        ; Low-voltage programming off

#include <xc.inc>
#include "pic18f45k22.inc"
    
    
;<editor-fold defaultstate="collapsed" desc="COPYABLE FOLD">
;</editor-fold>

;PORT MAPPING

SSD_PORT      equ PORTA
DISP_LED_PORT      equ PORTB; <5:7> R,G,B
STROBE_LED_PORT      equ PORTD; <0:2> R,G,B
     ;Buttons     PORTB; <0:1> L,R
     ;Sensors     PORTE; <0:2> L,C,R
     ;Motors	  PORTC; <0:3>
     ;LCD HD44780  PORTD; <3:7> RS,E,D4,D5,D6 | PORTB; <3> D7
     ;  VSS->GND  VDD->5V  V0->contrast-pot  RW->GND  D0-D3->GND
     ;  A(bklt+)->5V/100R  K(bklt-)->GND
    
;============== Definition of variables ===============
; =========================
; BANK 0 ACCESS (0x00-0x5F)
; safe with ,a
; =========================
;<editor-fold defaultstate="collapsed" desc="BANK 0 ACCESS 0x00-0x5F">

delay1                                  EQU 0x00
delay2                                  EQU 0x01
Count                                   EQU 0x02

current_state_var                       EQU 0x03
temp_var                                EQU 0x04
current_state_symbol_var                EQU 0x05
temp_var2                               EQU 0x06
display_select_state_var                EQU 0x07

must_navigate_to_var                    EQU 0x08
next_displayed_state_click_var          EQU 0x09
cal_read_pressed_var                    EQU 0x0A
SSD_OUT_var                             EQU 0x0B
DISP_LED_OUT_VAR                        EQU 0x0C
LLI_start_pressed_var                   EQU 0x0D
;cal_floor_colour_var                    EQU 0x0E

sensor_L_reading_var                    EQU 0x0F
sensor_C_reading_var                    EQU 0x10
sensor_R_reading_var                    EQU 0x11

sensor_L_strobe_R_reading_var           EQU 0x12
sensor_L_strobe_G_reading_var           EQU 0x13
sensor_L_strobe_B_reading_var           EQU 0x14

sensor_C_strobe_R_reading_var           EQU 0x15
sensor_C_strobe_G_reading_var           EQU 0x16
sensor_C_strobe_B_reading_var           EQU 0x17

sensor_R_strobe_R_reading_var           EQU 0x18
sensor_R_strobe_G_reading_var           EQU 0x19
sensor_R_strobe_B_reading_var           EQU 0x1A

current_strobe_reading_red_var          EQU 0x1B
current_strobe_reading_green_var        EQU 0x1C
current_strobe_reading_blue_var         EQU 0x1D

sensor_L_read_colour_enum_var           EQU 0x1E
sensor_C_read_colour_enum_var           EQU 0x1F
sensor_R_read_colour_enum_var           EQU 0x20

red_light_temp_diff_var                 EQU 0x21
green_light_temp_diff_var               EQU 0x22
blue_light_temp_diff_var                EQU 0x23

red_floor_sum_delta_var                 EQU 0x24
green_floor_sum_delta_var               EQU 0x25
blue_floor_sum_delta_var                EQU 0x26
white_floor_sum_delta_var               EQU 0x27
black_floor_sum_delta_var               EQU 0x28

lowest_diff_enum_colour_var             EQU 0x29
lowest_diff_score_var                   EQU 0x2A


current_sensor_cal_red_on_red_var       EQU 0x2D
current_sensor_cal_red_on_green_var     EQU 0x2E
current_sensor_cal_red_on_blue_var      EQU 0x2F
current_sensor_cal_red_on_white_var     EQU 0x30
current_sensor_cal_red_on_black_var     EQU 0x31

current_sensor_cal_green_on_red_var     EQU 0x32
current_sensor_cal_green_on_green_var   EQU 0x33
current_sensor_cal_green_on_blue_var    EQU 0x34
current_sensor_cal_green_on_white_var   EQU 0x35
current_sensor_cal_green_on_black_var   EQU 0x36

current_sensor_cal_blue_on_red_var      EQU 0x37
current_sensor_cal_blue_on_green_var    EQU 0x38
current_sensor_cal_blue_on_blue_var     EQU 0x39
current_sensor_cal_blue_on_white_var    EQU 0x3A
current_sensor_cal_blue_on_black_var    EQU 0x3B

has_read_all_black_on_sensor_array_var	EQU 0x3E

CAP_REG_var                             EQU 0x3F
touch_delay1                            EQU 0x40
touch_delay2                            EQU 0x41
touch_delay3                            EQU 0x42
touch_delay4                            EQU 0x43
touch_delay5                            EQU 0x44
touch_adc_h                             EQU 0x45

motor_power_left_var                    EQU 0x46
motor_power_right_var                   EQU 0x47
motor_dir_left_var                      EQU 0x48    ; bit 0: 0=forward, 1=reverse
motor_dir_right_var                     EQU 0x49    ; bit 0: 0=forward, 1=reverse

touch_baseline_var                      EQU 0x4A    ; WAIT_FOR_TOUCH live baseline
touch_count_var                         EQU 0x4B    ; consecutive above-threshold readings
touch_timer_var                         EQU 0x4C    ; total touch duration (timeout guard)
touch_sample1_var                       EQU 0x4D    ; 16-sample accumulator high
touch_sample2_var                       EQU 0x4E    ; 16-sample accumulator low / result
touch_sample3_var                       EQU 0x4F    ; sample loop counter / delta temp

lcd_temp_var                            EQU 0x50    ; LCD nibble scratch (_LCD_SEND_NIBBLE)
lcd_temp2_var                           EQU 0x51    ; LCD byte scratch (LCD_CMD / LCD_CHAR)
lcd_temp3_var                           EQU 0x52    ; LCD_PRINT_HEX byte save

RACE_COL_var                            EQU 0x2B
PERCEIVED_COLOUR_AT_SENSOR_BITS_var	EQU 0x3C
DRIVING_STATE_var                       EQU 0x2C
DRIVING_STATE_SSD_DISPLAY_var		EQU 0x3D

;</editor-fold>


; =========================
; BANK 0 BANKED-ONLY (0x60-0x8C)
; use ,b on normal file-register instructions
; MOVFF still fine
; =========================
;<editor-fold defaultstate="collapsed" desc="BANK 0 BANKED 0x60-0x8C (CAL vars)">

; ================= LEFT SENSOR =================
; WHITE
CAL_L_RED_ON_WHITE_var                  EQU 0x60
CAL_L_GREEN_ON_WHITE_var                EQU 0x61
CAL_L_BLUE_ON_WHITE_var                 EQU 0x62
; RED
CAL_L_RED_ON_RED_var                    EQU 0x63
CAL_L_GREEN_ON_RED_var                  EQU 0x64
CAL_L_BLUE_ON_RED_var                   EQU 0x65
; GREEN
CAL_L_RED_ON_GREEN_var                  EQU 0x66
CAL_L_GREEN_ON_GREEN_var                EQU 0x67
CAL_L_BLUE_ON_GREEN_var                 EQU 0x68
; BLUE
CAL_L_RED_ON_BLUE_var                   EQU 0x69
CAL_L_GREEN_ON_BLUE_var                 EQU 0x6A
CAL_L_BLUE_ON_BLUE_var                  EQU 0x6B
; BLACK
CAL_L_RED_ON_BLACK_var                  EQU 0x6C
CAL_L_GREEN_ON_BLACK_var                EQU 0x6D
CAL_L_BLUE_ON_BLACK_var                 EQU 0x6E

; ================= CENTRE SENSOR =================
; WHITE
CAL_C_RED_ON_WHITE_var                  EQU 0x6F
CAL_C_GREEN_ON_WHITE_var                EQU 0x70
CAL_C_BLUE_ON_WHITE_var                 EQU 0x71
; RED
CAL_C_RED_ON_RED_var                    EQU 0x72
CAL_C_GREEN_ON_RED_var                  EQU 0x73
CAL_C_BLUE_ON_RED_var                   EQU 0x74
; GREEN
CAL_C_RED_ON_GREEN_var                  EQU 0x75
CAL_C_GREEN_ON_GREEN_var                EQU 0x76
CAL_C_BLUE_ON_GREEN_var                 EQU 0x77
; BLUE
CAL_C_RED_ON_BLUE_var                   EQU 0x78
CAL_C_GREEN_ON_BLUE_var                 EQU 0x79
CAL_C_BLUE_ON_BLUE_var                  EQU 0x7A
; BLACK
CAL_C_RED_ON_BLACK_var                  EQU 0x7B
CAL_C_GREEN_ON_BLACK_var                EQU 0x7C
CAL_C_BLUE_ON_BLACK_var                 EQU 0x7D

; ================= RIGHT SENSOR =================
; WHITE
CAL_R_RED_ON_WHITE_var                  EQU 0x7E
CAL_R_GREEN_ON_WHITE_var                EQU 0x7F
CAL_R_BLUE_ON_WHITE_var                 EQU 0x80
; RED
CAL_R_RED_ON_RED_var                    EQU 0x81
CAL_R_GREEN_ON_RED_var                  EQU 0x82
CAL_R_BLUE_ON_RED_var                   EQU 0x83
; GREEN
CAL_R_RED_ON_GREEN_var                  EQU 0x84
CAL_R_GREEN_ON_GREEN_var                EQU 0x85
CAL_R_BLUE_ON_GREEN_var                 EQU 0x86
; BLUE
CAL_R_RED_ON_BLUE_var                   EQU 0x87
CAL_R_GREEN_ON_BLUE_var                 EQU 0x88
CAL_R_BLUE_ON_BLUE_var                  EQU 0x89
; BLACK
CAL_R_RED_ON_BLACK_var                  EQU 0x8A
CAL_R_GREEN_ON_BLACK_var                EQU 0x8B
CAL_R_BLUE_ON_BLACK_var                 EQU 0x8C

;</editor-fold>
        
;=Constants
        
 ;Config Constants
ADC_AN5       EQU  00010101B   ; RE0 = left sensor
ADC_AN6       EQU  00011001B   ; RE1 = centre sensor
ADC_AN7       EQU  00011101B   ; RE2 = right sensor
       
    ;;Suggested change to
;    ADC_AN5 EQU 00101001B   ; AN5 / RE0
;    ADC_AN6 EQU 00110001B   ; AN6 / RE1
;    ADC_AN7 EQU 00111001B   ; AN7 / RE2
               
;State Constants
state_constants:
selecting_state_val equ 0x0
calibrating_state_val equ 0x1
LLI_state_val equ 0x2
feedback_color_state_val equ 0x3
osc_delay_state_val equ 0x5
 
;Calibration/Colour Detect/LLI Constants
calibration_constants:
    ;used as indexes for colour enum
RED_COLOUR_STATE_val equ    0x0
GREEN_COLOUR_STATE_val equ  0x1
BLUE_COLOUR_STATE_val equ   0x2
BLACK_COLOUR_STATE_val equ  0x3
WHITE_COLOUR_STATE_val equ 0x4
UNKNOWN_COLOUR_val equ 0x5
 
;Sensor Constants
matching_floor_to_strobe_colour_reading_diff_multiplier_val equ    0x3

    
 ;Display Constants
    ;;7Seg Display Outputs
    ;<editor-fold defaultstate="collapsed" desc="7 Seg Output Options">
    ;7 seg disp setup
    ;Common Anode disp -> 0 means on. 1 means off
    ;B0->a
    ;B1->b
    ;B2->c
    ;B3->d
    ;B4->e
    ;B5->f
    ;B6->g
    ;B = xgfedcba inverted
    ;r = x1001110 = fea
    ;L = x1000111 = fed
    ;S = x0010010 = gfdca
    r_SSD    EQU 0b00110001
    C_SSD    EQU 0b00111001
    F_SSD    EQU 0b01110001
    L_SSD    EQU 0b00111000
    O_SSD    EQU 0b00111111
    S_SSD    EQU 0b01101101

    P_SSD    EQU 0b01110011
    A_SSD    EQU 0b01110111
    U_SSD    EQU 0b00111110
    CLEAR_SSD EQU 0x00

    ;</editor-fold>

    ;;RGB LED OUTPUTS
LED_RED_OUT_val equ 0b00000001
LED_GREEN_OUT_val equ 0b00000010
LED_BLUE_OUT_val equ 0b00000100

;LLI Constants
LEFT_DRIVING_STATE_val    equ 0x0
CENTRE_DRIVING_STATE_val   equ 0x1
RIGHT_DRIVING_STATE_val    equ 0x2
STOP_DRIVING_STATE_val        equ 0x3
LOST_DRIVING_STATE_val        equ 0x4

PWM_SPEED_FULL_LEFT_val  equ 16      ; > 75% duty cycle
PWM_SPEED_FULL_RIGHT_val  equ 15      ; 75% duty cycle 
PWM_SPEED_STOP_val  equ 0       ; 0% ? motor off

; WAIT_FOR_TOUCH tuning constants
WFT_THRESH      equ 0x03    ; min delta (baseline-reading) to count as touch
WFT_DEBOUNCE    equ 0x03    ; consecutive readings required for confirmation
WFT_TIMEOUT     equ 0xC8    ; ~200 loops before timeout/baseline reset
	

 
 
;============== Reset vector ===============
    PSECT code,abs //Start of main code.
    org 00h
    
GOTO Init
ORG 0x8
    
GOTO ISR
ISR:
;<editor-fold defaultstate="collapsed" desc="ISR">

    ; Was this a PORTC IOC interrupt?
;
        ; INT0 (RB0)?
    BTFSC   INTCON,1,a          ; INT0IF set?
    CALL    INT0_HANDLER

    ; INT1 (RB1)?
    BTFSC   INTCON3,0,a         ; INT1IF set?
    CALL    INT1_HANDLER

    CALL    CLEAR_ISR
    
    RETFIE  1

CLEAR_ISR:
    BCF     INTCON,1,0         ; INT0IF = 0 (INTCON<1>)
    BCF     INTCON3,0,0        ; INT1IF = 0 (INTCON3<0>)
    RETURN

INT0_HANDLER: ;YELLOW BUTTON
    
    ;EQUALS CHECK for SELECTING state
    MOVF    current_state_var,W,a
    XORLW   selecting_state_val
    BZ        INT0_SELECTING_STATE_PRESS
    
    MOVF   current_state_var,W,a
    XORLW   calibrating_state_val
    BZ        INT0_CAL_PRESSED
    
    MOVF   current_state_var,W,a
    XORLW   LLI_state_val
    BZ        INT0_LLI_PRESSED
    
    ;;Fallback incase state doesn't have an attributed button presss function
    Call    do_reg_dump
    RETURN
    
    ;SET VARIABLE bit 0, to true
    INT0_SELECTING_STATE_PRESS:
    BSF        next_displayed_state_click_var,0,a
    RETURN
    
    INT0_CAL_PRESSED:
    BSF        cal_read_pressed_var,0,a
    RETURN
    
    INT0_LLI_PRESSED:
    BSF        LLI_start_pressed_var,0,a
    RETURN
    
    
INT1_HANDLER:;RED BUTTON
    ;RETURN immediately if in selecting state
    ;ELSE set current_state to nav to state select on next check
    
    ;;Ensure button released. This can pause program since selection is primary operation
    BTFSC   PORTB,1,a
    BRA        INT1_HANDLER
    
    ;;Check if in selecting state
    MOVLW   selecting_state_val
    CPFSEQ  current_state_var,a
    
    ;; Not in selecting state, so inside of a different state
    ;; Which means it should navigate on next NAV_STATE_IF_REQUIRED call
    BRA    INT1_SET_PENDING_NAV_TO_STATE_SELECT
    
    ;;SELECTED STATE FROM MENU, SO NOW IT'S READY TO NAV
    MOVFF    display_select_state_var,must_navigate_to_var,a
    MOVFF    current_state_symbol_var,SSD_OUT_var,a
    RETURN
    
    INT1_SET_PENDING_NAV_TO_STATE_SELECT:
    ;;Check if in feedback colour state ? lock colour as race colour and go to LLI
    MOVLW   feedback_color_state_val
    CPFSEQ  current_state_var,a
    BRA     INT1_DEFAULT_NAV_TO_SELECT

    MOVFF   sensor_C_read_colour_enum_var,RACE_COL_var
    MOVLW   LLI_state_val
    MOVWF   must_navigate_to_var,a
    RETURN

    INT1_DEFAULT_NAV_TO_SELECT:
    MOVLW    selecting_state_val
    MOVWF    must_navigate_to_var,a
    RETURN

;</editor-fold>
;============== Setup ==============
    
Init:
;<editor-fold defaultstate="collapsed" desc="Init">
    ; Initialize Port A (example on p. 121 of datasheet)
    MOVLB        0x0F
    
    
    ; ---- Oscillator: 4 MHz internal ----
    ; OSCCON IRCF[2:0] = 110 => 4 MHz
    BSF     OSCCON, 6, a    ; IRCF2 = 1
    BCF     OSCCON, 5, a    ; IRCF1 = 0
    BSF     OSCCON, 4, a    ; IRCF0 = 1
    
    
    ; ---- Analog/Digital configuration (Bank 15) ----
    MOVLB   0xF
    CLRF    ANSELA, b       ; PORTA = all digital
    CLRF    ANSELB, b       ; PORTB = all digital
    CLRF    ANSELC, b       ; PORTC = all digital
    CLRF    ANSELD, b       ; PORTD = all digital
    MOVLW   00000111B
    MOVWF   ANSELE, b       ; RE0, RE1, RE2 = analog inputs for sensors
    MOVLB   0
    
    ; ----PORTA: (SSD) ----
    CLRF    TRISA, a
    CLRF    PORTA, a
    
    ; ---- PORTE: RE0-RE2 = analog inputs (sensors), RE3 = output ----
    MOVLW   00000111B
    MOVWF   TRISE, a
    CLRF    PORTE, a

    ; ---- ADC setup ----
    MOVLW   ADC_AN5             ; AN5 (left sensor, RE0)
    MOVWF   ADCON0, a
    CLRF    ADCON1, a           ; Vref+ = VDD, Vref- = VSS
    MOVLW   00101011B           ; Left-justify result, 8 Tad, Fosc/32
    MOVWF   ADCON2, a

    
    CLRF        PORTB,a
    CLRF        LATB,a
    CLRF        ANSELB,b
    BSF        TRISB,0,a
    BSF        TRISB,1,a
    ;PORT-> Display LED <5:7>
    BCF        TRISB,5,a
    BCF        TRISB,6,a
    BCF        TRISB,7,a
    BCF        TRISB,3,a           ; RB3 = output (LCD D7)
    
    CLRF    TRISD, a
    CLRF    PORTD, a
    
    ; Optional: internal pull-ups for PORTB (if using active-low buttons to GND)
    ; BCF   INTCON2,7,0         ; RBPU=0 enables pull-ups

    ; Choose edge: INTEDG0 (INTCON2<6>), INTEDG1 (INTCON2<5>)
    ; 1 = rising edge, 0 = falling edge
    BSF     INTCON2,6,0        ; INTEDG0 = 1 (RB0 rising)
    BSF     INTCON2,5,0        ; INTEDG1 = 1 (RB1 rising)

    ; Clear flags
    BCF     INTCON,1,0         ; INT0IF = 0 (INTCON<1>)
    BCF     INTCON3,0,0        ; INT1IF = 0 (INTCON3<0>)

    ; Enable interrupts
    BSF     INTCON,4,0         ; INT0IE = 1 (INTCON<4>)
    BSF     INTCON3,3,0        ; INT1IE = 1 (INTCON3<3>)

    ; Global enable
    BSF     INTCON,7,0         ; GIE = 1 (INTCON<7>)

    MOVLB        0x00
    
    CLRF    must_navigate_to_var,a
    ;Default values for sensor cal.
    ;<editor-fold defaultstate="collapsed" desc="SENSOR CAL DEFAULT VALUES">
    ; Real measurements ? sensor_plot.py dump 2026-04-11
    ;================= RED surface =================
    ; L: R=10 G=23 B=8  C: R=39 G=50 B=29  R: R=30 G=17 B=6
    MOVLW   10
    MOVWF   CAL_L_RED_ON_RED_var,b
    MOVLW   23
    MOVWF   CAL_L_GREEN_ON_RED_var,b
    MOVLW   8
    MOVWF   CAL_L_BLUE_ON_RED_var,b
    MOVLW   39
    MOVWF   CAL_C_RED_ON_RED_var,b
    MOVLW   50
    MOVWF   CAL_C_GREEN_ON_RED_var,b
    MOVLW   29
    MOVWF   CAL_C_BLUE_ON_RED_var,b
    MOVLW   30
    MOVWF   CAL_R_RED_ON_RED_var,b
    MOVLW   17
    MOVWF   CAL_R_GREEN_ON_RED_var,b
    MOVLW   6
    MOVWF   CAL_R_BLUE_ON_RED_var,b
    ;================= GREEN surface =================
    ; L: R=3 G=28 B=24  C: R=14 G=60 B=54  R: R=9 G=45 B=12
    MOVLW   3
    MOVWF   CAL_L_RED_ON_GREEN_var,b
    MOVLW   28
    MOVWF   CAL_L_GREEN_ON_GREEN_var,b
    MOVLW   24
    MOVWF   CAL_L_BLUE_ON_GREEN_var,b
    MOVLW   14
    MOVWF   CAL_C_RED_ON_GREEN_var,b
    MOVLW   60
    MOVWF   CAL_C_GREEN_ON_GREEN_var,b
    MOVLW   54
    MOVWF   CAL_C_BLUE_ON_GREEN_var,b
    MOVLW   9
    MOVWF   CAL_R_RED_ON_GREEN_var,b
    MOVLW   45
    MOVWF   CAL_R_GREEN_ON_GREEN_var,b
    MOVLW   12
    MOVWF   CAL_R_BLUE_ON_GREEN_var,b
    ;================= BLUE surface =================
    ; L: R=1 G=10 B=15  C: R=1 G=18 B=28  R: R=2 G=17 B=13
    MOVLW   1
    MOVWF   CAL_L_RED_ON_BLUE_var,b
    MOVLW   10
    MOVWF   CAL_L_GREEN_ON_BLUE_var,b
    MOVLW   15
    MOVWF   CAL_L_BLUE_ON_BLUE_var,b
    MOVLW   1
    MOVWF   CAL_C_RED_ON_BLUE_var,b
    MOVLW   18
    MOVWF   CAL_C_GREEN_ON_BLUE_var,b
    MOVLW   28
    MOVWF   CAL_C_BLUE_ON_BLUE_var,b
    MOVLW   2
    MOVWF   CAL_R_RED_ON_BLUE_var,b
    MOVLW   17
    MOVWF   CAL_R_GREEN_ON_BLUE_var,b
    MOVLW   13
    MOVWF   CAL_R_BLUE_ON_BLUE_var,b
    ;================= WHITE surface =================
    ; L: R=16 G=57 B=43  C: R=53 G=120 B=111  R: R=38 G=75 B=30
    MOVLW   16
    MOVWF   CAL_L_RED_ON_WHITE_var,b
    MOVLW   57
    MOVWF   CAL_L_GREEN_ON_WHITE_var,b
    MOVLW   43
    MOVWF   CAL_L_BLUE_ON_WHITE_var,b
    MOVLW   53
    MOVWF   CAL_C_RED_ON_WHITE_var,b
    MOVLW   120
    MOVWF   CAL_C_GREEN_ON_WHITE_var,b
    MOVLW   111
    MOVWF   CAL_C_BLUE_ON_WHITE_var,b
    MOVLW   38
    MOVWF   CAL_R_RED_ON_WHITE_var,b
    MOVLW   75
    MOVWF   CAL_R_GREEN_ON_WHITE_var,b
    MOVLW   30
    MOVWF   CAL_R_BLUE_ON_WHITE_var,b
    ;================= BLACK surface =================
    ; L: R=1 G=4 B=4  C: R=3 G=7 B=7  R: R=1 G=4 B=3
    MOVLW   1
    MOVWF   CAL_L_RED_ON_BLACK_var,b
    MOVLW   4
    MOVWF   CAL_L_GREEN_ON_BLACK_var,b
    MOVLW   4
    MOVWF   CAL_L_BLUE_ON_BLACK_var,b
    MOVLW   3
    MOVWF   CAL_C_RED_ON_BLACK_var,b
    MOVLW   7
    MOVWF   CAL_C_GREEN_ON_BLACK_var,b
    MOVLW   7
    MOVWF   CAL_C_BLUE_ON_BLACK_var,b
    MOVLW   1
    MOVWF   CAL_R_RED_ON_BLACK_var,b
    MOVLW   4
    MOVWF   CAL_R_GREEN_ON_BLACK_var,b
    MOVLW   3
    MOVWF   CAL_R_BLUE_ON_BLACK_var,b
;</editor-fold>

    ; PWM motor init ? CCP1 on RC2 (right/IN3), CCP2 on RC1 (left/IN1)
    ; IN2 and IN4 are grounded on the TC1508A board ? forward/coast only
    movlw   19
    movwf   PR2, a              ; PR2=19 -> 50 kHz PWM period at 4 MHz
    clrf    LATC, a
    bcf     TRISC, 2, a         ; RC2/CCP1 = output (right motor IN3)
    bcf     TRISC, 1, a         ; RC1/CCP2 = output (left motor IN1)
    bcf     TRISC, 0, a         ; RC0 = output (left motor IN2 ? reverse)
    bcf     TRISC, 3, a         ; RC3 = output (right motor IN4 ? reverse)
    BCF     LATC, 0, a          ; IN2 low (not reversing)
    BCF     LATC, 3, a          ; IN4 low (not reversing)
    clrf    T2CON, a
    clrf    TMR2, a
    BSF     CCP1CON, 3, a       ; CCP1: PWM mode (1100)
    BSF     CCP1CON, 2, a
    BCF     CCP1CON, 1, a
    BCF     CCP1CON, 0, a
    BSF     CCP2CON, 3, a       ; CCP2: PWM mode (1100)
    BSF     CCP2CON, 2, a
    BCF     CCP2CON, 1, a
    BCF     CCP2CON, 0, a
    bsf     T2CON, 2, a         ; Enable Timer2
    clrf    motor_power_left_var, a
    clrf    motor_power_right_var, a
    clrf    motor_dir_left_var, a
    clrf    motor_dir_right_var, a
    movlw   PWM_SPEED_STOP_val
    movwf   CCPR1L, a           ; Right motor stopped
    movwf   CCPR2L, a           ; Left motor stopped

    ; LLI default race colour = RED (index 0). LLI_SELECT_COLOUR can override this.
    MOVLW   RED_COLOUR_STATE_val
    MOVWF   RACE_COL_var, a

    ; Initialise driving state to LOST so display is defined from the start
    MOVLW   LOST_DRIVING_STATE_val
    MOVWF   DRIVING_STATE_var, a

    CALL    LCD_INIT

;</editor-fold>


;<editor-fold defaultstate="collapsed" desc="COPYABLE FOLD">
;</editor-fold>

;============ Main program ==============
Main:
    GOTO STATE_SELECT_LOOP
    goto         Main         ; do this loop forever
    
    
    
;<editor-fold defaultstate="collapsed" desc="SELECT STATE SECTION">
    
    
    
STATE_SELECT_LOOP:
;<editor-fold defaultstate="collapsed" desc="SELECT STATE LOOP">
    ;;Interrupts cause change in state inside this loop
    
    ;;This loop sets up display and selection for the state
    
    ;;The first block is storing the selectable state as data
    ;;The second is loading the correct display bits for that state's selection
    
    MOVLW   0x0
    MOVWF   current_state_var,a
    MOVF    current_state_var, W, a
    
    MOVLW   calibrating_state_val
    MOVWF   display_select_state_var,a
    MOVLW   C_SSD
    MOVWF   current_state_symbol_var,a
    call    STATE_SELECT_INPUT
    
    MOVLW   feedback_color_state_val
    MOVWF   display_select_state_var,a
    MOVLW   F_SSD
    MOVWF   current_state_symbol_var,a
    call    STATE_SELECT_INPUT
    
    MOVLW   LLI_state_val
    MOVWF   display_select_state_var,a
    MOVLW   L_SSD
    MOVWF   current_state_symbol_var,a
    call    STATE_SELECT_INPUT
    
    MOVLW   osc_delay_state_val
    MOVWF   display_select_state_var,a
    MOVLW   O_SSD
    MOVWF   current_state_symbol_var,a
    call    STATE_SELECT_INPUT
       
;</editor-fold>
GOTO    STATE_SELECT_LOOP
    
    
STATE_SELECT_INPUT:
;<editor-fold defaultstate="collapsed" desc="STATE SELECT INPUT">
    CLRF    next_displayed_state_click_var,a
    
    MOVLW    0x1
    MOVWF    temp_var2,a
    
    movlw   0x60
    movwf   delay1, a
outer_state_inp:
    movlw   0xFF
    movwf   delay2, a
inner_state_inp:
    ;Logic Block (keeps being polled)
    

    ;;B0 CLICKED AND RELEASED in interrupt
    BTFSC    next_displayed_state_click_var,0,a
    RETURN; goes to the STATE SELECT LOOP to acquire the next values
    
    ;;check PORT B1 triggered by interrupt which will navigate in the
    CALL    NAV_STATE_IF_REQUIRED; case that it was indeed clicked
    
    ;;FLASH THE LED ON AND OFF in half periods while waiting for button press
    BTFSC   temp_var2,0,a
    BRA        ssi_block_1
    MOVLW   CLEAR_SSD
    BRA        ssi_block_2
    ssi_block_1:
    MOVLW   0x30;HALF THE OUTER DELAY BITS
    
    CPFSGT  delay1,a   ;;Clear
    CLRF    temp_var2,a
    
    MOVF    current_state_symbol_var,W,a

    ssi_block_2:
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    ;End Logic Block
    
    decfsz  delay2, f, a
    goto    inner_state_inp
    decfsz  delay1, f, a
    goto    outer_state_inp
    
;</editor-fold>
;There is an interrupt triggered return inside of here
GOTO STATE_SELECT_INPUT
    
STATE_SELECT_INPUT_PRESSED:
    
;<editor-fold defaultstate="collapsed" desc="STATE_SELECT_INPUT_PRESSED">
    
    BTFSC   PORTB,1,a;;Make sure the button is released
    BRA        STATE_SELECT_INPUT_PRESSED
;
    MOVFF   display_select_state_var,current_state_var,a
    MOVFF   current_state_symbol_var,SSD_OUT_var,a
    call    SET_SSD
    call    TIMEOUT_333ms
    call    TIMEOUT_333ms
    call    TIMEOUT_333ms
    call    TIMEOUT_333ms
    ;</editor-fold>
    bra        STATE_NAV

STATE_NAV:
;<editor-fold defaultstate="collapsed" desc="Navigate to the new state">
    MOVFF   must_navigate_to_var,current_state_var,a
    
    ;NOT EQUALS CHECK
    MOVF    current_state_var,W, a        ; WREG = state
    XORLW    calibrating_state_val       ; WREG = state ^ lit
    BZ        to_cal            ; if WREG == 0 (equal), skip next
    
    ;NOT EQUALS CHECK
    MOVF    current_state_var,W, a        ; WREG = state
    XORLW    LLI_state_val            ; WREG = state ^ lit
    BZ        to_LLI
    
    ;NOT EQUALS CHECK
    MOVF    current_state_var,W, a        ; WREG = state
    XORLW    feedback_color_state_val        ; WREG = state ^ lit
    BZ        to_colour_feedback
    
    ;NOT EQUALS CHECK
    MOVF    current_state_var,W, a        ; WREG = state
    XORLW    osc_delay_state_val        ; WREG = state ^ lit
    BZ        to_osc_delay
;;If the current set state is not found (eg selecting_state_val = 0x0), go select a valid state
    GOTO    STATE_SELECT_LOOP
to_cal:
    GOTO    CAL_STATE
to_LLI:
    GOTO    LLI_STATE
to_colour_feedback:
    GOTO    FEEDBACK_COLOUR_STATE
to_osc_delay:
    GOTO    OSC_DELAY_STATE
;</editor-fold>

    
;</editor-fold>
    
NAV_STATE_IF_REQUIRED:
;<editor-fold defaultstate="collapsed" desc="NAV_STATE_IF_REQUIRED">
    MOVF    must_navigate_to_var,W,a
    CPFSEQ  current_state_var,a
    BRA        NSIR_CHANGE_REQUIRED
    
    ;;CHANGE NOT REQUIRED
    return
    
    ;;CHANGE REQUIRED|
    NSIR_CHANGE_REQUIRED:
    MOVWF   current_state_var,a
;    POP        ;;Prevents stack overflow after ~30 change required calls
    GOTO    STATE_NAV
    
;</editor-fold>
RETURN
    
;<editor-fold defaultstate="collapsed" desc="COPYABLE FOLD">
;</editor-fold>
    
CAL_STATE:
;<editor-fold defaultstate="collapsed" desc="CAL SECTION">

;<editor-fold defaultstate="collapsed" desc="CAL_STATE">
    
    MOVLW   C_SSD
    MOVWF   current_state_symbol_var,a
    MOVFF   current_state_symbol_var,SSD_OUT_var
    call    SET_SSD
    call    FLASH_RGB_DISP_DELAYED
    
    ;Cal Red
    call    set_disp_rgb_red
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    call    STROBE_SAVE_CAL_RED_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal Green
    call    set_disp_rgb_green
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    call    STROBE_SAVE_CAL_GREEN_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal Blue
    call    set_disp_rgb_blue
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    call    STROBE_SAVE_CAL_BLUE_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal White
    call    set_disp_rgb_white
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    call    STROBE_SAVE_CAL_WHITE_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal Black
    call    set_disp_rgb_black
    call    set_disp_SSD_dot
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    call    STROBE_SAVE_CAL_BLACK_FLOOR
    call    clear_disp_SSD_dot
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    MOVLW   feedback_color_state_val
    MOVWF   must_navigate_to_var, a
    
    call    NAV_STATE_IF_REQUIRED
;</editor-fold>
GOTO    CAL_STATE
    
    
    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE:
    ;<editor-fold defaultstate="collapsed" desc="WAIT FOR LEFT BUTTON PRESS CAL STATE">
    BTFSS   cal_read_pressed_var,0,a
    BRA        WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    WAIT_FOR_LEFT_BUTTON_RELEASE_CAL_STATE:
    BTFSC    PORTB,0,a
    BRA WAIT_FOR_LEFT_BUTTON_RELEASE_CAL_STATE
    BCF cal_read_pressed_var,0,a
    ;</editor-fold>
    return
    
    
   
    
    STROBE_SAVE_CAL_RED_FLOOR:
    call    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var,CAL_L_RED_ON_RED_var
    MOVFF   sensor_L_strobe_G_reading_var,CAL_L_GREEN_ON_RED_var
    MOVFF   sensor_L_strobe_B_reading_var,CAL_L_BLUE_ON_RED_var
    
    MOVFF   sensor_C_strobe_R_reading_var,CAL_C_RED_ON_RED_var
    MOVFF   sensor_C_strobe_G_reading_var,CAL_C_GREEN_ON_RED_var
    MOVFF   sensor_C_strobe_B_reading_var,CAL_C_BLUE_ON_RED_var
    
    MOVFF   sensor_R_strobe_R_reading_var,CAL_R_RED_ON_RED_var
    MOVFF   sensor_R_strobe_G_reading_var,CAL_R_GREEN_ON_RED_var
    MOVFF   sensor_R_strobe_B_reading_var,CAL_R_BLUE_ON_RED_var
    return
    
    STROBE_SAVE_CAL_GREEN_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var,CAL_L_RED_ON_GREEN_var
    MOVFF   sensor_L_strobe_G_reading_var,CAL_L_GREEN_ON_GREEN_var
    MOVFF   sensor_L_strobe_B_reading_var,CAL_L_BLUE_ON_GREEN_var

    MOVFF   sensor_C_strobe_R_reading_var,CAL_C_RED_ON_GREEN_var
    MOVFF   sensor_C_strobe_G_reading_var,CAL_C_GREEN_ON_GREEN_var
    MOVFF   sensor_C_strobe_B_reading_var,CAL_C_BLUE_ON_GREEN_var

    MOVFF   sensor_R_strobe_R_reading_var,CAL_R_RED_ON_GREEN_var
    MOVFF   sensor_R_strobe_G_reading_var,CAL_R_GREEN_ON_GREEN_var
    MOVFF   sensor_R_strobe_B_reading_var,CAL_R_BLUE_ON_GREEN_var
    RETURN


STROBE_SAVE_CAL_BLUE_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var,CAL_L_RED_ON_BLUE_var
    MOVFF   sensor_L_strobe_G_reading_var,CAL_L_GREEN_ON_BLUE_var
    MOVFF   sensor_L_strobe_B_reading_var,CAL_L_BLUE_ON_BLUE_var

    MOVFF   sensor_C_strobe_R_reading_var,CAL_C_RED_ON_BLUE_var
    MOVFF   sensor_C_strobe_G_reading_var,CAL_C_GREEN_ON_BLUE_var
    MOVFF   sensor_C_strobe_B_reading_var,CAL_C_BLUE_ON_BLUE_var

    MOVFF   sensor_R_strobe_R_reading_var,CAL_R_RED_ON_BLUE_var
    MOVFF   sensor_R_strobe_G_reading_var,CAL_R_GREEN_ON_BLUE_var
    MOVFF   sensor_R_strobe_B_reading_var,CAL_R_BLUE_ON_BLUE_var
    RETURN


STROBE_SAVE_CAL_WHITE_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var,CAL_L_RED_ON_WHITE_var
    MOVFF   sensor_L_strobe_G_reading_var,CAL_L_GREEN_ON_WHITE_var
    MOVFF   sensor_L_strobe_B_reading_var,CAL_L_BLUE_ON_WHITE_var

    MOVFF   sensor_C_strobe_R_reading_var,CAL_C_RED_ON_WHITE_var
    MOVFF   sensor_C_strobe_G_reading_var,CAL_C_GREEN_ON_WHITE_var
    MOVFF   sensor_C_strobe_B_reading_var,CAL_C_BLUE_ON_WHITE_var

    MOVFF   sensor_R_strobe_R_reading_var,CAL_R_RED_ON_WHITE_var
    MOVFF   sensor_R_strobe_G_reading_var,CAL_R_GREEN_ON_WHITE_var
    MOVFF   sensor_R_strobe_B_reading_var,CAL_R_BLUE_ON_WHITE_var
    RETURN


STROBE_SAVE_CAL_BLACK_FLOOR:
    CALL    strobe_and_save_sensor_readings
    MOVFF   sensor_L_strobe_R_reading_var,CAL_L_RED_ON_BLACK_var
    MOVFF   sensor_L_strobe_G_reading_var,CAL_L_GREEN_ON_BLACK_var
    MOVFF   sensor_L_strobe_B_reading_var,CAL_L_BLUE_ON_BLACK_var

    MOVFF   sensor_C_strobe_R_reading_var,CAL_C_RED_ON_BLACK_var
    MOVFF   sensor_C_strobe_G_reading_var,CAL_C_GREEN_ON_BLACK_var
    MOVFF   sensor_C_strobe_B_reading_var,CAL_C_BLUE_ON_BLACK_var

    MOVFF   sensor_R_strobe_R_reading_var,CAL_R_RED_ON_BLACK_var
    MOVFF   sensor_R_strobe_G_reading_var,CAL_R_GREEN_ON_BLACK_var
    MOVFF   sensor_R_strobe_B_reading_var,CAL_R_BLUE_ON_BLACK_var
    RETURN
    

;</editor-fold>

    
FEEDBACK_COLOUR_STATE:
;<editor-fold defaultstate="collapsed" desc="FEEDBACK COLOUR SECTION">
;<editor-fold defaultstate="collapsed" desc="FEEDBACK COLOUR STATE">
    MOVLW   F_SSD
    MOVWF   current_state_symbol_var,a
    MOVFF   current_state_symbol_var,SSD_OUT_var
    call    SET_SSD
    
    call    poll_sensors_for_average_detected_colour
    call    disp_centre_sensor_stored_colour
    
    call    NAV_STATE_IF_REQUIRED
GOTO    FEEDBACK_COLOUR_STATE
    
    
;</editor-fold>
   
 
    disp_centre_sensor_stored_colour:
    call    clear_disp_SSD_dot
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   RED_COLOUR_STATE_val
    BZ        disp_sensing_red
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   GREEN_COLOUR_STATE_val
    BZ        disp_sensing_green
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   BLUE_COLOUR_STATE_val
    BZ        disp_sensing_blue
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   WHITE_COLOUR_STATE_val
    BZ        disp_sensing_white
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   BLACK_COLOUR_STATE_val
    BZ        disp_sensing_black
        
    return
    
    disp_sensing_red:
	call	set_disp_rgb_red
	return
    disp_sensing_green:
	call	set_disp_rgb_green
	return
    disp_sensing_blue:
	call	set_disp_rgb_blue
	return
    disp_sensing_white:
	call	set_disp_rgb_white
	return
    disp_sensing_black:
	call    set_disp_rgb_black
	call    set_disp_SSD_dot
	return
;</editor-fold>

    ; Sets the RGB display LED to match RACE_COL_var (used in LLI_STATE before touch start)
    set_disp_to_race_colour:
    MOVF    RACE_COL_var,W,a
    XORLW   RED_COLOUR_STATE_val
    BZ      race_col_red

    MOVF    RACE_COL_var,W,a
    XORLW   GREEN_COLOUR_STATE_val
    BZ      race_col_green

    MOVF    RACE_COL_var,W,a
    XORLW   BLUE_COLOUR_STATE_val
    BZ      race_col_blue

    MOVF    RACE_COL_var,W,a
    XORLW   WHITE_COLOUR_STATE_val
    BZ      race_col_white

    ; Default (black or unknown): show white so something is visible
    call    set_disp_rgb_white
    RETURN

    race_col_red:
    call    set_disp_rgb_red
    RETURN
    race_col_green:
    call    set_disp_rgb_green
    RETURN
    race_col_blue:
    call    set_disp_rgb_blue
    RETURN
    race_col_white:
    call    set_disp_rgb_white
    RETURN
    
    
LLI_STATE:
;<editor-fold defaultstate="collapsed" desc="LLI SECTION">
    MOVLW   L_SSD
    MOVWF   current_state_symbol_var,a
    MOVFF   current_state_symbol_var,SSD_OUT_var
    call    SET_SSD
    call    FLASH_RGB_DISP_DELAYED
    call    set_disp_to_race_colour     ; hold race colour on LED while waiting for touch

    call    LLI_SELECT_COLOUR
    call    WAIT_FOR_LLI_TOUCH_START
    
    
    LLI_NAV_LOOP:
    call    POLL_SENSORS_FOR_NEWEST_DRIVING_STATE_AND_UPDATE_STATE
    
    MOVF    DRIVING_STATE_var,W,a
    XORLW    LEFT_DRIVING_STATE_val
    BZ    set_LLI_left
    
    MOVF    DRIVING_STATE_var,W,a
    XORLW    CENTRE_DRIVING_STATE_val
    BZ    set_LLI_centre
    
    MOVF    DRIVING_STATE_var,W,a
    XORLW    RIGHT_DRIVING_STATE_val
    BZ    set_LLI_right
    
    MOVF    DRIVING_STATE_var,W,a
    XORLW    LOST_DRIVING_STATE_val
    BZ    set_LLI_lost
    
    MOVF    DRIVING_STATE_var,W,a
    XORLW    STOP_DRIVING_STATE_val
    BZ    LLI_NAV_STOP
    
    call    NAV_STATE_IF_REQUIRED

    GOTO    LLI_NAV_LOOP
    
    LLI_NAV_STOP:
    call    set_LLI_stop

    LLI_STOP_WAIT:
    BTFSS   PORTB, 1, a             ; skip if RB1 pressed
    GOTO    LLI_STOP_WAIT
    LLI_STOP_RB1_RELEASE:
    BTFSC   PORTB, 1, a             ; wait for release
    GOTO    LLI_STOP_RB1_RELEASE
    MOVLW   selecting_state_val
    MOVWF   must_navigate_to_var, a
    call    NAV_STATE_IF_REQUIRED
    GOTO    LLI_STOP_WAIT
    
; LEFT_DRIVING_STATE_val    equ 0x0
; CENTRE_DRIVING_STATE_val    equ 0x1
; RIGHT_DRIVING_STATE_val    equ 0x2
; STOP_DRIVING_STATE_val    equ 0x3
; LOST_DRIVING_STATE_val    equ 0x4
    set_LLI_left:
    MOVLW    LEFT_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    MOVLW    L_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   motor_power_left_var, a
    call    set_motor_left
    MOVLW   PWM_SPEED_FULL_LEFT_val
    MOVWF   motor_power_right_var, a
    call    set_motor_right
    GOTO    LLI_NAV_LOOP        ; reached via BZ branch ? must loop, not return

    set_LLI_centre:
    MOVLW    CENTRE_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    MOVLW    C_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    MOVLW   PWM_SPEED_FULL_LEFT_val
    MOVWF   motor_power_left_var, a
    call    set_motor_left
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   motor_power_right_var, a
    call    set_motor_right
    GOTO    LLI_NAV_LOOP        ; reached via BZ branch ? must loop, not return

    set_LLI_right:
    MOVLW    RIGHT_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    MOVLW    r_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   motor_power_left_var, a
    call    set_motor_left
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   motor_power_right_var, a
    call    set_motor_right
    GOTO    LLI_NAV_LOOP        ; reached via BZ branch ? must loop, not return

    set_LLI_lost:
    MOVLW    LOST_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    MOVLW    U_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   motor_power_left_var, a
    call    set_motor_left
    MOVLW   PWM_SPEED_FULL_RIGHT_val
    MOVWF   motor_power_right_var, a
    call    set_motor_right
    GOTO    LLI_NAV_LOOP        ; reached via BZ branch ? must loop, not return
    set_LLI_stop:
    MOVLW    STOP_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    
    MOVLW    U_SSD
    MOVWF    SSD_OUT_var,a
    call     SET_SSD
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   motor_power_left_var, a
    call    set_motor_left
    MOVWF   motor_power_right_var, a
    call    set_motor_right
    return
    
    
    ; Left motor: RC1/CCP2=IN1 (forward PWM), RC0=IN2 (reverse digital)
    ; motor_dir_left_var bit 0: 0=forward, 1=reverse
    set_motor_left:
    BTFSC   motor_dir_left_var, 0, a    ; skip if forward
    BRA     set_motor_left_rev
    BCF     LATC, 0, a                  ; IN2 low
    MOVF    motor_power_left_var, W, a
    MOVWF   CCPR2L, a                   ; IN1 PWM
    RETURN
    set_motor_left_rev:
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR2L, a                   ; IN1 off
    BSF     LATC, 0, a                  ; IN2 high ? full reverse
    RETURN

    ; Right motor: RC2/CCP1=IN3 (forward PWM), RC3=IN4 (reverse digital)
    ; motor_dir_right_var bit 0: 0=forward, 1=reverse
    set_motor_right:
    BTFSC   motor_dir_right_var, 0, a   ; skip if forward
    BRA     set_motor_right_rev
    BCF     LATC, 3, a                  ; IN4 low
    MOVF    motor_power_right_var, W, a
    MOVWF   CCPR1L, a                   ; IN3 PWM
    RETURN
    set_motor_right_rev:
    MOVLW   PWM_SPEED_STOP_val
    MOVWF   CCPR1L, a                   ; IN3 off
    BSF     LATC, 3, a                  ; IN4 high ? full reverse
    RETURN


    WAIT_FOR_LLI_TOUCH_START:
    CALL    WAIT_FOR_TOUCH
    RETURN
    
; ============================================================
; MAIN_CAP_ROUTINE: samples RB2/AN8 twice via CTMU, sets CAP_REG_var if touch detected
; Touch detected = ADC reading < 0x13 (baseline ~0x17, touch ~0x10)
MAIN_CAP_ROUTINE:
    CALL    CAP_TOUCH_ROUTINE
    CALL    _TOUCH_1S_DELAY
    CALL    CAP_TOUCH_ROUTINE   ; Second sample to confirm

    MOVLW   0x13                ; threshold midpoint: touch ~0x10, no-touch ~0x17
    CPFSLT  touch_adc_h, a     ; skip if touch_adc_h < 0x13 (touch detected)
    BRA     MAIN_CAP_NO_TOUCH
    SETF    CAP_REG_var, a
    BRA     MAIN_CAP_DONE

MAIN_CAP_NO_TOUCH:
    CLRF    CAP_REG_var, a

MAIN_CAP_DONE:
    ; Restore ADCON for sensor readings
    MOVLB   0xF
    BCF     ANSELB, 2, b        ; RB2 back to digital
    MOVLB   0x0
    CLRF    ADCON1, a
    MOVLW   00101011B           ; restore sensor ADC timing
    MOVWF   ADCON2, a
    RETURN


; ============================================================
; WAIT_FOR_TOUCH: blocks until a confirmed touch on RB2/AN8.
; Self-calibrates baseline (4 readings) on entry, then tracks drift.
; 16-sample averaging, debounce (WFT_DEBOUNCE), timeout guard (WFT_TIMEOUT).
; Restores ANSELB/ADCON before returning.
; Clobbers: touch_adc_h, touch_baseline_var, touch_count_var, touch_timer_var,
;           touch_sample1_var, touch_sample2_var, touch_sample3_var
WAIT_FOR_TOUCH:
    ; --- Calibrate baseline: average 4 readings ---
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    MOVWF   touch_baseline_var, a
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_baseline_var, f, a
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_baseline_var, f, a
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_baseline_var, f, a
    ; Divide by 4 (two right-rotates, mask carry-in bits)
    RRNCF   touch_baseline_var, f, a
    RRNCF   touch_baseline_var, f, a
    MOVLW   0x3F
    ANDWF   touch_baseline_var, f, a
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a

WFT_POLL:
    ; Average 16 samples to reduce noise floor
    CLRF    touch_sample1_var, a    ; accumulator high
    CLRF    touch_sample2_var, a    ; accumulator low
    MOVLW   0x10
    MOVWF   touch_sample3_var, a
WFT_AVG:
    CALL    CAP_TOUCH_ROUTINE
    MOVF    touch_adc_h, W, a
    ADDWF   touch_sample2_var, f, a
    MOVLW   0x00
    ADDWFC  touch_sample1_var, f, a
    DECFSZ  touch_sample3_var, f, a
    BRA     WFT_AVG
    ; Divide 16-bit sum by 16 (right-shift 4) -> result in touch_sample2_var
    SWAPF   touch_sample2_var, f, a
    MOVLW   0x0F
    ANDWF   touch_sample2_var, f, a
    SWAPF   touch_sample1_var, W, a
    ANDLW   0xF0
    IORWF   touch_sample2_var, f, a
    MOVFF   touch_sample2_var, touch_adc_h

    ; delta = baseline - reading (positive = touch pulled reading down)
    MOVF    touch_adc_h, W, a
    SUBWF   touch_baseline_var, W, a
    BN      WFT_DRIFT_UP            ; negative = reading rose above baseline

    MOVWF   touch_sample3_var, a    ; store delta as temp
    MOVLW   WFT_THRESH
    CPFSGT  touch_sample3_var, a    ; skip if delta > WFT_THRESH
    BRA     WFT_NO_TOUCH

    ; Above threshold ? possible touch
    INCF    touch_count_var, f, a
    INCF    touch_timer_var, f, a
    MOVLW   WFT_TIMEOUT
    CPFSLT  touch_timer_var, a      ; skip if touch_timer < WFT_TIMEOUT
    BRA     WFT_TIMEOUT_RST
    MOVLW   WFT_DEBOUNCE
    CPFSGT  touch_count_var, a      ; skip if touch_count > WFT_DEBOUNCE
    BRA     WFT_POLL

    ; *** TOUCH CONFIRMED ? restore ADC and return ***
    MOVLB   0xF
    BCF     ANSELB, 2, b
    MOVLB   0x0
    CLRF    ADCON1, a
    MOVLW   00101011B
    MOVWF   ADCON2, a
    RETURN

WFT_DRIFT_UP:
    INCF    touch_baseline_var, f, a
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a
    BRA     WFT_POLL

WFT_NO_TOUCH:
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a
    MOVF    touch_adc_h, W, a
    CPFSGT  touch_baseline_var, a   ; skip if baseline > reading
    BRA     WFT_BL_LOW
    DECF    touch_baseline_var, f, a
    BRA     WFT_POLL
WFT_BL_LOW:
    CPFSLT  touch_baseline_var, a   ; skip if baseline < reading
    BRA     WFT_POLL                ; equal: do nothing
    INCF    touch_baseline_var, f, a
    BRA     WFT_POLL

WFT_TIMEOUT_RST:
    MOVFF   touch_adc_h, touch_baseline_var
    CLRF    touch_count_var, a
    CLRF    touch_timer_var, a
    BRA     WFT_POLL


; ============================================================
; CAP_TOUCH_ROUTINE: CTMU-based cap touch on RB2/AN8 -> touch_adc_h
; Self-contained: manages ANSELB, ADC, and CTMU internally.
; CTMU regs at 0xF43-0xF45 are below the access bank ? must use banked (,b) access.
CAP_TOUCH_ROUTINE:
    ; 1. Discharge RB2
    MOVLB   0xF
    BCF     ANSELB, 2, b        ; digital mode
    MOVLB   0x0
    BCF     TRISB, 2, a         ; output
    BCF     LATB, 2, a          ; drive low ? discharge pad
    NOP
    NOP

    ; 2. Switch RB2 to analog input
    BSF     TRISB, 2, a
    MOVLB   0xF
    BSF     ANSELB, 2, b        ; analog (AN8)
    MOVLB   0x0

    ; 3. Configure ADC for AN8
    MOVLW   0x21                ; CHS = AN8 (bits[6:2]=01000), ADON = 1
    MOVWF   ADCON0, a
    CLRF    ADCON1, a           ; Vref = VDD/VSS
    MOVLW   00100110B           ; ADFM=0, ACQT=100 (8 Tad=128us), ADCS=110 (Fosc/64)
    MOVWF   ADCON2, a

    ; 4. Configure CTMU (regs at 0xF43-0xF45, below access bank ? banked access required)
    MOVLB   0xF
    MOVLW   00000001B           ; CTMUICON: IRNG=01 (0.55 uA)
    MOVWF   CTMUICON, b
    MOVLW   10000000B           ; CTMUCONH: CTMUEN=1, IDISSEN=0, CTTRIG=0
    MOVWF   CTMUCONH, b
    MOVLW   00000001B           ; CTMUCONL: EDG1STAT=1 ? close switch, current ON
    MOVWF   CTMUCONL, b
    MOVLB   0x0

    ; 5. No pre-charge NOPs ? CTMU charges from 0V during 128us ACQT window

    ; 6. Trigger ADC ? CTMU keeps charging pad+S/H during acquisition
    BSF     ADCON0, 1, a        ; GO = 1
CAP_ADC_POLL:
    BTFSC   ADCON0, 1, a
    BRA     CAP_ADC_POLL

    ; 7. Stop CTMU after sampling
    MOVLB   0xF
    CLRF    CTMUCONL, b         ; EDG1STAT=0 ? current off
    CLRF    CTMUCONH, b         ; CTMUEN=0
    MOVLB   0x0

    MOVFF   ADRESH, touch_adc_h
    RETURN


; ============================================================
; _TOUCH_1MS_DELAY: ~1 ms at 4 MHz
_TOUCH_1MS_DELAY:
    MOVLW   0xA6
    MOVWF   touch_delay5, a
_TOUCH_1MS_L2:
    MOVLW   0x04
    MOVWF   touch_delay4, a
_TOUCH_1MS_L1:
    DECFSZ  touch_delay4, f, a
    BRA     _TOUCH_1MS_L1
    DECFSZ  touch_delay5, f, a
    BRA     _TOUCH_1MS_L2
    RETURN


; ============================================================
; _TOUCH_1S_DELAY: ~100 ms at 4 MHz (between double-sample)
_TOUCH_1S_DELAY:
    MOVLW   0xCA
    MOVWF   touch_delay3, a
_TOUCH_1S_L3:
    MOVLW   0x1B
    MOVWF   touch_delay2, a
_TOUCH_1S_L2:
    MOVLW   0x28
    MOVWF   touch_delay1, a
_TOUCH_1S_L1:
    DECFSZ  touch_delay1, f, a
    BRA     _TOUCH_1S_L1
    DECFSZ  touch_delay2, f, a
    BRA     _TOUCH_1S_L2
    DECFSZ  touch_delay3, f, a
    BRA     _TOUCH_1S_L3
    RETURN


    LLI_SELECT_COLOUR:
    ;todo impl
    ;;thinking of copying the state select flow 
    ;;(optional, likely a waste of time) mabye including an automatic function, where the detected colour gets followed
    return
    
    POLL_SENSORS_FOR_NEWEST_DRIVING_STATE_AND_UPDATE_STATE:
    call    poll_sensors_for_average_detected_colour
    call    set_bits_on_colour_perception_array
    call    set_driving_state_from_saved_sensor_colour_perception_array
    return
    
    set_driving_state_from_saved_sensor_colour_perception_array:
    
    ;Test for stop
	BTFSC   has_read_all_black_on_sensor_array_var,0,a
	BRA	set_driving_state_stop
    
    ;Go Right Tests
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000001
	BZ	set_driving_state_right
	
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000011
	BZ	set_driving_state_right
    ;Go Straight Tests
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000010
	BZ	set_driving_state_centre
	
    ;Go Left Tests
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000100
	BZ	set_driving_state_left
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000110
	BZ	set_driving_state_left
    ;Fall through lost state
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000001
	BZ	set_driving_state_right
	
	MOVF	PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
	XORLW	0b00000001
	BZ	set_driving_state_right
	return
	
	set_driving_state_right:
	    MOVLW   RIGHT_DRIVING_STATE_val
	    MOVWF   DRIVING_STATE_var,a
	    return
	set_driving_state_centre:
	    MOVLW   CENTRE_DRIVING_STATE_val
	    MOVWF   DRIVING_STATE_var,a
	    return
	set_driving_state_left:
	    MOVLW   LEFT_DRIVING_STATE_val
	    MOVWF   DRIVING_STATE_var,a
	    return
	set_driving_state_lost:
	    MOVLW   LOST_DRIVING_STATE_val
	    MOVWF   DRIVING_STATE_var,a
	    return
	set_driving_state_stop:
	    MOVLW   STOP_DRIVING_STATE_val
	    MOVWF   DRIVING_STATE_var,a
	    return
    
    set_bits_on_colour_perception_array:

    CLRF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var,a
    CLRF    has_read_all_black_on_sensor_array_var,a

    ;Check if L = selected colour ? fall through to check C regardless
    MOVF    RACE_COL_var,W,a
    XORWF   sensor_L_read_colour_enum_var,a
    BNZ     skip_L_on_line_bit
    BSF     PERCEIVED_COLOUR_AT_SENSOR_BITS_var,2
    skip_L_on_line_bit:

    ;Check if C = selected colour ? fall through to check R regardless
    MOVF    RACE_COL_var,W,a
    XORWF   sensor_C_read_colour_enum_var,a
    BNZ     skip_C_on_line_bit
    BSF     PERCEIVED_COLOUR_AT_SENSOR_BITS_var,1
    skip_C_on_line_bit:

    ;Check if R = selected colour ? fall through to all-black check regardless
    MOVF    RACE_COL_var,W,a
    XORWF   sensor_R_read_colour_enum_var,a
    BNZ     skip_R_on_line_bit
    BSF     PERCEIVED_COLOUR_AT_SENSOR_BITS_var,0
    skip_R_on_line_bit:

    ;If any race colour bit was set, skip all-black check
    MOVF    PERCEIVED_COLOUR_AT_SENSOR_BITS_var,W,a
    BNZ     not_all_black_on_line_bits

    ;CHECK FOR ALL BLACK
    MOVF    sensor_L_read_colour_enum_var,W,a
    XORLW   BLACK_COLOUR_STATE_val
    BNZ     not_all_black_on_line_bits

    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   BLACK_COLOUR_STATE_val
    BNZ     not_all_black_on_line_bits

    MOVF    sensor_R_read_colour_enum_var,W,a
    XORLW   BLACK_COLOUR_STATE_val
    BNZ     not_all_black_on_line_bits

    ;ALL BLACK CONFIRMED
    BSF	    has_read_all_black_on_sensor_array_var,0,a
    not_all_black_on_line_bits:
    return
    

;</editor-fold>


    
OSC_DELAY_STATE:
    call    SET_SSD
    call    NAV_STATE_IF_REQUIRED
GOTO    OSC_DELAY_STATE
    
    
;FUNCTIONS

;<editor-fold defaultstate="collapsed" desc="Functions">

;<editor-fold defaultstate="collapsed" desc="Delay">
    
TIMEOUT_333ms:
    movlw   0x6C
    movwf   delay1, a
outer333:
    movlw   0xFF
    movwf   delay2, a
inner333:
    decfsz  delay2, f, a
    goto    inner333
    
    decfsz  delay1, f, a
    goto    outer333
RETURN
TIMEOUT_167ms:
    movlw   0x36
    movwf   delay1, a
outer167:
    movlw   0xFF
    movwf   delay2, a
inner167:
    decfsz  delay2, f, a
    goto    inner167
    
    decfsz  delay1, f, a
    goto    outer167
RETURN
    

TIMEOUT_LED_WAIT_LED_GET_HIGH:
    nop;20 nop = 20 us
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
RETURN
    
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Colour Sensor Feature">

;;Method is to check if the driving state self-repeats a certain amount of times before accepting a state change
poll_sensors_for_average_detected_colour:
    call    poll_sensors_for_detected_colour
    ;TODO IMPLEMENT
    ;;This implementation will just check if it's the same as last time, and if not, will require a 
    ;;confirmation reading before switching state. The number of confirmation readings can be changed if we want
    ;;to implement averaging over a larger base. Currently at 4MHz, it does about 1000 readings per second
    return
    
poll_sensors_for_detected_colour:
    call    strobe_and_save_sensor_readings
    call    calc_perceived_colour_L
    call    calc_perceived_colour_C
    call    calc_perceived_colour_R
return
    
  
;Colour Calculation Method
;;Calibrated to all floor types
;;Calculate the sum difference between each sensor reading and what it is expected to be on a certain floor
;;Take the smallest floor delta/difference
;;(Optional)-Multiply the difference between the tested shined colour and the matching floor colour by a constant factor (eg 2 or 5)
;;Difference capped at 255
    calc_perceived_colour_L:
    call    set_current_strobe_to_L
    call    set_current_sensor_cal_to_L
    call    calculate_diff_sums
    call    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF    sensor_L_read_colour_enum_var,a
    return
    calc_perceived_colour_C:
    call    set_current_strobe_to_C
    call    set_current_sensor_cal_to_C
    call    calculate_diff_sums
    call    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF    sensor_C_read_colour_enum_var,a
    return
    calc_perceived_colour_R:
    call    set_current_strobe_to_R
    call    set_current_sensor_cal_to_R
    call    calculate_diff_sums
    call    calc_lowest_diff_sum_colour_index_to_wreg
    MOVWF    sensor_R_read_colour_enum_var,a
    return
    
    calc_lowest_diff_sum_colour_index_to_wreg:
    MOVFF    red_floor_sum_delta_var,lowest_diff_score_var
    MOVLW    RED_COLOUR_STATE_val
    MOVWF    lowest_diff_enum_colour_var,a
    
    MOVF    lowest_diff_score_var,w,a
    CPFSLT    green_floor_sum_delta_var,a
    BRA    lowest_diff_blue_section
    MOVFF    green_floor_sum_delta_var,lowest_diff_score_var
    MOVLW    GREEN_COLOUR_STATE_val
    MOVWF    lowest_diff_enum_colour_var,a
    
    lowest_diff_blue_section:
    MOVF    lowest_diff_score_var,w,a
    CPFSLT    blue_floor_sum_delta_var,a
    BRA    lowest_diff_white_section
    MOVFF    blue_floor_sum_delta_var,lowest_diff_score_var
    MOVLW    BLUE_COLOUR_STATE_val
    MOVWF    lowest_diff_enum_colour_var,a
    
    lowest_diff_white_section:
    MOVF    lowest_diff_score_var,w,a
    CPFSLT    white_floor_sum_delta_var,a
    BRA    lowest_diff_black_section
    MOVFF    white_floor_sum_delta_var,lowest_diff_score_var
    MOVLW    WHITE_COLOUR_STATE_val
    MOVWF    lowest_diff_enum_colour_var,a
    
    lowest_diff_black_section:
    MOVF    lowest_diff_score_var,w,a
    CPFSLT    black_floor_sum_delta_var,a
    BRA    lowest_diff_end_section
    MOVFF    black_floor_sum_delta_var,lowest_diff_score_var
    MOVLW    BLACK_COLOUR_STATE_val
    MOVWF    lowest_diff_enum_colour_var,a
    lowest_diff_end_section:
    
    MOVF    lowest_diff_enum_colour_var,W,a
    return
        
    calculate_diff_sums:
    ;;The multiplier is for floor to strobe colour matching
    
    ;Add red floor diff sums
    MOVF    current_sensor_cal_red_on_red_var,W,a
    SUBWF   current_strobe_reading_red_var,W,a
    call    abs_val_subtraction_in_wreg
    MOVWF    red_floor_sum_delta_var,a
     
    MOVLW    matching_floor_to_strobe_colour_reading_diff_multiplier_val
    MULWF   red_floor_sum_delta_var,a
    MOVFF   PRODL,red_floor_sum_delta_var
    TSTFSZ  PRODH, a
    SETF    red_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_green_on_red_var,W,a
    SUBWF   current_strobe_reading_green_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    red_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    red_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_blue_on_red_var,W,a
    SUBWF   current_strobe_reading_blue_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    red_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    red_floor_sum_delta_var,a
    
    ;Add green floor diff sums
    

    MOVF    current_sensor_cal_green_on_green_var,W,a
    SUBWF   current_strobe_reading_green_var,W,a
    call    abs_val_subtraction_in_wreg
    MOVWF    green_floor_sum_delta_var,a
    
    MOVLW   matching_floor_to_strobe_colour_reading_diff_multiplier_val
    MULWF   green_floor_sum_delta_var,a
    MOVFF   PRODL,green_floor_sum_delta_var
    TSTFSZ  PRODH, a
    SETF    green_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_red_on_green_var,W,a
    SUBWF   current_strobe_reading_red_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    green_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    green_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_blue_on_green_var,W,a
    SUBWF   current_strobe_reading_blue_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    green_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    green_floor_sum_delta_var,a
    
    ;Add blue floor diff sums
    MOVF    current_sensor_cal_blue_on_blue_var,W,a
    SUBWF   current_strobe_reading_blue_var,W,a
    call    abs_val_subtraction_in_wreg
    MOVWF    blue_floor_sum_delta_var,a
    
    MOVLW   matching_floor_to_strobe_colour_reading_diff_multiplier_val
    MULWF   blue_floor_sum_delta_var,a
    MOVFF   PRODL,blue_floor_sum_delta_var
    TSTFSZ  PRODH, a
    SETF    blue_floor_sum_delta_var,a
        
    MOVF    current_sensor_cal_red_on_blue_var,W,a
    SUBWF   current_strobe_reading_red_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    blue_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    blue_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_green_on_blue_var,W,a
    SUBWF   current_strobe_reading_green_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    blue_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    blue_floor_sum_delta_var,a
    
    ;Add white floor diff sums
    MOVF    current_sensor_cal_red_on_white_var,W,a
    SUBWF   current_strobe_reading_red_var,W,a
    call    abs_val_subtraction_in_wreg
    MOVWF    white_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_green_on_white_var,W,a
    SUBWF   current_strobe_reading_green_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    white_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    white_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_blue_on_white_var,W,a
    SUBWF   current_strobe_reading_blue_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    white_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0, a
    SETF    white_floor_sum_delta_var,a
    
    ;Macro to multiply by 1.375 since the above is multiplied by avg 1.4 (assuming mult val is 3)
    MOVF    white_floor_sum_delta_var,W,a
    call    MUL1375_WREG
    MOVWF    white_floor_sum_delta_var,a
    
    ;Add black floor diff sums
    MOVF    current_sensor_cal_red_on_black_var,W,a
    SUBWF   current_strobe_reading_red_var,W,a
    call    abs_val_subtraction_in_wreg
    MOVWF    black_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_green_on_black_var,W,a
    SUBWF   current_strobe_reading_green_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    black_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0,a
    SETF    black_floor_sum_delta_var,a
    
    MOVF    current_sensor_cal_blue_on_black_var,W,a
    SUBWF   current_strobe_reading_blue_var,W,a
    call    abs_val_subtraction_in_wreg
    ADDWF    black_floor_sum_delta_var,F,a
    BTFSC   STATUS, 0,a
    SETF    black_floor_sum_delta_var,a
    
    MOVF    black_floor_sum_delta_var,W,a
    call    MUL1375_WREG
    MOVWF    black_floor_sum_delta_var,a
    return
    
    

abs_val_subtraction_in_wreg:
    BTFSC   STATUS,0,a
    return

    COMF    WREG,a
    INCF    WREG,a
    return

set_current_strobe_to_L:
    MOVFF   sensor_L_strobe_R_reading_var,current_strobe_reading_red_var,a
    MOVFF   sensor_L_strobe_G_reading_var,current_strobe_reading_green_var,a
    MOVFF   sensor_L_strobe_B_reading_var,current_strobe_reading_blue_var,a
    return
    
set_current_strobe_to_C:
    MOVFF   sensor_C_strobe_R_reading_var,current_strobe_reading_red_var,a
    MOVFF   sensor_C_strobe_G_reading_var,current_strobe_reading_green_var,a
    MOVFF   sensor_C_strobe_B_reading_var,current_strobe_reading_blue_var,a
    return
    
set_current_strobe_to_R:
    MOVFF   sensor_R_strobe_R_reading_var,current_strobe_reading_red_var,a
    MOVFF   sensor_R_strobe_G_reading_var,current_strobe_reading_green_var,a
    MOVFF   sensor_R_strobe_B_reading_var,current_strobe_reading_blue_var,a
    return
    
set_current_sensor_cal_to_L:

    MOVFF   CAL_L_RED_ON_RED_var,      current_sensor_cal_red_on_red_var
    MOVFF   CAL_L_RED_ON_GREEN_var,    current_sensor_cal_red_on_green_var
    MOVFF   CAL_L_RED_ON_BLUE_var,     current_sensor_cal_red_on_blue_var
    MOVFF   CAL_L_RED_ON_WHITE_var,    current_sensor_cal_red_on_white_var
    MOVFF   CAL_L_RED_ON_BLACK_var,    current_sensor_cal_red_on_black_var

    MOVFF   CAL_L_GREEN_ON_RED_var,    current_sensor_cal_green_on_red_var
    MOVFF   CAL_L_GREEN_ON_GREEN_var,  current_sensor_cal_green_on_green_var
    MOVFF   CAL_L_GREEN_ON_BLUE_var,   current_sensor_cal_green_on_blue_var
    MOVFF   CAL_L_GREEN_ON_WHITE_var,  current_sensor_cal_green_on_white_var
    MOVFF   CAL_L_GREEN_ON_BLACK_var,  current_sensor_cal_green_on_black_var

    MOVFF   CAL_L_BLUE_ON_RED_var,     current_sensor_cal_blue_on_red_var
    MOVFF   CAL_L_BLUE_ON_GREEN_var,   current_sensor_cal_blue_on_green_var
    MOVFF   CAL_L_BLUE_ON_BLUE_var,    current_sensor_cal_blue_on_blue_var
    MOVFF   CAL_L_BLUE_ON_WHITE_var,   current_sensor_cal_blue_on_white_var
    MOVFF   CAL_L_BLUE_ON_BLACK_var,   current_sensor_cal_blue_on_black_var

    RETURN
    
set_current_sensor_cal_to_C:

    MOVFF   CAL_C_RED_ON_RED_var,      current_sensor_cal_red_on_red_var
    MOVFF   CAL_C_RED_ON_GREEN_var,    current_sensor_cal_red_on_green_var
    MOVFF   CAL_C_RED_ON_BLUE_var,     current_sensor_cal_red_on_blue_var
    MOVFF   CAL_C_RED_ON_WHITE_var,    current_sensor_cal_red_on_white_var
    MOVFF   CAL_C_RED_ON_BLACK_var,    current_sensor_cal_red_on_black_var

    MOVFF   CAL_C_GREEN_ON_RED_var,    current_sensor_cal_green_on_red_var
    MOVFF   CAL_C_GREEN_ON_GREEN_var,  current_sensor_cal_green_on_green_var
    MOVFF   CAL_C_GREEN_ON_BLUE_var,   current_sensor_cal_green_on_blue_var
    MOVFF   CAL_C_GREEN_ON_WHITE_var,  current_sensor_cal_green_on_white_var
    MOVFF   CAL_C_GREEN_ON_BLACK_var,  current_sensor_cal_green_on_black_var

    MOVFF   CAL_C_BLUE_ON_RED_var,     current_sensor_cal_blue_on_red_var
    MOVFF   CAL_C_BLUE_ON_GREEN_var,   current_sensor_cal_blue_on_green_var
    MOVFF   CAL_C_BLUE_ON_BLUE_var,    current_sensor_cal_blue_on_blue_var
    MOVFF   CAL_C_BLUE_ON_WHITE_var,   current_sensor_cal_blue_on_white_var
    MOVFF   CAL_C_BLUE_ON_BLACK_var,   current_sensor_cal_blue_on_black_var

    RETURN

set_current_sensor_cal_to_R:

    MOVFF   CAL_R_RED_ON_RED_var,      current_sensor_cal_red_on_red_var
    MOVFF   CAL_R_RED_ON_GREEN_var,    current_sensor_cal_red_on_green_var
    MOVFF   CAL_R_RED_ON_BLUE_var,     current_sensor_cal_red_on_blue_var
    MOVFF   CAL_R_RED_ON_WHITE_var,    current_sensor_cal_red_on_white_var
    MOVFF   CAL_R_RED_ON_BLACK_var,    current_sensor_cal_red_on_black_var

    MOVFF   CAL_R_GREEN_ON_RED_var,    current_sensor_cal_green_on_red_var
    MOVFF   CAL_R_GREEN_ON_GREEN_var,  current_sensor_cal_green_on_green_var
    MOVFF   CAL_R_GREEN_ON_BLUE_var,   current_sensor_cal_green_on_blue_var
    MOVFF   CAL_R_GREEN_ON_WHITE_var,  current_sensor_cal_green_on_white_var
    MOVFF   CAL_R_GREEN_ON_BLACK_var,  current_sensor_cal_green_on_black_var

    MOVFF   CAL_R_BLUE_ON_RED_var,     current_sensor_cal_blue_on_red_var
    MOVFF   CAL_R_BLUE_ON_GREEN_var,   current_sensor_cal_blue_on_green_var
    MOVFF   CAL_R_BLUE_ON_BLUE_var,    current_sensor_cal_blue_on_blue_var
    MOVFF   CAL_R_BLUE_ON_WHITE_var,   current_sensor_cal_blue_on_white_var
    MOVFF   CAL_R_BLUE_ON_BLACK_var,   current_sensor_cal_blue_on_black_var

    RETURN
    
strobe_and_save_sensor_readings:
    call    set_strobe_leds_red
    call    TIMEOUT_LED_WAIT_LED_GET_HIGH
    call    read_and_save_sensor_array_perception
    call    save_sensor_reading_to_strobe_red
    
    call    set_strobe_leds_green
    call    TIMEOUT_LED_WAIT_LED_GET_HIGH
    call    read_and_save_sensor_array_perception
    call    save_sensor_reading_to_strobe_green
    
    call    set_strobe_leds_blue
    call    TIMEOUT_LED_WAIT_LED_GET_HIGH
    call    read_and_save_sensor_array_perception
    call    save_sensor_reading_to_strobe_blue
    
    call    set_strobe_leds_off
    
    return
 
save_sensor_reading_to_strobe_red:
    MOVFF    sensor_L_reading_var,sensor_L_strobe_R_reading_var,a
    MOVFF    sensor_C_reading_var,sensor_C_strobe_R_reading_var,a
    MOVFF    sensor_R_reading_var,sensor_R_strobe_R_reading_var,a
    return
 
save_sensor_reading_to_strobe_green:
    MOVFF    sensor_L_reading_var,sensor_L_strobe_G_reading_var,a
    MOVFF    sensor_C_reading_var,sensor_C_strobe_G_reading_var,a
    MOVFF    sensor_R_reading_var,sensor_R_strobe_G_reading_var,a
    return
 
save_sensor_reading_to_strobe_blue:
    MOVFF    sensor_L_reading_var,sensor_L_strobe_B_reading_var,a
    MOVFF    sensor_C_reading_var,sensor_C_strobe_B_reading_var,a
    MOVFF    sensor_R_reading_var,sensor_R_strobe_B_reading_var,a
    return
    
read_and_save_sensor_array_perception:
    ;E0
    MOVLW   ADC_AN5
    call    read_wreg_selected_adc_to_wreg
    MOVWF   sensor_L_reading_var,a
    
    ;E1
    MOVLW   ADC_AN6
    call    read_wreg_selected_adc_to_wreg
    MOVWF   sensor_C_reading_var,a
    
    ;E2
    MOVLW   ADC_AN7
    call    read_wreg_selected_adc_to_wreg
    MOVWF   sensor_R_reading_var,a
    return
    
    read_wreg_selected_adc_to_wreg:
    MOVWF   ADCON0, a

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

    
;0,1,2 - R,G,B
set_strobe_leds_red:
    BSF    STROBE_LED_PORT,0,a
    BCF    STROBE_LED_PORT,1,a
    BCF    STROBE_LED_PORT,2,a
    return
   
set_strobe_leds_green:
    BCF    STROBE_LED_PORT,0,a
    BSF    STROBE_LED_PORT,1,a
    BCF    STROBE_LED_PORT,2,a
    return
   
set_strobe_leds_blue:
    BCF    STROBE_LED_PORT,0,a
    BCF    STROBE_LED_PORT,1,a
    BSF    STROBE_LED_PORT,2,a
    return
   
set_strobe_leds_white:
    BSF    STROBE_LED_PORT,0,a
    BSF    STROBE_LED_PORT,1,a
    BSF    STROBE_LED_PORT,2,a
    return
   
set_strobe_leds_off:
    BCF    STROBE_LED_PORT,0,a
    BCF    STROBE_LED_PORT,1,a
    BCF    STROBE_LED_PORT,2,a
    return
;</editor-fold>
    
;<editor-fold defaultstate="collapsed" desc="Display Feature">
FLASH_SSD:
    MOVWF   temp_var,a
    MOVFF   SSD_OUT_var,SSD_PORT
    call    TIMEOUT_333ms
    call    TIMEOUT_333ms
    MOVLW   0b11111111
    MOVWF   SSD_PORT,a
    call    TIMEOUT_333ms
    call    TIMEOUT_333ms
    MOVF    temp_var,W,a
    
RETURN
    

SET_SSD:
    MOVFF   SSD_OUT_var,SSD_PORT,a
RETURN
    
    
do_reg_dump:
    MOVLW   r_SSD
    MOVWF   SSD_OUT_var,a
    call    FLASH_SSD
    call    FLASH_SSD
    
    return
        
    
BLINK_WHITE_DISP_TWICE_DELAYED:
    call    set_disp_rgb_white
    call    TIMEOUT_167ms
    call    set_disp_rgb_black
    call    TIMEOUT_167ms
    call    set_disp_rgb_white
    call    TIMEOUT_167ms
    call    set_disp_rgb_black
    call    TIMEOUT_167ms
    return
    
FLASH_RGB_DISP_DELAYED:
    call    set_disp_rgb_red
    call    TIMEOUT_167ms
    call    set_disp_rgb_green
    call    TIMEOUT_167ms
    call    set_disp_rgb_blue
    call    TIMEOUT_167ms
    call    set_disp_rgb_black
    call    TIMEOUT_167ms
    return

set_disp_rgb_red: ;B<5:7> = R,G,B
    BSF        DISP_LED_PORT,5,a
    BCF        DISP_LED_PORT,6,a
    BCF        DISP_LED_PORT,7,a
    return
    
set_disp_rgb_green: ;B<5:7> = R,G,B
    BCF        DISP_LED_PORT,5,a
    BSF        DISP_LED_PORT,6,a
    BCF        DISP_LED_PORT,7,a
    return
    
set_disp_rgb_blue: ;B<5:7> = R,G,B
    BCF        DISP_LED_PORT,5,a
    BCF        DISP_LED_PORT,6,a
    BSF        DISP_LED_PORT,7,a
    return
    
set_disp_rgb_white: ;B<5:7> = R,G,B
    BSF        DISP_LED_PORT,5,a
    BSF        DISP_LED_PORT,6,a
    BSF        DISP_LED_PORT,7,a
    return
    
set_disp_rgb_black: ;B<5:7> = R,G,B
    BCF        DISP_LED_PORT,5,a
    BCF        DISP_LED_PORT,6,a
    BCF        DISP_LED_PORT,7,a
    return
    
set_disp_SSD_dot:
    BSF        SSD_PORT,7,a
    return
clear_disp_SSD_dot:
    BCF        SSD_PORT,7,a
    return
    
display_error:
    ;todo implement
    ;this is a way to flag while testing that something unacceptable is happening
    ;Displaying a red flash 3 times + a 7SEG code could be a good use
    ;eg the smallest sensor difference sum is > 40
    ;if it's constantly activated that's very useful to see there's an error.
    ;Unique codes for an error make it very easy
    
    return


;</editor-fold>
    

 MUL1375_WREG:
    ; Input : WREG = x
    ; Output: WREG = min(255, x * 1.375)
    ; Uses  : temp_var, temp_var2

    ; Save original x
    MOVWF   temp_var,a

    ; Running result = x
    MOVWF   temp_var2,a

    ; ---------- add x/4 ----------
    MOVF    temp_var,W,a
    BCF     STATUS,0,a
    RRCF    WREG,F,a
    BCF     STATUS,0,a
    RRCF    WREG,F,a          ; WREG = x/4

    ADDWF   temp_var2,F,a
    BTFSC   STATUS,0,a
    SETF    temp_var2,a

    ; ---------- add x/8 ----------
    MOVF    temp_var,W,a
    BCF     STATUS,0,a
    RRCF    WREG,W,a
    BCF     STATUS,0,a
    RRCF    WREG,W,a
    BCF     STATUS,0,a
    RRCF    WREG,W,a          ; WREG = x/8

    ADDWF   temp_var2,F,a
    BTFSC   STATUS,0,a
    SETF    temp_var2,a

    ; Return result in W
    MOVF    temp_var2,W,a
    RETURN
      
    
;</editor-fold>


; ============================================================
; HD44780 LCD DRIVER ? 4-bit mode
; Pins: RS=RD3  E=RD4  D4=RD5  D5=RD6  D6=RD7  D7=RB3
; ============================================================

; --- LCD_INIT ---
; Power-on initialisation. Call once during startup.
; Leaves display on, cursor off, 2-line 5x8, cursor auto-increment.
LCD_INIT:
    BCF     LATD, 3, a              ; RS = 0
    BCF     LATD, 4, a              ; E  = 0
    BCF     LATB, 3, a              ; D7 = 0
    MOVLW   0x1F
    ANDWF   LATD, f, a              ; D4-D6 = 0 (keep strobe LEDs)
    CALL    TIMEOUT_333ms           ; > 40 ms VDD rise time

    ; Three 0x03 nibbles ? hardware reset sequence
    MOVLW   0x03
    CALL    _LCD_SEND_NIBBLE
    CALL    _LCD_DELAY_5MS
    MOVLW   0x03
    CALL    _LCD_SEND_NIBBLE
    CALL    _LCD_DELAY_5MS
    MOVLW   0x03
    CALL    _LCD_SEND_NIBBLE
    CALL    _LCD_DELAY_5MS

    ; Switch to 4-bit interface
    MOVLW   0x02
    CALL    _LCD_SEND_NIBBLE
    CALL    _LCD_DELAY_5MS

    ; Function set: 4-bit bus, 2-line, 5x8 font
    MOVLW   0x28
    CALL    LCD_CMD
    ; Display on, cursor off, blink off
    MOVLW   0x0C
    CALL    LCD_CMD
    ; Entry mode: cursor moves right, no display shift
    MOVLW   0x06
    CALL    LCD_CMD
    ; Clear display (needs 2 ms)
    CALL    LCD_CLEAR
    RETURN

; --- LCD_CMD ---
; Send byte in W as command (RS=0, two nibbles high-then-low).
LCD_CMD:
    MOVWF   lcd_temp2_var, a        ; save command byte
    BCF     LATD, 3, a              ; RS = 0
    SWAPF   lcd_temp2_var, W, a
    ANDLW   0x0F
    CALL    _LCD_SEND_NIBBLE        ; send high nibble
    CALL    _LCD_DELAY_50US
    MOVF    lcd_temp2_var, W, a
    ANDLW   0x0F
    CALL    _LCD_SEND_NIBBLE        ; send low nibble
    CALL    _LCD_DELAY_50US
    RETURN

; --- LCD_CHAR ---
; Send byte in W as character data (RS=1).
LCD_CHAR:
    MOVWF   lcd_temp2_var, a
    BSF     LATD, 3, a              ; RS = 1
    SWAPF   lcd_temp2_var, W, a
    ANDLW   0x0F
    CALL    _LCD_SEND_NIBBLE        ; send high nibble
    CALL    _LCD_DELAY_50US
    MOVF    lcd_temp2_var, W, a
    ANDLW   0x0F
    CALL    _LCD_SEND_NIBBLE        ; send low nibble
    CALL    _LCD_DELAY_50US
    BCF     LATD, 3, a              ; RS = 0
    RETURN

; --- LCD_CLEAR ---
; Clear display and home cursor (2 ms execution time on HD44780).
LCD_CLEAR:
    MOVLW   0x01
    CALL    LCD_CMD
    CALL    _LCD_DELAY_2MS
    RETURN

; --- LCD_LINE1 ---
; Set cursor to column 0 of line 1.
LCD_LINE1:
    MOVLW   0x80
    CALL    LCD_CMD
    RETURN

; --- LCD_LINE2 ---
; Set cursor to column 0 of line 2.
LCD_LINE2:
    MOVLW   0xC0
    CALL    LCD_CMD
    RETURN

; --- LCD_PRINT_HEX ---
; Print byte in W as two ASCII hex digits (e.g. 0x4F -> "4F").
; Uses lcd_temp3_var to survive the nested LCD_CHAR calls.
LCD_PRINT_HEX:
    MOVWF   lcd_temp3_var, a        ; save full byte
    SWAPF   lcd_temp3_var, W, a
    ANDLW   0x0F
    CALL    _LCD_HEX_DIGIT          ; high nibble
    MOVF    lcd_temp3_var, W, a
    ANDLW   0x0F
    CALL    _LCD_HEX_DIGIT          ; low nibble
    RETURN

; Convert nibble in W[3:0] to ASCII and send via LCD_CHAR.
_LCD_HEX_DIGIT:
    ANDLW   0x0F
    MOVWF   lcd_temp_var, a         ; save nibble (0-15)
    MOVLW   0x0A
    CPFSLT  lcd_temp_var, a         ; skip if nibble < 10
    BRA     _LCD_HD_LETTER
    MOVF    lcd_temp_var, W, a
    ADDLW   0x30                    ; '0'-'9'
    BRA     _LCD_HD_SEND
_LCD_HD_LETTER:
    MOVF    lcd_temp_var, W, a
    ADDLW   0x37                    ; 'A'-'F'
_LCD_HD_SEND:
    CALL    LCD_CHAR
    RETURN

; --- _LCD_SEND_NIBBLE ---
; Send nibble in W[3:0] to LCD (RS already set in LATD[3]).
; bit0->D4->RD5  bit1->D5->RD6  bit2->D6->RD7  bit3->D7->RB3
; Strobes E (RD4) high then low.
_LCD_SEND_NIBBLE:
    MOVWF   lcd_temp_var, a         ; save nibble
    ; LATD[7:5] = nibble[2:0]: clear data bits, then shift in
    MOVLW   0x1F
    ANDWF   LATD, f, a              ; preserve LATD[4:0] (E, RS, strobe LEDs)
    MOVF    lcd_temp_var, W, a
    ANDLW   0x07                    ; isolate D4, D5, D6 bits [2:0]
    SWAPF   WREG, W, a              ; shift [2:0] up to [6:4]
    BCF     STATUS, 0, a            ; clear carry
    RLCF    WREG, W, a              ; shift one more: [2:0] now at [7:5]
    IORWF   LATD, f, a
    ; LATB[3] = nibble[3] (D7)
    BCF     LATB, 3, a
    BTFSC   lcd_temp_var, 3, a
    BSF     LATB, 3, a
    ; Strobe E (RD4) high then low ? min 450 ns, 2 NOPs = 2 �s at 4 MHz
    BSF     LATD, 4, a
    NOP
    NOP
    BCF     LATD, 4, a
    RETURN

; --- _LCD_DELAY_50US ---
; ~50 �s busy-wait (covers 37 �s HD44780 command execution time).
_LCD_DELAY_50US:
    MOVLW   0x0D                    ; 13 x 4 cycles = 52 �s
    MOVWF   lcd_temp_var, a
_LCD_D50_L:
    DECFSZ  lcd_temp_var, f, a
    BRA     _LCD_D50_L
    RETURN

; --- _LCD_DELAY_2MS ---
; ~2 ms (Clear Display / Return Home execution time).
_LCD_DELAY_2MS:
    MOVLW   0x03                    ; 3 outer x 250 inner x 3 cycles ~ 2.3 ms
    MOVWF   lcd_temp2_var, a
_LCD_D2MS_OUT:
    MOVLW   0xFA
    MOVWF   lcd_temp_var, a
_LCD_D2MS_IN:
    DECFSZ  lcd_temp_var, f, a
    BRA     _LCD_D2MS_IN
    DECFSZ  lcd_temp2_var, f, a
    BRA     _LCD_D2MS_OUT
    RETURN

; --- _LCD_DELAY_5MS ---
; ~5 ms (init sequence inter-nibble spacing).
_LCD_DELAY_5MS:
    MOVLW   0x08                    ; 8 outer x 250 inner x 3 cycles ~ 6 ms
    MOVWF   lcd_temp2_var, a
_LCD_D5MS_OUT:
    MOVLW   0xFA
    MOVWF   lcd_temp_var, a
_LCD_D5MS_IN:
    DECFSZ  lcd_temp_var, f, a
    BRA     _LCD_D5MS_IN
    DECFSZ  lcd_temp2_var, f, a
    BRA     _LCD_D5MS_OUT
    RETURN


end
    

