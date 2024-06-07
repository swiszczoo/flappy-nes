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
    .import easy_hiscore_digits, prev_hiscore_digits
    .import game_level
    .import new_hiscore_flag
    
    .import ppu_update_addr


.segment "OAM"
    .import OAM


.segment "BSS"
    restore_progress: .res 1
    restore_column: .res 1

    .import sprite_addr_lo, sprite_addr_hi, sprite_pos_x, sprite_pos_y
    .import bird_pos_y


.import reset_bird
.import set_game_state

.segment "CODE"
screen_restore_init:
    LDA #0
    STA restore_progress
    STA restore_column
    STA sprite_addr_hi+0
    STA sprite_addr_hi+1
    STA sprite_addr_hi+2
    STA sprite_addr_hi+3
    STA sprite_addr_hi+4
    STA sprite_addr_hi+5
    STA sprite_addr_hi+6
    STA sprite_addr_hi+7
    STA sprite_addr_hi+8
    STA sprite_addr_hi+9
    STA sprite_addr_hi+10

    RTS

screen_restore_destroy:
    ; set back sprite 0 for SZH
    LDA #$CE
    STA OAM+0
    LDA #$A8
    STA OAM+3

    JSR reset_bird
    LDA #$64
    STA bird_pos_y

    RTS

screen_restore_vblank:
    ; disable rendering
    LDA #%00000000
    STA PPUMASK

    ; restore background color
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDA #$21
    STA PPUDATA

    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR

    RTS

screen_restore_loop:
    ; check if we're still restoring
    LDX restore_progress
    CPX #3
    BCS @no_loading

    LDA restore_stage_lo, X
    STA ppu_update_addr+0
    LDA restore_stage_hi, X
    STA ppu_update_addr+1
    INC restore_progress
    RTS

@no_loading:
    ; now, recover background layer
    LDA restore_column
    CMP #$40
    BCS @no_recover

    LDA #($80 | 24)
    STA PPU_UPD_BUF+0
    LDA #0
    STA PPU_UPD_BUF+27

    LDA restore_column
    AND #$20
    LSR A
    LSR A
    LSR A
    ORA #$20
    STA PPU_UPD_BUF+1
    LDA restore_column
    AND #$1F
    STA PPU_UPD_BUF+2

    ; put 18 blank tiles
    LDX #18
    LDA #00
:   DEX
    STA PPU_UPD_BUF+3, X
    BNE :-

    LDA restore_column
    AND #3
    STA SCRATCH+0

    ; then put 5 parallax tiles
    LDA #$B0
    ORA SCRATCH+0
    STA PPU_UPD_BUF+21
    LDA #$C0
    ORA SCRATCH+0
    STA PPU_UPD_BUF+22
    LDA #$D0
    ORA SCRATCH+0
    STA PPU_UPD_BUF+23
    LDA #$E0
    ORA SCRATCH+0
    STA PPU_UPD_BUF+24
    LDA #$F0
    ORA SCRATCH+0
    STA PPU_UPD_BUF+25

    ; and finally $03 tile
    LDA #$03
    STA PPU_UPD_BUF+26

    INC restore_column
    RTS

@no_recover:
    LDA STATE_INSTRUCTIONS
    JMP set_game_state

.export screen_restore_init    
.export screen_restore_destroy
.export screen_restore_vblank
.export screen_restore_loop

;
; Lookup tables
; =============

.segment "RODATA"
restore_stage_1:
    .byte 48, $23, $C0
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5
    .byte $00

restore_stage_2:
    .byte 48, $27, $C0
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $55, $55, $55, $55, $55, $55, $55, $55
    .byte $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5
    .byte $00

restore_stage_3:
    .byte 3, $3F, $0D, $07, $37, $27
    .byte $00

restore_stage_lo:
    .byte .lobyte(restore_stage_1)
    .byte .lobyte(restore_stage_2)
    .byte .lobyte(restore_stage_3)
    
restore_stage_hi:
    .byte .hibyte(restore_stage_1)
    .byte .hibyte(restore_stage_2)
    .byte .hibyte(restore_stage_3)
