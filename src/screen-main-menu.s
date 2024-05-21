.include "gamestates.inc"
.include "registers.inc"

.import decimal_skip_leading_zeros
.import draw_ground
.import draw_metasprite
.import wait_for_szh

.import set_game_state

.import draw_bird
.import update_bird
.import reset_bird

.segment "ZEROPAGE"
    .import SCRATCH
    .import palette_addr
    .import frame_counter, my_ppuctrl, my_scroll_x, my_scroll_y
    .import skip_nmi, global_scroll_x, global_chr_bank
    .import hiscore_digits
    .import gamepad_1_chg
    .import ppu_update_addr
    .import oam_offset

.segment "OAM"
    .import OAM

.segment "BSS"
    my_ppumask: .res 1
    current_palette: .res 1
    prev_palette: .res 1
    jump_text_offset: .res 1
    jump_text_start_sprite: .res 1
    menu_exit_stage: .res 1

    .import bird_pos_x, bird_pos_y

.segment "CODE"
screen_main_menu_init:
    ; disable rendering
    LDA #0
    STA PPUMASK
    STA my_ppumask

    ; set current palette
    STA current_palette

    ; set global scroll and CHR bank to 0
    STA global_scroll_x
    STA global_chr_bank

    ; set exit stage
    STA menu_exit_stage

    ;disable NMI
    LDA #$FF
    STA skip_nmi
    STA jump_text_start_sprite

    LDA #(jumping_text_y_offset_end - jumping_text_y_offset)
    STA jump_text_offset

    ; set prev palette
    STA prev_palette

    ; set palette address
    LDA #.lobyte(menu_palette_1)
    STA palette_addr+0
    LDA #.hibyte(menu_palette_1)
    STA palette_addr+1

    LDA #$20
    STA PPUADDR
    LDA #$00
    STA PPUADDR

    LDA #.lobyte(menu_nametable)
    STA SCRATCH+0
    LDA #.hibyte(menu_nametable)
    STA SCRATCH+1

    ; copy 1KB of nametable data twice (left and right nametable)
    LDX #$04
    LDY #$00
:   LDA (SCRATCH+0), Y
    STA PPUDATA
    INY
    BNE :-
    INC SCRATCH+1
    DEX
    BNE :-

    LDA #.hibyte(menu_nametable)
    STA SCRATCH+1
    LDX #$04
    LDY #$00
:   LDA (SCRATCH+0), Y
    STA PPUDATA
    INY
    BNE :-
    INC SCRATCH+1
    DEX
    BNE :-

    ; setup sprite 0 for SZH detection
    LDA #$BF                    ; Y position
    STA OAM
    LDA #1                      ; tile ID
    STA OAM+1
    LDA #0                      ; attributes
    STA OAM+2
    LDA #$E0                    ; X position
    STA OAM+3

    ; copy rest of the sprites to this screen
    LDX #0
:   LDA jumping_text_oam, X
    STA OAM+128, X
    INX
    CPX #(jumping_text_oam_end - jumping_text_oam)
    BCC :-

    ; create sprites for top score
    LDA #.lobyte(hiscore_digits)
    STA SCRATCH+0
    LDA #.hibyte(hiscore_digits)
    STA SCRATCH+1
    LDA #4
    STA SCRATCH+2
    JSR decimal_skip_leading_zeros
    LDX SCRATCH+2                ; SCRATCH+2 is how many digits left
    LDA top_score_offsets_x, X
    STA SCRATCH+15               ; SCRATCH+15 is our current X position
    LDX #176
    LDY #0

