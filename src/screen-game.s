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
    .import game_level


.segment "OAM"
    .import OAM


.segment "BSS"
    game_paused: .res 1                     ; 0xFF if paused
    last_processed_scroll_x: .res 1
    pipe_y: .res 8                          ; circular buffer containing pipe heights
    pipe_read_ptr: .res 1
    pipe_write_ptr: .res 1
    pipe_last_write_ptr: .res 1
    pipes_next_column: .res 1
    palette_buffer: .res 6

    .import nametbl1_attrs, nametbl2_attrs
    .import bird_pos_x, bird_pos_y, bird_physics_active, bird_animation_speed, bird_animation_frames_left, bird_velocity

    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y

.segment "BSS_NV"
    .import nametbl1_attrs, nametbl2_attrs


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

PIPE_MAX_Y = 72
LOAD_SEAM_OFFSET = $10

.segment "CODE"
screen_game_init:
    LDA #$FF
    STA bird_physics_active
    JSR bird_do_flap

    LDA frame_counter+0
    EOR $6000                           ; read some shit from uninitialized memory
    TAX
    LDA frame_counter+1
    EOR $6001                           ; read some shit from uninitialized memory
    TAY
    JSR random_seed

    JSR random_next
    JSR random_next
    JSR draw_score

    ; init map generator
    LDA #0
    STA pipe_read_ptr
    STA pipe_write_ptr
    STA pipe_last_write_ptr
    STA pipes_next_column

    LDA my_scroll_x
    CLC
    SBC #0
    AND #$F8
    STA last_processed_scroll_x
    AND #%00001000                      ; add one extra cycle to align to attribute table boundaries
    BNE @no_mapgen_alignment
    LDA #9
    STA pipes_next_column
@no_mapgen_alignment:
    
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
    BNE :+
    INC my_coarse_scroll_x
:

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
    JSR process_map_gen
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

process_map_gen:
    LDA my_scroll_x
    SEC
    SBC last_processed_scroll_x
    CMP #8              ; check if we are ready to process next column of tiles
    BCS @process
    RTS

@process:
    ; increment last processed column by 8 (carry is set here)
    LDA last_processed_scroll_x
    ADC #7              ; 7 + CARRY = 8
    STA last_processed_scroll_x

    ; we are generating a new column
    ; if pipes_next_column is 0, we need to generate a new pipe
    LDA pipes_next_column
    BNE @no_gen_new_pipe
    JSR generate_next_pipe
@no_gen_new_pipe:
    ; we will be updating 24 tile rows vertically
    ; during the next vblank
    LDA #($80 | 24)
    STA PPU_UPD_BUF

    ; now calculate the address of this seam update
    CLC
    LDA my_coarse_scroll_x
    STA SCRATCH+14
    INC SCRATCH+14
    LDA my_scroll_x
    ADC #LOAD_SEAM_OFFSET
    STA SCRATCH+15
    BCC :+
    INC SCRATCH+14      ; store temporarily the scroll position in SCRATCH{14, 15}
:   LDA SCRATCH+14
    AND #1
    TAX
    LDA ppu_nametable_hi_addrs, X
    STA PPU_UPD_BUF+1
    LDA SCRATCH+15
    LSR A
    LSR A
    LSR A
    STA PPU_UPD_BUF+2

    ; the next step is to decide whether the pipe will appear on this column
    ; or there will be the parallax background
    LDA pipes_next_column
    CMP #4                  ; every pipe is 4 tiles wide
    BCC @pipe_column

@empty_column:
    LDA #0
    LDX #18
:   DEX
    STA PPU_UPD_BUF+3, X    ; store 18 zeroes
    BNE :-

    CLC
    LDA PPU_UPD_BUF+2
    AND #3
    LDX #5
