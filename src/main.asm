; ------------
; memory map
; ------------
; $0.1c01 - $0.afff: programcode. only enable basic-rom when needed. close to 41kB
; $1.0400 - $1.f700: data --> 62 kB
; $1.f700 - $1.ff00: link table -> 2 kB

; configuration constants

HISTORY_TABLE = $b000   ; room for 128 entries
HISTORY_STACK = $b100   

; CONTENT describes one full gopher page
CONTENT_BANK = 1
CONTENT_ADDRESS = $0400

LINKTABLE_ADDRESS = $f000

VRAM_CONTENT = $1000    ; the 'invisible' part of vram that stores all text ready for display
VISIBLE_LINES = 23
FIRST_LINE = 1
LAST_LINE = FIRST_LINE+VISIBLE_LINES-1

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
zp_linkTablePosition = $11 ; and $12
zp_fastmode = $13

; used by parseGopher.asm
zp_visibleLength = $14  ; length of visible text in current line. also used by display.asm

; used by display.asm
; textdisplay
; also using zp_visibleLength
zp_currentLinkTablePtr = $15; and $16
zp_vram_content_addr = $17 ; and $18 ;  also used by copytovram.asm
zp_vram_screenram = $189 ; and $1a
zp_linenumber_start = $1b   ; and $1c ; this is the scrolling position. ie the number of the first visible line (in context of the document, not the visible lines)
zp_cursorLineContent = $1d    ; and $1e     ; this is the cursor line relative to the content
zp_cursorPosScreen = $1f ; and $20   this is the cursor position on screen (content line x 80 + top offset - scroll offset)
zp_cursorLineScreen = $21   ; the line on the screen where the cursor is (must be within 1 and 24 or so)
zp_lastLine = $22       ; this is #LAST_LINE when all content lines fit screen lines. is reduced by one for each multi-line. refers to the screen, not the file
zp_scrollDirectionUp = $23  ; 0=up, else=down

; used by copytovram.asm
; zp_vram_content_addr
; zp_linecount
; zp_tempX
; zp_visibleLength
; zp_currentLinkTablePtr
; zp_linkTablePosition
; zp_contentBank
zp_currentType = $24
zp_currentSelectorPtr = $25 ; and $26
zp_currentHostPtr = $27 ; and $28
zp_currentPortPtr = $29 ; and $2a
zp_currentTypePtr = $2b ; and $2c
zp_linkTableIncr = $2d      ; link table has entries of different sizes (gopher=9 bytes, plain text = 3 bytes)
zp_responseSize = $2e ; and $2f ; the nr of bytes we counted for response. upfront information should be in zp_contentLength
zp_scrollModeCrsr = $30 ; 0=cursor movement, else=just scroll screen lines
zp_contentLength = $31; and $32 ; the content length that's reported by the server. zp_responseSize holds the nr bytes we counted

; history.asm
zp_historyStackPos = $33    ; the position (entry) in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackSize = $34   ; the nr of entries in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackAddress = $35; and $36. holds the address of the current entry (ie HISTORY_STACK + stackpos*12)
zp_hostSelBank = $37        ; where to read host,port,selector from (1 for current page, 0 for history)
zp_navModeHistory = $38     ; 0=navigation via history stack (cursor keys), else=navigation via return key
                            ; (0 means no stack updates, only changing stack position, 1 means push new page to stack)
zp_tempCalc     = $39 ; and $3a

zp_lastVramContentLine = $3b ; and $3c. this is used to stop scrolling and load more in to vram. document might be larger than vram (esp with 16kb VRAM)
zp_memPtr   = $3d ; and $3e. can be used for any temporary indirect read or write memory operation
zp_pageType = $3f ; keeps type of current page persistently loaded. we run into conflicts with "type of current cursor positon" otherwise

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

