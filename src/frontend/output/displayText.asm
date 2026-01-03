!zone outputText

; zp_linkTablePosition will always point to the beginning of the current line
; this way we should be able to work with a single byte for offset (just y)

; this routine only deals with vram (not ram, etc)
displayTextmode
    ldy #LAST_LINE
    sty zp_lastLine

    jsr .doTextAttributeRam
    jsr writeCurrentGopherToHeadline
    jsr setStatusLineAttributeRam
    jmp .allLinesDisplayed

    lda #4
    sta zp_linkTableIncr


; bank 1
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank
    

; line start for text files
    lda #80
    sta zp_lineLength
    sta zp_vram_screenram

    lda #0
    sta zp_vram_screenram+1

; setup the position in vramLineOffset
    jsr .gotoLineNumber

    ; vram read address is taken from link-table
    ; when not starting display at the first line, we're adding up visible-lengths until we're there
    ; with each line displayed, the read address is just increased by the amount of the previous line.
    ; the write address starts at zero and increments 80 bytes for each line

    ; block copy source address is automatically increased, so we only need to set it once for 25 lines
    ; each copy operation only requires setting target address (increments of 80, unless line-length is longer)
    ;  and nr of characters to copy

; if we have two bytes line-count, visible lines are for sure #VISIBLE_LINES
    lda zp_linecount+1
    beq +
    lda #VISIBLE_LINES
    sta zp_tempX    ; nr of visible lines on screen. is decremented as lines are printed
    jmp ++

; only one byte line-count, check if we have less lines than what fits the screen
+   ldx #VISIBLE_LINES
    cpx zp_linecount
    bcc +
    ldx zp_linecount
+   stx zp_tempX    ; nr of visible lines on screen. is decremented as lines are printed

; clear screen sets register bit to block fill and vram address (18/19 to $0000)
; this also waits for the next vblank period
++  jsr clearScreen

;setup block copy
; set register bit for BLOCK COPY:
    jsr setBlockCopy

; target address
    jsr .writeVramAddress

; block copy source (HB/LB order)
    ldy zp_vram_content_addr
    lda zp_vram_content_addr+1
    ldx #32
    jsr AY_to_vdc_regs_Xp1

    ldy #0
    sty zp_tempY    ; we use zp_tempY to count the current contentline.
    ldy #FIRST_LINE
    sty .currentScreenLine      ; initialize currentScreenLine to topmost visible line

;-----------------------------------------
; here, printing the line is triggered 
;-----------------------------------------
; displaying a screen works like this:
; text is stored in $1000 onwards. 
; visible screen is at $0000
; block copy takes text from $1000 (or higher, for increasing lines) and copies to screen-ram
; for each line, screen-ram is increased by 80
; the block-copy source increases automatically with each copy operation

; renderloop for all visible content lines on screen
-   lda #80
    ldy #0  ; high-byte in Y is zero anyways, because we print 79 chars max
    jsr vdc_do_YYAA_cycles  ; this writes the length to reg #30 to trigger the VDC block copy operation
                            ; the destination location is updated by the vdc automatically

    jsr .incVramBackbufferPosition  ; where we read line information for block copy
    jsr .incOutputLineNumber        ; where we write lines to
    inc zp_tempY    ; content line increasing
    dec zp_tempX    ; content lines left to print
    inc .currentScreenLine

; is the screen full?
    ldx .currentScreenLine
    cpx #VISIBLE_LINES+1
    beq .allLinesDisplayed

    jmp -

.allLinesDisplayed

    jmp drawPlainTextStatusline

.doTextAttributeRam
    jsr setBlockFill

; set lines 1 - 23 to charset1, text black data
; screen-ram
    lda #%10000000
    ldy #$50
    ldx #$08
    jsr A_to_vram_XXYY

    ;set count
    lda #$2f    ;lowbyte
    ldy #$07    ;highbyte
    jmp vdc_do_YYAA_cycles

.writeHexValue
    pha
    jsr .hiNybToHex
    ldx #7
    jsr A_to_vram_XXYY

    pla
    jsr .loNybToHex
    ldx #7
    iny
    jmp A_to_vram_XXYY

.hiNybToHex
    lsr
    lsr
    lsr
    lsr
    jmp makeItHex

.loNybToHex
    and #%00001111
    jmp makeItHex


; use jsr AY_to_vdc_regs_18_19 to set the vram location of the first character
.printUntilNull
    ldy #0
