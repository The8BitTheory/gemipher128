; 

!zone copyCommon

checkAsciiUtf8
    ; check for 0xxxxxxx    -> ascii is most common. check with minimal speed impact.
    ;bit .isAscii    ; if not set (set=negative, not set=positive), then ascii
    bmi +   ;set. check for utf8 sequences
    rts     ; not set. return unchanged

    ; valid utf-8 sequence of any length?
    ; save acc, we'll have to continue working with AND, which will overwrite the acc value
+   sta zp_tempA
    and #%11100000
    cmp #%11000000
    bne .check3ByteSeqs ; bit 5 set, must be 3 or 4 byte sequence
    
    ; c0 and c1 are invalid utf-8 sequence starters. $c2-$df are valid
    lda zp_tempA
    cmp #$C0
    beq .invalidSequence
    cmp #$C1
    beq .invalidSequence

    ; decode common 2-byte sequences to ascii table entries here. 11 bits
    ; use zp_tempCalc as working variables as they are unused in copy routines
    ; acc holds parsed value. get 5 lower bits
    ; next value to read holds 6 bits. forms lower byte with 2 lower bits of current acc value
    
    ; read next value
    ldx zp_contentBank
    iny
    jsr c_fetch
    dec zp_visibleLength

    cmp #$84    ; Ä
    bne +
    lda #196
    rts

+   cmp #$9f    ; ß
    bne +
    lda #223
    rts

+   cmp #$a4    ; ä
    bne +
    lda #228
    rts

+   cmp #$b6    ; ö
    bne +
    lda #246
    rts

+   cmp #$bc    ; ü
    bne +
    lda #252
    rts

+   cmp #$96    ; Ö
    bne +
    lda #214
    rts


+   cmp #$9c    ; Ü
    bne +
    lda #220
    rts

    
+   and #%11000000  ; follow-up byte always start with 10
    cmp #%10000000
    bne .invalidSequence

    ; drop 2 highest bits
    asl zp_tempCalc
    asl zp_tempCalc

    lda zp_tempA
    ror ; lowest bit into carry
    ror zp_tempCalc ; carry into highest bit
    ror
    ror zp_tempCalc
    and #%00000111
    sta zp_tempCalc+1

    lda zp_tempA
    rts

.invalidSequence
    ; set accumulator value to question mark here
    lda #$3f ; ?
    rts


.check3ByteSeqs
    lda zp_tempA
    and #%11110000
    cmp #%11100000
    bne .check4ByteSeq   ; bit 4 set, must be 4-byte sequence
    ; decode common 3-byte sequences to ascii table entries here. 16 bits

    ; read next value
    ldx zp_contentBank
    iny
    jsr c_fetch
    dec zp_visibleLength
    bne +
    dec zp_visibleLength+1

+   cmp #$80
    bne .invalidSequence

    ldx zp_contentBank
    iny
    jsr c_fetch
    dec zp_visibleLength
    bne +
    dec zp_visibleLength+1

+   cmp #$99
    bne +
    lda #$27    ; '
    rts

+   cmp #$9e
    bne +
    lda #$22    ; "
    rts

+   cmp #$9c
    bne +
    lda #$22    ; "
    rts

+   cmp #$9d
    bne .invalidSequence
    lda #$22    ; "
    rts
    ; $e2 80 99
    ; $e2 80 9e -> "
    ; $e2 80 9c -> "
    ; $e2 80 9d -> "


    ; bit 3 must be unset for a valid 4-byte sequence start byte
.check4ByteSeq
    lda zp_tempA
    and #%11111000
    cmp #%11110000
    bne .invalidSequence    ; bit 3 set, not a valid utf-8 start byte
    ; decode common 4-byte sequences to ascii table entries here. 21 bits

    rts


.toUnicodeFF

.isAscii     !byte %10000000
.isUtf2Byte  !byte %11000000
.isUtf3Byte  !byte %11100000
.isUtf4Byte  !byte %11110000

