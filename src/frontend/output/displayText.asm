!zone outputText

; zp_linkTablePosition will always point to the beginning of the current line
; this way we should be able to work with a single byte for offset (just y)
displayTextmode
    lda zp_pageType
    cmp #$30
    bne +
    lda #4    
    jmp ++
+   lda #3
++  sta .vramLineOffsetIncr


    ldy #LAST_LINE
    sty zp_lastLine

; bank 1
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
; pointer to beginning of link table
    jsr initLinkTableAddress

; read length of current line from link-table
    lda #zp_linkTablePosition
    sta c_fetch_zp

    lda zp_pageType
    cmp #$31 ; gopher
    bne +

; line start for gopher files
    lda #79
    sta zp_lineLength
    lda #81
    sta zp_vram_screenram
    jmp ++

; line start for text files
+   lda #80
    sta zp_lineLength
    sta zp_vram_screenram

++  lda #0
    sta zp_vram_screenram+1

; setup the position in vramLineOffset
    jsr .gotoLineNumber

    ; vram read address is taken from link-table
    ; when not starting display at the first line, we're adding up visible-lengths until we're there
    ; with each line displayed, the read address is just increased by the amount of the previous line.
    ; the write address starts at zero and increments 80 bytes for each line

    ; block copy source address is automatically increased, so we only need to set it once for 25 lines
    ; each copy operation only requires setting target address (increments of 80, unless line-length is longer)
    ;  and nr of characters to copy

; if we have two bytes line-count, visible lines are for sure #VISIBLE_LINES
    lda zp_linecount+1
    beq +
    lda #VISIBLE_LINES
    sta zp_tempX    ; nr of visible lines on screen. is decremented as lines are printed
    jmp ++

; only one byte line-count, check if we have less lines than what fits the screen
+   ldx #VISIBLE_LINES
    cpx zp_linecount
    bcc +
    ldx zp_linecount
+   stx zp_tempX    ; nr of visible lines on screen. is decremented as lines are printed

; clear screen sets register bit to block fill and vram address (18/19 to $0000)
; this also waits for the next vblank period
++  jsr clearScreen

;setup block copy
; set register bit for BLOCK COPY:
    ldx #24
    jsr vdc_reg_X_to_A
    ora #128
    jsr A_to_vdc_reg_X

; target address
    jsr .writeVramAddress

; block copy source (HB/LB order)
    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    ldx #32
    jsr AY_to_vdc_regs_Xp1

    ldy #0
    sty zp_tempY    ; we use zp_tempY to count the current contentline.
    ldy #FIRST_LINE
    sty .currentScreenLine      ; initialize currentScreenLine to topmost visible line
    jsr .writeScreenToContentLine

;-----------------------------------------
; here, printing the line is triggered 
;-----------------------------------------
; displaying a screen works like this:
; text is stored in $1000 onwards. 
; visible screen is at $0000
; block copy takes text from $1000 (or higher, for increasing lines) and copies to screen-ram
; for each line, screen-ram is increased by 80
; the block-copy source increases automatically with each copy operation

; renderloop for all visible content lines on screen
-   jsr .displayGopherLine

    jsr .incVramLineOffsetPosition  ; where we read line information for block copy
    jsr .incOutputLineNumber        ; where we write lines to
    inc zp_tempY    ; content line increasing
    dec zp_tempX    ; content lines left to print
    inc .currentScreenLine
    jsr .writeScreenToContentLine

    lda zp_scrollModeCrsr
    bne +
    jsr .calculateCursorOffset

; is the screen full?
+   ldx .currentScreenLine
    cpx #VISIBLE_LINES+1
    beq .allLinesDisplayed

    clc
    lda zp_linenumber_start
    adc zp_tempY
    sta zp_tempCalc
    lda zp_linenumber_start+1
    adc #0
    sta zp_tempCalc+1

    lda zp_linecount+1
    cmp zp_tempCalc+1
    bcc .allLinesDisplayed
    lda zp_linecount
    cmp zp_tempCalc
    bne -

.allLinesDisplayed
    jsr .doTextAttributeRam
    jmp .drawPlainTextStatusline

.doTextAttributeRam
    ; clear BLOCK COPY register bit to get BLOCK WRITE:
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jsr A_to_vdc_reg_X

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


.doGopherAttributeRam
; write to attribute ram
;  we don't write attribute ram with content lines, as we'd lose the auto-increment feature of the vdc chip
;  also, writing content lines might start over if longer lines are involved.
;  by writing attributes here, we are much more efficient

+   ldx #0
    stx zp_tempX    ; we use zp_tempY to count the current displayline
   
    jsr .resetLinkTablePosition

    ; clear BLOCK COPY register bit to get BLOCK WRITE:
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jsr A_to_vdc_reg_X

-   jsr .readLineType
    cmp #$69 ; info line
    bne +
    jsr .makeLineBlack
    jmp .incAddresses

