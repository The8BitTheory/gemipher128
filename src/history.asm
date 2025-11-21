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

pushToHistoryStack
    ; HISTORY_TABLE is accessed via x-offset only (128 entries, 256 bytes max)
    ; HISTORY_STACK is accessed via (zp_historyStackAddress),y (pointing to the beginning of an entry)
;    jsr .bankRam00

    jsr .resetHistoryStackAddress

    ; get the offset in HISTORY_TABLE for stack entry to write
    lda zp_historyStackPos  ; we load position, not size, because we might be in the middle of the history
    beq .doWriting   ; stack empty, skip increasing address
    clc
    adc zp_historyStackPos
    tax

    clc
    lda HISTORY_TABLE,x
    adc zp_historyStackAddress
    sta zp_historyStackAddress
    inx
    lda HISTORY_TABLE,x
    adc zp_historyStackAddress+1
    sta zp_historyStackAddress+1

.doWriting
; write type to history stack (HB is always zero for now)
    ldy #0
    lda zp_currentType
    sta (zp_historyStackAddress),y
    tya
    iny
    sta (zp_historyStackAddress),y
    ; skip 4 entries (reserved for content line and screenline-start)
    iny
    iny
    iny
    iny
    iny
    sty zp_tempY

; write host:port and selector to the history text-area
    lda #zp_currentHostPtr
    sta c_fetch_zp

    jsr .writeToHistoryStack

    ldy zp_tempY
    iny
    lda #':'
    sta (zp_historyStackAddress),y
    iny
    sty zp_tempY

    lda #zp_currentPortPtr
    sta c_fetch_zp

    jsr .writeToHistoryStack
    jsr .writeZeroToHistoryStack

    lda #zp_currentSelectorPtr
    sta c_fetch_zp

    jsr .writeToHistoryStack
    jsr .writeZeroToHistoryStack

    ldx #0
    lda zp_tempY
    sta HISTORY_TABLE,x
    lda #0
    sta HISTORY_TABLE,x

    inc zp_historyStackPos
    lda zp_historyStackPos
    sta zp_historyStackSize

    jmp disableBasicRom ; return to "regular" mmu setup for program execution

.writeToHistoryStack
    ; use zp_tempX for the reading-y
    ldy #0
    sty zp_tempX
-   ldy zp_tempX
    ldx zp_contentBank
    jsr c_fetch
    beq +
    cmp #9
    beq +
    cmp #$0d
    beq +
    inc zp_tempX
    ldy zp_tempY
    sta (zp_historyStackAddress),y
    inc zp_tempY
    jmp -
+   rts

.writeZeroToHistoryStack
    ldy zp_tempY
    iny
    lda #'0'
    sta (zp_historyStackAddress),y
    iny
    sty zp_tempY
    rts

writeCursorPosToStack

    rts

readFromStack
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
    sta zp_historyStackAddress
    lda #>HISTORY_STACK
    sta zp_historyStackAddress+1

    rts


; all roms disabled, I/O disabled, all ram of block 0
;.bankRam00
;    lda #%00111111
;    sta $ff00
;    rts

