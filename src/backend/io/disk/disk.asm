!zone contentFromDisk

loadPageFromDisk
    lda #$93 ; clear screen
    jsr bsout

    jsr initContentAddress

    lda #0
    sta zp_responseSize
    sta zp_responseSize+1

    ; the wic64 expects all parameters as ascii, eg the tcp-port
    ; so, userinput matches the request format
    ; the disk routines, on the other hand, expect numeric values.
    ; device #8 is $38 in text, but $8 in numeric
    ; the zp_current*Ptr variables are also used for filling the address bar when displaying
    ; these are also filled when entering the address manually
    
    ; what is the right place to do the translation from text to numeric devicenr?
    ; also, filename needs to be petscii, not ascii.
    
    ; I guess, whenever something is written to zp_currentHostPtr, we need to check what the
    ; expected loading device is. "device" means: load from disk
    ; So that would be the point to branch between disk and network loading
    ; writing to zp_currentPortPtr would then need to write the numeric value to a separate pointer (read by the loadFromDisk routine)
    ;  LDX $BA       ; last used device number
    ; writing to zp_currentSelectorPtr would then also need to write a petscii string for the loadFromDisk routine.
    ;  LDA #nameContentLength
    ;  LDX #<nameContent
    ;  LDY #>nameContent
    

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

setParamsForLoadingLocalStartPage
    jsr clearAddressHostPortSelector

    ; write startpage to address bar
    ldx #0
-   lda startPageLocal,x
    cmp #$09
    beq .startEntryDone
    jsr writeToAddress
    inx
    jmp -

.startEntryDone
    jsr parseAddress
    jsr setRequestPointersToAddress

    jsr portToDeviceNr
    jsr selectorToFilename
   
    jmp setFromHistory

.ramLeft            !word 0

startPageLocal      !text "device:0/START.GOP",$9
deviceNumber        !byte 0

; these are the values to set the start page
;diskHost        !text "device",$9
;diskPort        !text "8\r\n"

;selectorContent !text "/"
;diskNameContent !pet "start.gop"
;                !byte $9        ;this byte is for displaying the filename on screen like a gopher selector.
                                ; it is irrelevant for loading from disk
