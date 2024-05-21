.include "gamestates.inc"
.include "registers.inc"

; screen imports
.import screen_game_init
.import screen_game_destroy
.import screen_game_vblank
.import screen_game_loop
.import screen_instructions_init
.import screen_instructions_destroy
.import screen_instructions_vblank
.import screen_instructions_loop
.import screen_main_menu_init
.import screen_main_menu_destroy
.import screen_main_menu_vblank
.import screen_main_menu_loop
.import screen_transition_init
.import screen_transition_destroy
.import screen_transition_vblank
.import screen_transition_loop

.import highscore_load

.segment "ZEROPAGE"
    SCRATCH: .res 16
    wait_for_vblank: .res 1 ; 0xFF if waiting for vblank
    skip_nmi: .res 1        ; 0xFF to skip NMI
    my_ppuctrl: .res 1
    my_scroll_x: .res 1
    my_scroll_y: .res 1
    frame_counter: .res 2
    game_state: .res 1
    game_state_vblank_addr: .res 2
    game_state_loop_addr: .res 2
    palette_addr: .res 2
    global_scroll_x: .res 1
    global_chr_bank: .res 1
    gamepad_1: .res 1
    gamepad_2: .res 1
    gamepad_1_chg: .res 1
    gamepad_2_chg: .res 1

    hiscore_digits: .res 4
    current_score_digits: .res 4
    new_hiscore_flag: .res 1
    ppu_update_addr: .res 2             ; start address of PPU update instruction stream

    oam_offset: .res 1                  ; current OAM offset

    .export frame_counter, my_ppuctrl, my_scroll_x, my_scroll_y, skip_nmi
    .export SCRATCH, palette_addr, global_scroll_x, global_chr_bank
    .export gamepad_1, gamepad_2, hiscore_digits, current_score_digits
    .export gamepad_1_chg, gamepad_2_chg
    .export new_hiscore_flag
    .export ppu_update_addr
    .export oam_offset


.segment "OAM"
    OAM: .res $100

    .export OAM

.segment "BSS_NV"
    nametbl1_attrs: .res 64
    nametbl2_attrs: .res 64

    .export nametbl1_attrs, nametbl2_attrs


.segment "CODE"
CHR_PAGE: .byte $FF

main:
    ; turn off rendering
    LDA #0
    STA PPUCTRL
    STA PPUMASK

    ; set CHR ROM page 0
    STA CHR_PAGE

    ; load highscore
    JSR highscore_load

    ; set game_state_vblank func ptr to something ok
    LDA func_screen_vblank_lo
    STA game_state_vblank_addr+0
    LDA func_screen_vblank_hi
    STA game_state_vblank_addr+1

    ; set game_state_loop func ptr to something ok
    LDA func_screen_loop_lo
    STA game_state_loop_addr+0
    LDA func_screen_loop_hi
    STA game_state_loop_addr+1

    ; ensure game_state is #0
    LDA STATE_NO_SCREEN
    STA game_state

    ; first, init PPU palettes to pure black ($0f)
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDA #$0f
    LDX #32             ; loop through 16 palette colors
:   STA PPUDATA
    DEX
    BPL :-

    ; palette corruption workaround
    LDA #$3F
    STA PPUADDR
    LDA #0
    STA PPUADDR
    STA PPUADDR
    STA PPUADDR

    ; then, set some reasonable PPU settings
    LDA #%10001000
    STA my_ppuctrl
    LDA #%00011110
    STA PPUMASK
    LDA #0
    STA OAMADDR

    ; set PPUCTRL and PPUSCROLL
    LDA my_ppuctrl
    STA PPUCTRL
    BIT PPUSTATUS
    LDA my_scroll_x
    STA PPUSCROLL
    LDA my_scroll_y
    STA PPUSCROLL
    
    ; fallthrough to spinwait
    
@spinwait:
    ; wait until we get an NMI from PPU, then jump to vblank_handler
    LDA #$FF
    STA wait_for_vblank
:   BIT wait_for_vblank
    BMI :-
    JSR vblank_handler
    JMP @spinwait

nmi: 
    BIT skip_nmi
    BNE irq
    BIT wait_for_vblank
    BPL irq ; if the cpu is not waiting for vblank, do nothing
    INC wait_for_vblank ; else increment it, so it becomes $00
irq:
    RTI

update_ppu_from_rom:
    ; update PPU RAM (from ROM)
    LDY #0

@ppu_loop:
    LDX #0
    LDA (ppu_update_addr), Y
    BEQ @ppu_end                    ; if we read a block of length 0, end the loop
    STA SCRATCH+0

    ; update PPUCTRL to set PPUADDR increment (32 if first bit of length was set)
    BPL @ppu_increment_horizontal
    LDX #$04                        ; set increment mode to vertical
