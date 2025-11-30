
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

.resetVramLeft
    lda size_vram_content
    sta .parseVramLeft
    lda size_vram_content+1
    sta .parseVramLeft+1

    rts

; decreases remaining vram block size
; if reaches zero, stores the linetablepointer as start of next block
;  and resets the remaining vram size to the initial value
trackVramBlock
    sec
    lda .parseVramLeft
    sbc #1
    sta .parseVramLeft
    bcs +
    dec .parseVramLeft+1
    
+   lda .parseVramLeft+1
    bne +
    lda .parseVramLeft
    bne +

    ; no vram left. write current linktablepointer, increase vramBlock, reset available vram size
    ; calc index for vramblock offsets
    inc zp_vramBlock
    jsr vramBlockIndexIntoX

    lda zp_linecount
    sta vram_block_offsets,x
    lda zp_linecount+1
    sta vram_block_offsets+1,x

    jmp .resetVramLeft

+   rts

vramBlockIndexIntoX
    lda zp_vramBlock
    asl
    tax
    rts

.parseVramLeft          !word 0