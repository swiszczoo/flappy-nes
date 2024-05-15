.segment "CODE"
.import main, nmi, irq

; some boilerplate code to tame NES startup
; https://www.nesdev.org/wiki/Init_code
    
reset:
    SEI        ; ignore IRQs
    CLD        ; disable decimal mode
    LDX #$40
    STX $4017  ; disable APU frame IRQ
    LDX #$ff
    TXS        ; Set up stack
    INX        ; now X = 0
    STX $2000  ; disable NMI
    STX $2001  ; disable rendering
    STX $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; The vblank flag is in an unknown state after reset,
    ; so it is cleared here to make sure that @vblankwait1
    ; does not exit immediately.
    BIT $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
@vblankwait1:  
    BIT $2002
    BPL @vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
@clrmem:
    LDA #$00
    STA $000,x
    STA $100,x
    STA $300,x
    STA $400,x
    STA $500,x
    STA $600,x
    LDA #$FF
    STA $200,x  ; OAM sprites are set to be offscreen
    ;STA $700,x ; We're not erasing page $700, because there will be our highscore
    INX
    BNE @clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.
   
@vblankwait2:
    BIT $2002
    BPL @vblankwait2
    JMP main

.export reset

.segment "VECTORS"
.word nmi
.word reset
.word irq

.segment "TILES"

; here we include 32 pages of CHR ROM banks
; to create a background parallax effect
; (we're using mapper 3 [CNROM])

.incbin "pages/page0.chr"
.incbin "pages/page1.chr"
.incbin "pages/page2.chr"
.incbin "pages/page3.chr"
.incbin "pages/page4.chr"
.incbin "pages/page5.chr"
.incbin "pages/page6.chr"
.incbin "pages/page7.chr"
.incbin "pages/page8.chr"
.incbin "pages/page9.chr"
.incbin "pages/page10.chr"
.incbin "pages/page11.chr"
.incbin "pages/page12.chr"
.incbin "pages/page13.chr"
.incbin "pages/page14.chr"
.incbin "pages/page15.chr"
.incbin "pages/page16.chr"
.incbin "pages/page17.chr"
.incbin "pages/page18.chr"
.incbin "pages/page19.chr"
.incbin "pages/page20.chr"
.incbin "pages/page21.chr"
.incbin "pages/page22.chr"
.incbin "pages/page23.chr"
.incbin "pages/page24.chr"
.incbin "pages/page25.chr"
.incbin "pages/page26.chr"
.incbin "pages/page27.chr"
.incbin "pages/page28.chr"
.incbin "pages/page29.chr"
.incbin "pages/page30.chr"
.incbin "pages/page31.chr"
