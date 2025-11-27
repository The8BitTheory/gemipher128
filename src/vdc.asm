!zone vdc

initVdc

    ; light grey background
    lda #$0e    ;black foreground, light grey background
    ldx #26
    jsr A_to_vdc_reg_X

    ;pal: 35 character rows (default: 40), reg 4 (40x8=320, 35*9=315 + 5 extra in reg5)
    lda #35
    ldx #4
    jsr A_to_vdc_reg_X

    lda #5
    ldx #5
    jsr A_to_vdc_reg_X

    ; 9 scanlines per character (value 8 to reg 9)
    lda #8
    ldx #9
    jsr A_to_vdc_reg_X

; initialize charset
    jsr loadFromDisk

    ; arguments: ram-source, vram-target, nr of characters to copy
    ; copy from 16384 ($4000) to $3000 in fram, copy 96 bytes
    lda #$00
    sta arg1
    sta arg2
    sta arg3+1
    lda #$b0
    sta arg1+1

    lda #$30
    sta arg2+1

    lda #98
    sta arg3

    jsr vcc

    rts

!src "src/vdcbasic/vdcbasic.asm"