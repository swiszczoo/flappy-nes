.include "gamestates.inc"
.include "registers.inc"


.segment "ZEROPAGE"
    .import SCRATCH
    .import palette_addr
    .import frame_counter, my_ppuctrl, my_scroll_x, my_scroll_y
    .import skip_nmi, global_scroll_x, global_chr_bank
    .import gamepad_1_chg
    .import oam_offset

    .import current_score_digits


.segment "OAM"
    .import OAM


.segment "BSS"
    game_paused: .res 1                     ; 0xFF if paused

    .import nametbl1_attrs, nametbl2_attrs
    .import bird_pos_x, bird_pos_y, bird_physics_active, bird_animation_speed, bird_animation_frames_left, bird_velocity

    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y


.import bird_do_flap
.import decimal_skip_leading_zeros
.import decimal_increment
.import draw_ground
.import draw_sprites_to_oam
.import random_next
.import random_seed
.import set_bird_data_for_first_sprite
.import update_bird
.import wait_for_szh


.segment "CODE"
screen_game_init:
    LDA #$FF
    STA bird_physics_active
    JSR bird_do_flap

    LDX frame_counter+0
    LDY frame_counter+1
    JSR random_seed

    JSR random_next
    JSR random_next
    
    RTS

screen_game_destroy:
    LDA #$00
    STA bird_physics_active
    RTS

screen_game_vblank:
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

    ; palette corruption workaround
    LDA #$3F
    STA PPUADDR
    LDA #0
    STA PPUADDR
    STA PPUADDR
    STA PPUADDR

    RTS

screen_game_loop:
    ; scroll main bg every single frame
    ; bankswitch every two frames
    INC global_scroll_x
    INC my_scroll_x

    LDA frame_counter
    AND #1
    BNE @no_bankswitch
    DEC global_chr_bank
    LDA global_chr_bank
    AND #31
    STA global_chr_bank

@no_bankswitch:

    ; update bird animation speed based on sign of the bird's vertical speed
    BIT bird_velocity
    BMI :+
    LDA #10
    STA bird_animation_speed
    JMP @gamepad_read
:   LDA #2
    STA bird_animation_speed
    CMP bird_animation_frames_left
    BCS @gamepad_read
    STA bird_animation_frames_left

@gamepad_read:
    ; check if A button was pressed in this frame
    LDA gamepad_1_chg
    AND BUTTON_A
    BEQ @no_btn_a
    JSR bird_do_flap
@no_btn_a:
    ; check if START button was pressed in this frame
    LDA gamepad_1_chg
    AND BUTTON_START
    BEQ @no_btn_start
    NOP                                 ; drop pause handler here
@no_btn_start:
    ; test - increment score each frame
    LDX #.lobyte(current_score_digits)
    STX SCRATCH+0
    LDX #.hibyte(current_score_digits)
    STX SCRATCH+1
    LDX #4
    STX SCRATCH+2
    LDA frame_counter
    AND #$1F
    BNE :+
    JSR decimal_increment
:

    JSR update_bird
    JSR set_bird_data_for_first_sprite
    JSR draw_score

    JSR draw_sprites_to_oam
    JSR wait_for_szh
    JSR draw_ground

    RTS

.export screen_game_init
.export screen_game_destroy
.export screen_game_vblank
.export screen_game_loop

draw_score:
    ; clear sprite slots 2, 3, 4 and 5 and set their Y pos to $30
    LDA #0
    STA sprite_addr_hi+1
    STA sprite_addr_hi+2
    STA sprite_addr_hi+3
    STA sprite_addr_hi+4
    LDA #$18
    STA sprite_pos_y+1
    STA sprite_pos_y+2
    STA sprite_pos_y+3
    STA sprite_pos_y+4

    ; get score length skipping leading zeroes
    LDX #.lobyte(current_score_digits)
    STX SCRATCH+0
    LDX #.hibyte(current_score_digits)
    STX SCRATCH+1
    LDX #4
    STX SCRATCH+2
    JSR decimal_skip_leading_zeros

    ; calculate total length of text in pixels
    LDY #0
    STY SCRATCH+4
    CLC
