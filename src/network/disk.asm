!zone contentFromDisk

loadInitialPageFromDisk
    jsr setParamsForGopherPage

    lda #$93 ; clear screen
    jsr bsout

    jsr initContentAddress

    lda #0
    sta zp_responseSize
    sta zp_responseSize+1

    jsr loadContentFromDisk

    lda $ae
    sta zp_contentAddress
    lda $af
    sta zp_contentAddress+1

    sec
    lda zp_contentAddress
    sbc #<CONTENT_ADDRESS
    sta zp_contentLength
    sta zp_responseSize
    lda zp_contentAddress+1
    sbc #>CONTENT_ADDRESS
    sta zp_contentLength+1
    sta zp_responseSize+1

    sec
    lda #<CONTENT_END_ADDRESS
    sbc zp_contentAddress
    sta .ramLeft
    lda #>CONTENT_END_ADDRESS
    sbc zp_contentAddress+1
    sta .ramLeft+1

    lda #1
    sta zp_navModeHistory
    rts

.ramLeft    !word 0