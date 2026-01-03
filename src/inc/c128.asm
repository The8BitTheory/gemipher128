; ------------
; memory map
; ------------


; $0.1c01 - $0.afff: programcode. only enable basic-rom when needed. close to 41kB
; after programcode: link table -> 7.75 kB
; $0.b000 - $0.b0ff: history pointers
; $0.b100 - ?????: string entries for history (host:port/selector)


; $1.0400 - $1.dfff: data --> 56 kB


; configuration constants

HISTORY_TABLE = $b000   ; room for 128 entries
HISTORY_STACK = $b100   

;LINKTABLE_ADDRESS = $e000

; CONTENT describes one full gopher page
CONTENT_BANK = 1
CONTENT_ADDRESS = $0400
CONTENT_END_ADDRESS = $F000 ;LINKTABLE_ADDRESS -$fff


VRAM_CONTENT = $1000    ; the 'invisible' part of vram that acts like another RAM expansion
VISIBLE_LINES = 23
TEXT_LINE_LENGTH = 80
GOPHER_LINE_LENGTH = 79
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
; x16: $22-$7f is available for use
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
zp_lineLength = $24     ; this holds 80 for plain text and 79 for gopher lines. (for now)
; used by copytovram.asm
; zp_vram_content_addr
; zp_linecount
; zp_tempX
; zp_visibleLength
; zp_currentLinkTablePtr
; zp_linkTablePosition
; zp_contentBank
zp_currentType = $25    ; type of currently selected or iterated line. for type of currently displayed page, use zp_pageType
zp_currentSelectorPtr = $26 ; and $27
zp_currentHostPtr = $28 ; and $29
zp_currentPortPtr = $2a ; and $2b
;zp_currentTypePtr = $2c ; and $2d   --- AVAILABLE ---
zp_linkTableIncr = $2e      ; link table has entries of different sizes (gopher=9 bytes, plain text = 3 bytes)
zp_responseSize = $2f ; and $30 ; the nr of bytes we counted for response. upfront information should be in zp_contentLength
zp_scrollModeCrsr = $31 ; 0=cursor movement, else=just scroll screen lines
zp_contentLength = $32; and $33 ; the content length that's reported by the server. zp_responseSize holds the nr bytes we counted

; history.asm
zp_historyStackPos = $34    ; the position (entry) in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackSize = $35   ; the nr of entries in the history stack. (multiply x 12 to get stack offset per entry)
zp_historyStackAddress = $36; and $37. holds the address of the current entry (ie HISTORY_STACK + stackpos*12)
zp_hostSelBank = $38        ; where to read host,port,selector from (1 for current page, 0 for history)
zp_navModeHistory = $39     ; 0=navigation via history stack (cursor keys)
                            ; else=navigation via return key or manual address (modify history)
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

zp_wic_stash_x = $4b
zp_wic_stash_y = $4c

; common memory area below $0400
c_fetch = $02a2
c_fetch_zp = $02aa
c_stash = $02af
c_stash_zp = $02b9


; basic rom lo $4000-$7fff
;b_fast = $77b3
;b_slow = $77c4

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

!macro print .textaddress {
    pha
    txa
    pha

    ldx #0
-   lda .textaddress,x
    beq +
    jsr bsout
    inx
    jmp -

+   pla
    tax
    pla
}
