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
    +print txtParsing
    ; set zp_content to beginning of content so we can start parsing that now
    ; also sets linktableposition to the first byte
    jsr initParser
    
    lda #0
    sta .parseSeq
    sta .parseMode

    lda #$ff
    sta .startFound

; which section of the line are we parsing?
; 0=type and visible content
; 1=selector
; 2=host
; 3=port
; 4=end

; for convenience, here the structure of a linktable entry again (10 bytes per entry)
; - 1 byte for line type (gopher dir, text, audio, image, etc.)
; - 2 bytes for offset to linestart+1 (start at text, not at type). relative to $1:0400
; - 1 byte for length of visible content (78 max)
; - 2 bytes for offset to selector
; - 2 bytes for offset to host
; - 2 bytes for offset to port

.decideOnParseSeq
    lda .parseSeq
    bne +
    ;sta zp_visibleLength
    sta .nrSegments
    ;jsr .storePointerInLinkTable    ; 
    jmp .handleType                 ; stores type first (storeValueInLinkTable) - byte. offset 0
                                    ; stores pointer to start of visible text next - word. offset 1 and 2
                                    ; length is stored as value inside that routine. byte. offset 3

+   cmp #1
    bne +
    lda zp_contentAddress
    sta .segSelector
    lda zp_contentAddress+1
    sta .segSelector+1
    jmp .handleSelector

+   cmp #2
    bne +
    lda zp_contentAddress
    sta .segHost
    lda zp_contentAddress+1
    sta .segHost+1
    jmp .handleHost

+   cmp #3
    bne +
    lda zp_contentAddress
    sta .segPort
    lda zp_contentAddress+1
    sta .segPort+1
    jmp .handlePort

+   cmp #4
    bne +
    jmp .handlePlus

+   rts
    nop

.handleType
    lda .parseMode
    bne .selectNextParseMode
    jsr readNextByte
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

    ldy .startFound
    bpl +
    jsr readNextByte
    jmp .selectNextParseMode

;    cmp #'+' ; + - gopher + info
;    beq .handleVisible
+   cmp #'g' ; G - GIF
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


; visible text is split into 78 char segments each (max 78, can be shorter)
; each segment must have a 10 byte entry.
; challenge: we only get host:port/selector after text is fully parsed.
;            so when we can't write the entries for these segments immediately.

; 
; - 1 byte for line type. we have this immediately, same value for all segments
; - 2 bytes for offset to linestart+1 (start at text, not at type). we have this immediately, written per segment
; - 1 byte for length of visible content (78 max), available immediately, written per segment
; - 2 bytes for offset to selector, available after parsing visible text. same value for all segments
; - 2 bytes for offset to host, available after parsing visible text. same value for all segments
; - 2 bytes for offset to port, available after parsing visible text. same value for all segments

; keep list of linestart offsets and lengths
; once end of line is reached, write 10 byte entries


.handleVisible
    ; accumulator must hold type at this point
    pha
    jsr .resetSegmentData
    pla
    sta .segType

    jsr .storePointerInOffsetList

    lda #0
    sta .startFound
    sta charsSinceSpace

-   jsr readNextByte
    bcs .parseComplete  ; reached end of content

    cmp #' '            ; if this is a space character, we reset the counter
    bne +
    sty charsSinceSpace ; y should be zero because it was set in readNextByte
+   inc charsSinceSpace
    cmp #9  ; tab. end ascii output
    bne +

; end of visible part reached
    lda .lineLengthG
    jsr .storeLengthInList

    inc .parseSeq
    lda #0
    sta .parseMode
    
    jmp .decideOnParseSeq

+   inc .lineLengthG
    lda .lineLengthG
    cmp #78
    beq .wrapLine
    jmp -

.wrapLine
    ; when a line is running over, let's check if we're wrapping the word correctly
    ; if the following character is not a space character, it means we split a word
    jsr readNextByteWithoutInc
    cmp #' '    ; space
    bne +
    ; if space: wrap was luckily good. we can skip the space (would indent the next line otherwise)
    jsr readNextByte
    jmp ++  

    ; if no space: find previous space and wrap to new line from there
    ; first, reduce line length so it only goes until last space
+   sec
    lda .lineLengthG
    sbc charsSinceSpace
    sta .lineLengthG
    ; next, reset out read pointer to after the last space

    dec charsSinceSpace
    sec
    lda zp_contentAddress
    sbc charsSinceSpace
    sta zp_contentAddress
    lda zp_contentAddress+1
    sbc #0
    sta zp_contentAddress+1
    ; 

