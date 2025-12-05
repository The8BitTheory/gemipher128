!zone networkWic
wic64_include_load_and_run = 0
wic64_include_enter_portal = 0
wic64_optimize_for_size = 0

!src "src/wic64/wic64.h"

setInitialGopherHostSelector
    lda #$31
    sta zp_currentType
    sta zp_pageType

    lda #0
    sta zp_scrollModeCrsr

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
    jmp  ++

setBkm1GopherHostSelector
    ldx #0
    lda mmuBankConfig,x
    sta zp_hostSelBank

    lda #$31
    sta zp_currentType
    sta zp_pageType

    lda #0
    sta zp_scrollModeCrsr
    
    lda #0
    sta zp_navModeHistory

    lda #<bkm1Server
    sta zp_currentHostPtr
    lda #>bkm1Server
    sta zp_currentHostPtr+1

    lda #<startPort
    sta zp_currentPortPtr
    lda #>startPort
    sta zp_currentPortPtr+1

    lda #<bkm1Selector
    sta zp_currentSelectorPtr
    lda #>bkm1Selector
    sta zp_currentSelectorPtr+1

    rts

setBkm2GopherHostSelector
    ldx #0
    lda mmuBankConfig,x
    sta zp_hostSelBank

    lda #$30
    sta zp_currentType
    sta zp_pageType

    lda #1
    sta zp_scrollModeCrsr

    lda #0
    sta zp_navModeHistory

    lda #<bkm2Server
    sta zp_currentHostPtr
    lda #>bkm2Server
    sta zp_currentHostPtr+1

    lda #<startPort
    sta zp_currentPortPtr
    lda #>startPort
    sta zp_currentPortPtr+1

    lda #<bkm2Selector
    sta zp_currentSelectorPtr
    lda #>bkm2Selector
    sta zp_currentSelectorPtr+1

    rts

setNewGopherHostSelector
;    jsr pushToHistoryStack ; here we'll need to write cursor position and stuff to history

    lda zp_navModeHistory
    beq setFromHistory
; we're navigating from a content entry
; pointers go to bank 1

    ldx #1
    lda mmuBankConfig,x
    sta zp_hostSelBank
    jmp ++

; we're navigating from a history entry
; pointers go to bank 0
setFromHistory
    ldx #0
    lda mmuBankConfig,x
    sta zp_hostSelBank
    
++  ldy #0
    sty tcpOpenSizeL
    sty tcpWriteSizeL
    sty tcpOpenSizeH
    sty tcpWriteSizeH
    sty zp_tempX

    lda #zp_currentHostPtr
    sta c_fetch_zp

-   ldx zp_hostSelBank
    jsr c_fetch
    cmp #9
    beq +
    ldx zp_tempX
    sta tcpOpenHostPort,x
    inc zp_tempX
    jsr .incOpenSize
    jmp -

+   lda #':'
    ldx zp_tempX
    sta tcpOpenHostPort,x
    inc zp_tempX
    jsr .incOpenSize

    ldy #0
    lda #zp_currentPortPtr
    sta c_fetch_zp

-   ldx zp_hostSelBank
    jsr c_fetch
    cmp #$0d
    beq +
    ldx zp_tempX
    sta tcpOpenHostPort,x
    inc zp_tempX
    jsr .incOpenSize
    jmp -

+   ldy #0
    sty zp_tempX
    lda #zp_currentSelectorPtr
    sta c_fetch_zp

-   ldx zp_hostSelBank
    jsr c_fetch
    cmp #9
    beq +
    ldx zp_tempX
    sta tcpWriteSelector,x
    inc zp_tempX
    iny
    jsr .incWriteSize
    jmp -

+   ldx zp_tempX
    lda #$0d
    sta tcpWriteSelector,x
    jsr .incWriteSize
    inx
    lda #$0a
    sta tcpWriteSelector,x

.incWriteSize
    inc tcpWriteSizeL
    bne +
    inc tcpWriteSizeH