@ppu_increment_horizontal:
    TXA
    ORA my_ppuctrl
    STA PPUCTRL
    INY

    ;LDA SCRATCH+0
    ;AND #$7F                        ; ignore MSB of length
    ;STA SCRATCH+0

    LDA (ppu_update_addr), Y
    STA PPUADDR
    INY
    LDA (ppu_update_addr), Y
    STA PPUADDR
    INY

@ppu_inner_loop:
    LDA SCRATCH+0
    BEQ @ppu_loop
    LDA (ppu_update_addr), Y
    STA PPUDATA
    INY
    DEC SCRATCH+0
    JMP @ppu_inner_loop

@ppu_end:
    LDA #0
    STA ppu_update_addr
    STA ppu_update_addr+1
    RTS

vblank_handler:
    LDA #.hibyte(OAM)
    STA OAMDMA                      ; copy sprites data to OAM using DMA

    LDA global_chr_bank
    STA CHR_PAGE

    LDA ppu_update_addr+1           ; load hi byte of update instructions address
    BEQ :+
    JSR update_ppu_from_rom
    JMP @ppu_ram_update_end

:   ; update PPU RAM (from RAM)
    LDX #0
@ppu_loop:
    LDY #0                          ; set increment mode to horizontal
    LDA PPU_UPD_BUF, X
    BEQ @ppu_end                    ; if we read a block of length 0, end the loop
    STA SCRATCH+0

    ; update PPUCTRL to set PPUADDR increment (32 if first bit of length was set)
    BPL @ppu_increment_horizontal
    LDY #$04                        ; set increment mode to vertical
@ppu_increment_horizontal:
    TYA
    ORA my_ppuctrl
    STA PPUCTRL
    INX

    LDA SCRATCH+0
    AND #$7F                        ; ignore MSB of length
    STA SCRATCH+0

    LDA PPU_UPD_BUF, X
    STA PPUADDR
    INX
    LDA PPU_UPD_BUF, X
    STA PPUADDR
    INX

@ppu_inner_loop:
    LDA SCRATCH+0                
    BEQ @ppu_loop
    LDA PPU_UPD_BUF, X
    STA PPUDATA
    INX
    DEC SCRATCH+0
    JMP @ppu_inner_loop

@ppu_end:
    LDA #0
    STA PPU_UPD_BUF+1

@ppu_ram_update_end:
    LDA #.hibyte(:+-1)
    PHA
    LDA #.lobyte(:+-1)
    PHA
    JMP (game_state_vblank_addr)    ; indirectly call vblank handler for current screen
:
    ; set PPUCTRL and PPUSCROLL
    LDA my_ppuctrl
    STA PPUCTRL
    BIT PPUSTATUS
    LDA my_scroll_x
    STA PPUSCROLL
    LDA my_scroll_y
    STA PPUSCROLL

    ; save negated previous controller readings to scratch
    LDA gamepad_1
    EOR #$FF
    STA SCRATCH+0
    LDA gamepad_2
    EOR #$FF
    STA SCRATCH+1

    ; poll controller inputs
    ; https://www.nesdev.org/wiki/Controller_reading_code
    LDA #1
    STA JOYPAD1
    STA gamepad_2
    LSR A
    STA JOYPAD1
:   LDA JOYPAD1
    AND #%00000011
    CMP #1
    ROL gamepad_1
    LDA JOYPAD2
    AND #%00000011
    CMP #1
    ROL gamepad_2
    BCC :-

    ; save buttons that were pressed just in this frame
    LDA gamepad_1
    AND SCRATCH+0
    STA gamepad_1_chg
    LDA gamepad_2
    AND SCRATCH+1
    STA gamepad_2_chg

    LDA #.hibyte(:+-1)
    PHA
    LDA #.lobyte(:+-1)
    PHA
    JMP (game_state_loop_addr)      ; indirectly call second part of the screen loop
:
    INC frame_counter
    BNE :+
    INC frame_counter+1
:
    ; fallthrough to nop_sub
nop_sub: ; This routine exists to allow placing it in dynamic jump tables
    RTS  ; to do nothing

screen0_vblank: 
    ; this handler waits for 30 frames before calling main menu
    LDA frame_counter
    CMP #30
    BCC :+
    LDA STATE_MAIN_MENU
    JMP set_game_state                  ; we can use jump here, it will simply return to our original caller
:   RTS

;
; Utility routines
; ================

; A - which entry to jump to
dynjmp:
    ASL A
    TAY
    INY

    PLA
    STA SCRATCH+0
    PLA
    STA SCRATCH+1

    LDA (SCRATCH+0), Y
    TAX
    INY
    LDA (SCRATCH+0), Y
    STX SCRATCH+0
    STA SCRATCH+1
    JMP (SCRATCH)

; A - which entry to jump to
dynjsr:
    CLC
    ASL A
    ADC #3
    TAX

    PLA
    STA SCRATCH+0
    PLA
    STA SCRATCH+1

    LDY #2
    LDA (SCRATCH+0), Y
    PHA
    DEY
    LDA (SCRATCH+0), Y
    PHA

    TXA
    TAY
    LDA (SCRATCH+0), Y
    TAX
    INY
    LDA (SCRATCH+0), Y
    STX SCRATCH+0
    STA SCRATCH+1
    JMP (SCRATCH)

