!zone inputAddress

activateAddressEnterMode    
    lda #02
    sta .posCursorX
    lda #00
    sta .posCursorY
    jsr .setCursorPosition
    jsr .enableCursor


.handleInput
-   jsr k_getin
    beq -

    cmp #13
    bne +
    jmp .evaluateInput

; eval printable ascii characters: 32-127
+   ldx #0
    ldy .posCursorX
    jsr toScreencode
    jsr A_to_vram_XXYY
    inc .posCursorX
    jsr .setCursorPosition
    jmp -

    

.evaluateInput
    jsr .leaveAddressEnterMode
    jmp getUserInput

.leaveAddressEnterMode
    jsr .disableCursor
    rts

; reads value from vdc-register in Xreg into Acc
.enableCursor
    ldx #10 ; register 10: cursor control
    jsr vdc_reg_X_to_A
    ora #%01000000
    sta $0a2b   ; store in shadow register (for screen editor rom routines)
    jmp A_to_vdc_reg_X  ; store in vdc-register

.disableCursor
    ldx #10 ; register 10: cursor control
    jsr vdc_reg_X_to_A
    and #%10111111
    jmp A_to_vdc_reg_X

.setCursorPosition
    jsr .calcCursorAddrToAY
    ldx #14
    jmp AY_to_vdc_regs_Xp1

.calcCursorAddrToAY
    lda #0
    ldy #0
    ldx .posCursorY
    beq .addX
-   clc
    adc #80
    bcc +
    iny
+   dex
    bne -

.addX
    clc
    adc .posCursorX
    bcc +
    iny

; swap a and y, because HB/LB are mixed up
+   tax
    tya
    pha
    txa
    tay
    pla
    rts

.posCursorX     !byte 0
.posCursorY     !byte 0
.addressSizeL   !byte 0
.addressSizeH   !byte 0
.address        !fill 256