:   SEC
    SBC #$10
    DEX
    STA PPU_UPD_BUF+3+18, X ; store 5 appropriate parallax bg tiles
    BNE :-

    LDA #$03
    STA PPU_UPD_BUF+3+23    ; and finally, store tile $03

    ; set palettes
    LDA #$55
    STA palette_buffer+0
    STA palette_buffer+1
    STA palette_buffer+2
    STA palette_buffer+3
    STA palette_buffer+4
    LDA #$A5
    STA palette_buffer+5

    JMP @prepare_palettes

@pipe_column:
    LDX pipe_last_write_ptr
    LDA pipe_y, X
    SEC
    SBC #$10
    LSR A
    LSR A
    LSR A
    TAY
    STY SCRATCH+13
    LDA pipes_next_column
    CLC
    ADC #$90                ; draw tiles $90, $91, $92 or $93

    ; write top pipe 
:   DEY
    STA PPU_UPD_BUF+3, Y
    BNE :-

    ; calculate pipe Y modulo 8, X still contains pipe_last_write_ptr
    LDA pipe_y, X
    STA SCRATCH+7           ; this stores current pipe_y position
    AND #7
    TAX
    LDA pipe_down_tiles_lo, X
    STA SCRATCH+8
    LDA pipe_down_tiles_hi, X
    STA SCRATCH+9

    LDA #3
    STA SCRATCH+12          ; we'll be using DEC instruction as a loop counter
    LDX pipes_next_column
    LDA multiples_of_3, X
    TAY
    LDX SCRATCH+13
:   LDA (SCRATCH+8), Y
    STA PPU_UPD_BUF+3, X
    INY
    INX
    DEC SCRATCH+12
    BNE :-

    STX SCRATCH+13

    ; calculate bottom pipe Y modulo 8
    LDA SCRATCH+7
    LDX game_level
    CLC
    ADC pipe_spacing_for_levels, X
    STA SCRATCH+7
    AND #7
    TAX
    LDA pipe_up_tiles_lo, X
    STA SCRATCH+8
    LDA pipe_up_tiles_hi, X
    STA SCRATCH+9

    ; fill gap between top and bottom pipes with zero tiles
    LDA SCRATCH+7
    LSR A
    LSR A
    LSR A
    TAY
    STY SCRATCH+11
    LDA #$00
:   DEY
    STA PPU_UPD_BUF+3, Y
    CPY SCRATCH+13
    BNE :-

    ; draw bottom pipe head
    LDA #3
    STA SCRATCH+12          ; we'll be using DEC instruction as a loop counter
    LDX pipes_next_column
    LDA multiples_of_3, X
    TAY
    LDX SCRATCH+11
:   LDA (SCRATCH+8), Y
    STA PPU_UPD_BUF+3, X
    INY
    INX
    DEC SCRATCH+12
    BNE :-

    ; draw bottom pipe
    LDA pipes_next_column
    CLC
    ADC #$90                ; draw tiles $90, $91, $92 or $93
:   STA PPU_UPD_BUF+3, X
    INX
    CPX #24
    BCC :-

    ; set palettes
    LDA #0
    STA palette_buffer+0
    STA palette_buffer+1
    STA palette_buffer+2
    STA palette_buffer+3
    STA palette_buffer+4
    STA palette_buffer+5

@prepare_palettes:
    INC pipes_next_column
    LDA pipes_next_column
    CMP #10                 ; pipe every 10 tiles
    BCC :+
    LDA #0
    STA pipes_next_column
:
    LDA #1
    STA PPU_UPD_BUF+27
    STA PPU_UPD_BUF+31
    STA PPU_UPD_BUF+35
    STA PPU_UPD_BUF+39
    STA PPU_UPD_BUF+43
    STA PPU_UPD_BUF+47

    LDA PPU_UPD_BUF+1
    ORA #3
    STA PPU_UPD_BUF+28
    STA PPU_UPD_BUF+32
    STA PPU_UPD_BUF+36
    STA PPU_UPD_BUF+40
    STA PPU_UPD_BUF+44
    STA PPU_UPD_BUF+48

    LDA PPU_UPD_BUF+2
    LSR A
    ROR A                   ; carry flag now contains if our updated column
                            ; is placed on the left or right nibble of the
                            ; attribute table
    PHP
    ORA #$C0
    CLC
    STA PPU_UPD_BUF+29
    ADC #8
    STA PPU_UPD_BUF+33
    ADC #8
    STA PPU_UPD_BUF+37
    ADC #8
    STA PPU_UPD_BUF+41
    ADC #8
    STA PPU_UPD_BUF+45
    ADC #8
    STA PPU_UPD_BUF+49
    PLP

    ; update shadow palette buffer
    BCS :+
    JSR shadow_palette_update_left
    JMP @shadow_palette_updated
