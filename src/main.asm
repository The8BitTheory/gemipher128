; ------------
; memory map
; ------------


; $0.1c01 - $0.afff: programcode. only enable basic-rom when needed. close to 41kB
; $0.b000 - $0.b0ff: history pointers
; $0.b100 - ?????: string entries for history (host:port/selector)
; $0.e000 - $0.ff00: link table -> 7.75 kB

; $1.0400 - $1.dfff: data --> 56 kB


; configuration constants
VRAM_LINE_TABLE = $a800 ; offsets to the lines in vram. written by copyx.asm, read by display.asm

HISTORY_TABLE = $b000   ; room for 128 entries
HISTORY_STACK = $b100   

LINKTABLE_ADDRESS = $e000



; CONTENT describes one full gopher page
CONTENT_BANK = 1
CONTENT_ADDRESS = $0400

CONTENT_END_ADDRESS = LINKTABLE_ADDRESS-$ff


VRAM_CONTENT = $1000    ; the 'invisible' part of vram that stores all text ready for display
VISIBLE_LINES = 23
FIRST_LINE = 1
LAST_LINE = FIRST_LINE+VISIBLE_LINES-1

DMA = $03f0 ;y holds the value for the command register, A holds the value for the MMU configuration.
            ;REC needs to be configured to trigger execution upon writing to $ff00

; bank 1 used for data
;  content data starts at $0400 and goes up.
;  link tables are expected to have 2kb and start at $f700
;  once we have that working, we can think about keeping multiple pages in memory

;  no clue yet whether to work with indirect kernal routines, or with common memory
;  speed is not essential, so I guess we'll go with indirect routines
;  will need to either copy data to bank 0 for VDC-related things, or make VDC libs interact with bank 1

; zero page addresses. we use $0a-$8f ($7a and up is used by vdc-basic)
zp_contentAddress = $0a ; and $0b
zp_linecount = $0c  ; and $0d. the number of lines in the file/directory/... (might be more than what fits RAM or VRAM)
zp_tempX = $0e      ; used to hold x register when working with FAR routines
zp_tempY = $0f    ; used to hold y register when working with FAR routines

zp_contentBank  = $10   
zp_linkTablePosition = $11 ; and $12. contains one 3 or 9-byte entry per textline. starting at $1:f000
zp_fastmode = $13

; used by parseGopher.asm
zp_visibleLength = $14  ; and $15. length of visible text in current line. also used by display.asm

; used by display.asm
; textdisplay
; also using zp_visibleLength
zp_currentLinkTablePtr = $16; and $17   ; where the entry at linkTablePosition points to (related to $1:0400)
zp_vram_content_addr = $18 ; and $19 ;  also used by copytovram.asm
zp_vram_screenram = $1a ; and $1b
zp_linenumber_start = $1c   ; and $1d ; this is the scrolling position. ie the number of the first visible line (in context of the document, not the visible lines)
zp_cursorLineContent = $1e    ; and $1f     ; this is the cursor line relative to the content
zp_cursorPosScreen = $20 ; and $21   this is the cursor position on screen (content line x 80 + top offset - scroll offset)
zp_cursorLineScreen = $22   ; the line on the screen where the cursor is (must be within 1 and 24 or so)
zp_lastLine = $23       ; this is #LAST_LINE when all content lines fit screen lines. is reduced by one for each multi-line. refers to the screen, not the file
zp_scrollDirectionUp = $24  ; 0=up, else=down

