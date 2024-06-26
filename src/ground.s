.include "gamestates.inc"
.include "registers.inc"

.segment "ZEROPAGE"
    .import palette_addr


.segment "TMCODE"

; this routine must be perfectly timed
.align 256
draw_ground:
    LDY #32
    LDA (palette_addr), Y
    LDX #$3F
    LDY #$00
    STX PPUADDR
    STY PPUADDR
    STY PPUMASK
    STA PPUDATA
    STX PPUADDR
    STY PPUADDR

    ; waste some time
    LDX #$A
:   NOP
    DEX
    BNE :-

    LDY #33
    LDA (palette_addr), Y
    LDX #$3F
    LDY #$00
    STX PPUADDR
    STY PPUADDR
    STY PPUMASK
    STA PPUDATA
    STX PPUADDR
    STY PPUADDR

    ; waste some time
    LDX #$A
:   NOP
    DEX
    BNE :-
    NOP
    NOP
    NOP

    LDY #34
    LDA (palette_addr), Y
    LDX #$3F
    LDY #$00
    STX PPUADDR
    STY PPUADDR
    STY PPUMASK
    STA PPUDATA
    STX PPUADDR
    STY PPUADDR

    ; waste some time
    LDX #$B
:   NOP
    DEX
    BNE :-
    NOP

    LDY #35
    LDA (palette_addr), Y
    LDX #$3F
    LDY #$00
    STX PPUADDR
    STY PPUADDR
    STY PPUMASK
    STA PPUDATA
    STX PPUADDR
    STY PPUADDR

    ; waste some time
    LDX #$7B
:   NOP
    NOP
    NOP
    DEX
    BNE :-
    NOP
    NOP
    
    ; we need to enable sprite rendering for at least one scanline
    ; to fix OAM corruption
    LDA #%00010000
    STA PPUMASK
    RTS

.export draw_ground
