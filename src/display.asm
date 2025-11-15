    lda .parseMode
    cmp #$69 ;i - info
    bne +
    lda #$5     ;white
    jsr bsout
    jmp .handleInfo

+   cmp #$30 ; 0 - textfile
    bne +
    lda #$9c    ; purple
    jsr bsout
    jmp .handleTypeText

+   cmp #$31 ; 1 - menu / directory
    bne +
    lda #$1e    ; green
    jsr bsout
    jmp .handleTypeMenu

+   cmp #$32 ; 2 - cso phonebook
    bne +
    lda #$9a ;light blue
    jsr bsout
    jmp .handleTypePhonebook

+   cmp #$33 ; 3 - error/info
    bne +
    jmp .handleTypeError

+   cmp #$34 ; 4 - binary
    bne +
    jmp .handleTypeBinary

+   cmp #$35 ; 5 - dos binary
    bne +
    jmp .handleTypeDosBinary

+   cmp #$36 ; 6 - uuencoded text (probably a binary?)
    bne +
    jmp .handleTypeUUenc

+   cmp #$37 ; 7 - error/info
    bne +
    jmp .handleTypeSearch

+   cmp #$38 ; 8 - Telnet
    bne +
    jmp .handleTypeTelnet

+   cmp #$39 ; 9 - generic binary
    bne +
    jmp .handleTypeGenericBinary

+   cmp #'+' ; + - gopher + info
    bne +
    jmp .handleTypePlus

+   cmp #'g' ; G - GIF
    bne +
    jmp .handleTypeGif

+   cmp #'l' ; L - generic image
    bne +
    jmp .handleTypeGenericImage

+   cmp #'h' ; H - Hyperlink
    bne +
    lda #$9e    ; $9e=yellow, $81=dark purple (should be orange, which is not a vdc-color)
    jsr bsout
    jmp .handleTypeHyperlink

+   cmp #'s' ; s - audio
    bne +
    jmp .handleTypeAudio

+   cmp #'M' ; m - multipart mime
    bne +
    jmp .handleTypeMime

+   cmp #'D' ; d - document. mostly pdf
    bne +
    jmp .handleTypeDoc

+   cmp #'T' ; t - terminal connection tn3270
    bne +
    jmp .handleTypeTerminal

+   cmp #$9 ;tab
    bne +
    jmp .handleTab

+   lda #$12 ;reverse on
    jsr bsout
    lda #'x'
    jsr bsout
    rts
