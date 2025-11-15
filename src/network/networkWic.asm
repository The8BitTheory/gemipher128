!zone networkWic
wic64_include_load_and_run = 0
wic64_include_enter_portal = 0
wic64_optimize_for_size = 0

!src "src/wic64/wic64.h"

loadGopherPage
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
    jmp .sendRequest

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


.sendRequest
    jsr initContentAddress
    
    lda #0
    sta responseSize
    sta responseSize+1

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
    beq .waitForIncomingData

+   lda #$d
    jsr bsout
    +print txtTcpRead
.readResponsePart
;    inc zp_linecount
    +wic64_execute tcpRead, response, 5
    bcc +
    jmp .connTimeout
+   lda #'o'
    jsr bsout
    lda wic64_bytes_to_transfer
    sta packBytes
    jsr .storeInPerm

;    lda zp_linecount
;    cmp #10
;    beq .allResponseRead
    
.handleResponse
    +wic64_execute tcpAvailable, availableResponse, 5
    lda availableResponse
    bne +
    lda availableResponse+1
    beq ++

+   jmp .readResponsePart
++  jmp .allResponseRead

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

+   clc
    tya
    adc responseSize
    sta responseSize
    bcc +
    inc responseSize+1

+   rts

.storeInBank1

    
    rts

.allResponseRead
    lda #$0d
    jsr bsout

.closeConnection
    +print txtTcpClose
    +wic64_execute tcpClose, response
    +print txtDone
    rts

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

tcpOpen             !byte "R", WIC64_TCP_OPEN, <hostPort_size, >hostPort_size
hostPort            !text "gopher.floodgap.com:70",0
hostPort_size = *-hostPort

tcpAvailable        !byte "R", WIC64_TCP_AVAILABLE, $00, $00
tcpRead             !byte "R", WIC64_TCP_READ, $00, $00
tcpWrite            !byte "R", WIC64_TCP_WRITE, <url_size, >url_size
url                 !text "\r\n",0
url_size = *-url

tcpClose            !byte "R", WIC64_TCP_CLOSE, $00, $00

wic64IsConnected    !byte "R", WIC64_IS_CONNECTED, $01, $00, 5

wic64GetStMsg       !byte "R", WIC64_GET_STATUS_MESSAGE, $01, $00, 0
wic64TransferTimeout !byte "R", WIC64_SET_TRANSFER_TIMEOUT, $01, $00, 5
wic64RemoteTimeout  !byte "R", WIC64_SET_REMOTE_TIMEOUT, $01, $00, 10

availableResponse   !word 0
writeResponse       !word 0
openResponse        !word 0

packBytes           !byte 0
connectResponse     !byte 0
statusResponse      !fill 40

responseSize        !word 0
response            !fill 256

