    PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; PORTA (all 8 bits) = raw ADC high byte output
; RB2 = cap touch input (AN8)

delay1      EQU 0x00
delay2      EQU 0x01
adc_result  EQU 0x02

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

    ; PORTB — RB2 digital initially
    MOVLB   0xF
    CLRF    ANSELB, b
    MOVLB   0x0

; ============================================================
poll_loop:
    CALL    CAP_TOUCH_ROUTINE
    MOVFF   adc_result, LATA    ; dump raw ADRESH to PORTA for calibration
    GOTO    poll_loop

; ============================================================
; CAP_TOUCH_ROUTINE: CTMU charges RB2/AN8, ADC samples it.
; Result (left-justified high byte) stored in adc_result.
CAP_TOUCH_ROUTINE:
    ; 1. Discharge RB2
    MOVLB   0xF
    BCF     ANSELB, 2, b        ; digital mode
    MOVLB   0x0
    BCF     TRISB, 2, a         ; output
    BCF     LATB, 2, a          ; drive low
    NOP
    NOP

    ; 2. Switch RB2 to analog input
    BSF     TRISB, 2, a
    MOVLB   0xF
    BSF     ANSELB, 2, b        ; analog (AN8)
    MOVLB   0x0

    ; 3. Configure ADC for AN8
    MOVLW   0x21                ; CHS = AN8 (bits[6:2] = 01000), ADON = 1
    MOVWF   ADCON0, a
    CLRF    ADCON1, a           ; Vref = VDD/VSS
    MOVLW   00010110B           ; ADFM=0 (left-justify), ACQT=010 (4 Tad = 64us), ADCS=110 (Fosc/64)
    MOVWF   ADCON2, a

    ; 4. Configure CTMU (0xF43-0xF45 — below access bank, must use banked)
    MOVLB   0xF
    MOVLW   00000001B           ; CTMUICON: ITRIM=0, IRNG=01 (0.55 uA) — avoid saturation in 64us window
    MOVWF   CTMUICON, b

    MOVLW   10000000B           ; CTMUCONH: CTMUEN=1, IDISSEN=0, CTTRIG=0
    MOVWF   CTMUCONH, b

    MOVLW   00000001B           ; CTMUCONL: EDG1STAT=1 — close switch
    MOVWF   CTMUCONL, b
    MOVLB   0x0

    ; 5. Charge time ~4 us
    NOP
    NOP
    NOP
    NOP

    ; 6. Take ADC sample
    BSF     ADCON0, 1, a        ; GO = 1
ADC_POLL:
    BTFSC   ADCON0, 1, a
    BRA     ADC_POLL

    ; 7. Stop CTMU
    MOVLB   0xF
    CLRF    CTMUCONL, b         ; EDG1STAT=0 — open switch
    MOVLW   00000000B           ; CTMUEN=0, everything off
    MOVWF   CTMUCONH, b
    MOVLB   0x0

    ; 8. Save result
    MOVFF   ADRESH, adc_result

    ; 9. Restore RB2 to digital
    MOVLB   0xF
    BCF     ANSELB, 2, b
    MOVLB   0x0

    RETURN

    END
