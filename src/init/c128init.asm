!zone c128init

initc128
; disable case switching via Shift-Commodore
    lda #11
    jsr bsout

; switch to lower-case charset
    lda #14
    jsr bsout

    jsr doSlow

    lda #$93 ; clear screen
    jsr bsout

;    jsr .detectAndDisableSuperCpu

    ;jsr detectGeoRAM

;    jsr k_primm
;    !pet "pet klein GROSS",0
;    jsr k_primm
;    !text "ascii klein GROSS",0
;+
    lda #0
    sta zp_fastmode

    jsr disableBasicRom

    jsr .saveZp

    jmp initVdc

exitc128
    jsr .recoverZp
    jmp setBank15

; stores $0a-$8f to somewhere else
.saveZp
    ldx #$0a
    ldy #0
-   lda $0,x
    sta zpStore,y
    iny
    inx
    cpx #$8f+1
    bne -

    ldx #0
    ldy #9
-   lda $1000,x
    sta keyStore,x
    lda #0
    sta $1000,x
    inx
    dey
    bpl -

    rts

.recoverZp
    ldx #$0a
    ldy #0
-   lda zpStore,y
    sta $0,x
    iny
    inx
    cpx #$8f+1
    bne -

    lda #0
    ldx #0
    ldy #9
-   lda keyStore,x
    sta $1000,x
    inx
    dey
    bpl -
    rts
