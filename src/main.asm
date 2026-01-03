!src "src/inc/c128.asm"

*=$1c01
!byte $0b,$1c,$b5,$07,$9e,$20,$37,$34,$32,$34,$00,$00,$00

; these are the mappings from basic's bank command to the actual mmu config-register values
mmuBankConfig       !byte $3F,$7F,$BF,$FF,$16,$56,$96,$D6,$2A,$6A,$AA,$EA,$06,$0A,$01,$00

; this is used to keep an original copy of the zero-page range we're using. is restored when program ends
zpStore             !fill 134
keyStore            !fill 10    ;keeps values $1000-$1009

fileOpError         !byte 0

size_vram_content   !word 6143  ; available vram for content (after screen-ram (2k), attribute-ram (2k) and charset (4k))
vram_block_offsets  !fill 14    ; stores linkTablePosition values for fast ram-vram copy of blocks

*=$1d00
main
    jsr initc128
    jsr c128detect
    jsr disableBasicRom

    jsr initHistoryStack

; load from network
    ;jsr setInitialGopherHostSelector
    jsr loadInitialPageFromDisk
    jmp .afterRequest

requestNewContent
    jsr requestContent

    ; set the cursor line to zero here, that's important for calculating the right screen area for display
.afterRequest
    jsr .setToFirstContentLine

; do the processing
    lda #$0d
    jsr bsout
    jsr doFast

    lda zp_pageType
    cmp #$30    ;text file
    bne +
    jsr parsePlainText
    lda #4
    sta zp_linkTableIncr
    jsr copyTextToVram
    lda #1
    sta zp_scrollModeCrsr
    jmp .doneProcessing

+   cmp #$31    ;gopher file
    bne .doneProcessing
    jsr parseGopher
    lda #10
    sta zp_linkTableIncr
    jsr copyGopherToVram
    lda #0
    sta zp_scrollModeCrsr
.doneProcessing
; history stack only if "active" navigation, not going back and forth on stack
    lda zp_navModeHistory
    beq +
    jsr pushToHistoryStack  ; only push to stack when not navigating in history
+   ;jsr writeCurrentGopherToHeadline

.resetDisplay
    lda #0
    sta zp_linenumber_start
    sta zp_linenumber_start+1
    sta zp_cursorLineContent
    sta zp_cursorLineContent+1

    lda #FIRST_LINE
    sta zp_cursorLineScreen

    lda zp_scrollModeCrsr
    beq +
    jsr copyTextToVram
    jmp .updateDisplay
+   jsr copyGopherToVram

; this shows that we can start on a later line with correct display
;    lda #3
;    sta zp_linenumber_start
;    sta zp_cursorLineContent

; display page on top
.updateDisplay
    lda zp_pageType
    cmp #$30
    bne +
    jsr displayTextmode ; disable this b/c display text is already done by copying
    ; jsr to either scroll up or down one line
    jmp getUserInput
+   jsr displayGopher

; get user input to see what to do next
; useful special function keys might be
; - go to top of page           - Home
; - go to root selector         - F1
; - go to defined start gopher  - F3
; - previous page (in history)  - commodore + cursor left

; - next page (in history)      - commodore + cursor right
; - page up/down                - commodore + up/down

getUserInput
-   jsr k_getin
    beq -

    cmp #17     ;cursor down
    bne +
    jmp .tryCursorDown

; cursor up and down should know two different operation modes
; for gopher directories, do cursor movement
; for document display, scroll full lines

+   cmp #145 ; cursor up
    bne +
    jmp .tryCursorUp

+   cmp #157 ;cursor left - previous page in history, if available
    bne +
    lda #0
    sta zp_navModeHistory
    jmp .prevHistoryPage

+   cmp #29 ;cursor right - next page in history, if available
    bne +
    lda #0
    sta zp_navModeHistory
    jmp .nextHistoryPage

+   cmp #$31 ; 1 . first bookmark
    bne +
    jsr setBkm1GopherHostSelector
    jsr setFromHistory
    jmp requestNewContent

+   cmp #$32 ; 2 . second bookmark
    bne +
    jsr setBkm2GopherHostSelector
    jsr setFromHistory
    jmp requestNewContent

+   cmp #'P'
    bne +
;    lda zp_pageType
;    cmp #'s'
;    bne getUserInput
    jmp playbackCurrentAudio

+   cmp #'C'
    bne +
    jmp mexConnectionCheck