@topscore_loop:
    TXA
    CLC
    ADC #16
    TAX

    ; Tile 1
    ; first byte - Y position
    LDA #$42
    STA OAM+0, X
    ; second byte - tile index number
    LDA #$B0
    CLC
    ADC (SCRATCH+0), Y
    STA OAM+1, X
    ; fourth byte - X position
    LDA SCRATCH+15
    STA OAM+3, X
    
    ; Tile 2
    ; first byte - Y position
    LDA #$4A
    STA OAM+4, X
    ; second byte - tile index number
    LDA #$C0
    CLC
    ADC (SCRATCH+0), Y
    STA OAM+5, X
    ; fourth byte - X position
    LDA SCRATCH+15
    STA OAM+7, X

    LDA SCRATCH+15
    CLC
    ADC #8
    STA SCRATCH+15
    
    ; Tile 3
    ; first byte - Y position
    LDA #$42
    STA OAM+8, X
    ; second byte - tile index number
    LDA #$BA
    STA OAM+9, X
    ; fourth byte - X position
    LDA SCRATCH+15
    STA OAM+11, X
    
    ; Tile 4
    ; first byte - Y position
    LDA #$4A
    STA OAM+12, X
    ; second byte - tile index number
    LDA #$CA
    STA OAM+13, X
    ; fourth byte - X position
    LDA SCRATCH+15
    STA OAM+15, X

    ; third bytes - attributes
    LDA #0
    STA OAM+2, X
    STA OAM+6, X
    STA OAM+10, X
    STA OAM+14, X

    ; loop condition
    INY
    DEC SCRATCH+2
    BNE @topscore_loop

    ; reset bird
    JSR reset_bird

    ; enable NMI
    LDA #0
    STA skip_nmi

    ; enable rendering on next vblank
    LDA #%00011110
    STA my_ppumask

    RTS

screen_main_menu_destroy:
    ; remove all unnecessary sprites from the screen

    RTS

screen_main_menu_vblank:
    LDA my_ppumask
    STA PPUMASK

    ; restore palette after drawing
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDY #0
    LDA (palette_addr), Y
    STA PPUDATA

    ; check if we need to update palettes
    LDA current_palette
    CMP prev_palette
    BEQ @no_palette_chg

    ; change palette
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDY #0
:   LDA (palette_addr), Y
    STA PPUDATA
    INY
    CPY #32
    BMI :-

    ; palette corruption workaround
    LDA #$3F
    STA PPUADDR
    LDA #0
    STA PPUADDR
    STA PPUADDR
    STA PPUADDR

@no_palette_chg:

    RTS

screen_main_menu_loop:
    LDX current_palette
    STX prev_palette                ; update prev palette to ensure vblank routine knows when to change colors

    ; if frame is divisible by 8, go to next palette
    CPX #3
    BPL @no_palette_update
    LDA frame_counter
    AND #%00000011
    BNE @no_palette_update

    INC current_palette
    LDX current_palette

    ; update palette addresses
    LDA menu_palettes_lo, X
    STA palette_addr+0
    LDA menu_palettes_hi, X
    STA palette_addr+1
    
@no_palette_update:

    LDA frame_counter
    AND #1
    BNE :+
    JSR main_menu_text_animation_step ; do animation step every 2nd frame

:
    LDA current_palette
    CMP #1
    BMI @no_moving_bg               ; no moving background
    
    ; scroll main bg every two frames
    ; bankswitch every four frames

    LDA frame_counter
    AND #1
    BNE @no_scroll
    INC global_scroll_x

    LDA frame_counter
    AND #3
    BNE @no_scroll
    INC global_chr_bank
    LDA global_chr_bank
    AND #31
    STA global_chr_bank

@no_scroll:
    LDA menu_exit_stage
    BNE @screen_exiting

    ; check if A button is pressed in this frame
    LDA prev_palette
    CMP #3
    BCC @no_button_press
    LDA gamepad_1_chg
    AND BUTTON_A
    BEQ @no_button_press

    JSR start_game
    JMP @no_button_press

@screen_exiting:
    LDX menu_exit_stage
    LDA screen_exit_stages_lo, X
    STA ppu_update_addr+0
    LDA screen_exit_stages_hi, X
    STA ppu_update_addr+1
    INX
    STX menu_exit_stage
    CPX #(screen_exit_stages_hi - screen_exit_stages_lo)
    BCC @no_button_press
    JSR next_screen

