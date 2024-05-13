.segment "CODE"
.import main, nmi, irq

; some boilerplate code to tame NES startup
; https://www.nesdev.org/wiki/Init_code
    
reset:
    sei        ; ignore IRQs
    cld        ; disable decimal mode
    ldx #$40
    stx $4017  ; disable APU frame IRQ
    ldx #$ff
    txs        ; Set up stack
    inx        ; now X = 0
    stx $2000  ; disable NMI
    stx $2001  ; disable rendering
    stx $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; The vblank flag is in an unknown state after reset,
    ; so it is cleared here to make sure that @vblankwait1
    ; does not exit immediately.
    bit $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
@vblankwait1:  
    bit $2002
    bpl @vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
    txa
@clrmem:
    sta $000,x
    sta $100,x
    sta $200,x
    sta $300,x
    sta $400,x
    sta $500,x
    sta $600,x
    sta $700,x
    inx
    bne @clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.
   
@vblankwait2:
    bit $2002
    bpl @vblankwait2
    jmp main

.export reset

.segment "VECTORS"
.word nmi
.word reset
.word irq

.segment "TILES"

; here we include 32 pages of CHR ROM banks
; to create a background parallax effect
; (we're using mapper 3 [CNROM])

.incbin "../data/pages/page0.chr"
.incbin "../data/pages/page1.chr"
.incbin "../data/pages/page2.chr"
.incbin "../data/pages/page3.chr"
.incbin "../data/pages/page4.chr"
.incbin "../data/pages/page5.chr"
.incbin "../data/pages/page6.chr"
.incbin "../data/pages/page7.chr"
.incbin "../data/pages/page8.chr"
.incbin "../data/pages/page9.chr"
.incbin "../data/pages/page10.chr"
.incbin "../data/pages/page11.chr"
.incbin "../data/pages/page12.chr"
.incbin "../data/pages/page13.chr"
.incbin "../data/pages/page14.chr"
.incbin "../data/pages/page15.chr"
.incbin "../data/pages/page16.chr"
.incbin "../data/pages/page17.chr"
.incbin "../data/pages/page18.chr"
.incbin "../data/pages/page19.chr"
.incbin "../data/pages/page20.chr"
.incbin "../data/pages/page21.chr"
.incbin "../data/pages/page22.chr"
.incbin "../data/pages/page23.chr"
.incbin "../data/pages/page24.chr"
.incbin "../data/pages/page25.chr"
.incbin "../data/pages/page26.chr"
.incbin "../data/pages/page27.chr"
.incbin "../data/pages/page28.chr"
.incbin "../data/pages/page29.chr"
.incbin "../data/pages/page30.chr"
.incbin "../data/pages/page31.chr"
