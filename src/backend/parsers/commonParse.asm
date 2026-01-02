
initParser
    jsr initContentAddress

    jsr initParseVram   ; this should be called when copying to vram, not here

    ; setup indirect reading from bank 1
    lda #zp_contentAddress
    sta c_fetch_zp

    ; setup indirect writing to bank 1
    lda #zp_linkTablePosition
    sta c_stash_zp

    lda zp_responseSize
    sta leftToParse
    lda zp_responseSize+1
    sta leftToParse+1

clearLinkTable
; this clears 8x256 bytes

    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank

    ldy #0
-   lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    sta (zp_linkTablePosition),y
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    inc zp_linkTablePosition+1
    sta (zp_linkTablePosition),y
    ;lda #0
    ;ldx zp_contentBank
    ;jsr c_stash
    
    jsr initLinkTableAddress
    iny
    bne -

    jmp initLinkTableAddress

initParseVram
    ; first entry is always zero
    lda #0
    sta vram_block_offsets
    sta vram_block_offsets+1
    sta zp_vramBlock

    ldx #13
-   sta vram_block_offsets,x
    dex
    bpl -

    rts

vramBlockIndexIntoX
    lda zp_vramBlock
    asl
    tax
    rts

writeToLinkTable
;    ldx zp_contentBank
    ; y must be set accordingly at this point
;    jsr c_stash
    sta (zp_linkTablePosition),y
    inc zp_linkTablePosition
    bne +
    inc zp_linkTablePosition+1

+   rts

readNextByte
    ; read from bank 1
    ldx zp_contentBank
    ldy #0
    jsr c_fetch         ; read from bank 1
    
    sta zp_tempA
    pha

    inc zp_contentAddress
    bne +
    inc zp_contentAddress+1

+   lda #>CONTENT_END_ADDRESS
    cmp zp_contentAddress+1
    bcs +

    lda #<CONTENT_END_ADDRESS
    cmp zp_contentAddress
    bcs +
    jmp .reachedEof

    ; might make more sense to check leftToParse outside of this
    ;  because after we return, we check for crlf, which might be
    ;  the last characters here, but we set the carry flag and then that check is skipped
    ;  so we have some kind of redundancy here. but maybe it's ok. so, in case of weird trouble
    ;  related to end of files (too soon, too late), this might be an option to change.
+   sec
    lda leftToParse
    sbc #1
    sta leftToParse
    bcs +
    dec leftToParse+1

;    .checkEof
+   lda leftToParse+1
    bne +
    lda leftToParse
    bne +

    nop
    nop
    nop

.reachedEof
    sec ; set carry means we reached end of file
    pla
    rts

+   clc ; clear carry means we still have data left
    pla
    rts

leftToParse     !word 0
