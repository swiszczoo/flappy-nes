.include "gamestates.inc"
.include "registers.inc"

.import draw_ground
.import wait_for_szh

.segment "ZEROPAGE"
    .import SCRATCH
    .import palette_addr
    .import frame_counter, my_ppuctrl, my_scroll_x, my_scroll_y
    .import skip_nmi, global_scroll_x, global_chr_bank

.segment "OAM"
    .import OAM

.segment "BSS"
    my_ppumask: .res 1
    current_palette: .res 1
    prev_palette: .res 1


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

    ;disable NMI
    LDA #$FF
    STA skip_nmi

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

    ; enable NMI
    LDA #0
    STA skip_nmi

    ; enable rendering on next vblank
    LDA #%00011110
    STA my_ppumask

    RTS

screen_main_menu_destroy:
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

    LDA current_palette
    CMP #1
    BMI @no_moving_bg               ; no moving background

    ; waste some time
    LDX #$FF
:   NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    DEX
    BNE :-
    
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
    JSR wait_for_szh                ; we spin-wait for Sprite 0 Hit
    BIT PPUSTATUS

    LDA global_scroll_x
    STA PPUSCROLL
    BIT PPUSTATUS

    ; now some precise timing, we need to wait for 16 scanlines
    ; then set the palette color to a value from lookup table
    LDX #$80
:   NOP
    NOP
    NOP
    NOP
    DEX
    BNE :-
    NOP
    NOP

    ; call precisely timed routine
    JSR draw_ground

@no_moving_bg:
    RTS

menu_nametable:
    .incbin "menu.bin"

; the last 4 bytes in palettes are for ground gradient
menu_palette_1:
    .byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
    .byte $0F, $0F, $0F, $08

menu_palette_2:
    .byte $01, $0F, $0F, $0A, $01, $0C, $0F, $1C, $01, $0F, $1A, $0B, $01, $0F, $17, $07
    .byte $01, $0F, $0F, $0F, $01, $0F, $0F, $0F, $01, $0F, $0F, $0F, $01, $0F, $0F, $0F
    .byte $0F, $0F, $08, $18

menu_palette_3:
    .byte $11, $0F, $0B, $1A, $11, $1C, $0A, $2C, $11, $0A, $2A, $1B, $11, $0F, $27, $17
    .byte $11, $0F, $0F, $0F, $11, $0F, $0F, $0F, $11, $0F, $0F, $0F, $11, $0F, $0F, $0F
    .byte $0F, $08, $18, $28

menu_palette_4:
    .byte $21, $0F, $1B, $2A, $21, $2C, $1A, $3C, $21, $1A, $3A, $2B, $21, $07, $37, $27
    .byte $21, $0F, $0F, $0F, $21, $0F, $0F, $0F, $21, $0F, $0F, $0F, $21, $0F, $0F, $0F
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

.export screen_main_menu_init
.export screen_main_menu_destroy
.export screen_main_menu_vblank
.export screen_main_menu_loop
