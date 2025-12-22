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

    lda #<homeGopher
    sta zp_currentHostPtr
    lda #>homeGopher
    sta zp_currentHostPtr+1

    lda #<homePort
    sta zp_currentPortPtr
    lda #>homePort
    sta zp_currentPortPtr+1

    lda #<homeSelector
    sta zp_currentSelectorPtr
    lda #>homeSelector
    sta zp_currentSelectorPtr+1

    ldx #0
    lda mmuBankConfig,x
    sta zp_hostSelBank
    rts

ramLeft            !word 0