.include "gamestates.inc"
.include "registers.inc"


.segment "ZEROPAGE"
    .import SCRATCH
    .import palette_addr
    .import frame_counter, my_ppuctrl, my_coarse_scroll_x, my_scroll_x, my_scroll_y
    .import skip_nmi, global_scroll_x, global_chr_bank
    .import gamepad_1_chg
    .import oam_offset

    .import current_score_digits
    .import easy_hiscore_digits, prev_hiscore_digits
    .import game_level
    .import new_hiscore_flag
    
    .import ppu_update_addr


.segment "OAM"
    .import OAM


.segment "BSS"
    game_over_load_progress: .res 1
    game_over_state: .res 1
    current_score_counter: .res 5
    current_hiscore_counter: .res 5

    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y


.import decimal_increment
.import decimal_is_greater_than
.import draw_ground
.import draw_sprites_to_oam
.import dynjmp
.import set_bird_data_for_first_sprite
.import wait_for_szh
.import wait_for_16_scanlines

.segment "CODE"

screen_game_over_init:
    ; clear sprites 1, 2, 3, 4, 5, 6, 7, 8 and 9
    LDA #0
    STA sprite_addr_hi+1 
    STA sprite_addr_hi+2
    STA sprite_addr_hi+3
    STA sprite_addr_hi+4
    STA sprite_addr_hi+5 
    STA sprite_addr_hi+6
    STA sprite_addr_hi+7
    STA sprite_addr_hi+8
    STA sprite_addr_hi+9

    ; clear load progress
    STA game_over_load_progress
    STA my_scroll_x
    STA my_coarse_scroll_x
    STA game_over_state

    ; clear score counters
    LDX #5
    LDA #0
:   DEX
    STA current_score_counter, X
    STA current_hiscore_counter, X
    BNE :-

    LDA prev_hiscore_digits+0
    STA current_hiscore_counter+1
    LDA prev_hiscore_digits+1
    STA current_hiscore_counter+2
    LDA prev_hiscore_digits+2
    STA current_hiscore_counter+3
    LDA prev_hiscore_digits+3
    STA current_hiscore_counter+4


    ; setup sprite 0 for SZH detection
    LDA #$BF                    ; Y position
    STA OAM
    LDA #1                      ; tile ID
    STA OAM+1
    LDA #0                      ; attributes
    STA OAM+2
    LDA #$E0                    ; X position
    STA OAM+3

    ; setup score sprites
    LDA #$46
    STA sprite_pos_y+1
    STA sprite_pos_y+2
    STA sprite_pos_y+3
    STA sprite_pos_y+4
    LDA #$5E
    STA sprite_pos_y+5
    STA sprite_pos_y+6
    STA sprite_pos_y+7
    STA sprite_pos_y+8
    LDA #$B6
    STA sprite_pos_x+1
    STA sprite_pos_x+5
    LDA #$AE
    STA sprite_pos_x+2
    STA sprite_pos_x+6
    LDA #$A6
    STA sprite_pos_x+3
    STA sprite_pos_x+7
    LDA #$9E
    STA sprite_pos_x+4
    STA sprite_pos_x+8

    RTS

screen_game_over_destroy:
    RTS

screen_game_over_vblank:
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
    
screen_game_over_loop:
    ; check if we're still loading
    LDX game_over_load_progress
    CPX #14
    BCS @no_loading

    LDA game_over_load_stage_lo, X
    STA ppu_update_addr+0
    LDA game_over_load_stage_hi, X
    STA ppu_update_addr+1
    INC game_over_load_progress

@no_loading:
    LDA game_over_state
    JSR dynjmp
    .addr @initial
    .addr @counting
    .addr @main

    

@initial:
    LDX game_over_load_progress
    CPX #14
    BCC :+

    INC game_over_state
    LDX #1
    LDY #4
    JSR draw_score_sprite
    LDX #5
    LDY #9
    JSR draw_score_sprite
:
    JMP screen_game_over_loop_part2

