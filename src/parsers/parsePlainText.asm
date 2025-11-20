; parsing plain text files should be easy.
; just copy to vram and respect line breaks
; the fun part is the memory management
; I want text files to be displayed like gopher pages, just consisting of Info lines
; text files don't contain back-links by themselves
; so this is when we need to start thinking about a back button
; and much more about handling a history stack
; pushing the back button should display the last visible page with the cursor at the position where we left

!zone plainText
parsePlainText
    jsr initContentAddress

    ; setup indirect reading from bank 1
    lda #zp_contentAddress
    sta c_fetch_zp

    ; setup indirect writing to bank 1
    lda #zp_linkTablePosition
    sta c_stash_zp

; based on response-size, we can decide whether to overwrite the previous data, or keep it
    lda zp_responseSize
    sta .leftToParse
    lda zp_responseSize+1
    sta .leftToParse+1

    lda #0
    sta zp_visibleLength
    sta zp_linecount

; content is stored in the $1:0400 region, pointers to each line in the $1:f700 region
; each line takes 3 bytes in the linktable. 2 bytes for pointer, 1 byte for line length
; this also allows us to make word-wrap a user-choice

.parseLine
    jsr .storePointerInLinkTable

-   jsr .readNextByte
    bcs .doneParse
    cmp #$0d    ;line break?
    bne +
    jsr .readNextByte
    cmp #$0a
    beq .finishLine
+   inc zp_visibleLength
    jmp -

.finishLine
    inc zp_linecount
    bne +
    inc zp_linecount+1
    
+   lda zp_visibleLength
    jsr .storeValueInLinkTable
    lda #0
    sta zp_visibleLength
    jmp .parseLine

.doneParse
    rts
    nop

.readNextByte
    ; read from bank 1
    ldx zp_contentBank
    ldy #0
    jsr c_fetch
    pha

    inc zp_contentAddress
    bne +
    inc zp_contentAddress+1

+   dec .leftToParse
    bne +
    dec .leftToParse+1

;    .checkEof
+   lda .leftToParse
    bne +
    lda .leftToParse+1
    bne +
    sec ; set carry means we reached end of file
    pla
    rts

+   clc ; clear carry means we still have data left
    pla
    rts

.storeValueInLinkTable
    ldy #0
    jsr .stashToLinkTable
    rts

.storePointerInLinkTable
    ldy #0
    lda zp_contentAddress
    jsr .stashToLinkTable
    lda zp_contentAddress+1
    jsr .stashToLinkTable

+   rts


.stashToLinkTable
    ldx zp_contentBank
    ; y must be set accordingly at this point
    jsr c_stash
    inc zp_linkTablePosition
    bne +
    inc zp_linkTablePosition+1

+   rts

.leftToParse    !word 0
