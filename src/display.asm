!zone textdisplay

; zp_linkTablePosition will always point to the beginning of the current line
; zp_currentLinkTablePtr will point to the index inside of the current line
; this way we should be able to work with a single byte for offset (just y)
displayTextmode
    ; we run into infinite loops here if plain text content has less lines than available screen lines (23 usually)
    ; this is because of we only check scroll-up yes or no. but not "no scroll"
    ; this is a quick and dirty hack to get out of this loop
    ldx #25
    stx .retries

.displayTextmodeRestart
    dec .retries
    bne +
    rts

+   ldy #LAST_LINE
    sty zp_lastLine

; bank 1
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
; pointer to beginning of link table
    jsr initLinkTableAddress

; read length of current line from link-table
+   lda #zp_linkTablePosition
    sta c_fetch_zp

; vram target to zero
    lda #81
    sta zp_vram_screenram
    lda #0
    sta zp_vram_screenram+1

; setup the read-position in vram_content area
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
    sta zp_tempX
    jmp ++

; only one byte line-count, check if we have less lines than what fits the screen
+   ldx #VISIBLE_LINES
    cpx zp_linecount
    bcc +
    ldx zp_linecount
+   stx zp_tempX

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
    sty zp_tempY    ; we use zp_tempY to count the current displayline. we'll use that for calculating cursor position offsets

;-----------------------------------------
; here, printing the line is triggered 
;-----------------------------------------
-   jsr .displayLine
    bcc ++
    lda zp_scrollDirectionUp
    beq +
    ; scroll direction down ()
    inc zp_linenumber_start
    lda zp_scrollModeCrsr
    bne +
    inc zp_cursorLineScreen
+   jmp .displayTextmodeRestart ;restart building screen one content line later

    ; scroll direction up (scroll )
+   dec zp_linenumber_start
    lda zp_scrollModeCrsr
    bne +
    dec zp_cursorLineScreen
+   jmp .displayTextmodeRestart ;restart building screen one content line earlier

++  jsr .incLinkTableReadPosition
    jsr .incOutputLineNumber
    inc zp_tempY

    lda zp_scrollModeCrsr
    bne +
    jsr .calculateCursorOffset

+   ldx zp_tempX
    bne -

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

+   sec
    lda zp_cursorLineContent
    sbc zp_linenumber_start
    sta zp_tempY
    clc
    adc zp_tempY
    tax

    lda .cursorOffsets,x
    sta zp_cursorPosScreen
    inx
    lda .cursorOffsets,x
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

    lda zp_cursorLineContent
    jsr .drawCurrentLine ; writes content line in status line

.drawStatusLine
    ; this is using jsr bsout right now, should be changed to direct VRAM writes later (for consistency with charset, etc)
    lda c_fetch_zp
    pha

    lda #0
    sta zp_currentLinkTablePtr+1

    lda zp_cursorLineContent
    sta zp_currentLinkTablePtr

    ldx #8
-   clc
    lda zp_currentLinkTablePtr
    adc zp_cursorLineContent
    sta zp_currentLinkTablePtr
    bcc +
    inc zp_currentLinkTablePtr+1
+   dex
    bne -

    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_currentLinkTablePtr
    
    lda #>LINKTABLE_ADDRESS
    adc zp_currentLinkTablePtr+1
    sta zp_currentLinkTablePtr+1

    lda #zp_currentLinkTablePtr
    sta c_fetch_zp

    ; load line type
    ldy #0
    jsr .fetchFromContentBankOffsetY
    sta zp_currentTypePtr
    jsr .fetchFromContentBankOffsetY
    sta zp_currentTypePtr+1

    iny ;skip currentLength

    jsr .fetchFromContentBankOffsetY
    sta zp_currentSelectorPtr
    jsr .fetchFromContentBankOffsetY
    sta zp_currentSelectorPtr+1

    jsr .fetchFromContentBankOffsetY
    sta zp_currentHostPtr
    jsr .fetchFromContentBankOffsetY
    sta zp_currentHostPtr+1

    jsr .fetchFromContentBankOffsetY
    sta zp_currentPortPtr
    jsr .fetchFromContentBankOffsetY
    sta zp_currentPortPtr+1

    lda #zp_currentTypePtr
    sta c_fetch_zp
    ldy #0
    ldx zp_contentBank
    jsr c_fetch
;    pha
    sta zp_currentType

    ldy #64
    sty zp_tempX

    lda #$07
    ldy #$85
    jsr AY_to_vdc_regs_18_19
    
    lda zp_currentType
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    cmp #$30 ;0 -> textfile
    beq +
    cmp #$31 ;1 -> directory
    beq +
    jmp ++

+   lda #$07
    ldy #$87
    jsr AY_to_vdc_regs_18_19

    lda #' '
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

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

    lda #zp_currentSelectorPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda zp_tempX
    beq +


