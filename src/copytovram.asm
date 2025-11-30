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

!zone RAMTOVRAM

.VRAM_LEFT = 8191

copyVisibleContentToVram
    lda #0
    sta zp_firstVramContentLine
    sta zp_firstVramContentLine+1
    sta zp_lastVramContentLine
    sta zp_lastVramContentLine+1
    
    lda size_vram_content
    sta .vramLeft
    lda size_vram_content+1
    sta .vramLeft+1
    
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
    jsr initLinkTableAddress

    clc
    lda zp_linecount
    sta .linesLeftToCopy
    lda zp_linecount+1
    sta .linesLeftToCopy+1
    
;continueCopyToVram     ; when we left off before due to vram full   
    lda #<VRAM_CONTENT
    sta zp_vram_content_addr
    lda #>VRAM_CONTENT
    sta zp_vram_content_addr+1

    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    
    jsr AY_to_vdc_regs_18_19
    ldx #31 ; VRAM register
    stx vdc_reg

    jsr clearVramLineOffsetTable

-   jsr writeVramLineOffset
    jsr .copyLineToVram
    bcs +

    jsr .incLineNumber
    
    dec .linesLeftToCopy
    bne -
    dec .linesLeftToCopy+1
    bpl -

+   rts

.copyLineToVram
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

; read first character of current line from content area (holds the line type)
    lda #zp_currentLinkTablePtr
    sta c_fetch_zp
    ldy #0
    ldx zp_contentBank
    jsr c_fetch 
    
    jsr .myRtv

    rts
    nop

.myRtv   ; copy RAM to VRAM

    ldy #0
    
-   ldx zp_contentBank
    iny
    jsr c_fetch

    cmp #9
    beq .rtvDone

    jsr toScreencode

; write byte to VRAM
    +vdc_sta
    dec .vramLeft
    bne +
    dec .vramLeft +1
    bpl +
    sec
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


.incLineNumber
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
.linesLeftToCopy    !word 0
