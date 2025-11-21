; this handles the history stack
;  writing to the stack
;  reading from the stack
;  pushing to the stack
;  popping from the stack
;  clearing the stack

; the history stack has a text-area that contains "host:port" and "selector" in ascii.
;  these are zero-byte terminated
;  when visiting a history location, these are written to tcpOpen and tcpWrite
; a history stack entry contains type, pointer to host:port and pointer to selector
;  these are written after "actively" entering a new page (ie the user selected it)
; when a page is left, the current content line and the linenumber are written to the stack
;  these are 2 bytes each
; so, in total, one stack entry is 10 bytes long
; the stack is full when 24 entries are reached (for a start)
;  when the stack is full, the oldest entry is removed

; 2 bytes page type (mostly only 1 is used)
; 2 bytes pointer to host:port
; 2 bytes pointer to selector
; 2 bytes content line (written when leaving)
; 2 bytes screenline start (written when leaving)

!zone historyStack

pushToHistoryStack
; get offset in history stack to write current values to
; for each pre-existing entry we need to move on 12 bytes
    jsr .resetHistoryStackAddress

    ldy #0
    ldx zp_historyStackPos  ; we load position, not size, because 
    beq .doWriting   ; stack empty, skip increasing address
    
-   clc
    lda zp_historyStackAddress
    adc #10
    sta zp_historyStackAddress
    bcc +
    inc zp_historyStackAddress+1
+   dex
    bne -
    tay

.doWriting
+   jsr .bankRam00

; write host:port and selector to the history text-area

; write 6 bytes to the stack (type, pointers to host:port and selector)
; x holds the read offset of current pointer values
; y holds the write offset to the history stack
    lda #6
    sta zp_tempX

    ldx #0
-   lda zp_currentSelectorPtr,x
    sta (zp_historyStackAddress),y
    inx
    iny
    dec zp_tempX
    bne -

    inc zp_historyStackPos
    lda zp_historyStackPos
    sta zp_historyStackSize

    jmp disableBasicRom ; return to "regular" mmu setup for program execution

writeCursorPosToStack

    rts

readFromStack
    rts

initHistoryStack
    lda #0
    sta zp_historyStackPos
    sta zp_historyStackSize
.resetHistoryStackAddress
    lda #<HISTORY_STACK
    sta zp_historyStackAddress
    lda #>HISTORY_STACK
    sta zp_historyStackAddress+1
    rts


; all roms disabled, I/O disabled, all ram of block 0
.bankRam00
    lda #%00111111
    sta $ff00
    rts

