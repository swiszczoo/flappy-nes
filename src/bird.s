.segment "ZEROPAGE"
    .import SCRATCH


.segment "BSS"
    bird_pos_x: .res 1
    bird_pos_y: .res 2
    bird_velocity: .res 2
    bird_animation_frames_left: .res 1
    bird_animation_state: .res 1
    bird_animation_speed: .res 1
    
    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y
    .export bird_pos_x, bird_pos_y, bird_animation_speed


.import draw_metasprite
    
.segment "CODE"
reset_bird:
    LDA #5
    STA bird_animation_speed
    STA bird_animation_frames_left
    LDA #0
    STA bird_velocity
    STA bird_animation_state
    STA bird_pos_y+1
    RTS

.export reset_bird

update_bird:
    LDA bird_animation_frames_left
    BNE :+
    INC bird_animation_state
    LDA bird_animation_speed
    STA bird_animation_frames_left
:   DEC bird_animation_frames_left
    LDA bird_animation_state
    CMP #(bird_sprite_animation_end - bird_sprite_animation)
    BCC :+
    LDA #0
    STA bird_animation_state
:   RTS

.export update_bird

set_bird_data_for_first_sprite:
    LDX bird_animation_state
    LDA bird_sprite_animation, X
    TAX
    LDA bird_sprite_states_lo, X
    STA sprite_addr_lo+0
    LDA bird_sprite_states_hi, X
    STA sprite_addr_hi+0
    LDA bird_pos_x
    STA sprite_pos_x+0
    LDA bird_pos_y
    STA sprite_pos_y
    RTS 

.export set_bird_data_for_first_sprite

draw_bird:
    LDX bird_animation_state
    LDA bird_sprite_animation, X
    TAX
    LDA bird_sprite_states_lo, X
    STA SCRATCH+0
    LDA bird_sprite_states_hi, X
    STA SCRATCH+1
    LDA bird_pos_x
    STA SCRATCH+2
    LDA bird_pos_y
    STA SCRATCH+3
    JMP draw_metasprite

.export draw_bird


.segment "RODATA"
bird_sprite_state_1:
    .byte 256-8, $44, $00, 256-8
    .byte 256-8, $45, $00, 0
    .byte 0, $54, $00, 256-7
    .byte 256-1, $55, $00, 1
    .byte 256-8, $64, $01, 256-8
    .byte 256-8, $65, $01, 0
    .byte 0, $74, $01, 256-8
    .byte 0, $75, $01, 0
    .byte 0, 0, 0, 0

bird_sprite_state_2:
    .byte 256-8, $46, $00, 256-8
    .byte 256-8, $47, $00, 0
    .byte 0, $56, $00, 256-7
    .byte 256-1, $57, $00, 1
    .byte 256-8, $66, $01, 256-8
    .byte 256-8, $67, $01, 0
    .byte 0, $76, $01, 256-8
    .byte 0, $77, $01, 0
    .byte 0, 0, 0, 0

bird_sprite_state_3:
    .byte 256-8, $48, $00, 256-7
    .byte 256-8, $49, $00, 1
    .byte 256-1, $58, $00, 256-8
    .byte 0, $59, $00, 0
    .byte 256-8, $68, $01, 256-8
    .byte 256-8, $69, $01, 0
    .byte 0, $78, $01, 256-8
    .byte 0, $79, $01, 0
    .byte 0, 0, 0, 0

bird_sprite_states_lo:
    .byte .lobyte(bird_sprite_state_1)
    .byte .lobyte(bird_sprite_state_2)
    .byte .lobyte(bird_sprite_state_3)
    
bird_sprite_states_hi:
    .byte .hibyte(bird_sprite_state_1)
    .byte .hibyte(bird_sprite_state_2)
    .byte .hibyte(bird_sprite_state_3)

bird_sprite_animation:
    .byte $00, $00, $01, $02, $02, $01
bird_sprite_animation_end:
