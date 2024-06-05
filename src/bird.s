.segment "ZEROPAGE"
    .import SCRATCH


.segment "BSS"
    bird_dead: .res 1
    bird_pos_x: .res 1
    bird_pos_y: .res 2
    bird_velocity: .res 2
    bird_animation_frames_left: .res 1
    bird_animation_state: .res 1
    bird_animation_speed: .res 1
    bird_physics_active: .res 1             ; 0xFF if physics active
    
    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y
    .export bird_dead, bird_pos_x, bird_pos_y, bird_animation_speed, bird_animation_frames_left, bird_physics_active, bird_velocity


.import draw_metasprite

; Physics constants
GRAVITY = $001F
MAX_VERTICAL_SPEED = $0420
MIN_VERTICAL_SPEED = -(MAX_VERTICAL_SPEED + GRAVITY)
FLAP_BOOST = -($0243)
MIN_Y_POS = $1200
    
.segment "CODE"
reset_bird:
    LDA #5
    STA bird_animation_speed
    STA bird_animation_frames_left
    LDA #0
    STA bird_velocity
    STA bird_animation_state
    STA bird_pos_y+1
    STA bird_physics_active
    STA bird_dead
    RTS

.export reset_bird

update_bird:
    LDA bird_physics_active
    BEQ @no_physics

    ; first, apply vertical velocity to current bird Y position
    ; cap at min_y_pos
    CLC
    LDA bird_pos_y+1
    ADC bird_velocity+1
    STA bird_pos_y+1
    LDA bird_pos_y+0
    ADC bird_velocity+0
    STA bird_pos_y+0
    
    ; compare to minimum allowed falling speed
    LDA bird_pos_y+0
    CMP #.hibyte(MIN_Y_POS)
    BCC @cap_pos
    BNE @no_cap_pos
    LDA #.lobyte(MIN_Y_POS)
    CMP bird_pos_y+1
    BCS @cap_pos
    JMP @no_cap_pos

@cap_pos:
    LDA #.hibyte(MIN_Y_POS)
    STA bird_pos_y+0
    LDA #.lobyte(MIN_Y_POS)
    STA bird_pos_y+1
    ; reset velocity
    LDA #0
    STA bird_velocity+0
    STA bird_velocity+1

@no_cap_pos:
    ; then, apply gravity to velocity, capping at maximum vertical velocity
    CLC
    LDA bird_velocity+1
    ADC #.lobyte(GRAVITY)
    STA bird_velocity+1
    LDA bird_velocity+0
    ADC #.hibyte(GRAVITY)
    STA bird_velocity+0

    ; compare to maximum allowed falling speed
    LDA #.hibyte(MAX_VERTICAL_SPEED)
    CMP bird_velocity+0
    BMI @cap_velocity
    BNE @no_physics
    LDA bird_velocity+1
    CMP #.lobyte(MAX_VERTICAL_SPEED)
    BPL @cap_velocity
    JMP @no_physics

@cap_velocity:
    LDA #.hibyte(MAX_VERTICAL_SPEED)
    STA bird_velocity+0
    LDA #.lobyte(MAX_VERTICAL_SPEED)
    STA bird_velocity+1

@no_physics:
    LDA bird_dead
    BNE @no_animation

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
:   JMP @exit
@no_animation:
    LDA #(bird_sprite_animation_end - bird_sprite_animation)
    STA bird_animation_state
@exit:
    RTS

.export update_bird

bird_do_flap:
    ; do nothing if physics disabled
    LDA bird_physics_active
    BEQ @exit

    ; add flap boost to current vertical velocity, capping at minimum speed
    ; (moving upwards is denoted by negative speed)
    CLC
    LDA #.lobyte(FLAP_BOOST)
    STA bird_velocity+1
    LDA #.hibyte(FLAP_BOOST)
    STA bird_velocity+0

    ; compare to minimum allowed falling speed
    LDA bird_velocity+0
    CMP #.hibyte(MIN_VERTICAL_SPEED)
    BMI @cap_velocity
    BNE @exit
    LDA #.lobyte(MIN_VERTICAL_SPEED)
    CMP bird_velocity+1
    BPL @cap_velocity
    JMP @exit

@cap_velocity:
    LDA #.hibyte(MIN_VERTICAL_SPEED)
    STA bird_velocity+0
    LDA #.lobyte(MIN_VERTICAL_SPEED)
    STA bird_velocity+1

@exit:
    RTS

.export bird_do_flap

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


;
; Lookup tables
; =============

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

bird_sprite_state_4:                ; dead state
    .byte 256-8, $4A, $00, 256-8
    .byte 0, $5A, $00, 256-8
    .byte 256-8, $4B, $00, 0
    .byte 0, $5B, $00, 0
    .byte 8, $01, $00, 0
    .byte 0, $7A, $01, 256-8
    .byte 256-8, $6B, $01, 0
    .byte 0, $7B, $01, 0
    .byte 0, 0, 0, 0

bird_sprite_states_lo:
    .byte .lobyte(bird_sprite_state_1)
    .byte .lobyte(bird_sprite_state_2)
    .byte .lobyte(bird_sprite_state_3)
    .byte .lobyte(bird_sprite_state_4)
    
bird_sprite_states_hi:
    .byte .hibyte(bird_sprite_state_1)
    .byte .hibyte(bird_sprite_state_2)
    .byte .hibyte(bird_sprite_state_3)
    .byte .hibyte(bird_sprite_state_4)

bird_sprite_animation:
    .byte $00, $00, $01, $02, $02, $01
bird_sprite_animation_end:
    .byte $03

bird_collision_top:
   .byte 256-3, 256-4, 256-4, 256-5, 256-6, 256-6, 256-7, 256-7, 256-7, 256-7, 256-7, 256-7, 256-6, 256-5, 256-4, 256-1, 0

bird_collision_bottom:
    .byte 256-1, 0, 2, 3, 3, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 2, 0

.export bird_collision_top, bird_collision_bottom
