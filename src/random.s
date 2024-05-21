.segment "ZEROPAGE"
    .import SCRATCH


.segment "BSS"
    lfsr_state: .res 2

.segment "CODE"

random_seed:
    STX lfsr_state+0
    STY lfsr_state+1
    RTS

.export random_seed

; this implements a 16-bit Fibbonacci LFSR
; from https://en.wikipedia.org/wiki/Linear-feedback_shift_register

random_next:
    LDA #1
    STA SCRATCH+0
    CLC
@lfsr_loop:
    BCS @exit
    LDA lfsr_state+1
    AND #63
    TAX
    LDA lfsr_data, X
    ROR A
    ROR lfsr_state+0
    ROR lfsr_state+1
    LDA lfsr_state+1
    ROR A
    ROL SCRATCH+0
    JMP @lfsr_loop
@exit:
    LDA SCRATCH+0
    RTS

.export random_next

.segment "RODATA"
lfsr_data:
    ; a 64-byte lookup table to speed up LFSR computation
    .byte 0, 1, 0, 1, 1, 0, 1, 0, 1, 0
    .byte 1, 0, 0, 1, 0, 1, 0, 1, 0, 1
    .byte 1, 0, 1, 0, 1, 0, 1, 0, 0, 1
    .byte 0, 1, 1, 0, 1, 0, 0, 1, 0, 1
    .byte 0, 1, 0, 1, 1, 0, 1, 0, 1, 0
    .byte 1, 0, 0, 1, 0, 1, 0, 1, 0, 1
    .byte 1, 0, 1, 0