@no_button_press:
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

@no_moving_bg:
    JSR draw_menu_bird
    RTS

.define ANIMATION_DELAY             #3
main_menu_text_animation_step:
    INC jump_text_offset
    LDA jump_text_offset
    ;CMP #(jumping_text_y_offset_end - jumping_text_y_offset)
    CMP #80
    BCC :+

    ; loop animation
    LDA #0
    STA jump_text_offset
    STA jump_text_start_sprite

:   CMP ANIMATION_DELAY
    BCC :+
    LDA jump_text_start_sprite
    CMP #((jumping_text_oam_end - jumping_text_oam) / 4)
    BCS :+ ; do not increment start sprite if >= sprite count

    ; move to next sprite
    LDA #0
    STA jump_text_offset
    INC jump_text_start_sprite
:
    ; actual animation code
    LDX jump_text_start_sprite
    LDA jump_text_offset
    STA SCRATCH+1
:   CPX #0
    BMI @exit_animation             ; exit if sprite is 0
    LDA SCRATCH+1
    CMP #(jumping_text_y_offset_end - jumping_text_y_offset)
    BCS @exit_animation             ; exit if the offset table has ended

    TXA
    TAY                             ; hold original start_sprite in Y
    ASL A
    ASL A
    TAX                             ; multiply X by 4
    STX SCRATCH+2                   ; store it temporarily
    LDA jumping_text_oam+0, X       ; load Y pos original
    STA SCRATCH+0                   ; A holds original Y position
    LDX SCRATCH+1                   ; X holds an offset to our table
    CLC
    ADC jumping_text_y_offset, X    ; add offset to A position
    LDX SCRATCH+2                   ; restore sprite ID * 4 to X
    STA OAM+128, x                  ; store new sprite Y position in OAM
    ; restore register functions
    LDA SCRATCH+1
    CLC
    ADC ANIMATION_DELAY             ; move by 8 indices
    STA SCRATCH+1
    TYA
    TAX
    DEX                             ; decrease current sprite
    JMP :-

@exit_animation:
    RTS

draw_menu_bird:
    LDX #4
    STX oam_offset
    LDA #$80
    STA bird_pos_x

    STA SCRATCH+2
    LDA frame_counter
    LSR A
    LSR A
    AND #31
    TAX
    LDA bird_animation_y, X
    STA bird_pos_y

    JSR update_bird
    JMP draw_bird

start_game:
    LDA screen_exit_stages_lo
    STA ppu_update_addr+0
    LDA screen_exit_stages_hi
    STA ppu_update_addr+1
    LDA #1
    STA menu_exit_stage
    RTS

next_screen:
    LDA STATE_GAME_TRANSITION
    JMP set_game_state

;
; Timed code
; ==========
.segment "TMCODE"
.align 256
wait_for_16_scanlines:
    LDX #$7F
:   NOP
    NOP
    NOP
    NOP
    DEX
    BNE :-
    NOP
    NOP
    NOP
    RTS

;
; Lookup tables
; =============

.segment "RODATA"
menu_nametable:
    .incbin "menu.bin"

; the last 4 bytes in palettes are for ground gradient
menu_palette_1:
    .byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $08

menu_palette_2:
    .byte $01, $0F, $0F, $0A, $01, $0C, $0F, $1C, $01, $0F, $1A, $0B, $01, $0F, $17, $07
    .byte $01, $0F, $07, $10, $01, $08, $18, $0F, $01, $0F, $0F, $10, $01, $0F, $0F, $00
    .byte $0F, $0F, $08, $18

menu_palette_3:
    .byte $11, $0F, $0B, $1A, $11, $1C, $0A, $2C, $11, $0A, $2A, $1B, $11, $0F, $27, $17
    .byte $11, $0F, $17, $20, $11, $18, $28, $06, $11, $0F, $06, $20, $11, $0F, $00, $10
    .byte $0F, $08, $18, $28

