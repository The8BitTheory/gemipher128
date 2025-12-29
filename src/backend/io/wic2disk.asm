; this downloads a file and directly writes it to disk
!zone wic2disk
downloadWic2disk

    lda #$93 ; clear screen
    jsr bsout

    +wic64_set_store_instruction .wic64WriteByteToDiskStoreInstruction
    
    lda #0
    sta zp_responseSize
    sta zp_responseSize+1

    jsr doSlow

    +wic64_execute wic64TransferTimeout
    +wic64_execute wic64RemoteTimeout

    +print txtTcpOpen
    +wic64_execute tcpOpen, openResponse, 5
    bcc +
    jmp createTimeoutPage

+   +print txtDone
    +print txtTcpWrite
    +wic64_execute tcpWrite, writeResponse, 5
    bcc +
    jmp createTimeoutPage
+   +print txtDone

    lda #$ff
    sta zp_tempY    ;we'll use this as a retry counter (256 times)
    +print txtTcpRead
    
.readIncomingData
    lda #'.'
    jsr bsout
    +wic64_execute tcpRead, response, 5
    bcc +
    jmp .endWithTimeout    ; this means timeout
 
+   lda wic64_response_size
    bne .nextRequestStage
    lda wic64_response_size+1
    bne .nextRequestStage
    dec zp_tempY
    bne .readIncomingData
    jmp .allResponseRead

.nextRequestStage
    ldy #5
    sty zp_tempY
    jmp .isMoreDataAvailable
.readResponsePart
    lda #','
    jsr bsout
    +wic64_execute tcpRead, response, 5
    bcs .allResponseRead    ; this means timeout

.isMoreDataAvailable
    lda wic64_bytes_to_transfer+1
    bne .readResponsePart
    lda wic64_bytes_to_transfer
    bne .readResponsePart

    lda wic64_response_size
    bne .readResponsePart
    lda wic64_response_size+1
    bne .readResponsePart

    dec zp_tempY    ; we wait for 256 cycles if more data arrives
    bne .readResponsePart
    jmp .allResponseRead


.allResponseRead
    jsr .wic64CloseFile
    +wic64_reset_store_instruction

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
    lda zp_contentAddress
    sta zp_responseSize

    +print txtTcpClose
    +wic64_execute tcpClose, response
    +print txtDone

    jmp doFast


.endWithTimeout
    jmp .closeConnection

.makeItHex
    and #%00001111

    clc
    cmp #10
    bpl +
    adc #$30
    rts

+   adc #54
    rts

.wic64WriteByteToDiskStoreInstruction
    jsr .wic64WriteByteToDisk

; downloading a file to disk via bsave-like code.
; acc has to hold the byte to write
.wic64WriteByteToDisk
    stx zp_wic_stash_x
    sty zp_wic_stash_y

    JSR $E503	; -ciout-  Print Serial

    ldx zp_wic_stash_x
    ldy zp_wic_stash_y
    rts

; when end of data is reached:
.wic64CloseFile
    jmp $f59b 
