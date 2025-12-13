!zone networkCommon
setParamsForGopherPage
    lda #$31
    sta zp_currentType
    sta zp_pageType

    lda #0
    sta zp_scrollModeCrsr
    rts

setInitialGopherHostSelectorCommon
    jsr setParamsForGopherPage

    lda #<startGopher
    sta zp_currentHostPtr
    lda #>startGopher
    sta zp_currentHostPtr+1

    lda #<startPort
    sta zp_currentPortPtr
    lda #>startPort
    sta zp_currentPortPtr+1

    lda #<startSelector
    sta zp_currentSelectorPtr
    lda #>startSelector
    sta zp_currentSelectorPtr+1

    ldx #0
    lda mmuBankConfig,x
    sta zp_hostSelBank
    rts

ramLeft            !word 0