; this handles the history stack
;  writing to the stack
;  reading from the stack
;  pushing to the stack
;  popping from the stack
;  clearing the stack

; HISTORY_TABLE contains 2-byte pointers to each entry.
; HISTORY_STACK has 3 2-byte entries and one host:port string and one selector string after (both 0-byte terminated)

; type and strings are written when a page is visited
; when visiting a history location, these strings are recovered into tcpOpen and tcpWrite
; when a page is left, the current content line and the linenumber are written to the stack
;  these are 2 bytes each
; so, in total, one stack entry is 6 bytes + string-length long
; each entry is reachable through the HISTORY_TABLE
; when the stack is full, the oldest entry is removed

; 2 bytes page type (mostly only 1 byte is used)
; 2 bytes content line (written when leaving)
; 2 bytes screenline start (written when leaving)
; x bytes "host:port" text, zero-byte terminated
; x bytes "selector" text, zero-byte terminated

!zone historyStack

; pushing to the history stack takes the data from tcpOpenHostPort and tcpWriteSelector from networkWic.asm
;  these are in bank 0 and already in the format we'll want to re-use them.
pushToHistoryStack
    ; HISTORY_TABLE is accessed via x-offset only (128 entries, 256 bytes max)
    ; HISTORY_STACK is accessed via (zp_historyStackAddress),y (pointing to the beginning of an entry)
;    jsr .bankRam00

    jsr .resetHistoryStackAddress

    ; get the offset in HISTORY_TABLE for stack entry to write
;    inc zp_historyStackPos
    clc
    lda zp_historyStackPos  ; we load position, not size, because we might be in the middle of the history
    adc zp_historyStackPos
    tax

; set historystackaddress to $b100 + offset from history_table
    lda HISTORY_TABLE,x
    sta zp_historyStackAddress
    inx
    lda HISTORY_TABLE,x
    sta zp_historyStackAddress+1

.doWriting
; write type to history stack (HB is always zero for now)
    ldy #0
    lda zp_currentType
    sta (zp_historyStackAddress),y
    tya
    iny
    sta (zp_historyStackAddress),y
    iny
; skip 4 entries (reserved for content line and screenline-start)
    lda #0
    sta (zp_historyStackAddress),y
    iny
    lda #0
    sta (zp_historyStackAddress),y
    iny
    lda #0
    sta (zp_historyStackAddress),y
    iny
    lda #0
    sta (zp_historyStackAddress),y
    iny
    sty zp_tempY

; write host:port and selector to the history text-area
    lda #<tcpOpenHostPort
    sta zp_memPtr  ;we're mis-using this here, as we're not doing indfet
    lda #>tcpOpenHostPort
    sta zp_memPtr+1

    lda tcpOpenSizeL
    sta zp_tempCalc
    lda tcpOpenSizeH
    sta zp_tempCalc+1

    jsr .writeToHistoryStack

    jsr .writeCrByteToHistoryStack

    lda #<tcpWriteSelector
    sta zp_memPtr
    lda #>tcpWriteSelector+1
    sta zp_memPtr+1

    lda tcpWriteSizeL
    sta zp_tempCalc
    lda tcpWriteSizeH
    sta zp_tempCalc+1

; write the selector
    jsr .writeToHistoryStack
    jsr .writeTabByteToHistoryStack

    lda zp_historyStackPos
    sta zp_historyStackSize
    inc zp_historyStackSize

; calculate offset for next table entry (2 bytes per entry)
    clc
    lda zp_historyStackSize
    adc zp_historyStackSize
    tax

; add value of y (our write offset) to address of current entry
;  and store it as next history table entry
    clc
    lda zp_historyStackAddress
    adc zp_tempY
    sta HISTORY_TABLE,x
    lda zp_historyStackAddress+1
    adc #0
    inx
    sta HISTORY_TABLE,x



    jmp disableBasicRom ; return to "regular" mmu setup for program execution

.writeToHistoryStack
    ; use zp_tempX for the reading-y
    ldx #0
    stx zp_tempX
-   ldy zp_tempX
    lda (zp_memPtr),y
    cmp #':'
    bne +
    lda #9  ;replace : with tab
+   ldy zp_tempY
    sta (zp_historyStackAddress),y
    inc zp_tempY
    inc zp_tempX
    dec zp_tempCalc
    bne -
    rts

.writeCrByteToHistoryStack
    ldy zp_tempY
    lda #$0d
    sta (zp_historyStackAddress),y
    inc zp_tempY
    rts

.writeTabByteToHistoryStack
    ldy zp_tempY
    lda #$9
    sta (zp_historyStackAddress),y
    inc zp_tempY
    rts

writeCursorPosToStack

    rts

readFromStack
    clc
    lda zp_historyStackPos
    adc zp_historyStackPos
    tax

    lda HISTORY_TABLE,x
    sta zp_historyStackAddress
    lda HISTORY_TABLE+1,x
    sta zp_historyStackAddress+1

; byte 0-1: current type of page (0 for text, 1 for gopher, etc)
    ldy #0
    lda (zp_historyStackAddress),y
    sta zp_currentType
    sta zp_pageType
    iny

;bytes 2-5: scroll and cursor position when we left (not implemented yet)
    iny
    iny
    iny
    iny
    iny
    
    clc
    tya
    adc zp_historyStackAddress
    sta zp_currentHostPtr
    lda zp_historyStackAddress+1
    sta zp_currentHostPtr+1

; byte 6 until zero-byte is host:port
    ldx #0
-   lda (zp_historyStackAddress),y
    cmp #9
    beq +
;    sta tcpOpenHostPort,x
    inx
    iny
    jmp -

+   iny ; go past the ':'-byte from just before

    clc
    tya
    adc zp_historyStackAddress
    sta zp_currentPortPtr
    lda zp_historyStackAddress+1
    sta zp_currentPortPtr+1

; read until $0d, which is the end of the port
    ldx #0
-   lda (zp_historyStackAddress),y
;    sta tcpWriteSelector,x
    cmp #$0d
    beq +
    inx
    iny
    jmp -

+   iny ; skip the separator
    clc
    tya
    adc zp_historyStackAddress
    sta zp_currentSelectorPtr
    lda zp_historyStackAddress+1
    sta zp_currentSelectorPtr+1

    rts

initHistoryStack
    lda #0
    sta zp_historyStackPos
    sta zp_historyStackSize

;    jsr .bankRam00
    ldx #0
-   sta HISTORY_TABLE,x
    dex
    bne -

.resetHistoryStackAddress
    lda #<HISTORY_STACK
    sta HISTORY_TABLE
    lda #>HISTORY_STACK
    sta HISTORY_TABLE +1

    lda #<HISTORY_STACK
    sta zp_historyStackAddress
    lda #>HISTORY_STACK
    sta zp_historyStackAddress+1

    rts


; all roms disabled, I/O disabled, all ram of block 0
;.bankRam00
;    lda #%00111111
;    sta $ff00
;    rts

.stackInputAddr !word 0