; this is responsible for copying the visible content to vram (a part that's not visible on screen)
; in contrast to the content area in bank 1, this
; - is in screencode, not in ascii format
; - all visible lines are copied via block copy to the visible screen area

; this routine bridges ram and vram

; vram memory map
; $0000-$07ff screen ram
; $0800-$0fff attribute ram
; $1000-$2fff invisible content area (we're copying to this area) - 8 kB available in a 16 kB VRAM setup
; $3000-$3fff character set (uppercase/lowercase)

!zone textRamToVram
copyTextToVram
    lda #0
    sta zp_firstVramContentLine
    sta zp_firstVramContentLine+1
    sta zp_lastVramContentLine
    sta zp_lastVramContentLine+1

    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
    jsr initLinkTableAddress

continueCopyTextToVram     ; when we left off before due to vram full

    ; lines left to copy needs to be set accordingly
    sec
    lda zp_linecount
    sbc zp_linenumber_start
    sta .linesLeftToCopy
    lda zp_linecount+1
    sbc zp_linenumber_start+1
    sta .linesLeftToCopy+1

    ; vram-left is reset, because we fill it with subsequent data from the beginning
    ; we only fill 2000 bytes of vram, directly on the frontbuffer
    ;lda size_vram_content
    lda #$30
    sta .vramLeft
    ;lda size_vram_content+1
    lda #$07
    sta .vramLeft+1

    ; write to vram from the start
    ;lda #<VRAM_CONTENT
    lda #80
    sta zp_vram_content_addr
    ;lda #>VRAM_CONTENT
    lda #0
    sta zp_vram_content_addr+1

    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    
    ; vram target
    jsr AY_to_vdc_regs_18_19
    ldx #31 ; VRAM register
    stx vdc_reg

    lda zp_firstVramContentLine
    sta zp_lastVramContentLine
    lda zp_firstVramContentLine+1
    sta zp_lastVramContentLine+1

; --- copy line ------------
-   jsr .copyTLineToVram
    bcs +

    jsr incLineNumber

    dec .linesLeftToCopy
    bne -
    dec .linesLeftToCopy+1
    bpl -

+   rts

.copyTLineToVram
    ldy #0
    
    lda (zp_linkTablePosition),y
    sta zp_currentLinkTablePtr
    iny
    lda (zp_linkTablePosition),y
    sta zp_currentLinkTablePtr+1
    iny

    lda (zp_linkTablePosition),y
    sta zp_visibleLength
    iny
    lda (zp_linkTablePosition),y
    sta zp_visibleLength+1
    
    lda #zp_currentLinkTablePtr
    sta c_fetch_zp

; copy RAM to VRAM
; RAM-lines with variable line length (but: max. 80) become VRAM-lines with fixed line length of 80
    ldx #80
    stx zp_tempX    ; lines can be 80 chars max at this point, parsing made sure of this

    ldy #0
-   ldx zp_contentBank
    jsr c_fetch     ; read content byte from RAM

    cmp #$0d
    beq .rtvDone
    cmp #$0a
    beq .rtvDone
    iny
    dec zp_tempX
    jsr toScreencode

; write content byte to VRAM
    ;+vdc_sta        ; write byte to vram
    sta vdc_data
    sec
    lda .vramLeft
    sbc #1
    sta .vramLeft
    bcs +
    dec .vramLeft+1
    bpl + ; high byte positive, continue copy

    ; high byte below zero, screen is full
    sec             ; both zero
    rts ; return

+   dec zp_visibleLength
    bne -
    dec zp_visibleLength+1
    bpl -   ; bpl should work here, as it would only break with lines longer than 32768 chars

.rtvDone
    ; came across a linebreak
    ldx zp_tempX    ; y holds the nr chars left until line is full
    beq ++   ; if no chars left, leave

-   lda #' '    ; space character
    ;+vdc_sta
    sta vdc_data
    sec
    lda .vramLeft
    sbc #1
    sta .vramLeft
    bcs +
    dec .vramLeft+1
    bpl + ; high byte positive, continue copy

    sec
    rts

+   dec zp_tempX    ; one character written
    bne -           ; if none left, leave

    clc
    lda zp_vram_content_addr
    adc zp_tempX
    sta zp_vram_content_addr
    bcc ++
    inc zp_vram_content_addr+1

++  clc
    rts

copyLineToVram
    ; vram target
    jsr AY_to_vdc_regs_18_19
    ldx #31 ; VRAM register
    stx vdc_reg

    lda #80
    sta .vramLeft
    lda #0
    sta .vramLeft+1

    ; now read from linkpointertable and write to vram
    jmp .copyTLineToVram

key
-   jsr k_getin
    beq -
    rts


.vramLeft               !word 0
.linesLeftToCopy        !word 0     ; related to copying from ram to vram. if this is > 0, we have more data to show

