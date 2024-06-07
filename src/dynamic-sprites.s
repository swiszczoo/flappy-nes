.include "gamestates.inc"
.include "registers.inc"

.segment "ZEROPAGE"
    .import SCRATCH
    .import oam_offset

.segment "OAM"
    .import OAM

.define SPRITE_COUNT                    16   ; must be a power of 2

.segment "BSS"
    first_sprite: .res 1
    sprite_addr_lo: .res SPRITE_COUNT
    sprite_addr_hi: .res SPRITE_COUNT
    sprite_pos_x: .res SPRITE_COUNT
    sprite_pos_y: .res SPRITE_COUNT

    .export sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y

.import draw_metasprite

.segment "CODE"
draw_sprites_to_oam:
    LDA #4
    STA oam_offset

    LDX first_sprite
    STX SCRATCH+14                  ; current sprite to draw
    LDY #0
    STY SCRATCH+15                  ; total number of sprites drawn
@draw_loop:
    CPY #SPRITE_COUNT
    BEQ @exit_loop
    LDA sprite_addr_lo, X
    STA SCRATCH+0
    LDA sprite_addr_hi, X
    BEQ @no_draw                    ; if the sprite address is $00xx, do not draw it
    STA SCRATCH+1
    LDA sprite_pos_x, X
    STA SCRATCH+2
    LDA sprite_pos_y, X
    STA SCRATCH+3
    JSR draw_metasprite
@no_draw:
    INC SCRATCH+14
    INC SCRATCH+15
    LDA SCRATCH+14
    AND #(SPRITE_COUNT - 1)
    STA SCRATCH+14                  ; go back to the front of sprite table
    TAX
    LDY SCRATCH+15                  ; increase total number of sprites drawn
    JMP @draw_loop

@exit_loop:
    LDX first_sprite
    LDA sprite_addr_hi, X
    STX SCRATCH+12
    STA SCRATCH+13                  ; temporarily exchange sprite_addr_hi for at least one sprite
                                    ; to prevent endless looping
    LDA #$FF
    STA sprite_addr_hi, X

@next_sprite_loop:
    DEC first_sprite                ; on the next call another sprite will have priority
    LDA first_sprite
    AND #(SPRITE_COUNT - 1)
    STA first_sprite
    LDX first_sprite
    LDA sprite_addr_hi, X
    BEQ @next_sprite_loop           ; if this sprite is inactive, repeat

    ; restore previously changed address
    LDX SCRATCH+12
    LDA SCRATCH+13
    STA sprite_addr_hi, X
    
    ; now, remove all unused sprites by setting their Y position to #$FF
    LDA oam_offset
    LDY #$FF
    CLC
:   TAX
    TYA
    STA OAM, X
    TXA
    ADC #4                          ; we are sure that carry is clear here
    BCC :-
    RTS

.export draw_sprites_to_oam

