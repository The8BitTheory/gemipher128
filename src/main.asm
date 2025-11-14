; ------------
; memory map
; ------------
; $0.1c01 - $0.bfff: programcode. only enable basic-rom when needed

; bank 1 used for data
;  no clue yet whether to work with indirect kernal routines, or with common memory
;  speed is not essential, so I guess we'll go with indirect routines
;  will need to either copy data to bank 0 for VDC-related things, or make VDC libs interact with bank 1

; basic rom lo $4000-$7fff
b_fast = $77b3
b_slow = $77c4

; basic rom hi $8000-$bfff

; monitor, screen editor $c000-$cfff

; i/o $d000-$dfff

; kernal $e000-$ffff
k_primm = $ff7d
k_getin = $eeeb
bsout = $ffd2

zp_contentAddress = $0a
zp_linecount = $0c


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
;!byte $1c,$1c,$0a,$00
;!byte $fe,$11,$22,$56,$44,$43,$42,$41,$53,$49,$43,$32
;!byte $47,$2e,$31,$33,$30,$30,$22,$2c,$42,$30,$00   ;bload vdcbasic
;!byte $2c,$1c,$14,$00
;!byte $9e,$20,$d1,$28,$22,$31,$33,$30,$30,$22,$29,$00   ; sys dec("1300")
;!byte $49,$1c,$19,$00
;!byte $fe,$11,$22,$41,$53,$43,$49,$49,$32   
;!byte $2e,$43,$48,$52,$22,$2c,$42,$30           ;bload ascii2
;!byte $2c,$50,$31,$36,$33,$38,$34,$00
;!byte $63,$1c,$1e,$00
;!byte $fe,$31,$20,$31,$36,$33,$38,$34,$2c
;!byte $d1,$28,$22,$33,$30,$30,$30,$22
;!byte $29,$2c,$39,$36,$00                       ;vcc
;!byte $6e,$1c,$b5
;!byte $07,$9e,$20,$37,$34,$32,$34,$00       ;sys 7424
;!byte $00,$00
!byte $0b,$1c,$b5,$07,$9e,$20,$37,$34,$32,$34,$00,$00,$00

*=$1d00
main
;    jsr k_primm
;    !pet "pet klein GROSS",0
;    jsr k_primm
;    !text "ascii klein GROSS",0

    jsr disableBasicRom

    jsr saveZp

    jsr initVdc

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
    jsr doFast
    jsr parseGopher
    jsr doSlow

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
    !text "Zero response. Key to try again.",0

-   jsr k_getin
    beq -
    jmp .handleResponse

.noWicDetected
    jsr k_primm
    !text "No WiC64 detected!",$d,0
    rts

.legacyFirmware
    jsr k_primm
    !text "Firmware too old!",$d,0
    
    rts

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
;    lda #0
;    sta zp_linecount
;    sta zp_linecount+1

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


; used for regular runtime (should leave us with $1c01 - $bfff for program code. close to 42 kB )
disableBasicRom
    lda #%00001110
    sta $ff00
    rts

; used for slow/fast
enableBasicLo
    lda #%00000000
    sta $ff00
    rts

doFast
    jsr enableBasicLo
    jsr b_fast
    jmp disableBasicRom

doSlow
    jsr enableBasicLo
    jsr b_slow
    jmp disableBasicRom

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

!src "src/file/load.asm"
!src "src/vdc.asm"
!src "src/parseGopher.asm"
!src "src/wic64/wic64.asm"

mmuBankConfig       !byte $3F,$7F,$BF,$FF,$16,$56,$96,$D6,$2A,$6A,$AA,$EA,$06,$0A,$01,$00
zpStore             !fill 134

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

contentBank         !byte 0
contentAddr         !word 1024
responseSize        !word 0
response            !fill 256

fileOpError         !byte 0
filenameCharset     !pet "ascii2.chr"
filenameLength=*-filenameCharset

; this contains the vectors to all information per line
; start address (beginning of first line) is written after content is completely stored in 'permResponse'
; 10 bytes per line
; type, text, selector, host, port
; this could be kept at 4kb below I/O space at $c000 (2kb of table space is good for 200 lines)
linkTable           !word 0

permResponse        !byte 0