; used by copytovram.asm
; zp_vram_content_addr
; zp_linecount
; zp_tempX
; zp_visibleLength
; zp_currentLinkTablePtr
; zp_linkTablePosition
; zp_contentBank
zp_currentType = $25
zp_currentSelectorPtr = $26 ; and $27
zp_currentHostPtr = $28 ; and $29
zp_currentPortPtr = $2a ; and $2b
zp_currentTypePtr = $2c ; and $2d
zp_linkTableIncr = $2e      ; link table has entries of different sizes (gopher=9 bytes, plain text = 3 bytes)
zp_responseSize = $2f ; and $30 ; the nr of bytes we counted for response. upfront information should be in zp_contentLength
zp_scrollModeCrsr = $31 ; 0=cursor movement, else=just scroll screen lines
zp_contentLength = $32; and $33 ; the content length that's reported by the server. zp_responseSize holds the nr bytes we counted

; history.asm
zp_historyStackPos = $34    ; the position (entry) in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackSize = $35   ; the nr of entries in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackAddress = $36; and $37. holds the address of the current entry (ie HISTORY_STACK + stackpos*12)
zp_hostSelBank = $38        ; where to read host,port,selector from (1 for current page, 0 for history)
zp_navModeHistory = $39     ; 0=navigation via history stack (cursor keys), else=navigation via return key
                            ; (0 means no stack updates, only changing stack position, 1 means push new page to stack)
zp_tempCalc     = $3a ; and $3b

zp_lastVramContentLine = $3c ; and $3d. this is used to stop scrolling and load more in to vram. document might be larger than vram (esp with 16kb VRAM)
zp_memPtr   = $3e ; and $3f. can be used for any temporary indirect read or write memory operation
zp_pageType = $40 ; keeps type of current page persistently loaded. we run into conflicts with "type of current cursor positon" otherwise
zp_tempA = $41 ; used to keep temporary value when pha/pla is not sufficient

zp_vramLineOffsets = $42 ; and $43
zp_firstVramContentLine = $44 ; and $45
zp_vramBlock    = $46   ; which vram block we're currently working with. used by parse, copy, and display
zp_reu_blocks = $47  ; and $48. 0=not detected, above=nr of 64kb blocks/banks
zp_georam_blocks = $49 ; 0=no, above=nr of 64kb blocks/banks
zp_perm_target = $4a    ; where to store downloaded data. 0=bank1, 1=reu, 2=georam

; common memory area below $0400
c_fetch = $02a2
c_fetch_zp = $02aa
c_stash = $02af
c_stash_zp = $02b9


; basic rom lo $4000-$7fff
b_fast = $77b3
b_slow = $77c4

; basic rom hi $8000-$bfff

; monitor, screen editor $c000-$cfff

; i/o $d000-$dfff

; kernal $e000-$ffff
k_plot = $fff0
k_primm = $ff7d
k_getin = $eeeb
;k_scnkey= $c55d
k_scnkey= $c651
bsout = $ffd2

!macro print textaddress {
    pha
    txa
    pha

    ldx #0
-   lda textaddress,x
    beq +
    jsr bsout
    inx
    jmp -

+   pla
    tax
    pla
}

*=$1c01
!byte $0b,$1c,$b5,$07,$9e,$20,$37,$34,$32,$34,$00,$00,$00

; these are the mappings from basic's bank command to the actual mmu config-register values
mmuBankConfig       !byte $3F,$7F,$BF,$FF,$16,$56,$96,$D6,$2A,$6A,$AA,$EA,$06,$0A,$01,$00

; this is used to keep an original copy of the zero-page range we're using. is restored when program ends
zpStore             !fill 134
keyStore            !fill 10    ;keeps values $1000-$1009

fileOpError         !byte 0

