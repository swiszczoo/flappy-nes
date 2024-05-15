.segment "ZEROPAGE"
    .import hiscore_digits

.segment "BSS_NV"
    old_highscore_digits: .res 4
    old_highscore_complement: .res 4

.segment "CODE"

erase_nv_page:
    LDA #0
    TAX
:   STA $700, X
    INX
    BNE :-
    RTS

highscore_load:
    LDX #0
:   LDA old_highscore_digits, X
    CMP #10
    BCS erase_nv_page
    EOR old_highscore_complement, X
    CMP #$FF
    BNE erase_nv_page
    INX
    CPX #4
    BCC :-

    ; data valid, copy previous value to highscore register
    LDX #0
:   LDA old_highscore_digits, X
    STA hiscore_digits, X
    INX
    CPX #4
    BCC :-
    RTS

highscore_save:
    LDX #0  
:   LDA hiscore_digits, X
    STA old_highscore_digits, X
    EOR #$FF
    STA old_highscore_complement, X
    INX 
    CPX #4
    BCC :-
    RTS

.export highscore_load, highscore_save
