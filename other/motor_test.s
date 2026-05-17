    PROCESSOR 18F45K22

;; ---------- Configuration bits ----------
CONFIG  FOSC   = INTIO67
CONFIG  WDTEN  = OFF
CONFIG  MCLRE  = EXTMCLR
CONFIG  LVP    = ON

#include <xc.inc>
#include "pic18f45k22.inc"

; Motor pin mapping (matches marv.s)
; RC1 / CCP2 = IN1 — left motor forward PWM
; RC0         = IN2 — left motor reverse (digital)
; RC2 / CCP1 = IN3 — right motor forward PWM
; RC3         = IN4 — right motor reverse (digital)

PWM_FULL    equ 15      ; 75% duty cycle
PWM_STOP    equ 0

delay1      EQU 0x00
delay2      EQU 0x01

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

    ; Set RC0–RC3 as outputs, all low
    clrf    LATC, a
    bcf     TRISC, 0, a     ; RC0 = output (IN2 left reverse)
    bcf     TRISC, 1, a     ; RC1 = output (IN1 left forward PWM)
    bcf     TRISC, 2, a     ; RC2 = output (IN3 right forward PWM)
    bcf     TRISC, 3, a     ; RC3 = output (IN4 right reverse)
    BCF     LATC, 0, a      ; IN2 low
    BCF     LATC, 3, a      ; IN4 low

    ; Setup PWM — 50 kHz at 4 MHz (PR2 = 19)
    movlw   19
    movwf   PR2, a
    clrf    T2CON, a
    clrf    TMR2, a

    BSF     CCP1CON, 3, a   ; CCP1 PWM mode (1100)
    BSF     CCP1CON, 2, a
    BCF     CCP1CON, 1, a
    BCF     CCP1CON, 0, a

    BSF     CCP2CON, 3, a   ; CCP2 PWM mode (1100)
    BSF     CCP2CON, 2, a
    BCF     CCP2CON, 1, a
    BCF     CCP2CON, 0, a

    bsf     T2CON, 2, a     ; Enable Timer2

    ; Start stopped
    movlw   PWM_STOP
    movwf   CCPR1L, a
    movwf   CCPR2L, a

; ============================================================
motor_loop:

    ; === FORWARD ===
    BCF     LATC, 0, a          ; IN2 low  (left not reversing)
    BCF     LATC, 3, a          ; IN4 low  (right not reversing)
    movlw   PWM_FULL
    movwf   CCPR2L, a           ; left forward
    movwf   CCPR1L, a           ; right forward
    call    DELAY_333ms
    call    DELAY_333ms
    call    DELAY_333ms         ; ~1 second

    ; === STOP ===
    movlw   PWM_STOP
    movwf   CCPR1L, a
    movwf   CCPR2L, a
    call    DELAY_333ms         ; brief pause

    ; === REVERSE ===
    movlw   PWM_STOP
    movwf   CCPR2L, a           ; IN1 off
    movwf   CCPR1L, a           ; IN3 off
    BSF     LATC, 0, a          ; IN2 high (left reverse)
    BSF     LATC, 3, a          ; IN4 high (right reverse)
    call    DELAY_333ms
    call    DELAY_333ms
    call    DELAY_333ms         ; ~1 second

    ; === STOP ===
    BCF     LATC, 0, a
    BCF     LATC, 3, a
    call    DELAY_333ms         ; brief pause

    GOTO    motor_loop

; ============================================================
DELAY_333ms:
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

    END
