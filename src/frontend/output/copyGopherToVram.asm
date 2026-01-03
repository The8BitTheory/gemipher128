; this is responsible for copying the visible content to vram (a part that's not visible on screen)
; in contrast to the content area in bank 1, this
; - is in screencode, not in ascii format
; - only contains visible text. no type, no selector, no host, no port. these stay in bank 1
; - all visible lines are copied via block copy to the visible screen area

; vram memory map
; $0000-$07ff screen ram
; $0800-$0fff attribute ram
; $1000-$2fff invisible content area (we're copying to this area) - 8 kB available in a 16 kB VRAM setup
; $3000-$3fff character set (uppercase/lowercase)


!zone gopherRamToVram

copyGopherToVram
    lda #0
    sta zp_firstVramContentLine
    sta zp_firstVramContentLine+1
    sta zp_lastVramContentLine
    sta zp_lastVramContentLine+1

    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
    jsr initLinkTableAddress

    ; lines left to copy needs to be set accordingly
    sec
    lda zp_linecount
    sbc zp_linenumber_start
    sta .linesLeftToCopy
    lda zp_linecount+1
    sbc zp_linenumber_start+1
    sta .linesLeftToCopy+1

    ;lda size_vram_content
    lda #$30
    sta .vramLeft
    ;lda size_vram_content+1
    lda #$07
    sta .vramLeft+1

    ; write to vram from the start
    lda #81
    sta zp_vram_content_addr
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
-   jsr .copyGLineToVram
    bcs +

    jsr incLineNumber

    dec .linesLeftToCopy
    bne -
    dec .linesLeftToCopy+1
    bpl -

+   rts

.copyGLineToVram
    ldy #0
    sty .lineLength

    lda (zp_linkTablePosition),y
    sta zp_currentType
    bne +
    ldx #80
    stx zp_tempX
    jmp .rtvDone

+   iny
    
    lda (zp_linkTablePosition),y
    sta zp_currentLinkTablePtr  ;replace with zp_memptr?
    iny

    lda (zp_linkTablePosition),y
    sta zp_currentLinkTablePtr+1    ;replace with zp_memptr?
    iny

    lda (zp_linkTablePosition),y
    sta zp_visibleLength

    lda #zp_currentLinkTablePtr
    sta c_fetch_zp
    

; copy RAM to VRAM
    ldx #80
    stx zp_tempX    ; lines can be 79 chars max at this point, parsing made sure of this
    ldy #0
    sty zp_tempY    ; read index for the current screenline
    
-   ldy zp_tempY
    ldx zp_contentBank
    jsr c_fetch
    sta zp_tempA
    inc zp_tempY
    jsr checkAsciiUtf8
    bcs -

    cmp #9
    beq .rtvDone
    ;iny
    dec zp_tempX
    jsr toScreencode

; write content byte to VRAM
    +vdc_sta        ; write byte to vram
    inc .lineLength
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
    ; came across a linebreak
    ldx zp_tempX    ; y holds the nr chars left until line is full
    beq ++   ; if no chars left, leave

-   lda #' '    ; space character
    +vdc_sta
    ;sta vdc_data
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

copyGLineToVram
    ; vram target
    jsr AY_to_vdc_regs_18_19
    ldx #31 ; VRAM register
    stx vdc_reg

    lda #79
    sta .vramLeft
    lda #0
    sta .vramLeft+1

    ; now read from linkpointertable and write to vram
    jmp .copyGLineToVram



incLineNumber
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



.vramLeft           !word 0
.linesLeftToCopy    !word 0     ; related to copying from ram to vram. if this is > 0, we have more data to show
.lineLength         !byte 0     ; keep track of changes due to utf-8
