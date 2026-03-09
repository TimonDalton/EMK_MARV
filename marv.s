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
cal_floor_colour_var                    EQU 0x0E

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

RACE_COL_var                            EQU 0x2B
DRIVING_STATE_var                       EQU 0x2C

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

COL_L_var                               EQU 0x3C
COL_C_var                               EQU 0x3D
COL_R_var                               EQU 0x3E

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
    ;;;Make sure these are based on real readings with newest sensor
    ;================= WHITE surface =================
    MOVLW   0xFF
    ; Left sensor
    MOVWF   CAL_L_RED_ON_WHITE_var,b
    MOVWF   CAL_L_GREEN_ON_WHITE_var,b
    MOVWF   CAL_L_BLUE_ON_WHITE_var,b
    ; Centre sensor
    MOVWF   CAL_C_RED_ON_WHITE_var,b
    MOVWF   CAL_C_GREEN_ON_WHITE_var,b
    MOVWF   CAL_C_BLUE_ON_WHITE_var,b
    ; Right sensor
    MOVWF   CAL_R_RED_ON_WHITE_var,b
    MOVWF   CAL_R_GREEN_ON_WHITE_var,b
    MOVWF   CAL_R_BLUE_ON_WHITE_var,b
    ;================= GREEN surface =================
    MOVLW   0xB8
    ; Left sensor
    MOVWF   CAL_L_RED_ON_GREEN_var,b
    MOVWF   CAL_L_GREEN_ON_GREEN_var,b
    MOVWF   CAL_L_BLUE_ON_GREEN_var,b
    ; Centre sensor
    MOVWF   CAL_C_RED_ON_GREEN_var,b
    MOVWF   CAL_C_GREEN_ON_GREEN_var,b
    MOVWF   CAL_C_BLUE_ON_GREEN_var,b
    ; Right sensor
    MOVWF   CAL_R_RED_ON_GREEN_var,b
    MOVWF   CAL_R_GREEN_ON_GREEN_var,b
    MOVWF   CAL_R_BLUE_ON_GREEN_var,b
    ;================= RED surface =================
    MOVLW   0x88
    ; Left sensor
    MOVWF   CAL_L_RED_ON_RED_var,b
    MOVWF   CAL_L_GREEN_ON_RED_var,b
    MOVWF   CAL_L_BLUE_ON_RED_var,b
    ; Centre sensor
    MOVWF   CAL_C_RED_ON_RED_var,b
    MOVWF   CAL_C_GREEN_ON_RED_var,b
    MOVWF   CAL_C_BLUE_ON_RED_var,b
    ; Right sensor
    MOVWF   CAL_R_RED_ON_RED_var,b
    MOVWF   CAL_R_GREEN_ON_RED_var,b
    MOVWF   CAL_R_BLUE_ON_RED_var,b
    ;================= BLUE surface =================
    MOVLW   0xA9
    ; Left sensor
    MOVWF   CAL_L_RED_ON_BLUE_var,b
    MOVWF   CAL_L_GREEN_ON_BLUE_var,b
    MOVWF   CAL_L_BLUE_ON_BLUE_var,b
    ; Centre sensor
    MOVWF   CAL_C_RED_ON_BLUE_var,b
    MOVWF   CAL_C_GREEN_ON_BLUE_var,b
    MOVWF   CAL_C_BLUE_ON_BLUE_var,b
    ; Right sensor
    MOVWF   CAL_R_RED_ON_BLUE_var,b
    MOVWF   CAL_R_GREEN_ON_BLUE_var,b
    MOVWF   CAL_R_BLUE_ON_BLUE_var,b
    ;================= BLACK surface =================
    MOVLW   0x00
    ; Left sensor
    MOVWF   CAL_L_RED_ON_BLACK_var,b
    MOVWF   CAL_L_GREEN_ON_BLACK_var,b
    MOVWF   CAL_L_BLUE_ON_BLACK_var,b
    ; Centre sensor
    MOVWF   CAL_C_RED_ON_BLACK_var,b
    MOVWF   CAL_C_GREEN_ON_BLACK_var,b
    MOVWF   CAL_C_BLUE_ON_BLACK_var,b
    ; Right sensor
    MOVWF   CAL_R_RED_ON_BLACK_var,b
    MOVWF   CAL_R_GREEN_ON_BLACK_var,b
    MOVWF   CAL_R_BLUE_ON_BLACK_var,b
;</editor-fold>

            
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
    
    MOVLW   LLI_state_val
    MOVWF   display_select_state_var,a
    MOVLW   L_SSD
    MOVWF   current_state_symbol_var,a
    call    STATE_SELECT_INPUT
    
    MOVLW   feedback_color_state_val
    MOVWF   display_select_state_var,a
    MOVLW   F_SSD
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
to_cal:
    GOTO    CAL_STATE
to_LLI:
    GOTO    LLI_STATE
