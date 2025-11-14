!zone vdc

initVdc

; initialize charset
    jsr loadFromDisk

    ; arguments: ram-source, vram-target, nr of characters to copy
    ; copy from 16384 ($4000) to $3000 in fram, copy 96 bytes
    lda #$00
    sta arg1
    sta arg2
    sta arg3+1
    lda #$40
    sta arg1+1

    lda #$30
    sta arg2+1

    lda #96
    sta arg3

    jsr vcc

    rts

!src "src/vdcbasic/vdcbasic.asm"