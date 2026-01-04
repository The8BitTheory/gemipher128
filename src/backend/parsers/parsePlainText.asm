; displaying plain text will be handled differently from gopher dirs.
; the downloaded content should be prepared as lines of 80 characters each.
; if a line is shorter, it will be filled with spaces.
; it is copied to vram backbuffer that way.
; viewing plain text should just be a matter of copying the amount of visible lines
; to the frontbuffer.
; we'll still need the linkpointer table for the textfile in it's original downloaded format,
; but I think we won't need to keep vram pointers in the same way as for Gopher dirs.
; the linedefinition from the textfile will not be taken into the linkpointer table.
; lines longer than 80 characters will have multiple entries in the linkpointer table.

; this routine only deals with ram (not vram, etc)

!zone plainText
parsePlainText
    +print txtParsing
    jsr initParser

    lda #0
    sta zp_visibleLength
    sta zp_visibleLength+1
    sta zp_linecount
    sta zp_linecount+1
    sta .lineLength
    sta charsSinceSpace

    
; content is stored in the $1:0400 region, pointers to each line in the $1:f700 region
; each line takes 3 bytes in the linktable. 2 bytes for pointer, 1 byte for line length
; this also allows us to make word-wrap a user-choice

.parseLine
    jsr .storePointerInTxtLinkTable
    lda #0
    sta charsSinceSpace

-   jsr readNextByte
    bcs .finishLineWithBreak
    cmp #' '            ; if this is a space character, we reset the counter
    bne +
    sty charsSinceSpace ; y should be zero because it was set in readNextByte
+   inc charsSinceSpace
    
    cmp #$0d    ;line break?
    beq -
    cmp #$0a    ; other line break
    beq .finishLineWithBreak

    inc zp_visibleLength
    inc .lineLength
    lda .lineLength
    cmp #80
    beq .finishLine

    jmp -

.finishLine
    ; when a line is running over, let's check if we're wrapping the word correctly
    ; if the following character is not a space character, it means we split a word
    jsr readNextByteWithoutInc
    cmp #' '    ; space
    bne +
    ; if space: wrap was luckily good. we can skip the space (would indent the next line otherwise)
    jsr readNextByte
    jmp .finishLineWithBreak

    ; if no space: find previous space and wrap to new line from there
    ; first, reduce line length so it only goes until last space
+   sec
    lda .lineLength
    sbc charsSinceSpace
    sta .lineLength
    ; next, reset out read pointer to after the last space

    dec charsSinceSpace
    sec
    lda zp_contentAddress
    sbc charsSinceSpace
    sta zp_contentAddress
    lda zp_contentAddress+1
    sbc #0
    sta zp_contentAddress+1

.finishLineWithBreak
    inc zp_linecount
    bne +
    inc zp_linecount+1
    
+   lda .lineLength
    jsr .storeValueInTxtLinkTable
    lda #0;zp_visibleLength+1
    jsr .storeValueInTxtLinkTable
    lda #0
    sta zp_visibleLength
    sta zp_visibleLength+1
    sta .lineLength
    sta charsSinceSpace

    lda leftToParse+1
    bne .parseLine
    lda leftToParse
    bne .parseLine

.doneParse
    jsr .storePointerInTxtLinkTable
    lda zp_visibleLength
    jmp .storeValueInTxtLinkTable
    lda zp_visibleLength+1
    jmp .storeValueInTxtLinkTable


.storeValues
    lda zp_contentAddress
    sta .temp4
    lda zp_contentAddress+1
    sta .temp4+1
    lda leftToParse
    sta .temp4+2
    lda leftToParse+1
    sta .temp4+3
    rts

.recoverValues
    lda .temp4
    sta zp_contentAddress
    lda .temp4+1
    sta zp_contentAddress+1
    lda .temp4+2
    sta leftToParse
    lda .temp4+3
    sta leftToParse+1
    rts

.checkEndChar
; store values for if we're not at the end
    lda zp_contentAddress
    sta .temp4
    lda zp_contentAddress+1
    sta .temp4+1
    lda leftToParse
    sta .temp4+2
    lda leftToParse+1
    sta .temp4+3

    jsr readNextByte
    cmp #'.'
    bne +

    jmp .doneParse  ;if we find a single dot on a line, this is the end of the file



.storeValueInTxtLinkTable
    ldy #0
    jsr writeToLinkTable
    rts

.storePointerInTxtLinkTable
    ldy #0
    lda zp_contentAddress

    jsr writeToLinkTable
    lda zp_contentAddress+1

    jsr writeToLinkTable

    rts


.stashToTxtLinkTable
    ldx zp_contentBank
    ; y must be set accordingly at this point
    jsr c_stash
    inc zp_linkTablePosition
    bne +
    inc zp_linkTablePosition+1

+   rts

.temp4          !word 0,0
.lineLength     !byte 0     ; used to keep track of 80 chars max per line
