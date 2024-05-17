.include "gamestates.inc"
.include "registers.inc"


.segment "ZEROPAGE"
    .import SCRATCH
    .import palette_addr
    .import frame_counter, my_ppuctrl, my_scroll_x, my_scroll_y
    .import skip_nmi, global_scroll_x, global_chr_bank
    .import hiscore_digits
    .import gamepad_1_chg


.segment "OAM"
    .import OAM

.segment "BSS"

.segment "CODE"
screen_transition_init:
    ; remove all sprites above slot 32
    LDA #$FF
    LDX #$80
:   STA OAM, X
    INX
    INX
    INX
    INX
    BNE :-

    RTS

screen_transition_destroy:
    RTS

screen_transition_vblank:
    ; enable rendering
    LDA #%00011110
    STA PPUMASK

    ; restore background color
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDA #$21
    STA PPUDATA
    RTS

screen_transition_loop:
    RTS

.export screen_transition_init
.export screen_transition_destroy
.export screen_transition_vblank
.export screen_transition_loop
