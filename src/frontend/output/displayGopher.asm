!zone outputGopher

; zp_linkTablePosition will always point to the beginning of the current line
; this way we should be able to work with a single byte for offset (just y)
displayGopher
    ldy #LAST_LINE
    sty zp_lastLine

    jsr writeCurrentGopherToHeadline
    jsr setStatusLineAttributeRam

    jsr .doGopherAttributeRam
    
drawCursor
    sec
    lda zp_cursorLineScreen
    sbc #1
    asl
    tax
    
    lda vdc_lineoffsets,x
    sta zp_cursorPosScreen
    lda vdc_lineoffsets+1,x
    sta zp_cursorPosScreen+1

    lda #62 ; >
    ldx zp_cursorPosScreen+1
    ldy zp_cursorPosScreen
    jsr A_to_vram_XXYY

; print debug info to last line
    ;lda zp_cursorLineScreen
    ;jsr .makeItHex
    ;ldx #7
    ;ldy #$80
    ;jsr A_to_vram_XXYY

.drawStatusLine
    lda c_fetch_zp
    pha

    jsr drawPlainTextStatusline

    ; prepare values we want to show (type, selector, host, port)
    ; first, get content line from current screenline
    lda zp_cursorLineContent    
    sta zp_tempCalc
    lda zp_cursorLineContent+1
    sta zp_tempCalc+1
    jsr .loadLineType

    iny ;skip currentLength

    lda (zp_linkTablePosition),y
    sta zp_currentSelectorPtr
    iny

    lda (zp_linkTablePosition),y
    sta zp_currentSelectorPtr+1
    iny

    lda (zp_linkTablePosition),y
    sta zp_currentHostPtr
    iny

    lda (zp_linkTablePosition),y
    sta zp_currentHostPtr+1
    iny

    lda (zp_linkTablePosition),y
    sta zp_currentPortPtr
    iny
    
    lda (zp_linkTablePosition),y
    sta zp_currentPortPtr+1

    
    ; this is the counter to print spaces for the rest of the line
    ldy #38
    sty zp_tempX

    lda zp_currentType
    cmp #$30 ;0 -> textfile
    beq +
    cmp #$31 ;1 -> directory
    beq +
    cmp #$34    ; binary
    beq +
    cmp #$35    ; dos binary
    beq +
    cmp #$36    ; uuencoded text (probably a binary?)
    beq +
    cmp #$39 ; 9 -> generic binary
    beq +
    cmp #'s' ;s -> audio files
    beq +
    jmp .passiveLine

+   lda #$07
    ldy #$93
    jsr AY_to_vdc_regs_18_19

    lda #zp_currentHostPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda #':'
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    lda #zp_currentPortPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda #'/'
    jsr toScreencode
    jsr printAcc

    lda zp_currentType
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    lda #zp_currentSelectorPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda zp_tempX
    beq .doneStatusline

.passiveLine    ; a line that doesn't do anything. can be info lines or unsupported types
    lda #' '
-   jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X
    dec zp_tempX
    bne -

.doneStatusline
+   pla
    sta c_fetch_zp
    rts
    

.doGopherAttributeRam
; write to attribute ram
; this iterates over all 23 visible lines (1-23) and writes attribute ram for each of them.
; so, lines 0 and 24 are not affected

; we don't write attribute ram when writing content lines, as we'd lose the auto-increment feature of the vdc chip

    ldx #0
    stx .currentScreenLine
   
    jsr setBlockFill

-   clc
    lda zp_linenumber_start
    adc .currentScreenLine
    sta zp_tempCalc
    lda zp_linenumber_start+1
    adc #0
    sta zp_tempCalc+1

    jsr .loadLineType

    cmp #$69 ; info line
    bne +
    jsr .makeLineBlack
    jmp .incAddresses

+   jsr .makeLineGreen


.incAddresses
    ldx .currentScreenLine
    cpx #VISIBLE_LINES-1
    beq +   ; yes, this jumps back to .readLineType in the previous routine
    inc .currentScreenLine
    jmp -

+   rts


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
.printUntilZero
    ldy #0
-   lda (zp_memPtr),y
    beq +
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X
    iny
    jmp -

+   rts


.printStatusLineUntilTab
    ldy #0
-   ldx zp_contentBank
    jsr c_fetch
    cmp #9
    beq +
    cmp #$d
    beq +
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    dec zp_tempX
    beq +
    iny
    jmp -
+   rts
    nop

removeCursor
    ; zp_cursorPosScreen should be up-to-date at this point
    ; if not, do a calcCursorScreenPos

    lda #$20 ; >
    ldx zp_cursorPosScreen+1
    ldy zp_cursorPosScreen
    jmp A_to_vram_XXYY


.setAttributeRamToScreenLine
    ; the index for cursor offsets is starting with the second line on screen. so we subtract 1 from currentscreenline
    lda .currentScreenLine
    asl
    tax

    clc
    lda #1
    adc vdc_lineoffsets,x
    sta zp_vram_screenram
    tay
    lda vdc_lineoffsets+1,x
    adc #$08
    sta zp_vram_screenram+1
    
    jmp AY_to_vdc_regs_18_19

.makeLineGreen
    jsr .setAttributeRamToScreenLine
    lda #%10000010
    ldx #31
    jsr A_to_vdc_reg_X

    ldy #0
    lda #78
    jmp vdc_do_YYAA_cycles

.makeLineBlack
    jsr .setAttributeRamToScreenLine
    lda #%10000000
    ldx #31
    jsr A_to_vdc_reg_X

    ldy #0
    lda #78
    jmp vdc_do_YYAA_cycles


; this does what's needed to get currentTypePtr filled correctly
; we can continue reading other line attributes after this, if needed
.loadLineType
    lda zp_linkTableIncr
    sta zp_tempX
    jsr multiply

    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    lda #zp_linkTablePosition
    sta c_fetch_zp

    ; load line type
    ldy #0
    lda (zp_linkTablePosition),y
    sta zp_currentType
    
    iny ; at offsetposition 1
    iny ; at offsetposition 2
    iny ; at length

    rts

; scrolling up means text goes down
scrollGopherScreenUpOneLine
    ; block copy from screenline 1-22 to 2-23 (22>23, 21>22, ...)
    jsr removeCursor
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
    clc
    lda vdc_lineoffsets
    adc #1
    tay
    lda vdc_lineoffsets+1
    
    jmp copyGLineToVram

; scrolling down means text goes up
scrollGopherScreenDownOneLine
    ; block copy from screenline 1-22 to 2-23 (1>2, 2>3, ...)
    jsr removeCursor
    jsr moveLinesUp

    ; then copy the content of the last screenline from ram to vram
    ; while this routine should only deal with VRAM, we are doing RAM pointers here.
    ; might be a code smell, we'll see.
    ; vram line 23. zp_linenumber+VISIBLE_LINES start should be this
    lda zp_cursorLineContent
    sta zp_tempCalc
    lda zp_cursorLineContent+1
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
    clc
    lda vdc_lineoffsets+44
    adc #1
    tay
    lda vdc_lineoffsets+45
    

    ;AY hold VRAM target (HB/LB order)
    jmp copyGLineToVram


.textLineNr       !text "LineNr: ",0
.currentScreenLine      !byte 0     ; what screenline are we rendering currently

