
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


vramBlockIndexIntoX
    lda zp_vramBlock
    asl
    tax
    rts