-   lda (zp_memPtr),y
    beq +
    jsr toScreencode
    ldx #31
    jsr A_to_vdc_reg_X
    iny
    jmp -

+   rts

drawPlainTextStatusline
    jsr setBlockFill

    lda #$20
    ldy #$07
    ldx #$80
    jsr A_to_vram_XXYY

    ;set count
    lda #$50    ;lowbyte
    ldy #$00    ;highbyte
    jsr vdc_do_YYAA_cycles

    ; draw topmost linenr and total nr of lines
;    lda #$0f
;    ldy #$80
;    jsr AY_to_vdc_regs_18_19

    ; draw topmost linenr and total nr of lines
    lda #$07
    ldy #$80
    jsr AY_to_vdc_regs_18_19

    lda #<.textLineNr
    sta zp_memPtr
    lda #>.textLineNr
    sta zp_memPtr+1

    jsr .printUntilNull

    lda zp_linenumber_start+1
    jsr .hiNybToHex
    jsr printAcc
    lda zp_linenumber_start+1
    jsr .loNybToHex
    jsr printAcc
    lda zp_linenumber_start
    jsr .hiNybToHex
    jsr printAcc
    lda zp_linenumber_start
    jsr .loNybToHex
    jsr printAcc

    lda #'/'
    jsr toScreencode
    jsr printAcc

    lda zp_linecount+1
    jsr .hiNybToHex
    jsr printAcc

    lda zp_linecount+1
    jsr .loNybToHex
    jsr printAcc

    lda zp_linecount
    jsr .hiNybToHex
    jsr printAcc

    lda zp_linecount
    jsr .loNybToHex
    jsr printAcc
    
    rts

.gotoLineNumber
; go to the right vram offset
    
    sec
    lda zp_linenumber_start
    sbc zp_firstVramContentLine
    sta zp_tempCalc
    lda zp_linenumber_start+1
    sbc zp_firstVramContentLine+1
    sta zp_tempCalc+1

; linecount x 80 should be the offset to the first visible line in vram backbuffer
    ldx #80      ; plain text
    stx zp_tempX
    jsr multiply    ; multiplies zp_tempX with zp_tempCalc. result: A=LB, Y=HB

    clc
    adc #<VRAM_CONTENT
    sta zp_vram_content_addr
    tya
    adc #>VRAM_CONTENT
    sta zp_vram_content_addr+1
    rts

.incVramBackbufferPosition
    clc
    lda zp_vram_content_addr
    adc #80
    sta zp_vram_content_addr
    bcc +
    inc zp_vram_content_addr+1
    
+   rts
    nop

.incOutputLineNumber
    clc
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


; scrolling up means text goes down
scrollTextScreenUpOneLine
    ; block copy from screenline 1-22 to 2-23 (22>23, 21>22, ...)
    jsr moveLinesDown
    
    ; then copy the content of the first screenline from ram to vram
    ; while this routine should only deal with VRAM, we are doing RAM pointers here.
    ; might be a code smell, we'll see.
    ; vram line 1. zp_linenumber start should be this
    lda zp_linenumber_start
    sta zp_tempCalc
    lda #0
    sta zp_tempCalc+1

    ldx zp_linkTableIncr
    stx zp_tempX
    jsr multiply    ; result A=lo, Y=hi
    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    ;AY hold VRAM target (HB/LB order)
    ldy vdc_lineoffsets
    lda vdc_lineoffsets+1
    
    jmp copyTLineToVram

; scrolling down means text goes up
scrollTextScreenDownOneLine
    ; block copy from screenline 1-22 to 2-23 (1>2, 2>3, ...)
    jsr moveLinesUp

    ; then copy the content of the last screenline from ram to vram
    ; while this routine should only deal with VRAM, we are doing RAM pointers here.
    ; might be a code smell, we'll see.
    ; vram line 23. zp_linenumber+VISIBLE_LINES start should be this
    clc
    lda zp_linenumber_start
    adc #VISIBLE_LINES-1
    sta zp_tempCalc
    lda zp_linenumber_start+1
    adc #0
    sta zp_tempCalc+1

    ldx zp_linkTableIncr
    stx zp_tempX
    jsr multiply    ; result A=lo, Y=hi
    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    ; then copy the content of the last screenline from ram to vram
    ; vram line 23
    ldy vdc_lineoffsets+44
    lda vdc_lineoffsets+45

    ;AY hold VRAM target (HB/LB order)
    jmp copyTLineToVram


.textLineNr             !text "LineNr: ",0
.currentScreenLine      !byte 0     ; what line are we rendering currently