++  lda #' '
-   jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X
    dec zp_tempX

    bne -

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
    lda #$30    ;lowbyte
    ldy #$07    ;highbyte
    jmp vdc_do_YYAA_cycles


.doGopherAttributeRam
; write to attribute ram
;  we don't write attribute ram with content lines, as we'd lose the auto-increment feature of the vdc chip
;  also, writing content lines might start over if longer lines are involved.
;  by writing attributes here, we are much more efficient

+   ldx #0
    stx zp_tempX    ; we use zp_tempY to count the current displayline
   
    clc
    lda #<LINKTABLE_ADDRESS
    ;adc zp_linenumber_start
    sta zp_currentLinkTablePtr
    lda #>LINKTABLE_ADDRESS
    ;adc zp_linenumber_start+1
    sta zp_currentLinkTablePtr+1

    ldx zp_linenumber_start
    beq ++
-   clc
    lda zp_currentLinkTablePtr
    adc #9
    sta zp_currentLinkTablePtr
    bcc +
    inc zp_currentLinkTablePtr+1
+   dex
    bne -

    ; clear BLOCK COPY register bit to get BLOCK WRITE:
++  ldx #24
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
    clc
    lda zp_currentLinkTablePtr
    adc #9
    sta zp_currentLinkTablePtr
    bcc +
    inc zp_currentLinkTablePtr+1

+   inc zp_tempX
    ldx zp_tempX
    cpx zp_lastLine
    bne -

    rts

.drawCurrentLine
    pha 

    lsr
    lsr
    lsr
    lsr
    jsr .makeItHex
    ldx #7
    ldy #$82
    jsr A_to_vram_XXYY

    pla
    and #%00001111
    jsr .makeItHex
    ldx #7
    ldy #$83
    jmp A_to_vram_XXYY

.printHeaderLineUntilTab
    ldy #0
-   lda (zp_memPtr),y
    cmp #$d
    beq +
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
    lda zp_linenumber_start
    jsr .drawCurrentLine

    rts

.makeItHex
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
    lda #<VRAM_CONTENT
    sta zp_vram_content_addr
    lda #>VRAM_CONTENT
    sta zp_vram_content_addr+1

    ldx zp_linenumber_start
    bne +
    rts

+   stx zp_tempX

    ; read contentlength
-   jsr .readVisibleLength
    ; A holds visible length of current line
    clc
    adc zp_vram_content_addr
    sta zp_vram_content_addr
    bcc +
    inc zp_vram_content_addr+1

+   jsr .incLinkTableReadPosition
    dec zp_tempX
    bne -
    rts

.incLinkTableReadPosition
    clc
    lda zp_linkTablePosition
    adc zp_linkTableIncr
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1
+   rts

.incOutputLineNumber
    dec zp_tempX
    bne +
    rts

+   clc
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

.displayLine
    jsr .readVisibleLength
    beq +

    ; low-byte in A
-   cmp #79
    bcc +

    ; line longer than 75 characters
    sec
    sbc #79
    sta zp_visibleLength
    lda #79
    jmp ++

    ; line shorter than 75 characters
+   ldy #0
    sty zp_visibleLength

    ; this implies a maximum line-width of 255 visible characters
++  ldy #0  ; high-byte in Y is zero anyways, coming out of jsr .readVisibleLength above
    jsr vdc_do_YYAA_cycles  ; this writes the length to reg #30 to trigger the VDC block copy operation
    
    lda zp_visibleLength
    beq .displayDone
    dec zp_lastLine
    ldx zp_tempX    ;contains the nr of lines left to print
    cpx #1
    bne +       ; not on the last line, keep going
    sec
    rts       ; we are on the last line. set carry flag to trigger re-print of full page one line below
    
+   jsr .incOutputLineNumber
    lda zp_visibleLength
    jmp -

.displayDone
    clc
    rts

.readLineType
    lda #zp_currentLinkTablePtr
    sta c_fetch_zp

    ; load line type
    ldy #0
    jsr .fetchFromContentBankOffsetY
    sta zp_memPtr
    jsr .fetchFromContentBankOffsetY
    sta zp_memPtr+1

    lda #zp_memPtr
    sta c_fetch_zp

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
    ldx zp_contentBank
    jsr c_fetch
    sta zp_visibleLength
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

; fill line 0 with spaces
    ldy #$00
    ldx #$00
    lda #$20
    jsr A_to_vram_XXYY
    
    ; set count (79 characters)
    lda #$4f
    ldy #$00
    jsr vdc_do_YYAA_cycles

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
    ldy #10
    lda #00
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

; cursorOffsets holds the vram-offset for each cursor position
; this is required to keep track of multi-line text. otherwise we'd just go in incs of 80
; 25 lines, two bytes each. 23 sould be sufficient, but we can always reduce that
.cursorOffsets  !word 80    ; first offset is always 80 (as long as we're starting in second screenline)
                !fill 48

.retries        !byte 0