+   jsr .makeLineGreen


.incAddresses
    jsr .incLinkTableReadPosition

    inc zp_tempX
    ldx zp_tempX
    cpx zp_lastLine
    bne -   ; yes, this jumps back to .readLineType in the previous routine

    rts


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

.printHeaderLineUntilTab
    ldy #0
-   lda (zp_memPtr),y
    cmp #$d
    beq +
    pha
    jsr writeToAddress
    pla
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    dec zp_tempCalc
    beq +
    iny
    jmp -
+   rts
    nop

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

.fetchFromContentBankOffsetY
    ldx zp_contentBank
    jsr c_fetch
    iny
    rts

.drawPlainTextStatusline
    ; draw logical line, total nr of lines, start and end vram offset (from $1000)
    lda #$07
    ldy #$80
    jsr AY_to_vdc_regs_18_19

    lda #<.textLineNr
    sta zp_memPtr
    lda #>.textLineNr
    sta zp_memPtr+1

    jsr .printUntilZero

    lda zp_pageType
    cmp #$31
    bne +
    ; for gopher pages, print the cursor line
    lda zp_cursorLineContent+1
    jsr .hiNybToHex
    jsr printAcc
    lda zp_cursorLineContent+1
    jsr .loNybToHex
    jsr printAcc
    lda zp_cursorLineContent
    jsr .hiNybToHex
    jsr printAcc
    lda zp_cursorLineContent
    jsr .loNybToHex
    jsr printAcc
    jmp ++

+   lda zp_linenumber_start+1
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

++  lda #'/'
    jsr toScreencode
    jsr printAcc

    lda zp_lastVramContentLine+1
    jsr .hiNybToHex
    jsr printAcc

    lda zp_lastVramContentLine+1
    jsr .loNybToHex
    jsr printAcc

    lda zp_lastVramContentLine
    jsr .hiNybToHex
    jsr printAcc

    lda zp_lastVramContentLine
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
    
    ;rts

    lda zp_linkTablePosition+1
    ldy #$97
    jsr .writeHexValue
    lda zp_linkTablePosition
    ldy #$99
    jsr .writeHexValue

    lda zp_vramLineOffsets+1
    ldy #$9c
    jsr .writeHexValue
    lda zp_vramLineOffsets
    ldy #$9e
    jsr .writeHexValue

    lda zp_vram_content_addr+1
    ldy #$a1
    jsr .writeHexValue
    lda zp_vram_content_addr
    ldy #$a3
    jsr .writeHexValue

    lda zp_contentAddress+1
    ldy #$a6
    jsr .writeHexValue
    lda zp_contentAddress
    ldy #$a8
    jsr .writeHexValue

    lda zp_vramBlock
    ldy #$ab
    jsr .writeHexValue

    rts

.gotoLineNumber
; go to the right vram offset
    
    sec
    lda zp_linenumber_start
    sbc zp_firstVramContentLine
    sta zp_tempCalc
    lda zp_linenumber_start+1
    sbc zp_firstVramContentLine+1
    sta zp_tempCalc+1

; linecount x 3 (gopher) or x4 (text) should be the offset in the lineoffset table
    lda zp_pageType
    cmp #$30
    bne +
    ldx #4      ; plain text
    jmp ++
+   ldx #3      ; gopher files
    
++  stx zp_tempX
    jsr multiply

    clc
    adc #<VRAM_LINE_TABLE
    sta zp_vramLineOffsets
    tya
    adc #>VRAM_LINE_TABLE
    sta zp_vramLineOffsets+1

    clc
    ldy #0
    lda (zp_vramLineOffsets),y
    sta zp_vram_content_addr
    iny
    lda (zp_vramLineOffsets),y
    sta zp_vram_content_addr+1
    iny
    lda (zp_vramLineOffsets),y
    sta zp_visibleLength

    lda zp_pageType
    cmp #30 ; plain text
    bne +
    ; line-length stored in 2 bytes
    iny
    lda (zp_vramLineOffsets),y    
    jmp ++
+   lda #0  ; gopher
    
++  sta zp_visibleLength+1

; go to the right ram-content offset (increments of 10 or 3, depending on file type)
;    jsr .resetLinkTablePosition
;    rts
;    nop

; this sets the zp_linkTablePosition value to the first byte of the topmost line on screen
.resetLinkTablePosition
    lda zp_linenumber_start
    sta zp_tempCalc
    lda zp_linenumber_start+1
    sta zp_tempCalc+1
    lda zp_linkTableIncr
    sta zp_tempX
    jsr multiply

    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    rts

.incVramLineOffsetPosition
    clc
    lda zp_vramLineOffsets
    adc .vramLineOffsetIncr
    sta zp_vramLineOffsets
    bcc .incLinkTableReadPosition
    inc zp_vramLineOffsets+1

