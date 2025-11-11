;
; Example
;

k_primm = $ff7d
k_getin = $eeeb
bsout = $ffd2

zp_contentAddress = $0a

wic64_include_load_and_run = 0
wic64_include_enter_portal = 0
wic64_optimize_for_size = 0

!src "src/wic64/wic64.h"

!macro print textaddress {
    pha
    txa
    pha

    ldx #0
-   lda textaddress,x
    beq +
    jsr bsout
    inx
    jmp -

+   pla
    tax
    pla
}

*=$1c01
!byte $1c,$1c,$0a,$00
!byte $fe,$11,$22,$56,$44,$43,$42,$41,$53,$49,$43,$32
!byte $47,$2e,$31,$33,$30,$30,$22,$2c,$42,$30,$00
!byte $2c,$1c,$14,$00
!byte $9e,$20,$d1,$28,$22,$31,$33,$30,$30,$22,$29,$00
!byte $49,$1c,$19,$00
!byte $fe,$11,$22,$41,$53,$43,$49,$49,$32
!byte $2e,$43,$48,$52,$22,$2c,$42,$30
!byte $2c,$50,$31,$36,$33,$38,$34,$00
!byte $63,$1c,$1e,$00
!byte $fe,$31,$20,$31,$36,$33,$38,$34,$2c
!byte $d1,$28,$22,$33,$30,$30,$30,$22
!byte $29,$2c,$39,$36,$00
!byte $6e,$1c,$b5
!byte $07,$9e,$20,$37,$34,$32,$34,$00
!byte $00,$00
;!byte $0b,$1c,$b5,$07,$9e,$20,$37,$34,$32,$34,$00,$00,$00

*=$1d00
main
    jsr saveZp
    jsr .initContentAddress

    lda #14
    jsr bsout

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

.sendRequest
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
    +wic64_execute tcpRead, response, 5
    bcc +
    jmp .connTimeout
+   lda #'O'
    jsr bsout
    lda wic64_bytes_to_transfer
    sta packBytes
    jsr .storeInPerm
    
.handleResponse
    +wic64_execute tcpAvailable, availableResponse, 5
    lda availableResponse
    bne +
    lda availableResponse+1
    beq ++

+   jmp .readResponsePart
++  jmp .allResponseRead

.storeInPerm
    ldx #0
    ldy #0
-   lda response,x
    sta (zp_contentAddress),y
    inx
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

.allResponseRead
    lda #$0d
    jsr bsout
    jsr .closeConnection

    ; set zp_content to beginning of content so we can start parsing that now
    jsr .initContentAddress

    lda #$0d
    jsr bsout
    jsr .parseContent

    jsr recoverZp
    rts
    nop

.closeConnection
    +print txtTcpClose
    +wic64_execute tcpClose, response
    +print txtDone
    rts

.waitAndDoAgain
    jsr k_primm
    !pet "Zero response. Key to try again.",0

-   jsr k_getin
    beq -
    jmp .handleResponse

.parseContent
    lda #0
    sta parseSeq
    sta parseMode

    lda responseSize
    sta leftToParse
    lda responseSize+1
    sta leftToParse+1

    jmp .decideOnParseSeq

.decideOnParseSeq
    lda parseSeq
    bne +
    jmp .handleType

+   cmp #1
    bne +
    jmp .handleSelector

+   cmp #2
    bne +
    jmp .handleHost

+   cmp #3
    bne +
    jmp .handlePort

+   rts
    nop

.handleType
    lda parseMode
    bne .gotoParseMode
-   jsr .readNextByte
    bne .gotoParseMode

.foundZero
    jsr k_primm
    !pet "Found zero byte",$d,0
    rts

.gotoParseMode
    cmp #$69 ;i - info
    bne +
    sta parseMode
    jmp .handleInfo

+   cmp #$30 ; 0 - textfile
    bne +
    sta parseMode
    jmp .handleTypeText

+   cmp #$31 ; 1 - menu / directory
    bne +
    sta parseMode
    jmp .handleTypeMenu

