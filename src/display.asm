!zone textdisplay

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
++  jsr .clearScreen

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
-   jsr .displayLine

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
    lda zp_pageType
    cmp #$31
    bne +
    jsr .doGopherAttributeRam
    jmp drawCursor

; handle attribute-ram for plain-text here (ie clear screen with black text)
+   jsr .doTextAttributeRam

drawCursor
    lda zp_scrollModeCrsr
    beq +
    jmp .drawPlainTextStatusline

+   ldx zp_cursorLineScreen
    clc
    lda #0
    sta zp_cursorPosScreen+1
    
-   adc #80
    sta zp_cursorPosScreen
    bcc +
    inc zp_cursorPosScreen+1
    clc
+   dex
    bne -

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

    jsr .drawPlainTextStatusline

    ; prepare values we want to show (type, selector, host, port)
    ; first, get content line from current screenline
    clc
    lda zp_cursorLineScreen
    adc zp_cursorLineScreen
    tax

    lda .screenToContentLine,x
    ;lda zp_cursorLineContent
    sta zp_tempCalc
    lda .screenToContentLine+1,x
    ;lda zp_cursorLineContent+1
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

    lda #zp_linkTablePosition
    sta c_fetch_zp

    ; load line type
    ldy #0
    lda (zp_linkTablePosition),y
    sta zp_currentTypePtr
    iny
    
    lda (zp_linkTablePosition),y
    sta zp_currentTypePtr+1
    iny

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
    iny

    lda #zp_currentTypePtr
    sta c_fetch_zp
    ldy #0
    ldx zp_contentBank
    jsr c_fetch
    sta zp_currentType

;    lda #$07
;    ldy #$80
;    jsr AY_to_vdc_regs_18_19
    
    ; this is the counter to print spaces for the rest of the line
    ldy #38
    sty zp_tempX

    lda zp_currentType
    cmp #$30 ;0 -> textfile
    beq +
    cmp #$31 ;1 -> directory
    beq +
    jmp ++

+   lda #$07
    ldy #$ab
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
    jsr .printAcc

    lda zp_currentType
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    lda #zp_currentSelectorPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda zp_tempX
    beq .doneStatusline

++  lda #' '
-   jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X
    dec zp_tempX
    bne -

.doneStatusline
+   pla
    sta c_fetch_zp
    rts
    

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

.printAcc
    ldx #31
    jmp A_to_vdc_reg_X

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
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    inc addressPos
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
    jsr .printAcc
    lda zp_cursorLineContent+1
    jsr .loNybToHex
    jsr .printAcc
    lda zp_cursorLineContent
    jsr .hiNybToHex
    jsr .printAcc
    lda zp_cursorLineContent
    jsr .loNybToHex
    jsr .printAcc
    jmp ++

+   lda zp_linenumber_start+1
    jsr .hiNybToHex
    jsr .printAcc
    lda zp_linenumber_start+1
    jsr .loNybToHex
    jsr .printAcc
    lda zp_linenumber_start
    jsr .hiNybToHex
    jsr .printAcc
    lda zp_linenumber_start
    jsr .loNybToHex
    jsr .printAcc

++  lda #'/'
    jsr toScreencode
    jsr .printAcc

    lda zp_lastVramContentLine+1
    jsr .hiNybToHex
    jsr .printAcc

    lda zp_lastVramContentLine+1
    jsr .loNybToHex
    jsr .printAcc

    lda zp_lastVramContentLine
    jsr .hiNybToHex
    jsr .printAcc

    lda zp_lastVramContentLine
    jsr .loNybToHex
    jsr .printAcc

    lda #'/'
    jsr toScreencode
    jsr .printAcc

    lda zp_linecount+1
    jsr .hiNybToHex
    jsr .printAcc

    lda zp_linecount+1
    jsr .loNybToHex
    jsr .printAcc

    lda zp_linecount
    jsr .hiNybToHex
    jsr .printAcc

    lda zp_linecount
    jsr .loNybToHex
    jsr .printAcc
    
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

makeItHex
    clc
    cmp #10
    bpl +
    adc #$30
    rts

+   adc #54
    rts

removeCursor
    ; zp_cursorPosScreen should be up-to-date at this point
    ; if not, do a calcCursorScreenPos

    lda #$20 ; >
    ldx zp_cursorPosScreen+1
    ldy zp_cursorPosScreen
    jmp A_to_vram_XXYY

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

.displayLine
    jsr .readVisibleLength
    ;beq ++

    
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
    beq .displayDone    ; hb and lb are zero. nothing left to print
+   ldx .currentScreenLine    ;contains the current line nr that's printed on screen
    cpx #VISIBLE_LINES
    bne .drawNextLine       ; not on the last line, keep going
    rts       ; we are on the last line. stop printing despite there being more text in the current content line
    nop

