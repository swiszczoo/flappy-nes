.segment "CODE"

main:
    jmp main

irq:
    rti

nmi:
    rti

.export main, irq, nmi