:   LDA (SCRATCH+0), Y
    TAX
    LDA score_digit_lengths, X
    ADC SCRATCH+4
    STA SCRATCH+4
    INY
    CPY SCRATCH+2
    BCC :-

    LDA SCRATCH+4
    LSR A               ; divide by 2
    EOR #$7F            ; negate and add $80 -> XOR $7F
    STA SCRATCH+4       ; SCRATCH+4 now stores start X for centered score text

    ; now, select digit metasprites in order
    LDY #0
    CLC
:   LDA (SCRATCH+0), Y
    TAX
    LDA score_sprites_lo, X
    STA sprite_addr_lo+1, Y
    LDA score_sprites_hi, X
    STA sprite_addr_hi+1, Y
    LDA SCRATCH+4
    STA sprite_pos_x+1, Y
    ADC score_digit_lengths, X
    STA SCRATCH+4
    INY
    CPY SCRATCH+2
    BCC :-

    ; done
    RTS

;
; Lookup tables
; =============

.segment "RODATA"
score_digit_lengths:
    ;      0   1   2   3   4   5   6   7   8   9
    .byte 14, 10, 14, 14, 14, 14, 14, 14, 14, 14

score_0_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $10, $00, $00
    .byte $00, $11, $00, $08
    .byte $08, $20, $00, $00
    .byte $08, $21, $00, $08
    .byte $10, $30, $00, $00
    .byte $10, $31, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_1_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $12, $00, $FE
    .byte $00, $13, $00, $06
    .byte $08, $22, $00, $FE
    .byte $08, $23, $00, $06
    .byte $10, $32, $00, $FE
    .byte $10, $33, $00, $06
    .byte 0,   0,   0,   0              ; end of sprite

score_2_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $14, $00, $00
    .byte $00, $15, $00, $08
    .byte $08, $24, $00, $00
    .byte $08, $25, $00, $08
    .byte $10, $34, $00, $00
    .byte $10, $35, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_3_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $16, $00, $00
    .byte $00, $17, $00, $08
    .byte $08, $26, $00, $00
    .byte $08, $27, $00, $08
    .byte $10, $36, $00, $00
    .byte $10, $37, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_4_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $18, $00, $00
    .byte $00, $19, $00, $08
    .byte $08, $28, $00, $00
    .byte $08, $29, $00, $08
    .byte $10, $38, $00, $00
    .byte $10, $39, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_5_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $1A, $00, $00
    .byte $00, $1B, $00, $08
    .byte $08, $2A, $00, $00
    .byte $08, $2B, $00, $08
    .byte $10, $3A, $00, $00
    .byte $10, $3B, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_6_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $1C, $00, $00
    .byte $00, $1D, $00, $08
    .byte $08, $2C, $00, $00
    .byte $08, $2D, $00, $08
    .byte $10, $3C, $00, $00
    .byte $10, $3D, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_7_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $1E, $00, $00
    .byte $00, $1F, $00, $08
    .byte $08, $2E, $00, $00
    .byte $08, $2F, $00, $08
    .byte $10, $3E, $00, $00
    .byte $10, $3F, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_8_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $40, $00, $00
    .byte $00, $41, $00, $08
    .byte $08, $50, $00, $00
    .byte $08, $51, $00, $08
    .byte $10, $60, $00, $00
    .byte $10, $61, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_9_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $42, $00, $00
    .byte $00, $43, $00, $08
    .byte $08, $52, $00, $00
    .byte $08, $53, $00, $08
    .byte $10, $62, $00, $00
    .byte $10, $63, $00, $08
    .byte 0,   0,   0,   0              ; end of sprite

score_sprites_lo:
    .byte .lobyte(score_0_sprite)
    .byte .lobyte(score_1_sprite)
    .byte .lobyte(score_2_sprite)
    .byte .lobyte(score_3_sprite)
    .byte .lobyte(score_4_sprite)
    .byte .lobyte(score_5_sprite)
    .byte .lobyte(score_6_sprite)
    .byte .lobyte(score_7_sprite)
    .byte .lobyte(score_8_sprite)
    .byte .lobyte(score_9_sprite)

score_sprites_hi:
    .byte .hibyte(score_0_sprite)
    .byte .hibyte(score_1_sprite)
    .byte .hibyte(score_2_sprite)
    .byte .hibyte(score_3_sprite)
    .byte .hibyte(score_4_sprite)
    .byte .hibyte(score_5_sprite)
    .byte .hibyte(score_6_sprite)
    .byte .hibyte(score_7_sprite)
    .byte .hibyte(score_8_sprite)
    .byte .hibyte(score_9_sprite)
