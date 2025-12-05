
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
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash

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

+   lda #>LINKTABLE_ADDRESS
    cmp zp_contentAddress+1
    bcs +

    lda #<LINKTABLE_ADDRESS
    cmp zp_contentAddress
    bcs +
    jmp .reachedEof

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
