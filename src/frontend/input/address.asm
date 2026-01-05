!zone inputAddress

.FIRST_POS_X    = 2

activateAddressEnterMode
    jsr .resetCursorPosition

    ; read into .address what we currently have in the address line

    jsr .setCursorPosition
    jsr .enableCursor


.handleInput
-   jsr k_getin
    beq -

    cmp #3
    bne +
    jmp .cancelAddressEnterMode

+   cmp #13
    bne +
    jmp .evaluateInput

+   cmp #147    ;clear
    bne +
    jmp .clearInput

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
    ldx addressPos
    bne +
    jmp .handleInput

; move cursor one left
; write space character without advancing cursor
+   dec .posCursorX
    dec addressPos
    jsr .setCursorPosition
    ldx #0
    ldy .posCursorX
    lda #' '    ; space has same screencode as ascii code
    jsr A_to_vram_XXYY
    lda #0
    jsr writeToAddress
    dec addressPos
    jmp .handleInput

.parseInput
; eval printable ascii characters: 32-127. we'll get codes from 32-95. 96-126 will come as 192-222
    ldx addressPos
    cpx #75
    bne writeAsciiToAddress
    sec
    rts

writeAsciiToAddress
    cmp #32; drop everything < 32
    bcs +   ; value is >= 32
    sec
    rts
+   cmp #96 ;up to 95 is ok
    bcs +   ; value is >= 96 (and >= 32)
    jsr .upperToLowerCase
    jmp writeToAddress

+   cmp #193 ; ignore 122-193
    bcs +   ; greater than 193, go ahead check for uppercase ascii-block
    cmp #122
    bmi +
    sec
    rts

+   cmp #222
    bcs +   ; value is >= 222 (and >= 96)
    jsr .lowerToUpperCase
    jmp writeToAddress

+   ; invalid character. drop
    sec
    rts

writeToAddress
    stx zp_tempX
    
    ldx addressPos
    sta address,x
    inc addressPos

    ldx zp_tempX
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
    lda #1
    sta zp_navModeHistory

    jsr parseAddress        ; extracts input from address into .host, .port, .pageType, and .selector
    bcs .invalidAddress     
    jsr setRequestPointersToAddress ; sets pointers zp_currentHost, Port and Selector to .host, .port and .selector
    jsr setFromHistory  ; reads from pointers and writes to to tcpOpenXyz and tcpWriteXyz

loadFromAddress
    ; if host is "device",$9 then load from disk
    jsr .isDeviceHost
    bne +
    jsr portToDeviceNr
    jsr selectorToFilename
    jsr loadPageFromDisk
    jmp afterRequest

    ; else load from wic64
+   jmp requestNewContent

.isDeviceHost
    ldy #0
-   lda .deviceKey,y
    beq +
    cmp (zp_currentHostPtr),y
    bne .isNetworkHost
    iny
    jmp -

+   lda #0
    rts

.isNetworkHost
    lda #$1
    rts

.clearInput
    jsr clearAddressHostPortSelector
    jsr .resetCursorPosition
    jsr .setCursorPosition
    jsr fillLine0WithSpaces

    jmp .handleInput

clearAddressHostPortSelector
    lda #0
    sta addressPos

; 256 bytes
    ldx #$00
-   sta address,x
    dex
    bne -

.clearHostPortSelector
    lda #0

; 64 bytes
    ldx #63
-   sta .host,x
    dex
    bpl -

; 7 bytes
    ldx #6
-   sta .port,x
    dex
    bpl -

; 256 bytes
    ldx #$00
-   sta .selector,x
    dex
    bne -

    rts

.invalidAddress
    jmp .cancelAddressEnterMode

.leaveAddressEnterMode
    jsr .disableCursor
    rts

; turns user input into tokens ready for request
parseAddress
    jsr .clearHostPortSelector

    lda addressPos
    bne +
    sec
    rts
    
+   ldx #0  ; read index

; parse hostname (parse ends with :, request data ends with $9)
-   lda address,x
    cmp #':'
    beq .concludeHost   ; hostname complete, append tab
    cmp #'/'
    bne +   
    jmp .setDefaultPort ; we found a /, port was not entered. assume default port and continue parsing
    
+   sta .host,x
    inx
    cpx addressPos
    bne -
    beq .addressHostOnlyEnd    ; only hostname entered. assume default port, type and selector

; append $9
.concludeHost
    lda #$09
    sta .host,x

; parse port (parse ends with /, request data ends with $0d $0a)
    ldy #0      ; y is the write index
    inx
-   lda address,x
    beq .concludePort
    cmp #'/'
    beq .concludePort
    sta .port,y
    iny
    inx
    bne -

