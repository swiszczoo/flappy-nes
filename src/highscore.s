.segment "ZEROPAGE"
    .import easy_hiscore_digits

.segment "BSS_NV"
    magic_number: .res 4
    ; this three values must be sequential
    old_easy_highscore_digits: .res 4
    old_medium_highscore_digits: .res 4
    old_hard_highscore_digits: .res 4

    ; this three values must be sequential
    old_easy_highscore_complement: .res 4
    old_medium_highscore_complement: .res 4
    old_hard_highscore_complement: .res 4

.segment "CODE"

erase_nv_page:
    LDA #0
    TAX
:   STA $700, X
    INX
    BNE :-
    RTS

highscore_load:
    ; verify magic number
    LDX #0
:   LDA magic_number, X
    CMP magic_number_data, X
    BNE erase_nv_page
    INX
    CPX #4
    BCC :-

    LDX #0
:   LDA old_easy_highscore_digits, X
    CMP #10
    BCS erase_nv_page
    EOR old_easy_highscore_complement, X
    CMP #$FF
    BNE erase_nv_page
    INX
    CPX #12                 ; 4*3 = 12 highscore bytes
    BCC :-

    ; data valid, copy previous value to highscore register
    LDX #0
:   LDA old_easy_highscore_digits, X
    STA easy_hiscore_digits, X
    INX
    CPX #12                 ; 4*3 = 12 highscore bytes
    BCC :-
    RTS

highscore_save:
    ; store magic number
    LDX #0
:   LDA magic_number_data, X
    STA magic_number, X
    INX
    CPX #4
    BCC :-

    ; store highscores
    LDX #0  
:   LDA easy_hiscore_digits, X
    STA old_easy_highscore_digits, X
    EOR #$FF
    STA old_easy_highscore_complement, X
    INX 
    CPX #12                 ; 4*3 = 12 highscore bytes
    BCC :-
    RTS

.export highscore_load, highscore_save

.segment "RODATA"
magic_number_data:
    .byte 222, 173, 33, 55