+   rts

.incOpenSize
    iny
    inc tcpOpenSizeL
    bne +
    inc tcpOpenSizeH
+   rts

detectAndInitializeWic64
    +print txtDetect
    +wic64_detect
    +print txtDone
    bcc +
    jmp .noWicDetected
+   beq +
    jmp .legacyFirmware
+   +wic64_set_error_handler .handleWic64Error
    +print txtConnected
    +wic64_execute wic64IsConnected, connectResponse, 10
    bcs .connTimeout
    bne .notConnected

    +print txtDone
    rts

.connTimeout
    +print txtTimeout
    rts

.notConnected
    +print txtNotConnected
    rts

.noWicDetected
    jsr k_primm
    !text "No WiC64 detected!",$d,0
    rts

.legacyFirmware
    jsr k_primm
    !text "Firmware too old!",$d,0
    
    rts

.handleWic64Error
    bcc +
    +wic64_execute wic64GetStMsg, statusResponse
    jmp .connTimeout
+   rts

requestContent
    sec
    lda #<LINKTABLE_ADDRESS
    sbc #<CONTENT_ADDRESS
    sta .ramLeft
    lda #>LINKTABLE_ADDRESS
    sbc #>CONTENT_ADDRESS
    sta .ramLeft+1
    

    lda #$93 ; clear screen
    jsr bsout

    jsr initContentAddress
    
    lda #0
    sta zp_responseSize
    sta zp_responseSize+1
    sta zp_tempY    ;we'll use this as a retry counter (256 times)

    +wic64_execute wic64TransferTimeout
    +wic64_execute wic64RemoteTimeout

    +print txtTcpOpen
    +wic64_execute tcpOpen, openResponse, 5
    bcc +
    jmp .connTimeout

+   +print txtDone
    +print txtTcpWrite
    +wic64_execute tcpWrite, writeResponse, 5
    bcc +
    jmp .connTimeout
+   +print txtDone

.waitForIncomingData
    lda #'.'
    jsr bsout
    +wic64_execute tcpAvailable, availableResponse, 5
    lda availableResponse
    bne +
    lda availableResponse+1
    bne +
    dec zp_tempY
    bne .waitForIncomingData
    jmp .allResponseRead

+   lda availableResponse
    sta zp_contentLength
    lda availableResponse+1
    sta zp_contentLength+1

    lda #$d
    jsr bsout

    lda #'$'
    jsr bsout

    lda zp_contentLength+1
    lsr
    lsr
    lsr
    lsr 
    jsr .makeItHex
    jsr bsout
    
    lda zp_contentLength+1
    jsr .makeItHex
    jsr bsout

    lda zp_contentLength
    lsr
    lsr
    lsr
    lsr
    jsr .makeItHex
    jsr bsout
    
    lda zp_contentLength
    jsr .makeItHex
    jsr bsout

    lda #$d
    jsr bsout

    +print txtTcpRead
.readResponsePart
    ldy #0
    sty zp_tempY
    +wic64_execute tcpRead, response, 5
    bcc +
    jmp .connTimeout
+   lda #'o'
    jsr bsout
    lda wic64_bytes_to_transfer
    sta packBytes
    jsr .storeInPerm
    bcc .handleResponse
    jmp .allResponseRead  ; if carry flag is set, we're out of RAM and stop reading
    
.handleResponse
    +wic64_execute tcpAvailable, availableResponse, 5
    lda availableResponse
    bne .readResponsePart
    lda availableResponse+1
    bne .readResponsePart

    dec zp_tempY
    ;bne .handleResponse
    bne .readResponsePart

    jmp .allResponseRead

.storeInPerm
    ; setup for indsta
    lda #zp_contentAddress
    sta c_stash_zp

    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank

    ldy #0
    sty zp_tempX

-   ldx zp_tempX
    lda response,x

; begin store in bank 1
    ldx zp_contentBank
    jsr c_stash
