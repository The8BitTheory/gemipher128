!zone commonDisk

readStatusChannel
    lda #1 ;filenr
    ldx #8 ; device
    ldy #15 ; secondary device
    jsr $ffba
    lda #0 ;kein name
    jsr $ffbd
    jsr $ffc0 ; open
    ldx #1 ;filenr
    jsr $ffc6 ;chkin

    ldx #0
-   jsr $ffcf ;input
    sta diskStatus,x
    ;jsr $ffd2 ;output
    inx
    bit $90 ;status testen
    bvc -

    jsr $ffcc ;clrch
    lda #1
    jsr $ffc3 ;close
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