*=$1d00
main
;    jsr k_primm
;    !pet "pet klein GROSS",0
;    jsr k_primm
;    !text "ascii klein GROSS",0
    lda #$93 ; clear screen
    jsr bsout

    lda #0
    sta zp_fastmode

    jsr disableBasicRom

    jsr saveZp

    jsr initVdc

; disable case switching via Shift-Commodore
    lda #11
    jsr bsout

; switch to lower-case charset
    lda #14
    jsr bsout

    
    jsr initHistoryStack
    jsr disableBasicRom

; load from network
    jsr detectAndInitializeWic64
    jsr setInitialGopherHostSelector
    lda #1
    sta zp_navModeHistory

.requestNewContent
    jsr requestContent

    lda zp_currentType
    sta zp_pageType

    lda #$93 ; clear screen
    jsr bsout

; do the processing
    lda #$0d
    jsr bsout
    jsr doFast

    lda zp_currentType
    cmp #$30    ;text file
    bne +
    jsr parsePlainText
    lda #3
    sta zp_linkTableIncr
    jsr copyTextToVram
    lda #1
    sta zp_scrollModeCrsr
    jmp .doneProcessing

+   cmp #$31    ;gopher file
    bne .doneProcessing
    jsr parseGopher
    lda #9
    sta zp_linkTableIncr
    jsr copyVisibleContentToVram
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

+   cmp #13 ;return key
    bne ++
    lda #1
    sta zp_navModeHistory   ; not navigating in history
    lda zp_currentType
    cmp #$30
    beq +
    cmp #$31
    beq +
    jmp -
+   inc zp_historyStackPos
.prepareRequest
    
    jsr setNewGopherHostSelector
    jmp .requestNewContent

++  cmp #19 ;home
    bne +
.goToFirstLine
    jmp .resetDisplay

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
    bne -

; we're done, clean the campground before leaving
;    lda #27
;    jsr bsout
;    lda #'X'
;    jsr bsout
    jsr recoverZp
    rts
    nop ; only for debugging purposes to give breakpoints a safe spot

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
    clc
    lda #VISIBLE_LINES
    adc zp_linenumber_start
    sta zp_tempCalc
    lda zp_linenumber_start+1
    sta zp_tempCalc+1

    lda zp_tempCalc+1
    cmp zp_lastVramContentLine+1
    bcc +   ; 
    lda zp_tempCalc
    cmp zp_lastVramContentLine
    bcc +

    jmp .getUserinput   ; yes. don't do anything, get next input from user

+   lda zp_scrollModeCrsr
    bne +
    inc zp_cursorLineContent
    bne +
    inc zp_cursorLineContent+1
+   inc zp_linenumber_start ; no. increase linenumber and update display. ie scroll down
    bne +
    inc zp_linenumber_start+1
+   jmp .updateDisplay


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
    lda zp_linenumber_start
    bne +
    jmp .getUserinput
+   dec zp_linenumber_start
    sec
    lda zp_cursorLineContent
    sbc #1
    sta zp_cursorLineContent
    bcs +
    dec zp_cursorLineContent+1
+   jmp .updateDisplay

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
    sbc #0
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

; used for slow/fast
enableBasicRom
    lda #%00000000
    sta $ff00
    rts

doFast
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
    rts

!src "src/file/load.asm"
!src "src/vdc.asm"
!src "src/network/networkWic.asm"
!src "src/parsers/parseGopher.asm"
!src "src/parsers/parsePlainText.asm"
!src "src/copytovram.asm"
!src "src/copyTxtToVram.asm"
!src "src/display.asm"
!src "src/wic64/wic64.asm"
!src "src/history.asm"

; these are the mappings from basic's bank command to the actual mmu config-register values
mmuBankConfig       !byte $3F,$7F,$BF,$FF,$16,$56,$96,$D6,$2A,$6A,$AA,$EA,$06,$0A,$01,$00

; this is used to keep an original copy of the zero-page range we're using. is restored when program ends
zpStore             !fill 134


fileOpError         !byte 0
filenameCharset     !pet "latin9ui.char"
filenameLength=*-filenameCharset

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

