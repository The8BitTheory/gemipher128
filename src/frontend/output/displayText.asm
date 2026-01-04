!zone outputText

; zp_linkTablePosition will always point to the beginning of the current line
; this way we should be able to work with a single byte for offset (just y)

; this routine only deals with vram (not ram, etc)
displayTextmode
    ldy #LAST_LINE
    sty zp_lastLine

    lda #80
    sta zp_lineLength

    jsr .doTextAttributeRam
    jsr writeCurrentGopherToHeadline
    jsr setStatusLineAttributeRam

    jmp drawPlainTextStatusline

.doTextAttributeRam
    jsr setBlockFill

; set lines 1 - 23 to charset1, text black data
; screen-ram
    lda #%10000000
    ldy #$50
    ldx #$08
    jsr A_to_vram_XXYY

    ;set count
    lda #$2f    ;lowbyte
    ldy #$07    ;highbyte
    jmp vdc_do_YYAA_cycles

.writeHexValue
    pha
    jsr .hiNybToHex
    ldx #7
    jsr A_to_vram_XXYY

    pla
    jsr .loNybToHex
    ldx #7
    iny
    jmp A_to_vram_XXYY

.hiNybToHex
    lsr
    lsr
    lsr
    lsr
    jmp makeItHex

.loNybToHex
    and #%00001111
    jmp makeItHex


; use jsr AY_to_vdc_regs_18_19 to set the vram location of the first character
.printUntilNull
    ldy #0
-   lda (zp_memPtr),y
    beq +
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X
    iny
    jmp -

+   rts

drawPlainTextStatusline
    jsr setBlockFill

    lda #$20
    ldy #$07
    ldx #$80
    jsr A_to_vram_XXYY

    ;set count
    lda #$50    ;lowbyte
    ldy #$00    ;highbyte
    jsr vdc_do_YYAA_cycles

    ; draw topmost linenr and total nr of lines
;    lda #$0f
;    ldy #$80
;    jsr AY_to_vdc_regs_18_19

    ; draw topmost linenr and total nr of lines
    lda #$07
    ldy #$80
    jsr AY_to_vdc_regs_18_19

    lda #<.textLineNr
    sta zp_memPtr
    lda #>.textLineNr
    sta zp_memPtr+1

    jsr .printUntilNull

    lda zp_linenumber_start+1
    jsr .hiNybToHex
    jsr printAcc
    lda zp_linenumber_start+1
    jsr .loNybToHex
    jsr printAcc
    lda zp_linenumber_start
    jsr .hiNybToHex
    jsr printAcc
    lda zp_linenumber_start
    jsr .loNybToHex
    jsr printAcc

    lda #'/'
    jsr toScreencode
    jsr printAcc

    lda zp_linecount+1
    jsr .hiNybToHex
    jsr printAcc

    lda zp_linecount+1
    jsr .loNybToHex
    jsr printAcc

    lda zp_linecount
    jsr .hiNybToHex
    jsr printAcc

    lda zp_linecount
    jsr .loNybToHex
    jsr printAcc
    
    rts



; scrolling up means text goes down
scrollTextScreenUpOneLine
    ; block copy from screenline 1-22 to 2-23 (22>23, 21>22, ...)
    jsr moveLinesDown
    
    ; then copy the content of the first screenline from ram to vram
    ; while this routine should only deal with VRAM, we are doing RAM pointers here.
    ; might be a code smell, we'll see.
    ; vram line 1. zp_linenumber start should be this
    lda zp_linenumber_start
    sta zp_tempCalc
    lda zp_linenumber_start+1
    sta zp_tempCalc+1

    ldx zp_linkTableIncr
    stx zp_tempX
    jsr multiply    ; result A=lo, Y=hi
    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    ;AY hold VRAM target (HB/LB order)
    ldy vdc_lineoffsets
    lda vdc_lineoffsets+1
    
    jmp copyTLineToVram

; scrolling down means text goes up
scrollTextScreenDownOneLine
    ; block copy from screenline 1-22 to 2-23 (1>2, 2>3, ...)
    jsr moveLinesUp

    ; then copy the content of the last screenline from ram to vram
    ; while this routine should only deal with VRAM, we are doing RAM pointers here.
    ; might be a code smell, we'll see.
    ; vram line 23. zp_linenumber+VISIBLE_LINES start should be this
    clc
    lda zp_linenumber_start
    adc #VISIBLE_LINES-1
    sta zp_tempCalc
    lda zp_linenumber_start+1
    adc #0
    sta zp_tempCalc+1

    ldx zp_linkTableIncr
    stx zp_tempX
    jsr multiply    ; result A=lo, Y=hi
    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    ; then copy the content of the last screenline from ram to vram
    ; vram line 23
    ldy vdc_lineoffsets+44
    lda vdc_lineoffsets+45

    ;AY hold VRAM target (HB/LB order)
    jmp copyTLineToVram


.textLineNr             !text "LineNr: ",0
.currentScreenLine      !byte 0     ; what line are we rendering currently