; append $0d $0a
.concludePort
    lda #$0d
    sta .port,y
    iny
    lda #$0a
    sta .port,y

    cpx addressPos  
    beq .addressAddRootSelector ; end of input. we have to assume pagetype and root selector

; parse pagetype (one byte. parse ends with /, not part of request data)
; if second character is no / then no pagetype was given and we're at the selector already
.parsePageType
    inx
    lda address,x
    sta .pageType
    
    inx
    lda address,x
    cmp #'/'
    beq .parseSelector  ; second byte is a /, we successfully parsed the pagetype
    
    ; if not, roll back index, set default pagetype and continue parsing selector
    lda #$31    ; we assume gopher file
    sta .pageType
    dex
    dex

; parse selector (parse ends with EOL, request data ends with $9)
.parseSelector
    ldy #0
    inx

; check if first character of selector is a /
    lda address,x
    cmp #'/'
    beq +   ; yes, it is
    
    lda #'/'            ; no, it isn't. add it manually
    sta .selector,y
    iny

-   lda address,x
+   sta .selector,y
    iny
    inx
    cpx addressPos
    beq +
    bne -

; append $9
+   lda #$09
    sta .selector,y

    clc
    rts

.addressAddRootSelector
    ldy #0
    lda #$0d
    sta .selector,y
    iny
    lda #$0a
    sta .selector,y
    iny
    lda #$09
    sta .selector,y

    lda #$31    ; no pageType entered by the user. we assume gopher file
    sta .pageType

    clc
    rts

.addressHostOnlyEnd    ; no valid address entered (ie only host without port or selector)
    ; default page type will be set b/c this falls through to .addressAddRootSelector

    lda #$09
    sta .host,x


.setDefaultPort
    ; first, conclude host
    lda #$09
    sta .host,x

    ; set default port
    ldy #0      ; use y-based adressing b/c that seamlessly goes into .concludePort
    lda #$37
    sta .port,y
    iny
    lda #$30
    sta .port,y
    iny

    jmp .concludePort

setRequestPointersToAddress
    lda .pageType
    sta zp_pageType
    sta zp_currentType

    ; host must end with $9
    lda #<.host
    sta zp_currentHostPtr
    lda #>.host
    sta zp_currentHostPtr+1

    ; port must end with \r\n
    lda #<.port
    sta zp_currentPortPtr
    lda #>.port
    sta zp_currentPortPtr+1

    ; selector must end with $9
    lda #<.selector
    sta zp_currentSelectorPtr
    lda #>.selector
    sta zp_currentSelectorPtr+1
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

.resetCursorPosition
    lda #00
    sta .posCursorY

    clc
    lda addressPos
    adc #2
    sta .posCursorX
    rts

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

; this recovers the previous content of the headerline and leaves address entry mode
.cancelAddressEnterMode
    jsr .leaveAddressEnterMode
    jsr writeCurrentGopherToHeadline
    jmp getUserInput

; reads the value from .port and converts it into a numeric value
; result is written to deviceNumber
portToDeviceNr
    ldy #0
    sty deviceNumber
    sty .nrBytes
-   lda (zp_currentPortPtr),y
    beq +
    cmp #$0d
    beq +
    inc .nrBytes
    iny
    cpy #3
    beq .invalidPort    ; if 3 bytes long, the string is invalid
    jmp -

; calculate 
+   dec .nrBytes    ; convert into index. last index (or only) is single digit, next index (if existing) is 10s
    ldy .nrBytes
    lda (zp_currentPortPtr),y     ; eg $38 for 8
    sec
    sbc #$30
    bmi .invalidPort
    sta .deviceNr
    dey
    bmi .portToDeviceNrDone1Digit
    lda (zp_currentPortPtr),y     ; eg $31 for 1
    sec
    sbc #$30
    bmi .invalidPort
    beq .portToDeviceNrDone2Digits
    tax
    lda #0
-   clc
    adc #10
    dex
    beq .portToDeviceNrDone2Digits
    jmp -


.portToDeviceNrDone2Digits
    clc
    adc .deviceNr
.portToDeviceNrDone1Digit
    sta deviceNumber
    rts

.invalidPort
    rts

.posCursorX     !byte 0     ; screen coordinate
.posCursorY     !byte 0     ; screen coordinate
address        !fill 256   ; eg gopher.floodgap.com:70/0/selector
.host           !fill 64    ; eg gopher.floodgap.com. end with $9
.port           !fill 7     ; eg 70, but can be 65536. end with $0d$0a
.selector       !fill 256   ; eg /selector. end with $9
.pageType       !byte 0     
addressPos     !byte 0

.nrBytes        !byte 0     ; used for converting port to device nr
.deviceNr       !byte 0     ; temporary value. if successful, written to deviceNumber
.deviceKey      !text "device",$9,$0