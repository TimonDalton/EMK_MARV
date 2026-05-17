    PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; Pure ADC read on RB2/AN8 — no CTMU
; PORTA = ADRESL (low 8 bits of right-justified 10-bit result)
; At Vdd: ADRESL = 0xFF. At GND: ADRESL = 0x00.

adc_result  EQU 0x00

; ============================================================
    PSECT code, abs
    org 0x00
    GOTO    main

    org 0x08
    GOTO    main

; ============================================================
main:
    ; Oscillator: 4 MHz internal (IRCF = 110)
    BSF     OSCCON, 6, a
    BCF     OSCCON, 5, a
    BSF     OSCCON, 4, a

    ; PORTA — all outputs, all low
    MOVLB   0xF
    CLRF    ANSELA, b
    MOVLB   0x0
    CLRF    TRISA, a
    CLRF    LATA, a

    ; PORTB — start with RB2 digital
    MOVLB   0xF
    CLRF    ANSELB, b
    MOVLB   0x0

; ============================================================
poll_loop:
    CALL    CAP_TOUCH_ROUTINE
    MOVFF   adc_result, LATA
    GOTO    poll_loop

; ============================================================
; CAP_TOUCH_ROUTINE: pure ADC read, no CTMU.
; Right-justified — ADRESL stored in adc_result.
; At Vdd: ADRESL = 0xFF. Floating/GND: near 0x00.
CAP_TOUCH_ROUTINE:
    ; RB2 as analog input
    MOVLB   0xF
    BSF     ANSELB, 2, b
    MOVLB   0x0
    BSF     TRISB, 2, a

    ; ADC setup
    MOVLW   0x21                ; CHS = AN8, ADON = 1
    MOVWF   ADCON0, a
    CLRF    ADCON1, a           ; Vref = Vdd/Vss
    MOVLW   10111110B           ; ADFM=1 (right-justify), ACQT=111 (20 Tad), ADCS=110 (Fosc/64)
    MOVWF   ADCON2, a

    ; Trigger conversion
    BSF     ADCON0, 1, a
adc_wait:
    BTFSC   ADCON0, 1, a
    BRA     adc_wait

    MOVFF   ADRESL, adc_result
    RETURN

    END