; used by display.asm
; cursorOffsets holds the vram-offset for each cursor position
; this is required to keep track of multi-line text. otherwise we'd just go in incs of 80
; 25 lines, two bytes each. 23 sould be sufficient, but we can always reduce that
cursorOffsets  !word 80    ; first offset is always 80 (as long as we're starting in second screenline)
                !fill 48

retries        !byte 0

size_vram_content   !word 6143  ; available vram for content (after screen-ram, attribute-ram and charset)
vram_block_offsets  !fill 14    ; stores linkTablePosition values for fast ram-vram copy of blocks

*=$1d00
main
; disable case switching via Shift-Commodore
    lda #11
    jsr bsout

; switch to lower-case charset
    lda #14
    jsr bsout

    jsr b_slow

    lda #$93 ; clear screen
    jsr bsout

    jsr detectAndInitSwiftlink
    bcc +
    jmp .exitGracefully
    ;jsr detectGeoRAM

;    jsr k_primm
;    !pet "pet klein GROSS",0
;    jsr k_primm
;    !text "ascii klein GROSS",0
+
    lda #0
    sta zp_fastmode

    jsr disableBasicRom

    jsr saveZp

    jsr initVdc
    

;    jsr detectAndInitializeWic64
    
    jsr disableBasicRom
    jsr initHistoryStack

    jsr requestContentViaSwiftlink
    jmp .afterRequest

; load from network
    ;jsr setInitialGopherHostSelector
    jsr loadInitialPageFromDisk
    jmp .afterRequest

.requestNewContent
    jsr requestContent

    ; set the cursor line to zero here, that's important for calculating the right screen area for display
.afterRequest
    jsr .setToFirstContentLine
    
;    lda #$93 ; clear screen
;    jsr bsout

; do the processing
    lda #$0d
    jsr bsout
    jsr doFast

    lda zp_pageType
    cmp #$30    ;text file
    bne +
    jsr parsePlainText
    lda #3
    sta zp_linkTableIncr
    ;jsr copyTextToVram
    jsr copyToVram
    lda #1
    sta zp_scrollModeCrsr
    jmp .doneProcessing

+   cmp #$31    ;gopher file
    bne .doneProcessing
    jsr parseGopher
    lda #9
    sta zp_linkTableIncr
    ;jsr copyVisibleContentToVram
    jsr copyToVram
    lda #0
    sta zp_scrollModeCrsr
.doneProcessing
; history stack only if "active" navigation, not going back and forth on stack
    lda zp_navModeHistory
    beq +
    jsr pushToHistoryStack  ; only push to stack when not navigating in history
+   jsr writeCurrentGopherToHeadline

.resetDisplay
    lda #0
    sta zp_linenumber_start
    sta zp_linenumber_start+1
    sta zp_cursorLineContent
    sta zp_cursorLineContent+1

    lda #FIRST_LINE
    sta zp_cursorLineScreen

; this shows that we can start on a later line with correct display
;    lda #3
;    sta zp_linenumber_start
;    sta zp_cursorLineContent

; display page on top
.updateDisplay
    
    jsr displayTextmode

; get user input to see what to do next
; useful special function keys might be
; - go to top of page           - Home
; - go to root selector         - F1
; - go to defined start gopher  - F3
; - previous page (in history)  - commodore + cursor left

; - next page (in history)      - commodore + cursor right
; - page up/down                - commodore + up/down

.getUserinput
-   jsr k_getin
;-   lda 212
;    cmp #88
    beq -

    cmp #17     ;cursor down
    bne +
    lda #1
    sta zp_scrollDirectionUp
    jmp .tryCursorDown

; cursor up and down should know two different operation modes
; for gopher directories, do cursor movement
; for document display, scroll full lines

+   cmp #145 ; cursor up
    bne +
    lda #0
    sta zp_scrollDirectionUp
    jmp .tryCursorUp

;+   cmp #19   ;home
;    bne +
;    jsr setInitialGopherHostSelector
;    jmp .requestNewContent

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
    jmp .requestNewContent

+   cmp #$32 ; 2 . second bookmark
    bne +
    jsr setBkm2GopherHostSelector
    jsr setFromHistory
    jmp .requestNewContent

+   cmp #13 ;return key
    bne ++
    
    lda zp_pageType
    cmp #$31
    bne .getUserinput

    lda #1
    sta zp_navModeHistory   ; not navigating in history
    lda zp_currentType
    cmp #$30
    beq +
    cmp #$31
    beq +
    jmp -
+   sta zp_pageType     ; this is important. all processing of the next page is based on this
    inc zp_historyStackPos
.prepareRequest
    
    jsr setNewGopherHostSelector
    jmp .requestNewContent

++  cmp #19 ;home
    bne ++

    lda zp_vramBlock
    bne +
    jmp .resetDisplay

    ; setting these values to 1 allows us to leverage on most of regular scroll-up routines
+   lda #0
    sta zp_linenumber_start+1
    sta zp_cursorLineContent+1

    lda #1
    sta zp_linenumber_start
    sta zp_cursorLineContent
    sta zp_vramBlock
    jmp .loadPrevDataIntoVram

++  cmp #'H' ;go home
    bne +
    jsr setInitialGopherHostSelector
    jmp .requestNewContent

+   cmp #'S' ; go to startpage
    bne +
    jsr loadInitialPageFromDisk
    jmp .afterRequest

+   cmp #'R' ;reload
    bne +
    jmp .requestNewContent

+   cmp #'S'; speed
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
    jmp .getUserinput

; we're done, clean the campground before leaving
;    lda #27
;    jsr bsout
;    lda #'X'
;    jsr bsout
.exitGracefully
+   jsr recoverZp
    jmp enableBasicRom
    nop ; only for debugging purposes to give breakpoints a safe spot

.setToFirstContentLine
    lda #0
    sta zp_cursorLineScreen
    sta zp_linenumber_start
    sta zp_linenumber_start+1
    sta zp_cursorLineContent
    sta zp_cursorLineContent+1
    sta zp_firstVramContentLine
    sta zp_firstVramContentLine+1
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

+   jsr .calcCursorLineScreen

    ldy zp_linecount+1
    bne +       ; we have more content lines than what fits the screen. no need to check for lower cursor pos
    cmp zp_linecount
    bne +
    jmp .getUserinput   ; less content than screen lines, and we reached the last content line

+   cmp zp_lastLine ; is cursor on last screen-line?
    bne .cursorDown   ; not on the last screen-line, draw one line below

    ; on the last visible line, check if we can scroll down
    jmp .tryLineScrollDown

.cursorDown
+   jsr .drawCursorOneBelow
    jmp .getUserinput

.drawCursorOneBelow
    jsr removeCursor
    inc zp_cursorLineContent
    bne +
    inc zp_cursorLineContent+1
+   jmp drawCursor

.tryLineScrollDown
;    clc
;    lda #VISIBLE_LINES
;    adc zp_linenumber_start
;    cmp zp_linecount    ; is the last visible line also the last content line?

    ; is the last visible line also the last content line?
    ; zp_tempCalc contains the last visible line
    clc
    lda #VISIBLE_LINES
    adc zp_linenumber_start
    sta zp_tempCalc
    lda zp_linenumber_start+1
    adc #0
    sta zp_tempCalc+1

    lda zp_tempCalc+1
    cmp zp_lastVramContentLine+1
    bcc .doLineScrollDown
    lda zp_tempCalc
    cmp zp_lastVramContentLine
    bcc .doLineScrollDown

    ;yes, last line. now check, if RAM holds more lines.
    lda zp_lastVramContentLine+1
    cmp zp_linecount+1
    bcc .loadNextDataIntoVram
    lda zp_lastVramContentLine
    cmp zp_linecount
    bcc .loadNextDataIntoVram

    jmp .getUserinput   ; no. don't do anything, get next input from user

.doLineScrollDown
    lda zp_scrollModeCrsr
    bne +
    inc zp_cursorLineContent
    bne +
    inc zp_cursorLineContent+1
+   inc zp_linenumber_start ; no. increase linenumber and update display. ie scroll down
    bne +
    inc zp_linenumber_start+1
+   jmp .updateDisplay

.loadNextDataIntoVram
    ; we have reached the end of vram, but have more in RAM
    ; lines left to copy stays as it is. (as it holds the remaining number of lines to copy)
    ; start line of copy (current content line minus 23) (vram_content_addr) zp_linkTablePosition minus 23xincr (3 or 9)
    ; offset of line to display (in vramLineOffsets) and length of each line (linkTablePosition) are read
    ;  from different sources with different step increments (3/9 in linkTablePosition vs 2 in vramLineOffsets)
    ;  linkTablePosition stays in place, as this is built when loading the file
    ;  vramLineOffsets is to be re-built when copying the new data into vram
    jsr vramBlockIndexIntoX
    lda zp_firstVramContentLine
    sta vram_block_offsets,x
    lda zp_firstVramContentLine+1
    sta vram_block_offsets+1,x
    inc zp_vramBlock

    lda zp_linenumber_start
    sta zp_firstVramContentLine
    sta zp_lastVramContentLine
    lda zp_linenumber_start+1
    sta zp_firstVramContentLine+1
    sta zp_lastVramContentLine+1

    lda zp_pageType
    cmp #$30    ;text file
    bne ++

+   lda #3
    sta zp_linkTableIncr
    jsr .calculateLinkTableOffset

    jsr continueCopyToVram
    lda #1
    sta zp_scrollModeCrsr
    jmp .doneLoadNext

++  cmp #$31    ;gopher file
    bne .doneLoadNext
    lda #9
    sta zp_linkTableIncr    
    jsr .calculateLinkTableOffset

    jsr continueCopyToVram
    lda #0
    sta zp_scrollModeCrsr

.doneLoadNext
    jmp .doLineScrollDown
    nop

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

+   jsr .calcCursorLineScreen
    cmp #FIRST_LINE     ; is cursor on first line on screen?
    bne +               ; no
    ;yes. try to scroll up
    jmp .tryLineScrollUp

    ;no. just draw cursor one line above
+   jsr .drawCursorOneAbove
    jmp .getUserinput

.drawCursorOneAbove
    jsr removeCursor
    sec
    lda zp_cursorLineContent
    sbc #1
    sta zp_cursorLineContent
    bcs +
    dec zp_cursorLineContent+1
+   jmp drawCursor

.tryLineScrollUp
    ; is the first visible line also the first vram line?
    lda zp_linenumber_start+1
    cmp zp_firstVramContentLine+1
    bne .doLineScrollUp ; more lines in vram. scroll up
    lda zp_linenumber_start
    cmp zp_firstVramContentLine
    bne .doLineScrollUp ; more lines in vram. scroll up

    ;yes, we're on top of vram.
    ;   check if ram holds more previous lines (ie firstVramContentLine > 0)
    lda zp_firstVramContentLine+1
    bne .loadPrevDataIntoVram
    lda zp_firstVramContentLine
    bne .loadPrevDataIntoVram

    jmp .getUserinput

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
+   jmp .updateDisplay

.loadPrevDataIntoVram
    ; we have reached the end of vram, but have more in RAM
    ; lines left to copy stays as it is. (as it holds the remaining number of lines to copy)
    ; start line of copy (current content line minus 23) (vram_content_addr) zp_linkTablePosition minus 23xincr (3 or 9)
    ; offset of line to display (in vramLineOffsets) and length of each line (linkTablePosition) are read
    ;  from different sources with different step increments (3/9 in linkTablePosition vs 2 in vramLineOffsets)
    ;  linkTablePosition stays in place, as this is built when loading the file
    ;  vramLineOffsets is to be re-built when copying the new data into vram
+   lda zp_linenumber_start
    sta zp_memPtr
    lda zp_linenumber_start+1
    sta zp_memPtr+1

    dec zp_vramBlock
    jsr vramBlockIndexIntoX
    lda vram_block_offsets,x
    sta zp_linenumber_start
    sta zp_firstVramContentLine
    lda vram_block_offsets+1,x
    sta zp_linenumber_start+1
    sta zp_firstVramContentLine+1

    lda zp_pageType
    cmp #$30    ;text file
    bne ++

+   ; stash current linenumber. we'll need it later, but for calc we need to change it temporarily
    lda #3
    sta zp_linkTableIncr
    jsr .calculateLinkTableOffset
    jsr continueCopyToVram

    lda #1
    sta zp_scrollModeCrsr
    jmp .doneLoadPrev

++  cmp #$31    ;gopher file
    bne .doneLoadPrev
    lda #9
    sta zp_linkTableIncr
    jsr .calculateLinkTableOffset
    jsr continueCopyToVram

    lda #0
    sta zp_scrollModeCrsr

.doneLoadPrev
    lda zp_memPtr
    sta zp_linenumber_start
    lda zp_memPtr+1
    sta zp_linenumber_start+1

    jmp .doLineScrollUp
    nop


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
    jmp .getUserinput   ; no next entry in stack

+   inc zp_historyStackPos
    jmp .commonHistoryPageHandling

.prevHistoryPage
    lda zp_historyStackPos
    bne +   
    jmp .getUserinput   ; no previous entry in stack

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

; used for slow/fast. resets to bank 15, not only enabling basic
enableBasicRom
    lda #%00000000
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


doFast
    rts
    jsr enableBasicRom
    jsr b_fast
    jmp disableBasicRom

doSlow
    jsr enableBasicRom
    jsr b_slow
    jmp disableBasicRom

k_indsta
    pha
    lda mmuBankConfig,x	; MMU Bank Configuration Values
    tax
    pla
    jmp $02AF	; Bank Poke Subroutine

; stores $0a-$8f to somewhere else
saveZp
    ldx #$0a
    ldy #0
-   lda $0,x
    sta zpStore,y
    iny
    inx
    cpx #$8f+1
    bne -

    ldx #0
    ldy #9
-   lda $1000,x
    sta keyStore,x
    lda #0
    sta $1000,x
    inx
    dey
    bpl -

    rts

recoverZp
    ldx #$0a
    ldy #0
-   lda zpStore,y
    sta $0,x
    iny
    inx
    cpx #$8f+1
    bne -

    lda #0
    ldx #0
    ldy #9
-   lda keyStore,x
    sta $1000,x
    inx
    dey
    bpl -
    rts

!src "src/file/load.asm"
!src "src/file/loadContent.asm"
!src "src/network/disk.asm"
!src "src/vdc.asm"
!src "src/network/networkCommon.asm"
!src "src/network/networkWic.asm"
!src "src/network/swiftlink.asm"
!src "src/wic64/wic64.asm"
!src "src/history.asm"
!src "src/memory/georam.asm"
!src "src/memory/reu.asm"

!src "src/parsers/parseGopher.asm"
!src "src/parsers/parsePlainText.asm"
!src "src/parsers/commonParse.asm"
!src "src/copy/copyCommon.asm"
!src "src/display.asm"


txtReu      !text "REU: ",0
txtGeoRam   !text "GeoRAM: ",0

; memory map
; bank 0 - $1c01 programcode
; bank 0 - $c000 history stack (usually screen editor and monitor)

; bank 1
; $0400 content from gopher server. unmodified
; $7f00 linktable. each line of gopher content is represented here with a 9 byte long entry.
; - 2 bytes for offset to linestart. relative to $0400
; - 1 byte for length of visible content
; - 2 bytes for offset to selector
; - 2 bytes for offset to host
; - 2 bytes for offset to port

; vdc-ram
; $0000 screen ram
; $0800 attribute ram
; $1000 visible content in a condensed form (from eg $1:7f01 to next tab)
;       this is block copied to screen by using the $1:7f00 entry of the line (first offset +1) and the length (offset 3 in linktable)
;       to copy lines 10-32 (23 lines), the code will add up all the lengths until line 10 and then copy each line
; $3000 charset (4kb)

