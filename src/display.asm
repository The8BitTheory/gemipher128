!zone textdisplay

; zp_linkTablePosition will always point to the beginning of the current line
; zp_currentLinkTablePtr will point to the index inside of the current line
; this way we should be able to work with a single byte for offset (just y)
displayTextmode
;    lda #$93 ; clear screen
;    jsr bsout

; bank 1
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    
; pointer to beginning of link table
    jsr initLinkTableAddress

    clc
    lda zp_linkTablePosition
    adc #2
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1

; read start position of current line from link-table
+   lda #zp_linkTablePosition
    sta c_fetch_zp

; vram target to zero
    lda #0
    sta zp_vram_screenram
    sta zp_vram_screenram+1

; setup the read-position in vram_content area
    jsr .gotoLineNumber

    ; vram read address is taken from link-table
    ; when not starting display at the first line, we're adding up visible-lengths until we're there
    ; with each line displayed, the read address is just increased by the amount of the previous line.
    ; the write address starts at zero and increments 80 bytes for each line

    ; block copy source address is automatically increased, so we only need to set it once for 25 lines
    ; each copy operation only requires setting target address (increments of 80, unless line-length is longer)
    ;  and nr of characters to copy

    ; load type
    ldx #25
    stx zp_tempX

    jsr .clearScreen

;setup block copy
; set register bit for BLOCK COPY:
    ldx #24
    jsr vdc_reg_X_to_A
    ora #128
    jsr A_to_vdc_reg_X

; target address
    jsr .writeVramAddress

; block copy source (HB/LB order)
    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    ldx #32
    jsr AY_to_vdc_regs_Xp1

 -  jsr .displayLine

    jsr .incLinkTableReadPosition
    jsr .incOutputLineNumber

    ldx zp_tempX
    bne -

    rts
    nop

.gotoLineNumber
    lda #<VRAM_CONTENT
    sta zp_vram_content_addr
    lda #>VRAM_CONTENT
    sta zp_vram_content_addr+1

    ldx zp_linenumber_start
    bne +
    rts

+   stx zp_tempX

    ; read contentlength
-   jsr .readVisibleLength
    ; A holds visible length of current line
    clc
    adc zp_vram_content_addr
    sta zp_vram_content_addr
    bcc +
    inc zp_vram_content_addr+1

+   jsr .incLinkTableReadPosition
    dec zp_tempX
    bne -
    rts

.incLinkTableReadPosition
    clc
    lda zp_linkTablePosition
    adc #9
    sta zp_linkTablePosition
    bcc +
    inc zp_linkTablePosition+1
+   rts

.incOutputLineNumber
    dec zp_tempX
    bne +
    rts

+   clc
    lda zp_vram_screenram
    adc #80
    sta zp_vram_screenram
    bcc .writeVramAddress
    inc zp_vram_screenram+1

; the vram target address. within the visible area of screen ram
.writeVramAddress
    ldy zp_vram_screenram
    lda zp_vram_screenram+1
    
    jmp AY_to_vdc_regs_18_19

.displayLine
    jsr .readVisibleLength
    ; low-byte in A
-   cmp #75
    bcc +   
    ; line longer than 75 characters
    sec
    sbc #75
    sta zp_visibleLength
    lda #75
    jmp ++

    ; line shorter thann 75 characters
+   ldy #0
    sty zp_visibleLength

    ; this implies a maximum line-width of 255 visible characters
    ;ldy #0  ; high-byte in Y is zero anyways, coming out of jsr .readVisibleLength above
++  jsr vdc_do_YYAA_cycles  ; this writes the length to reg #30 to trigger the VDC block copy operation

    lda zp_visibleLength
    beq +
    ldx zp_tempX    ;contains the nr of lines left to print
    cpx #1
    beq +           ;if this is the last line, don't print the next line
    jsr .incOutputLineNumber
    lda zp_visibleLength
    jmp -

+   rts


.readVisibleLength
    ldy #0
    ldx zp_contentBank
    jsr c_fetch
    sta zp_visibleLength
    rts

.clearScreen
;   wait until we are in text window (in case we're in a sync state right now)
-   lda vdc_state
    and #$20
    bne -

    ; wait until we are out of text window
-   lda vdc_state
    and #$20
    beq -

    ; clear BLOCK COPY register bit to get BLOCK WRITE:
    ldx #24
    jsr vdc_reg_X_to_A
    and #$7f
    jsr A_to_vdc_reg_X

    lda #$20
    ldy zp_vram_screenram
    ldx zp_vram_screenram+1
    jsr A_to_vram_XXYY

    ;set count
    lda #$ff    ;lowbyte
    ldy #$07    ;highbyte
    jsr vdc_do_YYAA_cycles
    
    rts


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