+   cmp #13 ;return key
    bne ++
    
    lda zp_pageType
    cmp #$31                ; only accept return key when showing a gopher dir
    bne getUserInput

    lda #1
    sta zp_navModeHistory   ; not navigating in history
    lda zp_currentType
    cmp #$30    ; text file. show in gopher viewer (special plain text handling mode)
    beq .validLineSelected
    cmp #$31    ; gopher dir. show in gopher viewer
    beq .validLineSelected
    cmp #$34    ; binary
    bne +
    jsr setNewGopherHostSelector
    jsr createUnsupportedPage
    jmp .afterRequest
+   cmp #$35    ; dos binary
    bne +
    jsr setNewGopherHostSelector
    jsr createUnsupportedPage
    jmp .afterRequest    
+   cmp #$36    ; uuencoded text (probably a binary?)
    bne +
    jsr setNewGopherHostSelector
    jsr createUnsupportedPage
    jmp .afterRequest
+   cmp #$39 ; 9 -> generic binary
    bne .checkIfSoundLine
    jsr setNewGopherHostSelector
    jsr createUnsupportedPage
    jmp .afterRequest

.checkIfSoundLine
    cmp #'s'    ; sound file. show information page
    beq +
    jmp getUserInput
+   jsr createSoundPage
    jmp .afterRequest

.validLineSelected
    sta zp_pageType     ; this is important. all processing of the next page is based on this
    inc zp_historyStackPos
.prepareRequest
    jsr setNewGopherHostSelector
    jmp requestNewContent

++  cmp #19 ;home
    bne +
    jmp .resetDisplay

+   cmp #'H' ;go home
    bne +
    jsr setInitialGopherHostSelector
    jmp requestNewContent

+   cmp #'S' ; go to startpage
    bne +
    jsr loadInitialPageFromDisk
    jmp .afterRequest

+   cmp #'R' ;reload
    bne +
    jmp requestNewContent

+   cmp #'G' ; goto
    bne +
    jmp activateAddressEnterMode

;+   cmp #'D' ; download
;    bne +
;    jsr saveContentToDisk
;    ;jsr downloadWic2disk
;    jmp getUserInput

+   cmp #'L' ; load from disk
    bne +
    jsr loadContentFromDisk
    jmp getUserInput

+   cmp #'F'; speed
    bne ++
    lda zp_fastmode
    beq +
    jsr doSlow
    dec zp_fastmode
    jmp -
+   jsr doFast
    inc zp_fastmode
    jmp -

++  cmp #'X'
    beq +
    jmp getUserInput

; we're done, clean the campground before leaving
;    lda #27
;    jsr bsout
;    lda #'X'
;    jsr bsout
.exitGracefully
+   jmp exitc128
    nop ; only for debugging purposes to give breakpoints a safe spot

.setToFirstContentLine
    lda #0
    sta zp_linenumber_start
    sta zp_linenumber_start+1
    sta zp_cursorLineContent
    sta zp_cursorLineContent+1
    sta zp_firstVramContentLine
    sta zp_firstVramContentLine+1
    lda #FIRST_LINE
    sta zp_cursorLineScreen
    rts

; ---------------------
; navigation logic
; ---------------------
; cursor down:
; - when above last display line (eg 23), just move cursor down 1 line. ie screen-line +1 and content-line +1
; - when at last display line, check scroll position: above bottom: content-line+1, screen-line stays, linenumber+1
;                                                     bottom: do nothing

.tryCursorDown
    lda zp_scrollModeCrsr
    beq +
    jmp .tryLineScrollDown

+   lda zp_cursorLineScreen

    ldy zp_linecount+1
    bne +       ; we have more content lines than what fits the screen. no need to check for lower cursor pos
    cmp zp_linecount
    bne +
    jmp getUserInput   ; less content than screen lines, and we reached the last content line

+   cmp zp_lastLine ; is cursor on last screen-line?
    bne .cursorDown   ; not on the last screen-line, draw one line below

    ; on the last visible line, check if we can scroll down
    jmp .tryCursorScrollDown

.cursorDown
+   jsr removeCursor
    inc zp_cursorLineContent
    bne +
    inc zp_cursorLineContent+1

+   inc zp_cursorLineScreen
    jsr drawCursor

    jmp getUserInput

.tryLineScrollDown
    lda zp_linenumber_start+1
    cmp zp_linecount+1
    bcc .doLineScrollDown
    clc
    lda zp_linenumber_start
    adc #VISIBLE_LINES
    cmp zp_linecount
    bcc .doLineScrollDown
    jmp getUserInput

