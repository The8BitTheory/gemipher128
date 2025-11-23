; parsing gopher files.
; when parsing, we just take pointers from each line.
; so we end up with a table of 10-byte entries per line
; each entry: pointer to type, pointer to displaytext, pointer to selector, pointer to host, pointer to port
; when displaying, each line is copied to screen-ram
; lines longer than 80 characters (or whatever the screen-width is) will wrap and continue indented on the next line
;  this requires some wrap logic
; at the left side will be some kind of > cursor
; moving it over a line that contains a selector will display the selector at the bottom
; 

; LINK TABLE
; 9 bytes per line of gopher content (data from network, not characters on screen)
;  each entry contains a pointer to that line's respective information
; text,length, selector, host, port
; this could be kept at 4kb below I/O space at $c000 (2kb of table space is good for 200 lines)


!zone gopher

parseGopher
    ; set zp_content to beginning of content so we can start parsing that now
    ; also sets linktableposition to the first byte
    jsr initContentAddress

    ; setup indirect reading from bank 1
    lda #zp_contentAddress
    sta c_fetch_zp

    ; setup indirect writing to bank 1
    lda #zp_linkTablePosition
    sta c_stash_zp

    jsr .clearLinkTable

    ; good thing we're both, reading and writing, from and to bank 1
    ldx #CONTENT_BANK
    lda mmuBankConfig,X
    sta zp_contentBank

    lda #0
    sta .parseSeq
    sta .parseMode
    sta zp_linecount
    sta zp_linecount+1

    lda zp_responseSize
    sta .leftToParse
    lda zp_responseSize+1
    sta .leftToParse+1

; which section of the line are we parsing?
; 0=type and visible content
; 1=selector
; 2=host
; 3=port
; 4=end
.decideOnParseSeq
    lda .parseSeq
    bne +
    sta zp_visibleLength
    jsr .storePointerInLinkTable
    jmp .handleType

+   cmp #1
    bne +
    jsr .storePointerInLinkTable
    jmp .handleSelector

+   cmp #2
    bne +
    jsr .storePointerInLinkTable
    jmp .handleHost

+   cmp #3
    bne +
    jsr .storePointerInLinkTable
    jmp .handlePort

+   rts
    nop

.handleType
    lda .parseMode
    bne .selectNextParseMode
    jsr .readNextByte
    bne .selectNextParseMode

.foundZero
    jsr k_primm
    !pet "Found zero byte",$d,0
    rts

; checks the first character of the line
;  that defines how to handle all remaining data until \r\n
.selectNextParseMode
    sta .parseMode

    cmp #$69 ; i - info
    beq .handleVisible
    cmp #$30 ; 0 - textfile
    beq .handleVisible
    cmp #$31 ; 1 - menu / directory
    beq .handleVisible
    cmp #$32 ; 2 - cso phonebook
    beq .handleVisible
    cmp #$33 ; 3 - error/info
    beq .handleVisible
    cmp #$34 ; 4 - binary
    beq .handleVisible
    cmp #$35 ; 5 - dos binary
    beq .handleVisible
    cmp #$36 ; 6 - uuencoded text (probably a binary?)
    beq .handleVisible
    cmp #$37 ; 7 - error/info
    beq .handleVisible
    cmp #$38 ; 8 - Telnet
    beq .handleVisible
    cmp #$39 ; 9 - generic binary
    beq .handleVisible
    cmp #'+' ; + - gopher + info
    beq .handleVisible
    cmp #'g' ; G - GIF
    beq .handleVisible
    cmp #$49 ; $49, I - generic image (upper-case i)
    beq .handleVisible
    cmp #$68 ; H - Hyperlink
    beq .handleVisible
    cmp #'s' ; s - audio
    beq .handleVisible
    cmp #'M' ; m - multipart mime
    beq .handleVisible
    cmp #'D' ; d - document. mostly pdf
    beq .handleVisible
    cmp #'T' ; t - terminal connection tn3270
    beq .handleVisible
    cmp #$2e    ; dot. end of menu
    beq .parsingDone
    
    
.parsingDone

    rts
    nop

.handleVisible
    jsr .readNextByte
    
    cmp #9  ; tab. end ascii output
    bne +
    inc .parseSeq
    lda #0
    sta .parseMode
    lda zp_visibleLength
    jsr .storeValueInLinkTable
    jmp .decideOnParseSeq

+   inc zp_visibleLength
    jmp .handleVisible

.handleTab
    inc .parseSeq
    jmp .decideOnParseSeq

; the order in the line is
; type, visible content, selector (ie target path), host, port

; for now, just skip until tab
.handleSelector
    jsr .readNextByte
    cmp #9
    beq +

    jmp .handleSelector
+   jmp .handleTab

.handleHost
    jsr .readNextByte
    cmp #9
    beq +
    jmp .handleHost
+   jmp .handleTab

.handlePort
    jsr .readNextByte
    cmp #13
    bne .handlePort
    jsr .readNextByte
    cmp #10
    bne .handlePort
    
    ; we found a CR LF sequence. end the line
    lda #0
    sta .parseSeq

    inc zp_linecount
    bne +
    inc zp_linecount+1

    ; and check whether to end parsing alltogether
+   lda .leftToParse+1
    bmi .parseComplete

    jmp .decideOnParseSeq

.parseComplete
    lda #4
    sta .parseSeq    ;.parseSeq 4 should end parsing
    jmp .decideOnParseSeq

.readNextByte
    ; read from bank 1
    ldx zp_contentBank
    ldy #0
    jsr c_fetch

    inc zp_contentAddress
    bne +
    inc zp_contentAddress+1

+   dec .leftToParse
    bne +
    dec .leftToParse+1

+   rts


.storeValueInLinkTable
    ldy #0
    jsr .stashToLinkTable
    rts

.storePointerInLinkTable
    ldy #0
    lda zp_contentAddress
    jsr .stashToLinkTable
    lda zp_contentAddress+1
    jsr .stashToLinkTable

+   rts


.stashToLinkTable
    ldx zp_contentBank
    ; y must be set accordingly at this point
    jsr c_stash
    inc zp_linkTablePosition
    bne +
    inc zp_linkTablePosition+1

+   rts

.clearLinkTable
; this clears 8x256 bytes

    ldy #0
-   lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash
    inc zp_linkTablePosition+1
    lda #0
    ldx zp_contentBank
    jsr c_stash

    jsr initLinkTableAddress
    iny
    bne -

    jmp initLinkTableAddress

.parseMode       !byte 0 ; $69 for i, $31 for 1, etc
.parseSeq        !byte 0 ; 0=type specific parsing, 1=selector, 2=hostname, 3=port
.leftToParse     !word 0