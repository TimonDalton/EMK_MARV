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
;
; RB0 = push button (active high) — hold to drive forward

PWM_FULL    equ 15
PWM_STOP    equ 0

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

    ; PORTB — RB0 as digital input
    MOVLB   0xF
    CLRF    ANSELB, b
    MOVLB   0x0
    BSF     TRISB, 0, a         ; RB0 = input

    ; PORTC motor outputs — all low
    clrf    LATC, a
    bcf     TRISC, 0, a         ; RC0 = output (IN2 left reverse)
    bcf     TRISC, 1, a         ; RC1 = output (IN1 left forward PWM)
    bcf     TRISC, 2, a         ; RC2 = output (IN3 right forward PWM)
    bcf     TRISC, 3, a         ; RC3 = output (IN4 right reverse)
    BCF     LATC, 0, a
    BCF     LATC, 3, a

    ; PWM setup — 50 kHz at 4 MHz (PR2 = 19)
    movlw   19
    movwf   PR2, a
    clrf    T2CON, a
    clrf    TMR2, a

    BSF     CCP1CON, 3, a       ; CCP1 PWM mode (1100)
    BSF     CCP1CON, 2, a
    BCF     CCP1CON, 1, a
    BCF     CCP1CON, 0, a

    BSF     CCP2CON, 3, a       ; CCP2 PWM mode (1100)
    BSF     CCP2CON, 2, a
    BCF     CCP2CON, 1, a
    BCF     CCP2CON, 0, a

    bsf     T2CON, 2, a         ; Enable Timer2

    movlw   PWM_STOP
    movwf   CCPR1L, a
    movwf   CCPR2L, a

; ============================================================
motor_loop:
    BTFSC   PORTB, 0, a         ; skip if RB0 low (not pressed)
    BRA     drive_forward

    ; RB0 not pressed — stop
    BCF     LATC, 0, a
    BCF     LATC, 3, a
    movlw   PWM_STOP
    movwf   CCPR2L, a
    movwf   CCPR1L, a
    GOTO    motor_loop

drive_forward:
    BCF     LATC, 0, a          ; IN2 low (left not reversing)
    BCF     LATC, 3, a          ; IN4 low (right not reversing)
    movlw   PWM_FULL
    movwf   CCPR2L, a           ; left forward
    movwf   CCPR1L, a           ; right forward
    GOTO    motor_loop

    END
