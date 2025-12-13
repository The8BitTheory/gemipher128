!zone swiftlink

.slInit      = $1300  ;( .AY=iobase, .X=hackedSlFlag )                          1
.slParms     = $1303  ;( .A=params, .X=parity ) : .CS=err#.A                    2
.slShutdown  = $1306  ;()
.slGetByte   = $1309  ;() : .A=byte, .X=notEmpty, .CS=err#.A                    4
.slPutByte   = $130c ;( .A=byte ) : .CS=err#.A                                  3
.slPause     = $130f ;()
.slUnpause   = $1312 ;()                                                        
.slStatus    = $1315 ;() : .A=status, .X=errorCount

;*----------------------------------------------------------------------------*
; slParms - swiftlink set communication parameters.
;
; baud rates              stops     word    |   parity
; ---------------------   -----     -----   |   ---------
; $00=50     $08=9600     $00=1     $00=8   |   $00=none
; $01=110    $09=19200    $80=2     $20=7   |   $20=odd
; $02=134.5  $0a=38400              $40=6   |   $60=even
; $03=300    $0b=57600              $60=5   |   $A0=mark
; $04=600    $0c=115200                     |   $E0=space
; $05=1200   $0d=230400
; $06=2400   $0e=future
; $07=4800   $0f=future
;*----------------------------------------------------------------------------*

; $d700 -> sid mirror (use on real c128 with real swiftlink for no reu/georam conflicts. requires hardware modification)
; $de00 -> georam
; $df00 -> reu
; $df80 -> acia (use on ultimate hardware for no reu/georam conflicts)

requestContentViaSwiftlink
    jsr enableIO

    sec
    lda #<CONTENT_END_ADDRESS
    sbc #<CONTENT_ADDRESS
    sta ramLeft
    lda #>CONTENT_END_ADDRESS
    sbc #>CONTENT_ADDRESS
    sta ramLeft+1

    lda #$93 ; clear screen
    jsr bsout

    jsr initContentAddress

    lda #0
    sta zp_responseSize
    sta zp_responseSize+1
    sta zp_tempY    ;we'll use this as a retry counter (256 times)

;    jsr .slUnpause
;    bcs .unpauseError

    jsr setInitialGopherHostSelectorCommon

    jsr .initSwiftlink


    +print txtTcpOpen
    ; open tcp connection by sending "ATD host:port" to swiftlink
    ; send ATD
    ldy #0
    sty zp_tempY
-   ldy zp_tempY
    lda .connectString,y
    beq +
    jsr .slPutByte
    bcs .putByteError
    inc zp_tempY
    jmp -

    ; send host:port
+   lda #zp_currentHostPtr
    sta c_fetch_zp

    ldy #0
    sty zp_tempY
-   ldy zp_tempY
    ldx zp_hostSelBank
    jsr c_fetch
    cmp #9
    beq +
    jsr .slPutByte
    inc zp_tempY
    jmp -
    
+   lda #':'
    jsr .slPutByte

    lda #zp_currentPortPtr
    sta c_fetch_zp

    ldy #0
    sty zp_tempY
-   ldy zp_tempY
    ldx zp_hostSelBank
    jsr c_fetch
    cmp #$0d
    beq +
    jsr .slPutByte
    inc zp_tempY
    jmp -

+   lda #$0d
    jsr .slPutByte

    +print txtDone

    ldy #0
.readResponse
    jsr .slGetByte
    beq +      ; x register holds empty/filled info
    beq .readResponse
    cmp #$d     ; byte is CR?
    beq +
    sta .swiftResponse,y
    iny
    cpy #32 ; response buffer is 32 bytes.
    beq +
    jmp .readResponse

; go ahead, sending selector
+   

    jsr .slShutdown
    jsr disableIO
    rts


;+   ldy #0
;    sty zp_tempX
;    lda #zp_currentSelectorPtr
;    sta c_fetch_zp

;-   ldx zp_hostSelBank
;    jsr c_fetch
;    cmp #$0d
;    bne +
;    iny
;    jmp -
;+   cmp #$0a
;    bne +
;    jmp .writeCrLf
;+   cmp #9
;    beq .writeCrLf
;    ldx zp_tempX
;    sta tcpWriteSelector,x
;    inc zp_tempX
;    iny
;;    jsr .incWriteSize
;    jmp -

;+   rts

;.writeCrLf
;    ldx zp_tempX
;    lda #$0d
;    sta tcpWriteSelector,x
;    jsr .incWriteSize
;    inx
;    lda #$0a
;    sta tcpWriteSelector,x

;.incWriteSize
;    inc tcpWriteSizeL
;    bne +
;    inc tcpWriteSizeH
;+   rts


.unpauseError
    brk
    rts
    nop

.putByteError
    ;brk
    jsr .slShutdown
    rts
    nop

.getByteError
    brk
    rts
    nop


detectAndInitSwiftlink
    jsr loadSwiftlinkDriverFromDisk

.initSwiftlink
    jsr enableIO

    lda #$00    ; io lowbyte
    ldy #$de    ; io highbyte
    ldx #$00    ; hacked flag

    jsr .slInit

    lda #$0a        ; 38400 bauds
    ldx #$00        ; no parity
    jsr .slParms
    bcs .initError

;    jsr .slPause
;    bcs .pauseError

    jmp disableIO

.initError
    sta zp_tempA
    jsr k_primm
    !text "slParams error: $",0
    lda zp_tempA
    lsr
    lsr
    lsr
    lsr 
    jsr .makeItHex
    jsr bsout
    
    lda zp_tempA
    jsr .makeItHex
    jsr bsout

    jsr .slShutdown
    sec
    jmp disableIO

    nop

.pauseError
    brk
    rts
    nop

.makeItHex
    and #%00001111

    clc
    cmp #10
    bpl +
    adc #$30
    rts

+   adc #54
    rts



.connectString  !text "atdt",0
.swiftResponse  !fill 32


