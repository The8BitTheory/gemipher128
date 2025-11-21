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

.VRAM_LEFT = 8000

copyTextToVram
    lda #<.VRAM_LEFT
    sta .vramLeft
    lda #>.VRAM_LEFT
    sta .vramLeft+1

    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
    jsr initLinkTableAddress
    
    lda #<VRAM_CONTENT
    sta zp_vram_content_addr
    lda #>VRAM_CONTENT
    sta zp_vram_content_addr+1

    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    
    jsr AY_to_vdc_regs_18_19
    ldx #31 ; VRAM register
    stx vdc_reg

    ; load type
    ldx zp_linecount
    stx zp_tempX
-   jsr .copyLineToVram
    bcs +

    jsr .incLineNumber

    dec zp_tempX
    bne -

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

    lda #zp_currentLinkTablePtr
    sta c_fetch_zp
    
    jsr .myRtv

    rts
    nop

.myRtv   ; copy RAM to VRAM
    ldy #0
    
-   ldx zp_contentBank
    jsr c_fetch
    cmp #$0d
    beq .rtvDone
    cmp #$0a
    beq .rtvDone
    iny
    beq .rtvDone    ; copy 255 chars max (as a guardrail)

    cmp #65 ;A  
    bmi .rtvWrite       ; < A (so, must be a digit. don't change)

    cmp #97 ;a  ; < a (so, must be an uppercase letter. subtract 64
    bpl +
    sec
    sbc #64
    jmp .rtvWrite

+   cmp #123 ; <z (so, must be a lowercase letter)
    bpl .rtvWrite
    sec
    sbc #32

; write byte to VRAM
.rtvWrite
    +vdc_sta
    dec .vramLeft
    bne +
    dec .vramLeft +1
    bpl +
    sec
    rts
+   dec zp_visibleLength
    bne -

.rtvDone
    clc
    jmp complex_instruction_shared_exit


.incLineNumber
    clc
    lda zp_linkTablePosition
    adc zp_linkTableIncr
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1

+   rts

.vramLeft       !word 0

