    PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; PORT MAPPING (matches marv.s)
; STROBE_LED_PORT = PORTD <0:2> = R, G, B strobe LEDs
; Sensors         = PORTE <0:2> = RE0(AN5)=L, RE1(AN6)=C, RE2(AN7)=R

; ADC channel select values (left-justified result in ADRESH)
ADC_AN5     EQU 00010101B   ; RE0 = left sensor
ADC_AN6     EQU 00011001B   ; RE1 = centre sensor
ADC_AN7     EQU 00011101B   ; RE2 = right sensor

; ---- 9 result variables (bank 0 access) ----
sensor_L_strobe_R   EQU 0x00
sensor_L_strobe_G   EQU 0x01
sensor_L_strobe_B   EQU 0x02

sensor_C_strobe_R   EQU 0x03
sensor_C_strobe_G   EQU 0x04
sensor_C_strobe_B   EQU 0x05

sensor_R_strobe_R   EQU 0x06
sensor_R_strobe_G   EQU 0x07
sensor_R_strobe_B   EQU 0x08

; ---- scratch ----
delay1              EQU 0x09
delay2              EQU 0x0A

; ============================================================
    PSECT code, abs
    org 0x00
    GOTO Init

; ============================================================
Init:
    ; Oscillator: 4 MHz internal
    BSF     OSCCON, 6, a    ; IRCF2 = 1
    BCF     OSCCON, 5, a    ; IRCF1 = 0
    BSF     OSCCON, 4, a    ; IRCF0 = 1 -> 4 MHz

    ; Analog/Digital config
    MOVLB   0xF
    CLRF    ANSELA, b
    CLRF    ANSELB, b
    CLRF    ANSELC, b
    CLRF    ANSELD, b
    MOVLW   00000111B
    MOVWF   ANSELE, b       ; RE0, RE1, RE2 = analog
    MOVLB   0

    ; PORTA: unused here, set as output and clear
    CLRF    TRISA, a
    CLRF    PORTA, a

    ; PORTB: all output (no buttons needed for this test)
    CLRF    TRISB, a
    CLRF    PORTB, a

    ; PORTD: strobe LEDs as outputs
    CLRF    TRISD, a
    CLRF    PORTD, a

    ; PORTE: RE0-RE2 analog inputs
    MOVLW   00000111B
    MOVWF   TRISE, a
    CLRF    PORTE, a

    ; ADC setup
    MOVLW   ADC_AN5
    MOVWF   ADCON0, a
    CLRF    ADCON1, a           ; Vref+ = VDD, Vref- = VSS
    MOVLW   00101011B           ; left-justify, 8 Tad, Fosc/32
    MOVWF   ADCON2, a


; ============================================================
Main:
    ; --- Red strobe ---
    BSF     PORTD, 0, a
    BCF     PORTD, 1, a
    BCF     PORTD, 2, a
    call    LED_SETTLE

    MOVLW   ADC_AN5
    call    READ_ADC
    MOVWF   sensor_L_strobe_R, a

    MOVLW   ADC_AN6
    call    READ_ADC
    MOVWF   sensor_C_strobe_R, a

    MOVLW   ADC_AN7
    call    READ_ADC
    MOVWF   sensor_R_strobe_R, a

    ; --- Green strobe ---
    BCF     PORTD, 0, a
    BSF     PORTD, 1, a
    BCF     PORTD, 2, a
    call    LED_SETTLE

    MOVLW   ADC_AN5
    call    READ_ADC
    MOVWF   sensor_L_strobe_G, a

    MOVLW   ADC_AN6
    call    READ_ADC
    MOVWF   sensor_C_strobe_G, a

    MOVLW   ADC_AN7
    call    READ_ADC
    MOVWF   sensor_R_strobe_G, a

    ; --- Blue strobe ---
    BCF     PORTD, 0, a
    BCF     PORTD, 1, a
    BSF     PORTD, 2, a
    call    LED_SETTLE

    MOVLW   ADC_AN5
    call    READ_ADC
    MOVWF   sensor_L_strobe_B, a

    MOVLW   ADC_AN6
    call    READ_ADC
    MOVWF   sensor_C_strobe_B, a

    MOVLW   ADC_AN7
    call    READ_ADC
    MOVWF   sensor_R_strobe_B, a

    ; --- Strobes off ---
    BCF     PORTD, 0, a
    BCF     PORTD, 1, a
    BCF     PORTD, 2, a

    GOTO    Main

; ============================================================
; READ_ADC: W = ADC channel select value -> W = ADRESH result
READ_ADC:
    MOVWF   ADCON0, a
    NOP
    NOP
    NOP
    NOP
    BSF     ADCON0, 1, a    ; GO/DONE = 1, start conversion
wait_adc:
    BTFSC   ADCON0, 1, a
    BRA     wait_adc
    MOVF    ADRESH, W, a
    RETURN

; ============================================================
; LED_SETTLE: ~20 us at 4 MHz for strobe LED to stabilise
LED_SETTLE:
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

    end
