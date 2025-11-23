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
    jsr .drawCurrentLine

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
    sta zp_currentType

    ldy #64
    sty zp_tempX

    ldx #24
    ldy #7
    jsr k_plot

    lda #$12 ;rvs on
    jsr bsout
    
    lda zp_currentType
    jsr bsout

    cmp #$30 ;0 -> textfile
    beq +
    cmp #$31 ;1 -> directory
    beq +
    jmp ++

+   ldx #24
    ldy #5
    jsr k_plot

    lda #' '
    jsr bsout

    lda #zp_currentHostPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda #':'
    jsr bsout

    lda #zp_currentPortPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda #zp_currentSelectorPtr
    sta c_fetch_zp
    jsr .printStatusLineUntilTab

    lda zp_tempX
    beq +


++  lda #' '
-   jsr bsout
    dec zp_tempX
    bne -

+   lda #$92    ;rvs off
    jsr bsout
    pla
    sta c_fetch_zp
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

.printStatusLineUntilTab
    ldy #0
-   ldx zp_contentBank
    jsr c_fetch
    cmp #9
    beq +
    cmp #$d
    beq +
    jsr bsout
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
    ;jsr .incOutputLineNumber
    ;lda zp_visibleLength
    ;jmp .displayDone

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


.readVisibleLength
    ldy #2
    ldx zp_contentBank
    jsr c_fetch
    sta zp_visibleLength
    rts

.read

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

; screen-ram
    lda #$20
    ldy #0
    ldx #0
    jsr A_to_vram_XXYY

    ;set count
    lda #$af    ;lowbyte
    ldy #$07    ;highbyte
    jsr vdc_do_YYAA_cycles

; attribute-ram
    ldy #0
    ldx #$08
    lda #%10000000
    jsr A_to_vram_XXYY

    ;set count
    lda #$af    ;lowbyte
    ldy #$07    ;highbyte
    jsr vdc_do_YYAA_cycles

; set last line of attribute ram to inverse
    ldy #$80
    ldx #$07
    lda #%11001111
    jsr A_to_vram_XXYY
    ;set count
    lda #$50    ;lowbyte
    ldy #$00    ;highbyte
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


; cursorOffsets holds the vram-offset for each cursor position
; this is required to keep track of multi-line text. otherwise we'd just go in incs of 80
; 25 lines, two bytes each. 23 sould be sufficient, but we can always reduce that
.cursorOffsets  !word 80    ; first offset is always 80 (as long as we're starting in second screenline)
                !fill 48

.retries        !byte 0