:   JSR shadow_palette_update_right
@shadow_palette_updated:
    LDA palette_buffer+0
    STA PPU_UPD_BUF+30
    LDA palette_buffer+1
    STA PPU_UPD_BUF+34
    LDA palette_buffer+2
    STA PPU_UPD_BUF+38
    LDA palette_buffer+3
    STA PPU_UPD_BUF+42
    LDA palette_buffer+4
    STA PPU_UPD_BUF+46
    LDA palette_buffer+5
    STA PPU_UPD_BUF+50 

    RTS

shadow_palette_update_left:
    LDA PPU_UPD_BUF+29
    AND #$3F
    LDY PPU_UPD_BUF+28
    CPY #$24
    BCC @first_nametable
    CLC
    ADC #$40
@first_nametable:
    TAX
    LDY #0
:   LDA nametbl1_attrs, X
    AND #%11001100
    STA SCRATCH+0
    LDA palette_buffer, Y
    AND #%00110011
    ORA SCRATCH+0
    STA nametbl1_attrs, X
    STA palette_buffer, Y
    TXA
    ADC #8
    TAX
    INY
    CPY #6
    BCC :-
    RTS 

shadow_palette_update_right:
    LDA PPU_UPD_BUF+29
    AND #$3F
    LDY PPU_UPD_BUF+28
    CPY #$24
    BCC @first_nametable
    CLC
    ADC #$40
@first_nametable:
    TAX
    LDY #0
:   LDA nametbl1_attrs, X
    AND #%00110011
    STA SCRATCH+0
    LDA palette_buffer, Y
    AND #%11001100
    ORA SCRATCH+0
    STA nametbl1_attrs, X
    STA palette_buffer, Y
    TXA
    ADC #8
    TAX
    INY
    CPY #6
    BCC :-
    RTS 

generate_next_pipe:
    JSR random_next
    AND #$7F
    CMP #PIPE_MAX_Y
    BCS generate_next_pipe

    ADC #$20

    LDX pipe_write_ptr
    STA pipe_y, X
    STX pipe_last_write_ptr
    INX
    TXA
    AND #7
    STA pipe_write_ptr
    RTS

;
; Lookup tables
; =============

.segment "RODATA"
multiples_of_3:
    .byte 0, 3, 6, 9, 12, 15

ppu_nametable_hi_addrs:
    .byte $20, $24

pipe_spacing_for_levels:
    ;     EASY MED  HARD
    .byte $31, $29, $25

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

; the LUTs below assign tile IDs to pipes
; having their Y pos set to particular value MOD 8
; in tables the tiles are aligned vertically

pipe_down_0_tiles:
    .byte $3C, $6C, $00
    .byte $3D, $6D, $00
    .byte $3E, $6E, $00
    .byte $3F, $6F, $00

pipe_down_1_tiles:
    .byte $40, $98, $50
    .byte $41, $99, $51
    .byte $42, $9A, $52
    .byte $43, $9B, $53

pipe_down_2_tiles:
    .byte $44, $94, $54
    .byte $45, $95, $55
    .byte $46, $96, $56
    .byte $47, $97, $57

pipe_down_3_tiles:
    .byte $48, $94, $58
    .byte $49, $95, $59
    .byte $4A, $96, $5A
    .byte $4B, $97, $5B

pipe_down_4_tiles:
    .byte $4C, $94, $5C
    .byte $4D, $95, $5D
    .byte $4E, $CE, $5E
    .byte $4F, $CF, $5F

