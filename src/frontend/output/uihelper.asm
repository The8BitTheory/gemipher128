; this contains all generic methods for UI handling
; clear screen, conversions, create screen areas, etc.
!zone uiHelper

clearHeaderLine
    jsr setBlockFill

; set line 0 of attribute ram to inverse
    ldy #$00
    ldx #$08
    lda #%11000011  ;charset 1, reverse on, dark gray
    jsr A_to_vram_XXYY

; set count (79 characters)
    lda #$4f
    ldy #$00
    jsr vdc_do_YYAA_cycles

    jsr fillLine0WithSpaces

    ldy #76
    sty zp_tempY
    ldy #02
    lda #00
    jmp AY_to_vdc_regs_18_19

writeCurrentGopherToHeadline
    jsr clearHeaderLine
    lda #0
    sta addressPos  ; this is used for cursorposition when entering a user-defined address

    lda #<tcpOpenHostPort
    sta zp_memPtr  ;we're mis-using this here, as we're not doing indfet
    lda #>tcpOpenHostPort
    sta zp_memPtr+1

    lda tcpOpenSizeL
    sta zp_tempCalc
    lda tcpOpenSizeH
    sta zp_tempCalc+1

    jsr printHeaderLineUntilTab

    lda #'/'
    pha
    jsr writeToAddress
    pla
    jsr toScreencode
    jsr printAcc
    dec zp_tempY

    lda zp_pageType
    pha
    jsr writeToAddress
    pla
    jsr toScreencode
    jsr printAcc
    dec zp_tempY

    lda #<tcpWriteSelector
    sta zp_memPtr
    lda #>tcpWriteSelector
    sta zp_memPtr+1

    lda tcpWriteSizeL
    sta zp_tempCalc
    lda tcpWriteSizeH
    sta zp_tempCalc+1

    jmp printHeaderLineUntilTab
    nop

printAcc
    ldx #31
    jmp A_to_vdc_reg_X

printHeaderLineUntilTab
    ldy #0
-   lda (zp_memPtr),y
    beq +
    cmp #$d
    beq +
    cmp #$09
    beq +
    pha
    jsr writeToAddress
    pla
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X

    dec zp_tempY    ; makes sure we're not printing beyond 76 characters
    beq +
    dec zp_tempCalc
    beq +
    iny
    jmp -
+   rts
    nop

fillLine0WithSpaces
    ldy #$00
    ldx #$00
    lda #$20
    jsr A_to_vram_XXYY
    
    ; set count (79 characters)
    lda #$4f
    ldy #$00
    jsr vdc_do_YYAA_cycles

; print rounded corners top left and right
    lda #96
    ldy #$00
    ldx #$00
    jsr A_to_vram_XXYY

    lda #97
    ldy #$4f
    ldx #$00
    jmp A_to_vram_XXYY

makeItHex
    clc
    cmp #10
    bpl +
    adc #$30
    rts

+   adc #54
    rts

toScreencode
    cmp #64 ;A  
    bmi .screencodeDone       ; < A (so, must be a digit. don't change)

    cmp #96 ;a  ; < a (so, must be an uppercase letter. subtract 64
    bpl +
    sec
    sbc #64
    jmp .screencodeDone

+   cmp #127 ; <z (so, must be a lowercase letter)
    bpl .screencodeDone
    sec
    sbc #32

.screencodeDone
    rts

clearScreen
;   wait until we are in text window (in case we're in a sync state right now)
-   lda vdc_state
    and #$20
    bne -

    ; wait until we are out of text window
-   lda vdc_state
    and #$20
    beq -

    jsr setBlockFill

; fill lines 1 - 23 with space character
; screen-ram
    lda #$20
    ldy #$50
    ldx #$00
    jsr A_to_vram_XXYY

    ;set count
    lda #$2f    ;lowbyte
    ldy #$07    ;highbyte
    jmp vdc_do_YYAA_cycles

; not clearing attribute-ram of lines 1-23 (content area)
; because every line writes to the attribute ram anyways

setStatusLineAttributeRam
    jsr setBlockFill
    
; set line 24 of attribute ram to inverse
    ldy #$80
    ldx #$0f
    lda #%11000011   ;charset 1, reverse on
    jsr A_to_vram_XXYY

    ;set count (79 chars)
    lda #$4f    ;lowbyte
    ldy #$00    ;highbyte
    jsr vdc_do_YYAA_cycles
    
; fill line 24 with spaces
    ldy #$80
    ldx #$07
    lda #$20
    jsr A_to_vram_XXYY
    
    ; set count (79 characters)
    lda #$4f
    ldy #$00
    jmp vdc_do_YYAA_cycles


; ----------- multiply ----------------
multiply
    lda #%00001110
    sta $ff00


    lda #$00
    tay
    beq .enterLoop

.doAdd:
    clc
    adc zp_tempCalc
    tax

    tya
    adc zp_tempCalc+1
    tay
    txa

.loop:
    asl zp_tempCalc
    rol zp_tempCalc+1
.enterLoop:  ; accumulating multiply entry point (enter with .A=lo, .Y=hi)
    lsr zp_tempX
    bcs .doAdd
    bne .loop

    rts

; -------------------------------------