+   cmp #$32 ; 2 - cso phonebook
    bne +
    sta parseMode
    jmp .handleTypePhonebook

+   cmp #$33 ; 3 - error/info
    bne +
    sta parseMode
    jmp .handleTypeError

+   cmp #$34 ; 4 - binary
    bne +
    sta parseMode
    jmp .handleTypeBinary

+   cmp #$35 ; 5 - dos binary
    bne +
    sta parseMode
    jmp .handleTypeDosBinary

+   cmp #$36 ; 6 - uuencoded text (probably a binary?)
    bne +
    sta parseMode
    jmp .handleTypeUUenc

+   cmp #$37 ; 7 - error/info
    bne +
    sta parseMode
    jmp .handleTypeSearch

+   cmp #$38 ; 8 - Telnet
    bne +
    sta parseMode
    jmp .handleTypeTelnet

+   cmp #$39 ; 9 - generic binary
    bne +
    sta parseMode
    jmp .handleTypeGenericBinary

+   cmp #'+' ; + - gopher + info
    bne +
    sta parseMode
    jmp .handleTypePlus

+   cmp #'g' ; G - GIF
    bne +
    sta parseMode
    jmp .handleTypeGif

+   cmp #'l' ; L - generic image
    bne +
    sta parseMode
    jmp .handleTypeGenericImage

+   cmp #'H' ; H - Hyperlink
    bne +
    sta parseMode
    jmp .handleTypeHyperlink

+   cmp #'s' ; s - audio
    bne +
    sta parseMode
    jmp .handleTypeAudio

+   cmp #'M' ; m - multipart mime
    bne +
    sta parseMode
    jmp .handleTypeMime

+   cmp #'D' ; d - document. mostly pdf
    bne +
    sta parseMode
    jmp .handleTypeDoc

+   cmp #'T' ; t - terminal connection tn3270
    bne +
    sta parseMode
    jmp .handleTypeTerminal

+   cmp #$9 ;tab
    bne +
    sta parseMode
    jmp .handleTab

+   dey
    beq +
    jmp -

+   sec
    lda availableResponse
    sbc wic64_bytes_to_transfer
    sta availableResponse
    lda availableResponse+1
    sbc wic64_bytes_to_transfer+1
    sta availableResponse+1

    lda availableResponse
    bne +
    lda availableResponse+1
    bne +
    jmp .allResponseRead

+   jmp .readResponsePart

.noWicDetected
    jsr k_primm
    !pet "No WiC64 detected!",$d,0
    rts

.legacyFirmware
    jsr k_primm
    !pet "Firmware too old!",$d,0
    
    rts

.handleTypeAudio
.handleTypeBinary
.handleTypeDoc
.handleTypeDosBinary
.handleTypeGenericBinary
.handleTypeGenericImage
.handleTypeGif
.handleTypeHyperlink
.handleTypeTerminal
.handleTypeMime
.handleTypePlus
.handleTypeTelnet
.handleTypeSearch
.handleTypeUUenc
.handleTypeError
.handleTypePhonebook
.handleTypeText
.handleTypeMenu
.handleInfo
    jsr .readNextByte
    cmp #9  ; tab. end ascii output
    bne +
    lda #$0d
    jsr bsout
    inc parseSeq
    lda #0
    sta parseMode
    jmp .decideOnParseSeq

+   jsr bsout
    jmp .handleInfo

.handleTab
    inc parseSeq
    jmp .decideOnParseSeq

; for now, just skip until tab
.handleSelector
    jsr .readNextByte
    cmp #9
    beq +
    jmp .handleSelector
+   jmp .handleTab

.handleHost
    jsr .readNextByte
    cmp #9
    beq +
    jmp .handleHost
+   jmp .handleTab

.handlePort
    jsr .readNextByte
    cmp #13
    bne .handlePort
    jsr .readNextByte
    cmp #10
    bne .handlePort
    
    ; we found a CR LF sequence. end the line
    lda #0
    sta parseSeq

    ; and check whether to end parsing alltogether
    lda leftToParse+1
    bmi .parseComplete
