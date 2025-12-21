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
    jsr .initInfoPage
    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtSound0

    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtSound1
    +writeToBank1 .txtSound2

    +writeToBank1 .txtEmptyLine
    
    ; create wic64mex json with url of file to play

    jsr wic64mexRequest

    +writeToBank1 .txtSoundUrl
    +writeToBank1 mexServer
    +writeToBank1 mexUrlJoin
    +writeToBank1 mexJoinCode
    +writeToBank1 .txtTrail


    lda #$31
    sta zp_currentType

    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtDot

    rts

createUnsupportedPage
    jsr .initInfoPage
    +writeToBank1 .txtUnsupported
    rts

createTimeoutPage
    jsr .initInfoPage
    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtTimeout0
    
    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtTimeout1
    +writeToBank1 .txtTimeout2
     
    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtTimeout3
    +writeToBank1 .txtTimeoutR
    +writeToBank1 .txtTimeoutG
    +writeToBank1 .txtTimeoutH
    +writeToBank1 .txtTimeoutS
    +writeToBank1 .txtTimeoutX
    +writeToBank1 .txtTimeoutCrsr
    +writeToBank1 .txtEmptyLine
    +writeToBank1 .txtEmptyLine

    rts

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

.txtDot         !text ".",$0d,$0a,$0
.txtUnsupported !text "iThis content can't be displayed.",$09," ",$09," ",$09," ",$0d,$0a,$0

.txtSound0      !text "iThis sound file can't be played back on the C128.",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtSound1      !text "iScan this QR-Code to play it using the WiC64-Media-Extension",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtSound2      !text "i Playback will be done through the browser on your mobile phone or tablet",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtSoundUrl    !text "i URL: "

.txtTrail       !text $09," ",$09," ",$09," ",$0d,$0a,$0

.txtEmptyLine !text "i",$09," ",$09," ",$09," ",$0d,$0a,$0

.txtTimeout0    !text "iThis page couldn't be loaded.",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeout1    !text "iPlease check if the address is correct",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeout2    !text "iIf it is, the host might be unavailable temporary",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeout3    !text "iYou can press the following keys to continue",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutR    !text "iR - Reload page",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutG    !text "iG - Go to a new address",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutH    !text "iH - Go to gopher.floodgap.com",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutS    !text "iS - Go to startpage",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutX    !text "iX - Exit to Basic",$09," ",$09," ",$09," ",$0d,$0a,$0
.txtTimeoutCrsr !text "iCursor left to go back in history",$09," ",$09," ",$09," ",$0d,$0a,$0