.drawNextLine
    jsr .incOutputLineNumber
    jsr .writeScreenToContentLine
    inc .currentScreenLine

    jmp -

.displayDone
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

.clearScreen
;   wait until we are in text window (in case we're in a sync state right now)
-   lda vdc_state
    and #$20
    bne -

    ; wait until we are out of text window
-   lda vdc_state
    and #$20
    beq -

    ; clear BLOCK COPY register bit to get BLOCK WRITE:
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jsr A_to_vdc_reg_X

; fill lines 1 - 23 with space character
; screen-ram
    lda #$20
    ldy #$50
    ldx #$00
    jsr A_to_vram_XXYY

    ;set count
    lda #$30    ;lowbyte
    ldy #$07    ;highbyte
    jsr vdc_do_YYAA_cycles

; not clearing lines 1-23 (content area) because every line writes to the attribute ram anyways

; set line 24 of attribute ram to inverse
    ldy #$80
    ldx #$0f
    lda #%11000011   ;charset 1, reverse on
    jsr A_to_vram_XXYY

    ;set count (79 chars)
    lda #$4f    ;lowbyte
    ldy #$00    ;highbyte
    jsr vdc_do_YYAA_cycles
    
; fill line 24 with spaces
    ldy #$80
    ldx #$07
    lda #$20
    jsr A_to_vram_XXYY
    
    ; set count (79 characters)
    lda #$4f
    ldy #$00
    jmp vdc_do_YYAA_cycles


.clearInvisibleContentArea
    ; clear BLOCK COPY register bit to get BLOCK WRITE:
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jsr A_to_vdc_reg_X

    lda #0
    ldy #$00
    ldx #$10
    jsr A_to_vram_XXYY

    ;set count
    lda #$ff    ;lowbyte
    ldy #$01    ;highbyte
    jmp vdc_do_YYAA_cycles

toScreencode
    cmp #64 ;A  
    bmi .screencodeDone       ; < A (so, must be a digit. don't change)

    cmp #96 ;a  ; < a (so, must be an uppercase letter. subtract 64
    bpl +
    sec
    sbc #64
    jmp .screencodeDone

+   cmp #127 ; <z (so, must be a lowercase letter)
    bpl .screencodeDone
    sec
    sbc #32

.screencodeDone
    rts

writeCurrentGopherToHeadline
    ; clear BLOCK COPY register bit to get BLOCK WRITE:
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jsr A_to_vdc_reg_X

; set line 0 of attribute ram to inverse
    ldy #$00
    ldx #$08
    lda #%11000011  ;charset 1, reverse on, dark gray
    jsr A_to_vram_XXYY

; set count (79 characters)
    lda #$4f
    ldy #$00
    jsr vdc_do_YYAA_cycles

    jsr fillLine0WithSpaces

; print rounded corners top left and right
    lda #96
    ldy #$00
    ldx #$00
    jsr A_to_vram_XXYY

    lda #97
    ldy #$4f
    ldx #$00
    jsr A_to_vram_XXYY

    ldx #64
    stx zp_tempX
    ldy #02
    lda #00
    sta addressPos  ; this is used for cursorposition when entering a user-defined address
    jsr AY_to_vdc_regs_18_19

    lda #<tcpOpenHostPort
    sta zp_memPtr  ;we're mis-using this here, as we're not doing indfet
    lda #>tcpOpenHostPort
    sta zp_memPtr+1

    lda tcpOpenSizeL
    sta zp_tempCalc
    lda tcpOpenSizeH
    sta zp_tempCalc+1

    jsr .printHeaderLineUntilTab

    lda #'/'
    jsr toScreencode
    jsr .printAcc
    inc addressPos

    lda zp_pageType
    jsr toScreencode
    jsr .printAcc
    inc addressPos

    lda #<tcpWriteSelector
    sta zp_memPtr
    lda #>tcpWriteSelector+1
    sta zp_memPtr+1

    lda tcpWriteSizeL
    sta zp_tempCalc
    lda tcpWriteSizeH
    sta zp_tempCalc+1

    jmp .printHeaderLineUntilTab
    nop

fillLine0WithSpaces
    ldy #$00
    ldx #$00
    lda #$20
    jsr A_to_vram_XXYY
    
    ; set count (79 characters)
    lda #$4f
    ldy #$00
    jmp vdc_do_YYAA_cycles


multiply
    lda #%00001110
    sta $ff00


    lda #$00
    tay
    beq .enterLoop

.doAdd:
    clc
    adc zp_tempCalc
    tax

    tya
    adc zp_tempCalc+1
    tay
    txa

.loop:
    asl zp_tempCalc
    rol zp_tempCalc+1
.enterLoop:  ; accumulating multiply entry point (enter with .A=lo, .Y=hi)
    lsr zp_tempX
    bcs .doAdd
    bne .loop

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