; reg A - new game state
set_game_state:
    PHA

    LDA game_state
    JSR dynjsr
    ; screen destroy routine table
    .addr :+-1
    .addr nop_sub                   ; STATE_NO_SCREEN
    .addr screen_main_menu_destroy  ; STATE_MAIN_MENU
    .addr screen_transition_destroy ; STATE_TRANSITION
    .addr screen_instructions_destroy ; STATE_INSTRUCTIONS
    .addr screen_game_destroy       ; STATE_GAME
:

    PLA
    STA game_state
    
    JSR dynjsr
    ; screen init routine table
    .addr :+-1
    .addr nop_sub                   ; STATE_NO_SCREEN
    .addr screen_main_menu_init     ; STATE_MAIN_MENU
    .addr screen_transition_init    ; STATE_TRANSITION
    .addr screen_instructions_init  ; STATE_INSTRUCTIONS
    .addr screen_game_init          ; STATE_GAME
:   

    ; set game_state_vblank func ptr to a new vblank handler
    LDX game_state
    LDA func_screen_vblank_lo, X
    STA game_state_vblank_addr+0
    LDA func_screen_vblank_hi, X
    STA game_state_vblank_addr+1
    LDA func_screen_loop_lo, X
    STA game_state_loop_addr+0
    LDA func_screen_loop_hi, X
    STA game_state_loop_addr+1
    RTS

.export set_game_state

; this routine busy waits for sprite-zero-hit
wait_for_szh:
    ; for timing debug
    ;LDA #%00011111
    ;STA PPUMASK

    ; wait for SZH flag to be cleared
    BIT PPUSTATUS
    BVS wait_for_szh
:   BIT PPUSTATUS
    BVC :-
    RTS

.export wait_for_szh

; inputs:
; SCRATCH+0 - low byte of metasprite def address
; SCRATCH+1 - hi byte of metasprite def address
; SCRATCH+2 - X offset
; SCRATCH+3 - Y offset
; oam_offset - OAM offset
draw_metasprite:
    LDX oam_offset
    LDY #0
:   INY
    LDA (SCRATCH+0), Y
    BEQ :+
    DEY
    LDA (SCRATCH+0), Y
    CLC
    ADC SCRATCH+3
    STA OAM+0, X
    INY
    LDA (SCRATCH+0), Y
    STA OAM+1, X
    INY
    LDA (SCRATCH+0), Y
    STA OAM+2, X
    INY
    LDA (SCRATCH+0), Y
    CLC
    ADC SCRATCH+2
    STA OAM+3, X
    INY
    TXA
    CLC
    ADC #4
    TAX
    JMP :-
:   STX oam_offset
    RTS

.export draw_metasprite

;
; Some lookup tables
; ==================

.segment "RODATA"
func_screen_vblank_lo:
    .byte .lobyte(screen0_vblank)                   ; STATE_NO_SCREEN
    .byte .lobyte(screen_main_menu_vblank)          ; STATE_MAIN_MENU
    .byte .lobyte(screen_transition_vblank)         ; STATE_TRANSITION
    .byte .lobyte(screen_instructions_vblank)       ; STATE_INSTRUCTIONS
    .byte .lobyte(screen_game_vblank)               ; STATE_GAME

func_screen_vblank_hi:
    .byte .hibyte(screen0_vblank)                   ; STATE_NO_SCREEN
    .byte .hibyte(screen_main_menu_vblank)          ; STATE_MAIN_MENU
    .byte .hibyte(screen_transition_vblank)         ; STATE_TRANSITION
    .byte .hibyte(screen_instructions_vblank)       ; STATE_INSTRUCTIONS
    .byte .hibyte(screen_game_vblank)               ; STATE_GAME

func_screen_loop_lo:
    .byte .lobyte(nop_sub)                          ; STATE_NO_SCREEN
    .byte .lobyte(screen_main_menu_loop)            ; STATE_MAIN_MENU
    .byte .lobyte(screen_transition_loop)           ; STATE_TRANSITION
    .byte .lobyte(screen_instructions_loop)         ; STATE_INSTRUCTIONS
    .byte .lobyte(screen_game_loop)                 ; STATE_GAME

func_screen_loop_hi:
    .byte .hibyte(nop_sub)                          ; STATE_NO_SCREEN
    .byte .hibyte(screen_main_menu_loop)            ; STATE_MAIN_MENU
    .byte .hibyte(screen_transition_loop)           ; STATE_TRANSITION
    .byte .hibyte(screen_instructions_loop)         ; STATE_INSTRUCTIONS
    .byte .hibyte(screen_game_loop)                 ; STATE_GAME

.export main, irq, nmi
.export dynjmp, dynjsr

