; ------------
; memory map
; ------------
; $0.1c01 - $0.bfff: programcode. only enable basic-rom when needed. close to 41kB
; $1.0400 - $1.f700: data --> 62 kB
; $1.f700 - $1.ff00: link table -> 2 kB

; configuration constants

HISTORY_STACK = $c000

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
zp_contentAddress = $0a
zp_linecount = $0c
zp_tempX = $0e      ; used to hold x register when working with FAR routines
zp_tempY = $0f    ; used to hold y register when working with FAR routines

zp_contentBank  = $10   
zp_linkTablePosition = $11 ; and $12
zp_fastmode = $1b

; used by parseGopher.asm
zp_visibleLength = $13  ; length of visible text in current line. also used by display.asm

; used by display.asm
; textdisplay
; also using zp_visibleLength
zp_currentLinkTablePtr = $14; and $15
zp_vram_content_addr = $16 ; and $17 ;  also used by copytovram.asm
zp_vram_screenram = $18 ; and $19
zp_linenumber_start = $1a   ; and $1b ; this is the scrolling position
zp_cursorLineContent = $1c         ; this is the cursor line relative to the content
zp_cursorPosScreen = $1d ; and $1e   this is the cursor position on screen (content line x 80 + top offset - scroll offset)
zp_cursorLineScreen = $1f   ; the line on the screen where the cursor is (must be within 1 and 24 or so)
zp_lastLine = $20       ; this is #LAST_LINE when all content lines fit screen lines. is reduced by one for each multi-line
zp_scrollDirectionUp = $21  ; 0=up, else=down
; used by copytovram.asm
; zp_vram_content_addr
; zp_linecount
; zp_tempX
; zp_visibleLength
; zp_currentLinkTablePtr
; zp_linkTablePosition
; zp_contentBank
zp_currentType = $22
zp_currentSelectorPtr = $23 ; and $24
zp_currentHostPtr = $25 ; and $26
zp_currentPortPtr = $27 ; and $28
zp_currentTypePtr = $29 ; and $2a
zp_linkTableIncr = $2b      ; link table has entries of different sizes (gopher=9 bytes, plain text = 3 bytes)
zp_responseSize = $2c ; and $2d ; the nr of bytes we counted for response. upfront information should be in zp_contentLength
zp_scrollModeCrsr = $2e ; 0=cursor movement, else=just scroll screen lines
zp_contentLength = $2f; and $30 ; the content length that's reported by the server. zp_responseSize holds the nr bytes we counted

; history.asm
zp_historyStackPos = $31    ; the position (entry) in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackSize = $32   ; the nr of entries in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackAddress = $33; and $34. holds the address of the current entry (ie HISTORY_STACK + stackpos*12)
zp_navModeHistory = $35     ; 0=navigation via history stack (cursor keys), else=navigation via return key
                            ; (0 means no stack updates, only changing stack position, 1 means push new page to stack)

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

; load from network
    jsr detectAndInitializeWic64
    jsr setInitialGopherHostSelector

.requestNewContent
    jsr requestContent

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
    ;jsr pushToHistoryStack
    jsr doSlow

.resetDisplay
    lda #0
    sta zp_linenumber_start
    sta zp_cursorLineContent
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

+   cmp #13 ;return key
    bne +
    lda zp_currentType
    cmp #$30
    beq .prepareRequest
    cmp #$31
    beq .prepareRequest
    jmp -
.prepareRequest
    jsr setNewGopherHostSelector
    jmp .requestNewContent

+   cmp #19 ;home
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
    cmp zp_lastLine ; is cursor on last screen-line?
    bne +   ; not on the last screen-line, draw one line below

    ; on the last visible line, check if we can scroll down
    jmp .tryLineScrollDown

+   jsr .drawCursorOneBelow
    jmp .getUserinput

.drawCursorOneBelow
    jsr removeCursor
    inc zp_cursorLineContent
    ;inc zp_cursorLineScreen
    jmp drawCursor

.tryLineScrollDown
    clc
    lda #VISIBLE_LINES
    adc zp_linenumber_start
    cmp zp_linecount    ; is the last visible line also the last content line?
    bmi +
    jmp .getUserinput   ; yes. don't do anything, get next input from user

+   lda zp_scrollModeCrsr
    bne +
    inc zp_cursorLineContent
+   inc zp_linenumber_start ; no. increase linenumber and update display. ie scroll down
    jmp .updateDisplay


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
    dec zp_cursorLineContent
    ;dec zp_cursorLineScreen
    jmp drawCursor

.tryLineScrollUp
    lda zp_linenumber_start
    bne +
    jmp .getUserinput
+   dec zp_linenumber_start
    dec zp_cursorLineContent
    jmp .updateDisplay

.calcCursorLineScreen
    clc
    lda #1
    adc zp_cursorLineContent
    sta zp_cursorLineScreen

    sec
    sbc zp_linenumber_start
    sta zp_cursorLineScreen
    rts

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
filenameCharset     !pet "ascii2.chr"
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

