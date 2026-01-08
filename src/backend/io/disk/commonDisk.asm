!zone commonDisk

readStatusChannel
    lda #1 ;filenr
    ldx deviceNumber ; device
    bne +
    ldx #8
+   ldy #15 ; secondary device
    jsr $ffba
    lda #0 ;kein name
    jsr $ffbd
    jsr $ffc0 ; open
    ldx #1 ;filenr
    jsr $ffc6 ;chkin

    ldx #0
-   jsr $ffcf ;input
    sta diskStatus,x
    cpx #2
    bcs +
    sta .statusCode,x
+   inx
    bit $90 ;status testen
    bvc -

    jsr $ffcc ;clrch
    lda #1
    jsr $ffc3 ;close

    lda #<.statusCode
    sta zp_memPtr
    lda #>.statusCode
    sta zp_memPtr+1
    jsr twoCharsToDeviceNr

    rts

printDiskStatus
    ldx #0
-   lda diskStatus,x
    cmp #$0d
    beq +
    jsr bsout
    inx
    jmp -

+   jsr bsout   ;print the CR
    rts


diskStatus  !fill 64
.statusCode !word 0     ; store the two bytes of the status code (until the first $2c)