to_colour_feedback:
    GOTO    FEEDBACK_COLOUR_STATE
to_osc_delay:
    GOTO    OSC_DELAY_STATE
    
;;If the current set state is not found, go select a valid state
;</editor-fold>
GOTO STATE_SELECT_LOOP

    
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
    MOVLW   RED_COLOUR_STATE_val
    MOVWF   cal_floor_colour_var,a
    call    STROBE_SAVE_CAL_RED_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal Green
    call    set_disp_rgb_green
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    MOVLW   GREEN_COLOUR_STATE_val
    MOVWF   cal_floor_colour_var,a
    call    STROBE_SAVE_CAL_GREEN_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal Blue
    call    set_disp_rgb_blue
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    MOVLW   BLUE_COLOUR_STATE_val
    MOVWF   cal_floor_colour_var,a
    call    STROBE_SAVE_CAL_BLUE_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal White
    call    set_disp_rgb_white
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    MOVLW   WHITE_COLOUR_STATE_val
    MOVWF   cal_floor_colour_var,a
    call    STROBE_SAVE_CAL_WHITE_FLOOR
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    ;Cal Black
    call    set_disp_rgb_black
    call    set_disp_SSD_dot
    call    WAIT_FOR_LEFT_BUTTON_PRESS_CAL_STATE
    MOVLW   BLACK_COLOUR_STATE_val
    MOVWF   cal_floor_colour_var,a
    call    STROBE_SAVE_CAL_BLACK_FLOOR
    call    clear_disp_SSD_dot
    
    call    BLINK_WHITE_DISP_TWICE_DELAYED
    
    MOVLW   LLI_state_val
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
    MOVLW   L_SSD
    MOVWF   current_state_symbol_var,a
    MOVFF   current_state_symbol_var,SSD_OUT_var
    call    SET_SSD
    
    call    poll_sensors_for_detected_colour
    call    disp_centre_sensor_stored_colour
    
    call    NAV_STATE_IF_REQUIRED
GOTO    FEEDBACK_COLOUR_STATE
    
    
;</editor-fold>
    
 
    disp_centre_sensor_stored_colour:
    call    clear_disp_SSD_dot
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   RED_COLOUR_STATE_val
    BZ        set_disp_rgb_red
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   GREEN_COLOUR_STATE_val
    BZ        set_disp_rgb_green
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   BLUE_COLOUR_STATE_val
    BZ        set_disp_rgb_blue
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   WHITE_COLOUR_STATE_val
    BZ        set_disp_rgb_white
    
    MOVF    sensor_C_read_colour_enum_var,W,a
    XORLW   BLACK_COLOUR_STATE_val
    BZ        disp_sensing_black
        
    return
    
    disp_sensing_black:
    call    set_disp_rgb_black
    call    set_disp_SSD_dot
    return
;</editor-fold>
    
    
LLI_STATE:
    
;<editor-fold defaultstate="collapsed" desc="LLI SECTION">
    MOVLW   L_SSD
    MOVWF   current_state_symbol_var,a
    MOVFF   current_state_symbol_var,SSD_OUT_var
    call    SET_SSD
    call    FLASH_RGB_DISP_DELAYED
    
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
    
    ;;todo impl
    call    NAV_STATE_IF_REQUIRED
    
GOTO    LLI_STATE
    
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
    return
    set_LLI_centre:
    MOVLW    CENTRE_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    
    MOVLW    C_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    return
    set_LLI_right:
    MOVLW    RIGHT_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    
    MOVLW    r_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    return
    set_LLI_lost:
    MOVLW    LOST_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    
    MOVLW    U_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    return
    set_LLI_stop:
    MOVLW    STOP_DRIVING_STATE_val
    MOVWF    DRIVING_STATE_var,a
    
    MOVLW    U_SSD
    MOVWF    SSD_OUT_var,a
    call    SET_SSD
    return
    
    
    WAIT_FOR_LLI_TOUCH_START:
    BTFSS    LLI_start_pressed_var,0,a
    BRA    WAIT_FOR_LLI_TOUCH_START
    CLRF    LLI_start_pressed_var, a
    return
    
    POLL_SENSORS_FOR_NEWEST_DRIVING_STATE_AND_UPDATE_STATE:
    call    poll_sensors_for_average_detected_colour
    call    set_driving_state_from_sensor_colour
    return
    
    set_driving_state_from_sensor_colour:
    

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
    ;TODO IMPLEMENT
    return
    
poll_sensors_for_detected_colour:
    call    calc_perceived_colour_L
    call    calc_perceived_colour_C
    call    calc_perceived_colour_R
    
  
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
     
    MOVF    matching_floor_to_strobe_colour_reading_diff_multiplier_val,W,a
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
    
    MOVF    matching_floor_to_strobe_colour_reading_diff_multiplier_val,W,a
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
    
    MOVF    matching_floor_to_strobe_colour_reading_diff_multiplier_val,W,a
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
  
end
    