; end store in bank 1
    
    inc zp_tempX
    iny
    dec packBytes
    bne -

    clc
    tya
    adc zp_contentAddress
    sta zp_contentAddress
    bcc +
    inc zp_contentAddress+1

; check if we reached the end of available RAM
+   lda #>LINKTABLE_ADDRESS
    cmp zp_contentAddress+1
    bcs +
    lda #<LINKTABLE_ADDRESS
    cmp zp_contentAddress
    bcs +
    
    sec
    rts

+   clc
    tya
    adc zp_responseSize
    sta zp_responseSize
    bcc +
    inc zp_responseSize+1

+   clc
    rts

.makeItHex
    and #%00001111

    clc
    cmp #10
    bpl +
    adc #$30
    rts

+   adc #54
    rts

.storeInBank1    
    rts

.allResponseRead
    lda #$0d
    jsr bsout

    lda #'$'
    jsr bsout

    lda zp_responseSize+1
    lsr
    lsr
    lsr
    lsr 
    jsr .makeItHex
    jsr bsout
    
    lda zp_responseSize+1
    jsr .makeItHex
    jsr bsout

    lda zp_responseSize
    lsr
    lsr
    lsr
    lsr
    jsr .makeItHex
    jsr bsout
    
    lda zp_responseSize
    jsr .makeItHex
    jsr bsout

    lda #$d
    jsr bsout


.closeConnection
    +print txtTcpClose
    +wic64_execute tcpClose, response
    +print txtDone
    rts

.ramLeft            !word 0

txtDetect           !text "Detecting WiC64... ",0
txtConnected        !text "Check WiC64 is connected ...",0
txtTimeout          !text "timeout",$d,0
txtNotConnected     !text "not connected",$d,0
txtTcpOpen          !text "TCP Connection open... ",0
txtTcpRead          !text "TCP Read... ",0
txtTcpWrite         !text "TCP Write... ",0
txtTcpClose         !text "TCP Close... ", 0
txtTcpAvlbl         !text "TCP Available... ",0
txtDone             !text "done",$d,0

tcpOpen             !byte "R", WIC64_TCP_OPEN
tcpOpenSizeL        !byte 0
tcpOpenSizeH        !byte 0
tcpOpenHostPort     !fill 256

tcpAvailable        !byte "R", WIC64_TCP_AVAILABLE, $00, $00
tcpRead             !byte "R", WIC64_TCP_READ, $00, $00

tcpWrite            !byte "R", WIC64_TCP_WRITE
tcpWriteSizeL       !byte 0
tcpWriteSizeH       !byte 0
tcpWriteSelector    !fill 256

tcpClose            !byte "R", WIC64_TCP_CLOSE, $00, $00

wic64IsConnected    !byte "R", WIC64_IS_CONNECTED, $01, $00, 5

wic64GetStMsg       !byte "R", WIC64_GET_STATUS_MESSAGE, $01, $00, 0
wic64TransferTimeout !byte "R", WIC64_SET_TRANSFER_TIMEOUT, $01, $00, 5
wic64RemoteTimeout  !byte "R", WIC64_SET_REMOTE_TIMEOUT, $01, $00, 10

availableResponse   !word 0
writeResponse       !word 0
openResponse        !word 0

packBytes           !byte 0     ; remaining bytes in this data package (240 bytes each, afaik)
connectResponse     !byte 0
statusResponse      !fill 40

response            !fill 256

startGopher         !text "gopher.floodgap.com",$9
;startGopher         !text "gopher.quux.org",$9
startPort           !text "70\r\n"
startSelector       !text "\r\n",$9

bkm1Server          !text "gopher.floodgap.com",$9
bkm1Selector        !text "/archive/info-mac/game",$9
bkm1Type            !byte $31

bkm2Server          !text "gopher.floodgap.com",$9
bkm2Selector        !text "/archive/info-mac/help/mirror-list.txt", $9
bkm2Type            !byte $30
