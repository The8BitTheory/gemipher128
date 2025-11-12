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

!zone gopher

parseGopher
    lda #0
    sta .parseSeq
    sta .parseMode

    lda responseSize
    sta .leftToParse
    lda responseSize+1
    sta .leftToParse+1

    jmp .decideOnParseSeq

.decideOnParseSeq
    lda .parseSeq
    bne +
    jmp .handleType

+   cmp #1
    bne +
    jmp .handleSelector

+   cmp #2
    bne +
    jmp .handleHost

+   cmp #3
    bne +
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

.selectNextParseMode
    ;pha
    ;jsr bsout
    ;pla

    cmp #$69 ;i - info
    bne +
    sta .parseMode
    lda #$5     ;white
    jsr bsout
    jmp .handleInfo

+   cmp #$30 ; 0 - textfile
    bne +
    sta .parseMode
    lda #$9c    ; purple
    jsr bsout
    jmp .handleTypeText

+   cmp #$31 ; 1 - menu / directory
    bne +
    sta .parseMode
    lda #$1e    ; green
    jsr bsout
    jmp .handleTypeMenu

+   cmp #$32 ; 2 - cso phonebook
    bne +
    sta .parseMode
    lda #$9a ;light blue
    jsr bsout
    jmp .handleTypePhonebook

+   cmp #$33 ; 3 - error/info
    bne +
    sta .parseMode
    jmp .handleTypeError

+   cmp #$34 ; 4 - binary
    bne +
    sta .parseMode
    jmp .handleTypeBinary

+   cmp #$35 ; 5 - dos binary
    bne +
    sta .parseMode
    jmp .handleTypeDosBinary

+   cmp #$36 ; 6 - uuencoded text (probably a binary?)
    bne +
    sta .parseMode
    jmp .handleTypeUUenc

+   cmp #$37 ; 7 - error/info
    bne +
    sta .parseMode
    jmp .handleTypeSearch

+   cmp #$38 ; 8 - Telnet
    bne +
    sta .parseMode
    jmp .handleTypeTelnet

+   cmp #$39 ; 9 - generic binary
    bne +
    sta .parseMode
    jmp .handleTypeGenericBinary

+   cmp #'+' ; + - gopher + info
    bne +
    sta .parseMode
    jmp .handleTypePlus

+   cmp #'g' ; G - GIF
    bne +
    sta .parseMode
    jmp .handleTypeGif

+   cmp #'l' ; L - generic image
    bne +
    sta .parseMode
    jmp .handleTypeGenericImage

+   cmp #'h' ; H - Hyperlink
    bne +
    sta .parseMode
    lda #$9e    ; $9e=yellow, $81=dark purple (should be orange, which is not a vdc-color)
    jsr bsout
    jmp .handleTypeHyperlink

+   cmp #'s' ; s - audio
    bne +
    sta .parseMode
    jmp .handleTypeAudio

+   cmp #'M' ; m - multipart mime
    bne +
    sta .parseMode
    jmp .handleTypeMime

+   cmp #'D' ; d - document. mostly pdf
    bne +
    sta .parseMode
    jmp .handleTypeDoc

+   cmp #'T' ; t - terminal connection tn3270
    bne +
    sta .parseMode
    jmp .handleTypeTerminal

+   cmp #$9 ;tab
    bne +
    sta .parseMode
    jmp .handleTab

+   lda #$12 ;reverse on
    jsr bsout
    lda #'x'
    jsr bsout
    rts


.handleTypeAudio
.handleTypeBinary
.handleTypeDoc
.handleTypeDosBinary
.handleTypeGenericBinary
.handleTypeGenericImage
.handleTypeGif
.handleTypeHyperlink
.handleTypeTerminal
.handleTypeMime
.handleTypePlus
.handleTypeTelnet
.handleTypeSearch
.handleTypeUUenc
.handleTypeError
.handleTypePhonebook
.handleTypeText
.handleTypeMenu
.handleInfo
    jsr .readNextByte
    cmp #9  ; tab. end ascii output
    bne +
    lda #$0d
    jsr bsout
    inc .parseSeq
    lda #0
    sta .parseMode
    ;lda #$12 ;reverse on
    ;jsr bsout
    jmp .decideOnParseSeq

+   jsr bsout
    jmp .handleInfo

.handleTab
    inc .parseSeq
    jmp .decideOnParseSeq

; for now, just skip until tab
.handleSelector
    jsr .readNextByte
    cmp #9
    beq +
;    jsr bsout
    jmp .handleSelector
+   ;lda #$92 ;reverse off
    ;jsr bsout
    jmp .handleTab

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
    ldy #0
    lda (zp_contentAddress),y

    inc zp_contentAddress
    bne +
    inc zp_contentAddress+1

+   dec .leftToParse
    bne +
    dec .leftToParse+1

+   rts


.parseMode       !byte 0 ; $69 for i, $31 for 1, etc
.parseSeq        !byte 0 ; 0=type specific parsing, 1=selector, 2=hostname, 3=port
.leftToParse     !word 0