!zone contentFromDisk

loadInitialPageFromDisk
    jsr setParamsForGopherPage

    lda #$93 ; clear screen
    jsr bsout

    jsr initContentAddress

    lda #0
    sta zp_responseSize
    sta zp_responseSize+1

    lda #<diskHost
    sta zp_currentHostPtr
    lda #>diskHost
    sta zp_currentHostPtr+1

    lda #<diskPort; $ba ;186, contains current drive number
    sta zp_currentPortPtr
    lda #>diskPort
    sta zp_currentPortPtr+1

    lda #<selectorContent
    sta zp_currentSelectorPtr
    lda #>selectorContent
    sta zp_currentSelectorPtr+1
    jsr setFromHistory

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