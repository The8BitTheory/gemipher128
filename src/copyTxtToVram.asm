; this is responsible for copying the visible content to vram (a part that's not visible on screen)
; in contrast to the content area in bank 1, this
; - is in screencode, not in ascii format
; - only contains visible text. no type, no selector, no host, no port. these stay in bank 1
; - text is also stored gapless/condensed here
; - all visible lines are copied via block copy to the visible screen area

; vram memory map
; $0000-$07ff screen ram
; $0800-$0fff attribute ram
; $1000-$2fff invisible content area (we're copying to this area) - 8 kB available in a 16 kB VRAM setup
; $3000-$3fff character set (uppercase/lowercase)

!zone txtRamToVram

.VRAM_LEFT = 3071

copyTextToVram
    lda #0
    sta zp_firstVramContentLine
    sta zp_firstVramContentLine+1
    sta zp_lastVramContentLine
    sta zp_lastVramContentLine+1
    
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
    clc
    lda zp_linecount
    sta .linesLeftToCopy
    lda zp_linecount+1
    sta .linesLeftToCopy+1

    jsr initLinkTableAddress

    jmp .test

continueCopyToVram     ; when we left off before due to vram full
    jmp .test
    ; go back one screen, so we can scroll up a bit without re-loading immediately
    ldx zp_linkTableIncr
    clc
    lda #0
-   adc #VISIBLE_LINES
    dex
    bne -

    sta zp_tempA

    sec
    lda zp_linkTablePosition
    sbc zp_tempA
    sta zp_linkTablePosition
    bcs +
    dec zp_linkTablePosition+1

; reduce vramLineOffset position (3 bytes per entry)
+   ldx #3
    clc
    lda #0
-   adc #VISIBLE_LINES
    dex
    bne -

    sta zp_tempA

    sec
    lda zp_vramLineOffsets
    sbc zp_tempA
    sta zp_vramLineOffsets
    bcs +
    dec zp_vramLineOffsets

    sec
    lda zp_linenumber_start
    sbc #VISIBLE_LINES
    sta zp_linenumber_start
    bcs .test
    dec zp_linenumber_start


.test
    ; vram-left is reset, because we fill it with subsequent data from the beginning
    lda #<.VRAM_LEFT
    sta .vramLeft
    lda #>.VRAM_LEFT
    sta .vramLeft+1

    ; write to vram from the start
    lda #<VRAM_CONTENT
    sta zp_vram_content_addr
    lda #>VRAM_CONTENT
    sta zp_vram_content_addr+1

    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    
    ; vram target
    jsr AY_to_vdc_regs_18_19
    ldx #31 ; VRAM register
    stx vdc_reg

    lda zp_linenumber_start
    sta zp_firstVramContentLine
    lda zp_linenumber_start+1
    sta zp_firstVramContentLine+1

    jsr clearVramLineOffsetTable

; --- copy line ------------
-   jsr writeVramLineOffset
    jsr .copyGLineToVram
    bcs +

    jsr .incGLineNumber

    dec .linesLeftToCopy
    bne -
    dec .linesLeftToCopy+1
    bpl -

+   lda zp_lastVramContentLine
    ldx zp_lastVramContentLine+1
    rts

.copyGLineToVram
    ldy #0

; read start position of current line from link-table
    lda #zp_linkTablePosition
    sta c_fetch_zp
    
    ldx zp_contentBank
    jsr c_fetch
    sta zp_currentLinkTablePtr
    iny
    ldx zp_contentBank
    jsr c_fetch
    sta zp_currentLinkTablePtr+1
    iny
    ldx zp_contentBank
    jsr c_fetch
    sta zp_visibleLength

    ldy #2
    sta (zp_vramLineOffsets),y

    jsr incVramLineOffsetPosition

    lda #zp_currentLinkTablePtr
    sta c_fetch_zp
    
; copy RAM to VRAM
    ldy #0
    
-   ldx zp_contentBank
    jsr c_fetch     ; read content byte from RAM
    cmp #$0d
    beq .rtvDone
    cmp #$0a
    beq .rtvDone
    iny
    beq .rtvDone    ; copy 255 chars max (as a guardrail)

    jsr toScreencode

; write content byte to VRAM
    +vdc_sta
    sec
    lda .vramLeft
    sbc #1
    sta .vramLeft
    bcs +
    dec .vramLeft+1
    bpl + ; high byte positive, continue copy

    ; high byte below zero, 
    sec             ; both zero
    rts ; no more vram left. leave

    ; increase vram address.
    ; we use this to mirror the actual vram address
    ; we could read from vdc regs, but that would auto-increment them
+   inc zp_vram_content_addr
    bne +
    inc zp_vram_content_addr+1

+   dec zp_visibleLength
    bne -

.rtvDone
    clc
    rts

writeVramLineOffset
    ldy #0
    lda zp_vram_content_addr
    sta (zp_vramLineOffsets),y
    iny
    lda zp_vram_content_addr+1
    sta (zp_vramLineOffsets),y

+   rts

incVramLineOffsetPosition
    clc
    lda zp_vramLineOffsets
    adc #3
    sta zp_vramLineOffsets
    bcc +
    inc zp_vramLineOffsets+1
+   rts

clearVramLineOffsetTable
    lda #<VRAM_LINE_TABLE
    sta zp_vramLineOffsets
    lda #>VRAM_LINE_TABLE
    sta zp_vramLineOffsets+1

    lda #0
    ldx #0

-   sta VRAM_LINE_TABLE,x
    sta VRAM_LINE_TABLE+$100,x
    sta VRAM_LINE_TABLE+$200,x
    sta VRAM_LINE_TABLE+$300,x
    sta VRAM_LINE_TABLE+$400,x
    sta VRAM_LINE_TABLE+$500,x
    sta VRAM_LINE_TABLE+$600,x
    sta VRAM_LINE_TABLE+$700,x
    dex
    bne -

    rts

.incGLineNumber
    clc
    lda zp_linkTablePosition
    adc zp_linkTableIncr
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1

+   inc zp_lastVramContentLine
    bne +
    inc zp_lastVramContentLine+1
+   rts

.vramLeft       !word 0
.linesLeftToCopy    !word 0     ; related to copying from ram to vram. if this is > 0, we have more data to show
