    PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; RB2 = cap touch (AN8)
; RA0 = top segment of 7-seg display (lights on touch, off otherwise)

; ---- RAM variables ----
delay1      EQU 0x00        ; DELAY_333ms outer counter
delay2      EQU 0x01        ; DELAY_333ms inner counter
adc_result  EQU 0x02        ; CAP_TOUCH_ROUTINE output
baseline    EQU 0x03        ; live-tracked baseline ADC value
touch_count EQU 0x04        ; consecutive above-threshold readings
touch_timer EQU 0x05        ; overall touch duration counter (timeout guard)
sample1     EQU 0x06        ; median filter sample
sample2     EQU 0x07
sample3     EQU 0x08

; ---- Touch tuning constants ----
TOUCH_THRESH    EQU 0x03    ; min delta (baseline - reading) to count as touch
DEBOUNCE_N      EQU 0x03    ; consecutive readings required for confirmation
MAX_TOUCH_T     EQU 0xC8    ; ~200 loops max before timeout/reset

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
main_loop:
    BCF     LATA, 0, a          ; segment off — waiting for touch

    CALL    WAIT_FOR_TOUCH      ; blocks until confirmed touch

    BSF     LATA, 0, a          ; touch confirmed — segment on
    CALL    DELAY_2S
    GOTO    main_loop

; ============================================================
; WAIT_FOR_TOUCH
; Blocks until a valid touch is detected.
; Self-calibrates baseline on entry, then tracks drift during polling.
; Uses median-of-3 filter, debounce (DEBOUNCE_N), and timeout (MAX_TOUCH_T).
; Returns when touch is confirmed. Clobbers: adc_result, baseline,
;   touch_count, touch_timer, sample1, sample2, sample3, delay1, delay2.
; ============================================================
WAIT_FOR_TOUCH:
    ; --- Calibrate baseline: sum 4 readings then divide by 4 ---
    CALL    CAP_TOUCH_ROUTINE
    MOVF    adc_result, W, a
    MOVWF   baseline, a

    CALL    CAP_TOUCH_ROUTINE
    MOVF    adc_result, W, a
    ADDWF   baseline, f, a

    CALL    CAP_TOUCH_ROUTINE
    MOVF    adc_result, W, a
    ADDWF   baseline, f, a

    CALL    CAP_TOUCH_ROUTINE
    MOVF    adc_result, W, a
    ADDWF   baseline, f, a

    ; Divide by 4 (two right-rotates, mask carry-in bits)
    RRNCF   baseline, f, a
    RRNCF   baseline, f, a
    MOVLW   0x3F
    ANDWF   baseline, f, a

    CLRF    touch_count, a
    CLRF    touch_timer, a

; --- Main polling loop ---
_WFT_POLL:
    ; Average 16 samples — reduces noise floor ~4x, making small deltas detectable
    CLRF    sample1, a          ; accumulator high byte
    CLRF    sample2, a          ; accumulator low byte
    MOVLW   0x10                ; 16 samples
    MOVWF   sample3, a
_WFT_AVG:
    CALL    CAP_TOUCH_ROUTINE
    MOVF    adc_result, W, a
    ADDWF   sample2, f, a       ; add to low byte
    MOVLW   0x00
    ADDWFC  sample1, f, a       ; carry into high byte
    DECFSZ  sample3, f, a
    BRA     _WFT_AVG
    ; Divide 16-bit sum by 16 (right-shift 4) -> result in sample2
    SWAPF   sample2, f, a       ; swap nibbles of low byte
    MOVLW   0x0F
    ANDWF   sample2, f, a       ; isolate low nibble (was high)
    SWAPF   sample1, W, a       ; swap high byte into W
    ANDLW   0xF0                ; isolate high nibble
    IORWF   sample2, f, a       ; merge: sample2 = sum/16
    MOVFF   sample2, adc_result

    ; delta = baseline - adc_result (positive = touch lowered the reading)
    MOVF    adc_result, W, a
    SUBWF   baseline, W, a      ; W = baseline - reading
    BN      _WFT_DRIFT_UP       ; negative means reading > baseline (drifted up)

    ; Positive delta — check against threshold
    MOVWF   sample1, a          ; reuse sample1 as delta temp
    MOVLW   TOUCH_THRESH
    CPFSGT  sample1, a          ; skip if delta > TOUCH_THRESH
    BRA     _WFT_NO_TOUCH

    ; --- Above threshold: possible touch ---
    INCF    touch_count, f, a
    INCF    touch_timer, f, a

    ; Timeout guard — held too long, not a real finger
    MOVLW   MAX_TOUCH_T
    CPFSLT  touch_timer, a      ; skip if touch_timer < MAX_TOUCH_T
    BRA     _WFT_TIMEOUT

    ; Debounce — need DEBOUNCE_N consecutive readings
    MOVLW   DEBOUNCE_N
    CPFSGT  touch_count, a      ; skip if touch_count > DEBOUNCE_N
    BRA     _WFT_POLL

    ; *** TOUCH CONFIRMED ***
    RETURN

