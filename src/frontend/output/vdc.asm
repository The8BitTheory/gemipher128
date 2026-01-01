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
    jsr loadCharsetFromDisk

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

    jsr doSlow
    jsr vcc
    jsr doFast

    rts

setBlockFill
    ; clear BLOCK COPY register bit to get BLOCK FILL
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jmp A_to_vdc_reg_X

setBlockCopy
    ; set BLOCK COPY register bit to get BLOCK COPY
    ldx #24
    jsr vdc_reg_X_to_A
    ora #128
    jmp A_to_vdc_reg_X

; moves lines 2-23 to 1-22. for scrolling down
;  we can copy lines from top to bottom (2>1, 3>2, ...)
moveLinesUp
    ;jsr setBlockCopy

    ; arg1=source. line 2
    lda vdc_lineoffsets+2
    sta arg1
    lda vdc_lineoffsets+3
    sta arg1+1

    ; arg2=target. line 1
    lda vdc_lineoffsets
    sta arg2
    lda vdc_lineoffsets+1
    sta arg2+1

    ; arg3=count
    lda #80
    sta arg3
    lda #0
    sta arg3+1

    ; arg4=nr repeats
    lda #22
    sta arg4

    ; arg5=increase target
    lda #80
    sta arg5
    lda #0
    sta arg5+1

    ; arg6=increase source
    lda #80
    sta arg6
    lda #0
    sta arg6+1

    jsr remember_mem_conf
    jmp vmc

; moves lines 1-22 to 2-23. for scrolling up
;  we have to copy lines from bottom to top (22>23, 21>22, ...)
moveLinesDown
    lda vdc_lineoffsets+42
    sta arg1
    lda vdc_lineoffsets+43
    sta arg1+1

    ; arg2=target. line 1
    lda vdc_lineoffsets+44
    sta arg2
    lda vdc_lineoffsets+45
    sta arg2+1

    ; arg3=count
    lda #80
    sta arg3
    lda #0
    sta arg3+1

    ; arg4=nr repeats
    lda #22
    sta arg4

    ; arg5=increase target. -80 $ffb0 is two's complement of -80
    lda #$b0
    sta arg5
    lda #$ff
    sta arg5+1

    ; arg6=increase source. -80 $ffb0 is two's complement of -80
    lda #$b0
    sta arg6
    lda #$ff
    sta arg6+1

    jsr remember_mem_conf
    jmp vmc


vdc_lineoffsets     !word   80, 160, 240, 320, 400, 480, 560, 640, 720, 800, 880, 960
                    !word 1040,1120,1200,1280,1360,1440,1520,1600,1680,1760,1840,1920

!src "src/lib/vdcbasic/vdcbasic.asm"