pipe_down_5_tiles:
    .byte $90, $30, $60
    .byte $91, $31, $61
    .byte $92, $32, $62
    .byte $93, $33, $63

pipe_down_6_tiles:
    .byte $90, $34, $64
    .byte $91, $35, $65
    .byte $92, $36, $66
    .byte $93, $37, $67
    
pipe_down_7_tiles:
    .byte $90, $38, $68
    .byte $91, $39, $69
    .byte $92, $3A, $6A
    .byte $93, $3B, $6B

pipe_up_0_tiles:
    .byte $10, $80, $90
    .byte $11, $81, $91
    .byte $12, $82, $92
    .byte $13, $83, $93

pipe_up_1_tiles:
    .byte $14, $84, $90
    .byte $15, $85, $91
    .byte $16, $86, $92
    .byte $17, $87, $93

pipe_up_2_tiles:
    .byte $18, $88, $90
    .byte $19, $89, $91
    .byte $1A, $8A, $92
    .byte $1B, $8B, $93

pipe_up_3_tiles:
    .byte $1C, $8C, $9C
    .byte $1D, $8D, $9D
    .byte $1E, $8E, $9E
    .byte $1F, $8F, $9F
    
pipe_up_4_tiles:
    .byte $20, $98, $70
    .byte $21, $99, $71
    .byte $22, $9A, $72
    .byte $23, $9B, $73
    
pipe_up_5_tiles:
    .byte $24, $94, $74
    .byte $25, $95, $75
    .byte $26, $96, $76
    .byte $27, $97, $77
    
pipe_up_6_tiles:
    .byte $28, $94, $78
    .byte $29, $95, $79
    .byte $2A, $96, $7A
    .byte $2B, $97, $7B
    
pipe_up_7_tiles:
    .byte $2C, $94, $7C
    .byte $2C, $95, $7D
    .byte $2C, $96, $7E
    .byte $2C, $97, $7F

pipe_down_tiles_lo:
    .byte .lobyte(pipe_down_0_tiles)
    .byte .lobyte(pipe_down_1_tiles)
    .byte .lobyte(pipe_down_2_tiles)
    .byte .lobyte(pipe_down_3_tiles)
    .byte .lobyte(pipe_down_4_tiles)
    .byte .lobyte(pipe_down_5_tiles)
    .byte .lobyte(pipe_down_6_tiles)
    .byte .lobyte(pipe_down_7_tiles)
    
pipe_down_tiles_hi:
    .byte .hibyte(pipe_down_0_tiles)
    .byte .hibyte(pipe_down_1_tiles)
    .byte .hibyte(pipe_down_2_tiles)
    .byte .hibyte(pipe_down_3_tiles)
    .byte .hibyte(pipe_down_4_tiles)
    .byte .hibyte(pipe_down_5_tiles)
    .byte .hibyte(pipe_down_6_tiles)
    .byte .hibyte(pipe_down_7_tiles)

pipe_up_tiles_lo:
    .byte .lobyte(pipe_up_0_tiles)
    .byte .lobyte(pipe_up_1_tiles)
    .byte .lobyte(pipe_up_2_tiles)
    .byte .lobyte(pipe_up_3_tiles)
    .byte .lobyte(pipe_up_4_tiles)
    .byte .lobyte(pipe_up_5_tiles)
    .byte .lobyte(pipe_up_6_tiles)
    .byte .lobyte(pipe_up_7_tiles)
    
pipe_up_tiles_hi:
    .byte .hibyte(pipe_up_0_tiles)
    .byte .hibyte(pipe_up_1_tiles)
    .byte .hibyte(pipe_up_2_tiles)
    .byte .hibyte(pipe_up_3_tiles)
    .byte .hibyte(pipe_up_4_tiles)
    .byte .hibyte(pipe_up_5_tiles)
    .byte .hibyte(pipe_up_6_tiles)
    .byte .hibyte(pipe_up_7_tiles)

