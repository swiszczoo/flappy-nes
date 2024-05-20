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
    a_btn_animation_state: .res 1

    .import nametbl1_attrs, nametbl2_attrs
    .import bird_pos_x, bird_pos_y

    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y


.import draw_bird
.import draw_ground
.import draw_sprites_to_oam
.import set_bird_data_for_first_sprite
.import update_bird
.import wait_for_szh


.segment "CODE"
screen_instructions_init:
    ; set animation state
    LDA #0
    STA a_btn_animation_state

    ; set sprites
    ; GET READY text
    LDA #.lobyte(get_ready_sprite)
    STA sprite_addr_lo+1
    LDA #.hibyte(get_ready_sprite)
    STA sprite_addr_hi+1
    LDA #$80
    STA sprite_pos_x+1
    LDA #$3A
    STA sprite_pos_y+1

    ; HELP part 1
    LDA #.lobyte(help_sprite)
    STA sprite_addr_lo+2
    LDA #.hibyte(help_sprite)
    STA sprite_addr_hi+2
    LDA #$80
    STA sprite_pos_x+2
    LDA #$60
    STA sprite_pos_y+2

    ; HELP part 2 - A btn animation
    LDA #.lobyte(a_btn_sprite_1)
    STA sprite_addr_lo+3
    LDA #.hibyte(a_btn_sprite_1)
    STA sprite_addr_hi+3
    LDA #$80
    STA sprite_pos_x+3
    LDA #$95
    STA sprite_pos_y+3

    ; dummy score sprite
    LDA #.lobyte(dummy_score_sprite)
    STA sprite_addr_lo+4
    LDA #.hibyte(dummy_score_sprite)
    STA sprite_addr_hi+4
    LDA #$80
    STA sprite_pos_x+4
    LDA #$24
    STA sprite_pos_y+4

    ; fill nametable attributes buffer with initial values
    LDX #$3F
:   LDA initial_attrs, X
    STA nametbl1_attrs, X
    STA nametbl2_attrs, X
    DEX
    BPL :-

    RTS


screen_instructions_destroy:
    RTS

screen_instructions_vblank:
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

screen_instructions_loop:
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
    JSR update_bird
    JSR set_bird_data_for_first_sprite

    ; update A button animation
    ; every 16 frames go to the next frame
    LDA frame_counter
    AND #15
    BNE @no_animation_update
    INC a_btn_animation_state
    LDA a_btn_animation_state
    AND #1
    BEQ :+
    LDA #.lobyte(a_btn_sprite_2)
    STA sprite_addr_lo+3
    LDA #.hibyte(a_btn_sprite_2)
    STA sprite_addr_hi+3
    JMP @no_animation_update
:   LDA #.lobyte(a_btn_sprite_1)
    STA sprite_addr_lo+3
    LDA #.hibyte(a_btn_sprite_1)
    STA sprite_addr_hi+3

@no_animation_update:
    JSR draw_sprites_to_oam
    JSR wait_for_szh
    JSR draw_ground

    RTS


.export screen_instructions_init
.export screen_instructions_destroy
.export screen_instructions_vblank
.export screen_instructions_loop

;
; Lookup tables
; =============

.segment "RODATA"
initial_attrs:
    .res 40, $55
    .res 8, $A5
    .res 16, $00

get_ready_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $E7, $00, $D8    ; G
    .byte $00, $E5, $00, $E0    ; E
    .byte $00, $F4, $00, $E8    ; T
    .byte $00, $F2, $00, $00    ; R
    .byte $00, $E5, $00, $08    ; E
    .byte $00, $E1, $00, $10    ; A
    .byte $00, $E4, $00, $18    ; D
    .byte $00, $F9, $00, $20    ; Y
    .byte 0,   0,   0,   0      ; sprite end

help_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $00, $80, $03, $F7    ; bird 0,0
    .byte $00, $81, $03, $FF    ; bird 1,0
    .byte $00, $82, $03, $07    ; bird 2,0
    .byte $08, $90, $03, $F7    ; bird 0,1
    .byte $08, $91, $03, $FF    ; bird 1,1
    .byte $08, $92, $03, $07    ; bird 2,1
    .byte $12, $A0, $03, $FC    ; up arrow
    .byte $28, $93, $02, $DC    ; HIT left 0,0
    .byte $28, $94, $02, $E4    ; HIT left 1,0
    .byte $28, $95, $02, $EC    ; HIT left 2,0
    .byte $30, $A3, $02, $DC    ; HIT left 0,1
    .byte $30, $A4, $02, $E4    ; HIT left 1,1
    .byte $30, $A5, $02, $EC    ; HIT left 2,1
    .byte $28, $96, $02, $0C    ; HIT right 0,0
    .byte $28, $97, $02, $14    ; HIT right 1,0
    .byte $28, $98, $02, $1C    ; HIT right 2,0
    .byte $30, $A6, $02, $0C    ; HIT right 0,1
    .byte $30, $A7, $02, $14    ; HIT right 1,1
    .byte $30, $A8, $02, $1C    ; HIT right 2,1
    .byte 0,   0,   0,   0      ; sprite end

a_btn_sprite_1:
    ;     Ypos Tile Attr Xpos
    .byte $E8, $4C, $03, $F8    ; finger 0,0
    .byte $E8, $4D, $03, $00    ; finger 1,0
    .byte $F0, $5C, $03, $F8    ; finger 0,1
    .byte $F0, $5D, $03, $00    ; finger 1,1
    .byte $F8, $6C, $03, $F8    ; finger 0,2
    .byte $F8, $6D, $03, $00    ; finger 1,2
    .byte $00, $7C, $03, $F8    ; finger 0,3
    .byte $00, $7D, $03, $00    ; finger 1,3
    .byte 0,   0,   0,   0      ; sprite end

a_btn_sprite_2:
    ;     Ypos Tile Attr Xpos
    .byte $E8, $4E, $03, $F8    ; finger 0,0
    .byte $E8, $4F, $03, $00    ; finger 1,0
    .byte $F0, $5E, $03, $F8    ; finger 0,1
    .byte $F0, $5F, $03, $00    ; finger 1,1
    .byte $F8, $6E, $03, $F8    ; finger 0,2
    .byte $F8, $6F, $03, $00    ; finger 1,2
    .byte $00, $7E, $03, $F8    ; finger 0,3
    .byte $00, $7F, $03, $00    ; finger 1,3
    .byte 0,   0,   0,   0      ; sprite end

dummy_score_sprite:
    ;     Ypos Tile Attr Xpos
    .byte $F4, $10, $00, $F8    ; digit 0 0,0
    .byte $F4, $11, $00, $00    ; digit 0 1,0
    .byte $FC, $20, $00, $F8    ; digit 0 0,1
    .byte $FC, $21, $00, $00    ; digit 0 1,1
    .byte $04, $30, $00, $F8    ; digit 0 0,1
    .byte $04, $31, $00, $00    ; digit 0 1,1
    .byte 0,   0,   0,   0      ; sprite end

