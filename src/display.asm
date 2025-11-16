!zone textdisplay

; zp_linkTablePosition will always point to the beginning of the current line
; zp_linkTablePointer will point to the index inside of the current line
; this way we should be able to work with a single byte for offset (just y)
displayTextmode
    lda #$93 ; clear screen
    jsr bsout

    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
    jsr initLinkTableAddress
    lda #0
    sta zp_vram_address
    sta zp_vram_address+1

;    ldx #10
;    jsr .gotoLineNumber

    ; load type
    ldx #20
    stx zp_tempX
-   jsr .displayVisibleContent

    jsr .incLineNumber
    jsr .incOutputLineNumber

+   ;lda #$0d
    ;jsr bsout

    dec zp_tempX
    bne -


    rts
    nop

.gotoLineNumber
    jsr .incLineNumber
    dex
    bne .gotoLineNumber
    rts

.incLineNumber
    clc
    lda zp_linkTablePosition
    adc #9
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1

+   rts

.incOutputLineNumber
    clc
    lda zp_vram_address
    adc #80
    sta zp_vram_address
    bcc +
    inc zp_vram_address+1
    
+   rts

.displayVisibleContent
    ldy #0

; read start position of current line from link-table
    lda #zp_linkTablePosition
    sta c_fetch_zp
    
    ldx zp_contentBank
    jsr c_fetch
    sta zp_currentLinkTablePtr
    iny
    ldx zp_contentBank
    jsr c_fetch
    sta zp_currentLinkTablePtr+1
    iny
    ldx zp_contentBank
    jsr c_fetch
    sta zp_visibleLength

; read first character of current line from content area (holds the line type)
    lda #zp_currentLinkTablePtr
    sta c_fetch_zp
    ldy #0
    ldx zp_contentBank
    jsr c_fetch 
    
    ; A now contains the type of the line
    jsr .handleType

    lda zp_vram_address
    sta arg2
    lda zp_vram_address+1
    sta arg2+1
    
    jsr .myRtv

    ; go on reading the text content of the line
;-   ldx zp_contentBank
;    iny
;    jsr c_fetch
;    cmp #9
;   beq +
;    jsr bsout
;    jmp -

;+   
    rts
    nop

.myRtv   ; copy RAM to VRAM

    ldy arg2
    lda arg2 + 1
    jsr rtv_vtr_swp_shared_setup

    ldy #0
    
-   ldx zp_contentBank
    iny
    jsr c_fetch

    cmp #9
    beq .rtvDone

    cmp #65 ;A  
    bmi .rtvWrite       ; < A (so, must be a digit. don't change)

    cmp #97 ;a  ; < a (so, must be an uppercase letter. subtract 64
    bpl +
    sec
    sbc #64
    jmp .rtvWrite

+   cmp #123 ; <z (so, must be a lowercase letter)
    bpl .rtvWrite
    sec
    sbc #32

; write byte to VRAM
.rtvWrite
    +vdc_sta
	jmp -

.rtvDone
    jmp complex_instruction_shared_exit

.handleType
    cmp #$69 ;i - info
    bne +
    lda #$5     ;white
    jsr bsout
    rts

+   cmp #$30 ; 0 - textfile
    bne +
    lda #$9c    ; purple
    jsr bsout
    rts

+   cmp #$31 ; 1 - menu / directory
    bne +
    lda #$1e    ; green
    jsr bsout
    rts

+   cmp #$32 ; 2 - cso phonebook
    bne +
    lda #$9a ;light blue
    jsr bsout
    rts

+   cmp #$33 ; 3 - error/info
    bne +
    brk
    rts

+   cmp #$34 ; 4 - binary
    bne +
    rts

+   cmp #$35 ; 5 - dos binary
    bne +
    rts

+   cmp #$36 ; 6 - uuencoded text (probably a binary?)
    bne +
    rts

+   cmp #$37 ; 7 - error/info
    bne +
    rts

+   cmp #$38 ; 8 - Telnet
    bne +
    rts

+   cmp #$39 ; 9 - generic binary
    bne +
    rts

+   cmp #'+' ; + - gopher + info
    bne +
    rts

+   cmp #'g' ; G - GIF
    bne +
    rts

+   cmp #'l' ; L - generic image
    bne +
    rts

+   cmp #'h' ; H - Hyperlink
    bne +
    lda #$9e    ; $9e=yellow, $81=dark purple (should be orange, which is not a vdc-color)
    jsr bsout
    rts

+   cmp #'s' ; s - audio
    bne +
    rts

+   cmp #'M' ; m - multipart mime
    bne +
    rts

+   cmp #'D' ; d - document. mostly pdf
    bne +
    rts

+   cmp #'T' ; t - terminal connection tn3270
    bne +
    rts

+   cmp #$9 ;tab
    bne +
    rts

+   ;lda #$12 ;reverse on
    ;jsr bsout
    ;lda #'x'
    ;jsr bsout
    rts