.tryCursorScrollDown
    lda zp_cursorLineContent+1
    cmp zp_linecount+1
    bcc .doLineScrollDown
    lda zp_cursorLineContent
    cmp zp_linecount
    bcc .doLineScrollDown
    jmp getUserInput

.doLineScrollDown
    lda zp_scrollModeCrsr
    bne +
    inc zp_cursorLineContent
    bne +
    inc zp_cursorLineContent+1
+   inc zp_linenumber_start ; no. increase linenumber and update display. ie scroll down
    bne +
    inc zp_linenumber_start+1
+   ldx zp_pageType
    cpx #$30 ; text is handled dedicated, all other page types are considered gopher (as these show a cursor)
    beq +   
    jsr scrollGopherScreenDownOneLine
    jmp .updateDisplay
+   jsr scrollTextScreenDownOneLine
    jmp .updateDisplay

.calculateLinkTableOffset
    lda zp_linenumber_start
    sta zp_tempCalc
    lda zp_linenumber_start+1
    sta zp_tempCalc+1
    lda zp_linkTableIncr
    sta zp_tempX
    jsr multiply

    clc
    adc #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition

    tya
    adc #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    rts

.tryCursorUp
    lda zp_scrollModeCrsr
    beq +
    jmp .tryLineScrollUp

+   lda zp_cursorLineScreen
    cmp #FIRST_LINE     ; is cursor on first line on screen?
    bne +               ; no
    ;yes. try to scroll up
    jmp .tryLineScrollUp

    ;no. just draw cursor one line above
+   jsr .drawCursorOneAbove
    jmp getUserInput

.drawCursorOneAbove
    jsr removeCursor
    sec
    lda zp_cursorLineContent
    sbc #1
    sta zp_cursorLineContent
    bcs +
    dec zp_cursorLineContent+1
+   dec zp_cursorLineScreen
    jmp drawCursor

.tryLineScrollUp
    ; is the first visible line also the first vram line?
    lda zp_linenumber_start+1
    cmp zp_firstVramContentLine+1
    bne .doLineScrollUp ; more lines in vram. scroll up
    lda zp_linenumber_start
    cmp zp_firstVramContentLine
    bne .doLineScrollUp ; more lines in vram. scroll up

    jmp getUserInput

.doLineScrollUp
+   sec
    lda zp_linenumber_start
    sbc #1
    sta zp_linenumber_start
    bcs +
    dec zp_linenumber_start+1

+   sec
    lda zp_cursorLineContent
    sbc #1
    sta zp_cursorLineContent
    bcs +
    dec zp_cursorLineContent+1
+   ldx zp_pageType
    cpx #$30 ; text is handled dedicated, all other page types are considered gopher (as these show a cursor)
    beq +   
    jsr scrollGopherScreenUpOneLine
    jmp .updateDisplay
+   jsr scrollTextScreenUpOneLine
    jmp .updateDisplay

.calcCursorLineScreen
    clc
    lda #FIRST_LINE  ; second line on screen is top-most one
    adc zp_cursorLineContent
    sta zp_tempCalc
    lda zp_cursorLineContent+1
    adc #0
    sta zp_tempCalc+1

    sec
    lda zp_tempCalc
    sbc zp_linenumber_start
    sta zp_tempCalc
    lda zp_tempCalc+1
    sbc zp_linenumber_start+1
    sta zp_tempCalc+1

    lda zp_tempCalc
    sta zp_cursorLineScreen
    rts
    nop

; when navigating through history entries, the pointers to host,port,selector refer to bank0
;  as opposed to bank1 when navigating based on selection from the current page
.nextHistoryPage
    clc
    lda zp_historyStackPos
    adc #1
    cmp zp_historyStackSize
    bne +   
    jmp getUserInput   ; no next entry in stack

+   inc zp_historyStackPos
    jmp .commonHistoryPageHandling

.prevHistoryPage
    lda zp_historyStackPos
    bne +   
    jmp getUserInput   ; no previous entry in stack

+   dec zp_historyStackPos
.commonHistoryPageHandling
    jsr .setToFirstContentLine
    jsr readFromStack
    jmp .prepareRequest

; set the relevant content pointers to their initial position
; this is done when writing downloaded data and when starting to parse
; and will probably also be done when displaying content on screen
initContentAddress
    lda #<CONTENT_ADDRESS
    sta zp_contentAddress
    lda #>CONTENT_ADDRESS
    sta zp_contentAddress+1

initLinkTableAddress
    lda #<LINKTABLE_ADDRESS
    sta zp_linkTablePosition
    lda #>LINKTABLE_ADDRESS
    sta zp_linkTablePosition+1

    rts


