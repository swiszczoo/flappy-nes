; this file contains general purpose routines
; operating on decimal digits

.segment "ZEROPAGE"
    .import SCRATCH

.segment "CODE"
; inputs:
; SCRATCH + 0 - low byte of number address
; SCRATCH + 1 - high byte of number address
; SCRATCH + 2 - total number length
; outputs: 
; SCRATCH + 0 - low byte of the first non-zero digit
; SCRATCH + 1 - high byte of the first non-zero digit
; SCRATCH + 2 - number length not counting leading zeros
; remarks: this function ignores the last digit
decimal_skip_leading_zeros:
    LDY #0
    STY SCRATCH+3
    DEC SCRATCH+2
:   LDA (SCRATCH+0), Y
    BNE :+
    INY
    INC SCRATCH+3
    CPY SCRATCH+2
    BCC :-
:   LDA SCRATCH+0
    CLC
    ADC SCRATCH+3
    STA SCRATCH+0
    BCC :+
    INC SCRATCH+1
:   LDA SCRATCH+2
    SEC
    SBC SCRATCH+3
    STA SCRATCH+2
    INC SCRATCH+2
    RTS

.export decimal_skip_leading_zeros

; inputs:
; SCRATCH + 0 - low byte of number address
; SCRATCH + 1 - high byte of number address
; SCRATCH + 2 - total number length
decimal_increment:
    CLC
    DEC SCRATCH+2
    LDY SCRATCH+2
    LDA (SCRATCH+0), Y
    ADC #1
    STA (SCRATCH+0), Y
    CMP #10
    BCC @no_carry
    LDA #0
    STA (SCRATCH+0), Y
    JMP decimal_increment             ; process next digit
@no_carry:
    RTS

.export decimal_increment

