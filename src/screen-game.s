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
    game_paused: .res 1                     ; 0xFF if paused

    .import nametbl1_attrs, nametbl2_attrs
    .import bird_pos_x, bird_pos_y, bird_physics_active, bird_animation_speed, bird_animation_frames_left, bird_velocity

    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y


.import bird_do_flap
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
    JSR update_bird
    JSR set_bird_data_for_first_sprite

    JSR draw_sprites_to_oam
    JSR wait_for_szh
    JSR draw_ground

    RTS

.export screen_game_init
.export screen_game_destroy
.export screen_game_vblank
.export screen_game_loop