; used for regular runtime (should leave us with $1c01 - $bfff for program code. close to 42 kB )
disableBasicRom
    lda #%00001110
    sta $ff00
    rts

    ; enable I/O (setting bit0 if $ff00 to 0)
enableIO
    pha
    lda $ff00
    and #%11111110
    sta $ff00
    pla
    rts

disableIO
    pha
    lda $ff00
    ora #%00000001
    sta $ff00
    pla
    rts

; goes to 2 mhz
; if super-cpu is present, goes to 20 mhz
doFast
    lda $ff00
    pha

    jsr setBank15
    ;set fast flag
    LDA $D011
    AND #$6F
    STA $D011
    LDA #$01
    STA $D030

    lda $D0B9
    bmi +       ; top-most bit set, no super-cpu detected
    sta $d07b   ; turbo on. 20 mhz super-cpu speed

+   pla
    sta $ff00
    RTS

setBank15
    LDA #$00
    STA $FF00
    rts

; goes to 1 mhz
; if super-cpu is present, disable turbo
doSlow
    lda $ff00
    pha

    jsr setBank15
    LDA #$00
    STA $D030
    LDA $D011
    AND #$7F
    ORA #$10
    STA $D011

    lda $D0B9
    bmi +       ; top-most bit set, no super-cpu detected
    sta $d07a   ; set super-cpu turbo off (ie to 1 mhz from the c128's speed register we just set)

+   pla
    sta $ff00
    rts

k_indsta
    pha
    lda mmuBankConfig,x	; MMU Bank Configuration Values
    tax
    pla
    jmp $02AF	; Bank Poke Subroutine


.detectAndDisableSuperCpu
    lda $D0B9
    bmi +   ; top-most bit set, no super-cpu detected

    lda #0
    sta $D07A   ; set super cpu to normal speed (ie 1 or 2 mhz, but not 20)

+   rts

!src "src/backend/io/networkWic.asm"
!src "src/init/c128init.asm"
!src "src/init/c128detect.asm"
!src "src/backend/io/networkCommon.asm"

!src "src/lib/wic64/wic64.asm"
!src "src/frontend/io/loadCharset.asm"
!src "src/backend/io/disk/saveToDisk.asm"
!src "src/backend/io/disk/disk.asm"
!src "src/backend/io/disk/loadContent.asm"
!src "src/backend/io/wic2disk.asm"
!src "src/frontend/output/vdc.asm"
!src "src/history.asm"
!src "src/backend/memory/georam.asm"
!src "src/backend/memory/reu.asm"

!src "src/backend/parsers/parseGopher.asm"
!src "src/backend/parsers/parsePlainText.asm"
!src "src/backend/parsers/commonParse.asm"
!src "src/frontend/output/copyTextToVram.asm"
!src "src/frontend/output/copyGopherToVram.asm"
!src "src/frontend/output/copyCommon.asm"
!src "src/frontend/output/uihelper.asm"
!src "src/frontend/output/displayText.asm"
!src "src/frontend/output/displayGopher.asm"
!src "src/frontend/input/address.asm"
!src "src/frontend/pages/information.asm"
;!src "src/pages/sound.asm"

txtReu      !text "REU: ",0
txtGeoRam   !text "GeoRAM: ",0

; memory map
; bank 0 - $1c01 programcode
; bank 0 - after programmcode: linktable. each line of gopher content is represented here with a 10 byte long entry.
; - 1 byte for line type (gopher dir, text, audio, image, etc.)
; - 2 bytes for offset to linestart+1 (start at text, not at type). relative to $1:0400
; - 1 byte for length of visible content (78 max)
; - 2 bytes for offset to selector
; - 2 bytes for offset to host
; - 2 bytes for offset to port
; multiline content of a gopher line would link to text-start for each screen line
;  selector, host, port would link to the same content position for each screen line (max 3 full lines and then some)

; bank 0 - $c000 history stack (usually screen editor and monitor)

; bank 1
; $0400 content from gopher server. unmodified

; vdc-ram
; $0000 screen ram
; $0800 attribute ram
; $1000 visible content in a condensed form (from eg $1:7f01 to next tab)
;       this is block copied to screen by using the $1:7f00 entry of the line (first offset +1) and the length (offset 3 in linktable)
;       to copy lines 10-32 (23 lines), the code will add up all the lengths until line 10 and then copy each line
; $3000 charset (4kb)

LINKTABLE_ADDRESS   !byte 0