@counting:
    ; increment current score every frame
    LDA #.lobyte(current_score_counter)
    STA SCRATCH+0
    LDA #.hibyte(current_score_counter)
    STA SCRATCH+1
    LDA #5
    STA SCRATCH+2
    JSR decimal_increment

    ; check if it is greater than player real score
    LDA #.lobyte(current_score_counter+1)
    STA SCRATCH+0
    LDA #.hibyte(current_score_counter+1)
    STA SCRATCH+1
    LDA #.lobyte(current_score_digits)
    STA SCRATCH+2
    LDA #.hibyte(current_score_digits)
    STA SCRATCH+3
    LDA #4
    STA SCRATCH+4
    JSR decimal_is_greater_than
    BEQ @counting_no_score_greater_than_real

    ; if it is, change state to and give control to player
    INC game_over_state
    JMP screen_game_over_loop_part2

@counting_no_score_greater_than_real:

    ; check if it is greater than current highscore
    LDA #.lobyte(current_score_counter)
    STA SCRATCH+0
    LDA #.hibyte(current_score_counter)
    STA SCRATCH+1
    LDA #.lobyte(current_hiscore_counter)
    STA SCRATCH+2
    LDA #.hibyte(current_hiscore_counter)
    STA SCRATCH+3
    LDA #5
    STA SCRATCH+4
    JSR decimal_is_greater_than
    BEQ @counting_no_score_greater_than_hiscore

    ; if it is, copy its bytes to current hiscore
    LDA current_score_counter+1
    STA current_hiscore_counter+1
    LDA current_score_counter+2
    STA current_hiscore_counter+2
    LDA current_score_counter+3
    STA current_hiscore_counter+3
    LDA current_score_counter+4
    STA current_hiscore_counter+4

@counting_no_score_greater_than_hiscore:

    ; then finally draw score sprites
    LDX #1
    LDY #4
    JSR draw_score_sprite               ; score

    LDX #5
    LDY #9
    JSR draw_score_sprite               ; highscore

    JMP screen_game_over_loop_part2

@main:
    

screen_game_over_loop_part2:
    JSR set_bird_data_for_first_sprite
    JSR draw_sprites_to_oam
    JSR wait_for_szh                ; we spin-wait for Sprite 0 Hit
    BIT PPUSTATUS

    LDA global_scroll_x
    STA PPUSCROLL
    BIT PPUSTATUS

    ; now some precise timing, we need to wait for 16 scanlines
    ; then set the palette color to a value from lookup table
    JSR wait_for_16_scanlines

    ; call precisely timed routine
    JSR draw_ground
    RTS

.export screen_game_over_init
.export screen_game_over_destroy
.export screen_game_over_vblank
.export screen_game_over_loop

; X - initial sprite slot
; Y - offset to last digit
draw_score_sprite:
    STY SCRATCH+8
    LDA #4
    STA SCRATCH+9
@loop:
    LDY SCRATCH+8
    LDA current_score_counter, Y
    TAY
    LDA sprite_mini_digit_lo, Y
    STA sprite_addr_lo, X
    LDA sprite_mini_digit_hi, Y
    STA sprite_addr_hi, X
    INX
    DEC SCRATCH+8
    DEC SCRATCH+9
    BNE @loop

    DEX
    INC SCRATCH+8
    LDY SCRATCH+8

    ; remove leading zeroes
    LDA #3
    STA SCRATCH+9
@loop2:
    LDA current_score_counter, Y
    BNE @exit
    LDA #0
    STA sprite_addr_hi, X
    DEX
    INY
    DEC SCRATCH+9
    BNE @loop2

@exit:
    RTS

;
; Lookup tables
; =============

.segment "RODATA"

game_over_load_stage_1:
    .byte 3, $3F, $0D, $18, $38, $28
    .byte 6, $23, $C9, $FF, $FF, $FF, $FF, $FF, $FF
    .byte 6, $23, $D1, $FF, $FF, $FF, $FF, $FF, $FF
    .byte 6, $23, $D9, $FF, $FF, $FF, $FF, $FF, $FF
    .byte 6, $23, $E1, $FF, $FF, $FF, $FF, $FF, $FF
    .byte $00

game_over_load_stage_2:
    .byte 20, $20, $A6, $B8, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $B9, $BA
    .byte $00

game_over_load_stage_3:
    .byte 20, $20, $C6, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_4:
    .byte 20, $20, $E6, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $C6, $C7, $C8, $02, $BC
    .byte $00

game_over_load_stage_5:
    .byte 20, $21, $06, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_6:
    .byte 20, $21, $26, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_7:
    .byte 20, $21, $46, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $C4, $C5, $C6, $C7, $C8, $02, $BC
    .byte $00