menu_palette_4:
    .byte $21, $0F, $1B, $2A, $21, $2C, $1A, $3C, $21, $1A, $3A, $2B, $21, $07, $37, $27
    .byte $21, $0F, $27, $30, $21, $28, $38, $16, $21, $0F, $16, $30, $21, $00, $10, $20
    .byte $08, $18, $28, $38

menu_palettes_lo:
    .byte .lobyte(menu_palette_1)
    .byte .lobyte(menu_palette_2)
    .byte .lobyte(menu_palette_3)
    .byte .lobyte(menu_palette_4)

menu_palettes_hi:
    .byte .hibyte(menu_palette_1)
    .byte .hibyte(menu_palette_2)
    .byte .hibyte(menu_palette_3)
    .byte .hibyte(menu_palette_4)

jumping_text_oam:
    ;     Ypos Tile Attr Xpos
    .byte $78, $F0, $02, $61
    .byte $78, $F2, $02, $6A
    .byte $78, $E5, $02, $73
    .byte $78, $F3, $02, $7C
    .byte $78, $F3, $02, $84
    .byte $78, $CF, $02, $97
    .byte $86, $F4, $02, $5D
    .byte $86, $EF, $02, $65
    .byte $86, $F3, $02, $79
    .byte $86, $F4, $02, $82
    .byte $86, $E1, $02, $8A
    .byte $86, $F2, $02, $93
    .byte $86, $F4, $02, $9C
jumping_text_oam_end:

jumping_text_y_offset:
    .byte $00, $00, $00, $00, $00, $00, $00, $00
    .byte $00, $FF, $FF, $00, $02, $04, $03, $01, $FF, $FD, $FC
    .byte $FB, $FB, $FB, $FC, $FC, $FD, $FD, $FD, $FE, $FE
    .byte $FE, $FF, $FF, $FF, $FF, $00
jumping_text_y_offset_end:

top_score_offsets_x:
    .byte $80, $7C, $78, $74, $70

bird_animation_y:
    .byte 100, 101, 102, 103, 104, 104, 105, 105, 105, 105
    .byte 105, 104, 104, 103, 102, 101, 100, 99, 98, 97
    .byte 96, 96, 95, 95, 95, 95, 95, 96, 96, 97
    .byte 98, 99

screen_exit_stage_1:
    .byte 12, $20, $6A, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte 12, $20, $8A, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte 12, $20, $AA, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte 6, $20, $D0, $00, $00, $00, $00, $00, $00
    .byte 4, $23, $C2, $55, $55, $55, $55
    .byte 4, $23, $CA, $55, $55, $55, $55
    .byte $00

screen_exit_stage_2:
    .byte 6, $20, $ED, $00, $00, $00, $00, $00, $00
    .byte 26, $22, $E3
    .res 26, $03
    .byte $00

screen_exit_stage_3:
    .byte 12, $24, $6A, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte 12, $24, $8A, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte 12, $24, $AA, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    .byte 6, $24, $D0, $00, $00, $00, $00, $00, $00
    .byte 4, $27, $C2, $55, $55, $55, $55
    .byte 4, $27, $CA, $55, $55, $55, $55
    .byte $00

screen_exit_stage_4:
    .byte 6, $24, $ED, $00, $00, $00, $00, $00, $00
    .byte 26, $26, $E3
    .res 26, $03
    .byte $00

screen_exit_stages_lo:
    .byte .lobyte(screen_exit_stage_1)
    .byte .lobyte(screen_exit_stage_2)
    .byte .lobyte(screen_exit_stage_3)
    .byte .lobyte(screen_exit_stage_4)

screen_exit_stages_hi:
    .byte .hibyte(screen_exit_stage_1)
    .byte .hibyte(screen_exit_stage_2)
    .byte .hibyte(screen_exit_stage_3)
    .byte .hibyte(screen_exit_stage_4)

.export screen_main_menu_init
.export screen_main_menu_destroy
.export screen_main_menu_vblank
.export screen_main_menu_loop