;    lda leftToParse
;    cmp responseSize
;    bne +               ; we haven't yet reached zero. continue parsing
;    lda leftToParse+1
;    bmi .parseComplete
;    cmp responseSize+1
;    beq .parseComplete

    jmp .decideOnParseSeq

.parseComplete
    lda #4
    sta parseSeq    ;parseSeq 4 should end parsing
    jmp .decideOnParseSeq

.readNextByte
    ldy #0
    lda (zp_contentAddress),y

    inc zp_contentAddress
    bne +
    inc zp_contentAddress+1

+   dec leftToParse
    bne +
    dec leftToParse+1

+   rts



storeInBank1

    lda #zp_contentAddress
    sta $02B9


    ldx #1
    ldy #0
    ;sta $mmu
    ; disable basic,i/o
    lda contentAddr
    jsr k_indsta
    
    ; enable basic,i/o

    rts

.initContentAddress
    lda #<permResponse
    sta zp_contentAddress
    lda #>permResponse
    sta zp_contentAddress+1
    rts

.handleWic64Error
    bcc +
    +wic64_execute wic64GetStMsg, statusResponse
    jmp .connTimeout
+   rts


k_indsta
    pha
    lda mmuBankConfig,x	; MMU Bank Configuration Values
    tax
    pla
    jmp $02AF	; Bank Poke Subroutine

; stores $0a-$8f to somewhere else
saveZp
    ldx #$0a
    ldy #0
-   lda $0,x
    sta zpStore,y
    iny
    inx
    cpx #$8f+1
    bne -
    rts

recoverZp
    ldx #$0a
    ldy #0
-   lda zpStore,y
    sta $0,x
    iny
    inx
    cpx #$8f+1
    bne -
    rts

mmuBankConfig   !byte $3F,$7F,$BF,$FF,$16,$56,$96,$D6,$2A,$6A,$AA,$EA,$06,$0A,$01,$00
zpStore         !fill 134

!src "src/wic64/wic64.asm"


txtDetect       !pet "Detecting WiC64... ",0
txtConnected    !pet "Check WiC64 is connected ...",0
txtTimeout      !pet "timeout",$d,0
txtNotConnected !pet "not connected",$d,0
txtTcpOpen      !pet "TCP Connection open... ",0
txtTcpRead      !pet "TCP Read... ",0
txtTcpWrite     !pet "TCP Write... ",0
txtTcpClose     !pet "TCP Close... ", 0
txtTcpAvlbl     !pet "TCP Available... ",0
txtDone         !pet "done",$d,0

availableResponse    !word 0,0
writeResponse        !word 0,0
openResponse         !word 0,0

tcpOpen         !byte "R", WIC64_TCP_OPEN, <hostPort_size, >hostPort_size
hostPort        !text "gopher.floodgap.com:70",0
hostPort_size = *-hostPort

tcpAvailable    !byte "R", WIC64_TCP_AVAILABLE, $00, $00
tcpRead         !byte "R", WIC64_TCP_READ, $00, $00
tcpWrite        !byte "R", WIC64_TCP_WRITE, <url_size, >url_size
url             !text "\r\n",0
url_size = *-url

tcpClose        !byte "R", WIC64_TCP_READ, $00, $00

wic64IsConnected !byte "R", WIC64_IS_CONNECTED, $01, $00, 5

wic64GetStMsg   !byte "R", WIC64_GET_STATUS_MESSAGE, $01, $00, 0
wic64TransferTimeout !byte "R", WIC64_SET_TRANSFER_TIMEOUT, $01, $00, 5
wic64RemoteTimeout !byte "R", WIC64_SET_REMOTE_TIMEOUT, $01, $00, 10

parseMode       !byte 0 ; $69 for i, $31 for 1, etc
parseSeq        !byte 0 ; 0=type specific parsing, 1=selector, 2=hostname, 3=port

packBytes       !byte 0
connectResponse !byte 0
statusResponse  !fill 40,$ea

contentBank     !byte 0
contentAddr     !word 1024
responseSize    !word 0
leftToParse     !word 0
response        !fill 256

permResponse    !byte 0