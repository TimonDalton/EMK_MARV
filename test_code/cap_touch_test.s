    PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; PORTA bit 0 (RA0) = top segment of 7-seg display
; RB2 = cap touch (AN8)

delay1       EQU 0x00
delay2       EQU 0x01
touch_adc_h  EQU 0x02
CAP_REG_var  EQU 0x03
touch_delay1 EQU 0x04
touch_delay2 EQU 0x05
touch_delay3 EQU 0x06

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

    ; PORTA — all outputs (SSD), all low
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
    CALL    MAIN_CAP_ROUTINE

    TSTFSZ  CAP_REG_var, a      ; skip if no touch
    BRA     touch_detected

    ; No touch — top segment off
    BCF     LATA, 0, a
    GOTO    poll_loop

touch_detected:
    BSF     LATA, 0, a          ; top segment on
    CALL    DELAY_2S
    BCF     LATA, 0, a          ; top segment off
    GOTO    poll_loop

; ============================================================
; MAIN_CAP_ROUTINE: double-sample via CTMU, sets CAP_REG_var
; Touch = ADC reading < 0xFA (250) — more capacitance charges slower
MAIN_CAP_ROUTINE:
    CALL    CAP_TOUCH_ROUTINE
    CALL    _TOUCH_SAMPLE_DELAY
    CALL    CAP_TOUCH_ROUTINE   ; second sample to confirm

    MOVLW   0x13
    CPFSLT  touch_adc_h, a      ; skip if touch_adc_h < 0x13 (touch: ~0x10)
    BRA     MCR_NO_TOUCH
    SETF    CAP_REG_var, a
    BRA     MCR_DONE

MCR_NO_TOUCH:
    CLRF    CAP_REG_var, a

MCR_DONE:
    RETURN

; ============================================================
; CAP_TOUCH_ROUTINE (CTMU method)
; Discharges RB2, then lets CTMU inject a fixed current for ~10 us,
; then takes an ADC reading. More capacitance (touch) = lower voltage
; = lower ADC value after the same charge time.
CAP_TOUCH_ROUTINE:
    ; 1. Discharge RB2
    MOVLB   0xF
    BCF     ANSELB, 2, b        ; digital mode
    MOVLB   0x0
    BCF     TRISB, 2, a         ; output
    BCF     LATB, 2, a          ; drive low — discharge sensor
    NOP
    NOP                         ; ~5 us discharge

    ; 2. Switch RB2 to analog input for CTMU/ADC
    BSF     TRISB, 2, a         ; input
    MOVLB   0xF
    BSF     ANSELB, 2, b        ; analog (AN8)
    MOVLB   0x0

    ; 3. Configure ADC for AN8
    MOVLW   0x21                ; CHS = AN8 (01000 = bits[6:2]), ADON = 1
    MOVWF   ADCON0, a
    CLRF    ADCON1, a           ; Vref = VDD/VSS
    MOVLW   00010110B           ; ADFM=0 (left-justify), ACQT=010 (4 Tad = 64us), ADCS=110 (Fosc/64)
    MOVWF   ADCON2, a

    ; 4. Configure CTMU (registers at 0xF43-0xF45 — below access bank, must use banked)
    MOVLB   0xF
    ; CTMUICON (0xF43): ITRIM=000000, IRNG=01 (0.55 uA)
    MOVLW   00000001B
    MOVWF   CTMUICON, b

    ; CTMUCONH (0xF45): CTMUEN=1, IDISSEN=0, CTTRIG=0
    MOVLW   10000000B
    MOVWF   CTMUCONH, b

    ; CTMUCONL (0xF44): EDG1STAT=1 (bit 0) — close current switch
    MOVLW   00000001B
    MOVWF   CTMUCONL, b
    MOVLB   0x0

    ; 5. Fixed charge time ~4 us
    NOP
    NOP
    NOP
    NOP

    ; 6. Take ADC sample
    BSF     ADCON0, 1, a        ; GO = 1
CTMU_ADC_POLL:
    BTFSC   ADCON0, 1, a        ; wait for GO = 0
    BRA     CTMU_ADC_POLL

    ; 7. Stop charging and disable CTMU
    MOVLB   0xF
    CLRF    CTMUCONL, b         ; EDG1STAT=0 — open current switch
    MOVLW   00000000B           ; CTMUEN=0, everything off
    MOVWF   CTMUCONH, b
    MOVLB   0x0

    ; 9. Save result
    MOVFF   ADRESH, touch_adc_h

    ; 10. Restore RB2 to digital
    MOVLB   0xF
    BCF     ANSELB, 2, b
    MOVLB   0x0

    RETURN

; ============================================================
; _TOUCH_SAMPLE_DELAY: ~100 ms between double-samples
_TOUCH_SAMPLE_DELAY:
    MOVLW   0xCA
    MOVWF   touch_delay3, a
_TSD_L3:
    MOVLW   0x1B
    MOVWF   touch_delay2, a
_TSD_L2:
    MOVLW   0x28
    MOVWF   touch_delay1, a
_TSD_L1:
    DECFSZ  touch_delay1, f, a
    BRA     _TSD_L1
    DECFSZ  touch_delay2, f, a
    BRA     _TSD_L2
    DECFSZ  touch_delay3, f, a
    BRA     _TSD_L3
    RETURN

; ============================================================
; DELAY_2S: ~2 seconds (6 x ~333 ms)
DELAY_2S:
    CALL    DELAY_333ms
    CALL    DELAY_333ms
    CALL    DELAY_333ms
    CALL    DELAY_333ms
    CALL    DELAY_333ms
    CALL    DELAY_333ms
    RETURN

DELAY_333ms:
    MOVLW   0x6C
    MOVWF   delay1, a
d333_outer:
    MOVLW   0xFF
    MOVWF   delay2, a
d333_inner:
    DECFSZ  delay2, f, a
    GOTO    d333_inner
    DECFSZ  delay1, f, a
    GOTO    d333_outer
    RETURN

    END