.incLinkTableReadPosition
    clc
    lda zp_linkTablePosition
    adc zp_linkTableIncr
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1
    
+   rts
    nop

.incOutputLineNumber
;    dec zp_tempX
;    bne +
;    rts
;+
    clc
    lda zp_vram_screenram
    adc #80
    sta zp_vram_screenram
    bcc .writeVramAddress
    inc zp_vram_screenram+1

; the vram target address. within the visible area of screen ram
.writeVramAddress
    ldy zp_vram_screenram
    lda zp_vram_screenram+1
    
    jmp AY_to_vdc_regs_18_19


; this is first calculated for the second line. the first line will always be 80 (see comment at the bottom of this file)
.calculateCursorOffset
    clc
    lda zp_tempY
    adc zp_tempY
    tax

    sec    
    lda zp_vram_screenram
    sbc #1
    sta .cursorOffsets,x
    inx
    lda zp_vram_screenram+1
    sta .cursorOffsets,x

    rts

.writeScreenToContentLine
    clc
    lda .currentScreenLine
    adc .currentScreenLine
    tax

    clc
    lda zp_linenumber_start
    adc zp_tempY
    sta .screenToContentLine,x
    lda zp_linenumber_start+1
    adc #0
    sta .screenToContentLine+1,x

    rts

.displayGopherLine
    jsr .readVisibleLength
    
-   lda zp_visibleLength+1    ; check
    bne .longerThanOneScreenLine
    lda zp_visibleLength
    cmp zp_lineLength
    bcc .shorterThanOneScreenLine

    ; line longer than 79 characters
.longerThanOneScreenLine
    sec
    lda zp_visibleLength
    sbc zp_lineLength
    sta zp_visibleLength
    bcs +
    dec zp_visibleLength+1
+   lda zp_lineLength
    jmp ++

    ; line shorter than 79 characters
.shorterThanOneScreenLine
    ldy #0
    sty zp_visibleLength
    
++  ldy #0  ; high-byte in Y is zero anyways, because we print 79 chars max
    jsr vdc_do_YYAA_cycles  ; this writes the length to reg #30 to trigger the VDC block copy operation
                            ; the destination location is updated by the vdc automatically
    
    lda zp_visibleLength+1  ;check if we have to handle multi-line content
    bne +
    lda zp_visibleLength
    beq .displayGopherDone    ; hb and lb are zero. nothing left to print
+   ldx .currentScreenLine    ;contains the current line nr that's printed on screen
    cpx #VISIBLE_LINES
    bne .drawNextGopherLine       ; not on the last line, keep going
    rts       ; we are on the last line. stop printing despite there being more text in the current content line
    nop

.drawNextGopherLine
    jsr .incOutputLineNumber
    jsr .writeScreenToContentLine
    inc .currentScreenLine

    jmp -

.displayGopherDone
    rts

.readLineType
    lda #zp_linkTablePosition
    sta c_fetch_zp

    ; we need the offset of the line type in the linktable first
    ldy #0
    lda (zp_linkTablePosition),y
    sta zp_memPtr
    iny
    lda (zp_linkTablePosition),y
    sta zp_memPtr+1
    iny

    lda #zp_memPtr
    sta c_fetch_zp

; load line type from the offset we just calculated
; the actual data is stored in bank 1
    ldy #0
    jsr .fetchFromContentBankOffsetY
    rts

.setAttributeRamToScreenLine
    clc
    lda zp_tempX
    adc zp_tempX
    tax

    lda .cursorOffsets,x
    sta zp_memPtr
    lda .cursorOffsets+1,x
    sta zp_memPtr+1

    clc
    lda #1
    adc zp_memPtr
    sta zp_vram_screenram
    tay
    lda zp_memPtr+1
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

.readVisibleLength
    ldy #2
    lda (zp_vramLineOffsets),y
    sta zp_visibleLength

    lda zp_pageType
    cmp #$30 ; plain text   
    bne +
    ; line-length stored in 2 bytes
    iny
    lda (zp_vramLineOffsets),y    ; plain text
    jmp ++
+   lda #0  ; gopher
    
++  sta zp_visibleLength+1

    rts
 

.textLineNr       !text "LineNr: ",0

; cursorOffsets holds the logical linenumber for each line on screen
; this is required to react to multi-line text correctly
; a gopher link line over two lines has line type and selector coming from the same offset in linktable
; 25 lines, two bytes each. 23 sould be sufficient, but we can always reduce that
.cursorOffsets  !word 80    ; first offset is always 80 (as long as we're starting in second screenline)
                !fill 50

.screenToContentLine    !fill 52    ; contains offset to contentline per screenline. needed to handle multi-line content
.currentScreenLine      !byte 0     ; what line are we rendering currently
.vramLineOffsetIncr !byte 0     ; 3 or 4 bytes, depending max line length 1 or 2 bytes