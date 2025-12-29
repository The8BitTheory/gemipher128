; this is about creating an information page
;  usually for timeouts due to an invalid address or an unavailable host or an unsupported filetype

; it contains a message showing the reason for this page being showed
; it displays the address that was tried to be loaded
; in case of error: show options like re-try, goto home, goto start, exit
; in case of an unsupported page type, show a qr-code of this address (especially for images, www-links, etc.)

; audio pagetypes are supposed to leverage on the wic64mex. not sure yet if the qr-code for that
;  should be shown here or if we create a dedicated asm file for this.

; as a result, this should be in memory just like a gopher page.

; The address you entered is not 

!macro writeToBank1 .nullTerminatedGopherLine {
    ldx #0
    stx zp_tempX
-   ldx zp_tempX
    lda .nullTerminatedGopherLine,x
    beq +
    jsr storeInfopageInBank1
    inc zp_tempX
    jmp -

+   
}

!macro writeLnToBank1 .nullTerminatedGopherLine {
    ldx #0
    stx zp_tempX
-   ldx zp_tempX
    lda .nullTerminatedGopherLine,x
    beq +
    jsr storeInfopageInBank1
    inc zp_tempX
    jmp -

+   inc zp_linecount
}


.initInfoPage
    lda #0
    sta zp_linecount
    sta zp_linecount+1
    jsr initRamLeft
    jsr initContentAddress
    lda #zp_contentAddress
    sta c_stash_zp
    rts

createSoundPage
    jsr writeCurrentGopherToHeadline
    
    jsr doSlow
    +wic64_reset_store_instruction
    ; create wic64mex json with url of file to play
    jsr wic64mexRequest
    bcc +
    jmp .endCreateSoundPage


+   jsr doFast
    jsr .initInfoPage
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtSound0

    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtSound1
    +writeLnToBank1 .txtSound2

    +writeLnToBank1 .txtEmptyLine

+   +writeToBank1 .txtSoundUrl
    +writeToBank1 mexServer
    +writeToBank1 mexUrlJoin
    +writeToBank1 mexJoinCode
    +writeLnToBank1 txtTrail
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtDot

    lda #'s'
    sta zp_currentType

.endCreateSoundPage
    rts

playbackCurrentAudio
    jsr wic64_reset_store_instruction
    jsr createMexUrl
    
    ldx #0
-   lda mexUrlPlay,x
    beq +
    sta httpGetUrl,y
    inx
    iny
    jmp -

; skip https
+   ldx #0
-   lda mexSessionId,x
    beq +
    sta httpGetUrl,y
    inx
    iny
    jmp -

+   lda #'/'
    sta httpGetUrl,y

    iny
    lda #$30
    sta httpGetUrl,y

    iny
    lda #$30
    sta httpGetUrl,y

    iny
;    lda #0
;    sta httpGetUrl,y

    sty httpGetSizeL
    jsr doSlow
    +wic64_execute httpGetCmd, response
    jsr doFast
    lda response
    beq +
    
    clc
    adc #$30
    +print .txtStatus
    jsr bsout
    lda #$0d
    jsr bsout

+   jmp getUserInput

mexConnectionCheck
    jsr wic64_reset_store_instruction
    jsr createMexUrl
    
    ldx #0
-   lda mexUrlCheck,x
    beq +
    sta httpGetUrl,y
    inx
    iny
    jmp -


+   ldx #0
-   lda mexSessionId,x
    beq +
    sta httpGetUrl,y
    inx
    iny
    jmp -

+   sty httpGetSizeL
    jsr doSlow
    +wic64_execute httpGetCmd, response
    jsr doFast
    lda response
    beq +
    
    clc
    adc #$30
    +print .txtConnectionstatus
    jsr bsout
    lda #$0d
    jsr bsout

+   jmp getUserInput

createUnsupportedPage
    jsr .initInfoPage
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtUnsupported
    
    ; write the filename, which is the part after the last / of the selector

    ; first, find the last /
    ;  set indfet pointer
    lda #zp_currentSelectorPtr
    sta c_fetch_zp

    ldy #0
-   ldx zp_contentBank
    jsr c_fetch
    cmp #$09    ; tab ends the selector string
    beq .writeFilename
    cmp #'/'
    bne +   ; no /, go to next line
    sty .slashPos   ; store current position as slashPos
+   iny
    jmp -

.writeFilename
    lda #$69
    jsr storeInfopageInBank1

    ldy .slashPos
    sty zp_tempY
-   ldy zp_tempY
    ldx zp_contentBank
    jsr c_fetch
    cmp #$09
    beq .writeRemainingLines
    jsr storeInfopageInBank1
    inc zp_tempY
    jmp -

.writeRemainingLines
    +writeLnToBank1 txtTrail
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtOptionG
    +writeLnToBank1 .txtOptionH
    +writeLnToBank1 .txtOptionS
    +writeLnToBank1 .txtOptionX
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtDot

    rts

createTimeoutPage
    jsr .initInfoPage
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtTimeout0
    
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtTimeout1
    +writeLnToBank1 .txtTimeout2
     
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtKeyOptions
    +writeLnToBank1 .txtTimeoutR
    +writeLnToBank1 .txtOptionCrsr
    +writeLnToBank1 .txtOptionG
    +writeLnToBank1 .txtOptionH
    +writeLnToBank1 .txtOptionS
    +writeLnToBank1 .txtOptionX
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtEmptyLine
    +writeLnToBank1 .txtDot

    rts

; this is used to create a gopher-dir on-the-fly
storeInfopageInBank1
    ldy #0
    ldx zp_contentBank
    jsr c_stash

    inc zp_contentAddress
    bne +
    inc zp_contentAddress+1
    
+   inc zp_responseSize
    bne +
    inc zp_responseSize+1

+   rts

.slashPos       !byte 0

.txtDot         !text ".",$0d,$0a,$0
.txtUnsupported !text "iThis content can't be displayed.",$09," ",$09," ",$09," ",$0d,$0a,$0

.txtSound0      !text "iThis sound file can't be played back on the C128.",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtSound1      !text "iScan this QR-Code to play it using the WiC64-Media-Extension",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtSound2      !text "i Playback will be done through the browser on your mobile phone or tablet",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtSoundUrl    !text "i URL: ",0

txtTrail       !text $09," ",$09," ",$09," ",$0d,$0a,$0

.txtEmptyLine !text "i",$09," ",$09," ",$09," ",$0d,$0a,$0

.txtTimeout0    !text "iThis page couldn't be loaded.",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeout1    !text "iPlease check if the address is correct",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeout2    !text "iIf it is, the host might be unavailable temporary",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtKeyOptions  !text "iYou can press the following keys to continue",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutR    !text "iR - Reload page",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtOptionG    !text "iG - Go to a new address",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtOptionH    !text "iH - Go to gopher.floodgap.com",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtOptionS    !text "iS - Go to startpage",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtOptionX    !text "iX - Exit to Basic",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtOptionCrsr !text "iCursor left to go back in history",$09," ",$09," ",$09," ",$0d,$0a,$0

.txtStatus      !text "Statuscode: ",0
.txtConnectionstatus    !text "Connectionstatus (0=ok, 1=error/invalid session, 2=no browser connected): ",0

