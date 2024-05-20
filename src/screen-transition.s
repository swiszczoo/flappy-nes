.include "gamestates.inc"
.include "registers.inc"


.segment "ZEROPAGE"
    .import SCRATCH
    .import palette_addr
    .import frame_counter, my_ppuctrl, my_scroll_x, my_scroll_y
    .import skip_nmi, global_scroll_x, global_chr_bank
    .import hiscore_digits
    .import gamepad_1_chg
    .import oam_offset


.segment "OAM"
    .import OAM

.segment "BSS"
    .import nametbl1_attrs, nametbl2_attrs
    .import bird_pos_x, bird_pos_y


.import draw_bird
.import draw_ground
.import set_game_state
.import update_bird
.import wait_for_szh


.segment "CODE"
screen_transition_init:
    ; copy scroll position
    LDA global_scroll_x
    STA my_scroll_x

    ; fix CHR bank
    LDA #$20
    SEC
    SBC global_chr_bank
    AND #$1F
    STA global_chr_bank


    ; remove all sprites above slot 32
    LDA #$FF
    LDX #$80
:   STA OAM, X
    INX
    INX
    INX
    INX
    BNE :-

    ; set up sprite 0 for SZH
    LDA #$CE
    STA OAM+0
    LDA #$A8
    STA OAM+3

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
    INC global_scroll_x
    INC global_scroll_x
    LDA global_scroll_x
    STA my_scroll_x

    DEC global_chr_bank
    LDA global_chr_bank
    AND #$1F
    STA global_chr_bank

    DEC bird_pos_x
    ; every second frame decrease bird_pos once more
    LDA frame_counter
    AND #1
    BNE @no_move_left
    DEC bird_pos_x
    
    ; also try to correct bird Y position
    LDA bird_pos_y
    CMP #$64
    BEQ @no_move_left
    BCC :+
    DEC bird_pos_y
    JMP @no_move_left
:   INC bird_pos_y
    
@no_move_left:
    LDX #4
    STX oam_offset
    JSR update_bird
    JSR draw_bird

    ; check if bird X position is already ok
    LDA bird_pos_x
    CMP #$26
    BNE @position_not_ok
    LDA STATE_INSTRUCTIONS
    JSR set_game_state

@position_not_ok:
    JSR wait_for_szh
    JSR draw_ground

    RTS

.export screen_transition_init
.export screen_transition_destroy
.export screen_transition_vblank
.export screen_transition_loop