++  jsr .storeLengthInList  ; lineLengthG holds the length
    lda #0
    sta .lineLengthG
    sta charsSinceSpace

    inc .nrSegments
    jsr .storePointerInOffsetList
    jmp -

.parseComplete
    lda #5
    sta .parseSeq    ;.parseSeq 5 should end parsing
    jmp .generalEnd

.handleTab
    inc .parseSeq
    jmp .decideOnParseSeq

; the order in the line is
; type, visible content, selector (ie target path), host, port

; for now, just skip until tab
.handleSelector
    jsr readNextByte
    bcs .parseComplete
    cmp #9
    beq +

    jmp .handleSelector
+   jmp .handleTab

.handleHost
    jsr readNextByte
    bcs .parseComplete
    cmp #9
    beq +
    jmp .handleHost
+   jmp .handleTab

.handlePort
    jsr readNextByte
    bcs .parseComplete  ; reached last byte of content
    beq .parseComplete  ; found zero-byte
    cmp #9              ; a tab after the port means, this is a gopher + server. we'll gracefully skip this for now
    bne +
    jmp .handleTab
+   cmp #13
    bne .handlePort
    jsr readNextByte
    bcs .parseComplete  ; reached last byte of content
    cmp #10
    bne .handlePort
    
.endLine
    ; we found a CR LF sequence. end the line
    lda #0
    sta .parseSeq

.generalEnd
    jsr .writeSegmentsToLinkPointer

+   jmp .decideOnParseSeq

.handlePlus
    jsr readNextByte
    bcs .parseComplete
    beq .parseComplete

    cmp #13
    bne .handlePlus
    jsr readNextByte
    bcs .parseComplete  ; reached last byte of content
    cmp #10
    bne .handlePlus

    ; we found a CR LF sequence. end the line
    jmp .endLine

.writeSegmentsToLinkPointer
    lda #0
    sta zp_tempA

-   lda .segType
    jsr .storeValueInLinkTable

    ;lda .nrSegments
    lda zp_tempA
    asl
    tax
    lda .offsetList,x
    jsr writeToLinkTable
    lda .offsetList+1,x
    jsr writeToLinkTable

    ldx zp_tempA
    lda .lengthList,x
    jsr .storeValueInLinkTable

    lda .segSelector
    jsr writeToLinkTable
    lda .segSelector+1
    jsr writeToLinkTable

    lda .segHost
    jsr writeToLinkTable
    lda .segHost+1
    jsr writeToLinkTable

    lda .segPort
    jsr writeToLinkTable
    lda .segPort+1
    jsr writeToLinkTable

    inc zp_linecount
    bne +
    inc zp_linecount+1

+   lda .nrSegments
    cmp zp_tempA
    beq +
    inc zp_tempA
    jmp -

+   rts

.storeValueInLinkTable
    ldy #0
    jsr writeToLinkTable
    rts

.storePointerInLinkTable
    ldy #0
    lda zp_contentAddress
    jsr writeToLinkTable
    lda zp_contentAddress+1
    jsr writeToLinkTable
    rts

.storePointerInOffsetList
    asl .nrSegments
    ldx .nrSegments
    lda zp_contentAddress
    sta .offsetList,x
    lda zp_contentAddress+1
    sta .offsetList+1,x
    lsr .nrSegments
    rts

.storeLengthInList
    ldx .nrSegments
    lda .lineLengthG
    sta .lengthList,x
    rts

.stashToLinkTable
    ldx zp_contentBank
    ; y must be set accordingly at this point
    jsr c_stash
    inc zp_linkTablePosition
    bne +
    inc zp_linkTablePosition+1

+   rts

.resetSegmentData
    lda #0
    ldy #.segmentDataLength
    
-   sta .lineLengthG,y
    dey
    bpl -

    rts

.parseMode      !byte 0 ; $69 for i, $31 for 1, etc
.parseSeq       !byte 0 ; 0=type specific parsing, 1=selector, 2=hostname, 3=port
.startFound     !byte 0    ; positive=start found.
.lineLengthG    !byte 0    ; used to keep track of 80 chars max per line

; keeps track of how many segments need to be written
.nrSegments     !byte 0     ; 4 segments max (78 chars max each)
.offsetList     !fill 8     ; 4 offsets max, 2 bytes each
.lengthList     !fill 4     ; 4 lenghts max, 1 byte each

.segType        !byte 0     ; type to write for each segment
.segHost        !word 0     
.segPort        !word 0     
.segSelector    !word 0     
.segmentDataLength = *-.lineLengthG-1