game_over_load_stage_8:
    .byte 20, $21, $66, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_9:
    .byte 20, $21, $86, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_10:
    .byte 20, $21, $A6, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_11:
    .byte 20, $21, $C6, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_12:
    .byte 20, $21, $E6, $BB, $02, $02, $02, $C9, $CA, $CB, $CC, $CD, $02, $02, $02, $02, $02, $02, $51, $52, $53, $02, $BC
    .byte $00

game_over_load_stage_13:
    .byte 20, $22, $06, $BB, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $BC
    .byte $00

game_over_load_stage_14:
    .byte 20, $22, $26, $BD, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BE, $BF
    .byte $00

game_over_load_stage_lo:
    .byte .lobyte(game_over_load_stage_1)
    .byte .lobyte(game_over_load_stage_2)
    .byte .lobyte(game_over_load_stage_3)
    .byte .lobyte(game_over_load_stage_4)
    .byte .lobyte(game_over_load_stage_5)
    .byte .lobyte(game_over_load_stage_6)
    .byte .lobyte(game_over_load_stage_7)
    .byte .lobyte(game_over_load_stage_8)
    .byte .lobyte(game_over_load_stage_9)
    .byte .lobyte(game_over_load_stage_10)
    .byte .lobyte(game_over_load_stage_11)
    .byte .lobyte(game_over_load_stage_12)
    .byte .lobyte(game_over_load_stage_13)
    .byte .lobyte(game_over_load_stage_14)
    
game_over_load_stage_hi:
    .byte .hibyte(game_over_load_stage_1)
    .byte .hibyte(game_over_load_stage_2)
    .byte .hibyte(game_over_load_stage_3)
    .byte .hibyte(game_over_load_stage_4)
    .byte .hibyte(game_over_load_stage_5)
    .byte .hibyte(game_over_load_stage_6)
    .byte .hibyte(game_over_load_stage_7)
    .byte .hibyte(game_over_load_stage_8)
    .byte .hibyte(game_over_load_stage_9)
    .byte .hibyte(game_over_load_stage_10)
    .byte .hibyte(game_over_load_stage_11)
    .byte .hibyte(game_over_load_stage_12)
    .byte .hibyte(game_over_load_stage_13)
    .byte .hibyte(game_over_load_stage_14)

sprite_mini_digit_0:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B0, $00, $00
    .byte $00, $C0, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_1:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B1, $00, $00
    .byte $00, $C1, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_2:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B2, $00, $00
    .byte $00, $C2, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_3:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B3, $00, $00
    .byte $00, $C3, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0

sprite_mini_digit_4:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B4, $00, $00
    .byte $00, $C4, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_5:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B5, $00, $00
    .byte $00, $C5, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_6:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B6, $00, $00
    .byte $00, $C6, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_7:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B7, $00, $00
    .byte $00, $C7, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_8:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B8, $00, $00
    .byte $00, $C8, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0
    
sprite_mini_digit_9:
    ;     Ypos Tile Attr Xpos
    .byte $F8, $B9, $00, $00
    .byte $00, $C9, $00, $00
    .byte $F8, $BA, $00, $08
    .byte $00, $CA, $00, $08
    .byte 0,   0,   0,   0

sprite_mini_digit_lo:
    .byte .lobyte(sprite_mini_digit_0)
    .byte .lobyte(sprite_mini_digit_1)
    .byte .lobyte(sprite_mini_digit_2)
    .byte .lobyte(sprite_mini_digit_3)
    .byte .lobyte(sprite_mini_digit_4)
    .byte .lobyte(sprite_mini_digit_5)
    .byte .lobyte(sprite_mini_digit_6)
    .byte .lobyte(sprite_mini_digit_7)
    .byte .lobyte(sprite_mini_digit_8)
    .byte .lobyte(sprite_mini_digit_9)

sprite_mini_digit_hi:
    .byte .hibyte(sprite_mini_digit_0)
    .byte .hibyte(sprite_mini_digit_1)
    .byte .hibyte(sprite_mini_digit_2)
    .byte .hibyte(sprite_mini_digit_3)
    .byte .hibyte(sprite_mini_digit_4)
    .byte .hibyte(sprite_mini_digit_5)
    .byte .hibyte(sprite_mini_digit_6)
    .byte .hibyte(sprite_mini_digit_7)
    .byte .hibyte(sprite_mini_digit_8)
    .byte .hibyte(sprite_mini_digit_9)