_WFT_DRIFT_UP:
    ; Reading drifted above baseline (environment shifted) — nudge baseline up
    INCF    baseline, f, a
    CLRF    touch_count, a
    CLRF    touch_timer, a
    BRA     _WFT_POLL

_WFT_NO_TOUCH:
    ; Delta too small — track baseline slowly toward current reading
    CLRF    touch_count, a
    CLRF    touch_timer, a
    MOVF    adc_result, W, a
    CPFSGT  baseline, a         ; skip if baseline > adc_result
    BRA     _WFT_BL_LOW
    DECF    baseline, f, a      ; baseline > reading: nudge down
    BRA     _WFT_POLL
_WFT_BL_LOW:
    CPFSLT  baseline, a         ; skip if baseline < adc_result
    BRA     _WFT_POLL           ; baseline == reading: do nothing
    INCF    baseline, f, a      ; baseline < reading: nudge up
    BRA     _WFT_POLL

_WFT_TIMEOUT:
    ; Touch held too long — snap baseline to current and reset
    MOVFF   adc_result, baseline
    CLRF    touch_count, a
    CLRF    touch_timer, a
    BRA     _WFT_POLL

; ============================================================
; _MEDIAN_3: sort sample1/sample2/sample3, return median in adc_result
; ============================================================
_MEDIAN_3:
    ; Pass 1: ensure sample1 <= sample2
    MOVF    sample2, W, a
    CPFSGT  sample1, a          ; skip if sample1 > sample2
    BRA     _M3_12OK
    MOVFF   sample1, adc_result ; swap via adc_result as temp
    MOVFF   sample2, sample1
    MOVFF   adc_result, sample2
_M3_12OK:
    ; Pass 2: ensure sample2 <= sample3
    MOVF    sample3, W, a
    CPFSGT  sample2, a          ; skip if sample2 > sample3
    BRA     _M3_23OK
    MOVFF   sample2, adc_result
    MOVFF   sample3, sample2
    MOVFF   adc_result, sample3
_M3_23OK:
    ; Pass 3: ensure sample1 <= sample2 again (bubble sort complete)
    MOVF    sample2, W, a
    CPFSGT  sample1, a
    BRA     _M3_DONE
    MOVFF   sample1, adc_result
    MOVFF   sample2, sample1
    MOVFF   adc_result, sample2
_M3_DONE:
    MOVFF   sample2, adc_result ; sample2 is the median
    RETURN

; ============================================================
; CAP_TOUCH_ROUTINE: CTMU-based cap touch on RB2/AN8
; Result (ADRESH, left-justified) stored in adc_result.
; CTMU regs at 0xF43-0xF45 are below the access bank — banked access required.
CAP_TOUCH_ROUTINE:
    ; 1. Discharge RB2
    MOVLB   0xF
    BCF     ANSELB, 2, b        ; digital mode
    MOVLB   0x0
    BCF     TRISB, 2, a         ; output
    BCF     LATB, 2, a          ; drive low
    NOP
    NOP

    ; 2. Switch to analog input
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

    ; 4. Configure CTMU (banked access required for 0xF43-0xF45)
    MOVLB   0xF
    MOVLW   00000001B           ; CTMUICON: IRNG=01 (0.55 uA)
    MOVWF   CTMUICON, b
    MOVLW   10000000B           ; CTMUCONH: CTMUEN=1, IDISSEN=0, CTTRIG=0
    MOVWF   CTMUCONH, b
    MOVLW   00000001B           ; CTMUCONL: EDG1STAT=1 — close switch, current ON
    MOVWF   CTMUCONL, b
    MOVLB   0x0

    ; 5. No pre-charge NOPs — CTMU charges from 0V during 128us ACQT window

    ; 6. Trigger ADC — CTMU keeps charging pad+S/H during acquisition
    BSF     ADCON0, 1, a        ; GO = 1
_CTR_ADC_POLL:
    BTFSC   ADCON0, 1, a
    BRA     _CTR_ADC_POLL

    ; 7. Stop CTMU after sampling is done
    MOVLB   0xF
    CLRF    CTMUCONL, b         ; EDG1STAT=0 — current off
    CLRF    CTMUCONH, b         ; CTMUEN=0
    MOVLB   0x0

    ; 8. Restore RB2 to digital
    MOVLB   0xF
    BCF     ANSELB, 2, b
    MOVLB   0x0

    MOVFF   ADRESH, adc_result
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
_D333_OUTER:
    MOVLW   0xFF
    MOVWF   delay2, a
_D333_INNER:
    DECFSZ  delay2, f, a
    GOTO    _D333_INNER
    DECFSZ  delay1, f, a
    GOTO    _D333_OUTER
    RETURN

    END
