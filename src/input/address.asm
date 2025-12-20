!zone inputAddress

.FIRST_POS_X    = 2

activateAddressEnterMode    
    lda #.FIRST_POS_X
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

+   cmp #20 ;delete key
    bne +
    jmp .deletePreviousCharacter

+   jsr .parseInput
    bcs -   ;carry set = invalid character. read next input

; display character in address line
    ldx #0
    ldy .posCursorX
    jsr toScreencode
    jsr A_to_vram_XXYY
    inc .posCursorX
    jsr .setCursorPosition
    jmp -

.deletePreviousCharacter
    ; check if we are at first position (ie nothing to delete)
    ldx .posCursorX
    cpx #.FIRST_POS_X
    bne +
    jmp .handleInput

; move cursor one left
; write space character without advancing cursor
+   dec .posCursorX
    jsr .setCursorPosition
    ldx #0
    ldy .posCursorX
    lda #' '    ; space has same screencode as ascii code
    jsr A_to_vram_XXYY
    jmp .handleInput

.parseInput
; eval printable ascii characters: 32-127. we'll get codes from 32-95. 96-126 will come as 192-222
    cmp #32; drop everything < 32
    bcs +   ; value is >= 32
    sec
    rts
+   cmp #96 ;up to 95 is ok
    bcs +   ; value is >= 96 (and >= 32)
    jsr .upperToLowerCase
    jmp .writeToAddress

+   cmp #193 ; ignore 122-193
    bcs +   ; greater than 193, go ahead check for uppercase ascii-block
    cmp #122
    bmi +
    sec
    rts

+   cmp #222
    bcs +   ; value is >= 222 (and >= 96)
    jsr .lowerToUpperCase
    jmp .writeToAddress

+   ; invalid character. drop
    sec
    rts

.writeToAddress
    clc
    rts

.upperToLowerCase
; if it's A-Z, make it a-z. 65-90 -> 97-122
;  we made sure earlier in the code that the character is between 32 and 95
    cmp #65 ; leave 32-64 unchanged
    bcc +
    clc
    adc #32
    rts
+   cmp #91 ; leave >90 unchanged
    rts

.lowerToUpperCase
    sec
    sbc #96

; if it's a-z, make it A-Z. 97-122 -> 65-90
;  we made sure earlier that the character is between 96 and 125
    ; ignore characters 96 and >122
    cmp #96
    bne +
    rts
+   cmp #123
    bmi +
    rts

+   sec
    sbc #32
    rts

.evaluateInput
    jsr .leaveAddressEnterMode
    jsr .setRequestPointers
    ;jsr requestNewContent
    jmp getUserInput

.leaveAddressEnterMode
    jsr .disableCursor
    rts

.setRequestPointers
    lda #<diskHost
    sta zp_currentHostPtr
    lda #>diskHost
    sta zp_currentHostPtr+1

    lda #<diskPort; $ba ;186, contains current drive number
    sta zp_currentPortPtr
    lda #>diskPort
    sta zp_currentPortPtr+1

    lda #<selectorContent
    sta zp_currentSelectorPtr
    lda #>selectorContent
    sta zp_currentSelectorPtr+1
    jmp setFromHistory


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
