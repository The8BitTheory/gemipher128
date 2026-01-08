; https://codebase64.net/doku.php?id=base:another_hexadecimal_to_decimal_conversion
; by Mace

!zone decHelper
makeItDec:
    sta .lobyte
    stx .hibyte

    lda #$30	// clear the result buffer
    ldy #$04

-   sta decResult,y
    dey
    bpl -
    ldx #$4f

.loop1:
    clc
    rol .lobyte
    rol .hibyte
    bcs .calculate	// when bit drops off, decimal value must be added
            // if not, go to the next bit
    txa
    sec
    sbc #$05
    tax
    bpl .loop1
.END:
	rts

.calculate:
    clc
    ldy #$04
.loop2:
    lda .table,x	// get decimal equivalent of bit in ASCII numbers
    adc #$00        // add carry, is set if the former addition ≥10
    beq .zero	// skip (speed up) when there's nothing to add
    adc decResult,y	// add to whatever result we already have
    cmp #$3a	// ≥10 with the addition?
    bcc .notten      // if not, skip the subtraction
    sbc #$0a	// subtract 10 
.notten:
    sta decResult,y
.zero:
    dex
    dey
    bpl .loop2	// loop until all 5 digits have been
    jmp .loop1
.table:                          // decimal values for every bit in 16-bit figure
    !byte 0,0,0,0,1 // %0000000000000001
    !byte 0,0,0,0,2 // %0000000000000010
    !byte 0,0,0,0,4 // %0000000000000100
    !byte 0,0,0,0,8 // %0000000000001000
    !byte 0,0,0,1,6 // %0000000000010000
    !byte 0,0,0,3,2 // %0000000000100000
    !byte 0,0,0,6,4 // %0000000001000000
    !byte 0,0,1,2,8 // %0000000010000000
    !byte 0,0,2,5,6 // %0000000100000000
    !byte 0,0,5,1,2 // %0000001000000000
    !byte 0,1,0,2,4 // %0000010000000000
    !byte 0,2,0,4,8 // %0000100000000000
    !byte 0,4,0,9,6 // %0001000000000000
    !byte 0,8,1,9,2 // %0010000000000000
    !byte 1,6,3,8,4 // %0100000000000000
    !byte 3,2,7,6,8 // %1000000000000000

decResult:
    !byte 0,0,0,0,0 // this is where the result will be
    !byte 0
.lobyte:
    !byte 0       // demonstration value
.hibyte:
    !byte 0       // demonstration value
