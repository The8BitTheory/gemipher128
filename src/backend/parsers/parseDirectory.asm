!zone directoryParser

; contrary to regular parsers, which construct just the zp_linktable entries, this parser also
; constructs the content starting at content_address (gopher lines that show the directory contents)
; this is similar behavior to information or fileNotFound and timeout pages

; the challenge here is that we need to read the directory from $1.0400
; and write the gopher structure also to $1.0400

; 144 entries for a 1541
; 296 entries for a 1581
; each entry 31 bytes -> 9176 bytes
!macro writeLnToDir .nullTerminatedGopherLine {
    ldx #0
    stx zp_tempX
-   ldx zp_tempX
    lda .nullTerminatedGopherLine,x
    beq +
    jsr writeToDirectory
    inc zp_tempX
    jmp -

+   inc zp_linecount
    bne +
    inc zp_linecount+1
+
}

parseDirectory
    jsr .initDirectoryGopherOutput

    jsr initParser

    lda #zp_directoryAddress
    sta c_stash_zp

    ; skip 5 bytes (8 really, but 2 were skipped by bload itself)
    ; one of these is the reverse-flag for screen output. we ignore that
    jsr readNextByte
    jsr readNextByte
    jsr readNextByte
    jsr readNextByte
    jsr readNextByte

    jsr clearScreen

    ldy #5
    ; read diskname
    jsr .handleDiskName

    jsr clearHeaderLine

    lda #<.txtDirOfDisk
    sta zp_memPtr
    lda #>.txtDirOfDisk
    sta zp_memPtr+1
    jsr printHeaderLineUntilTab

    lda #<.diskname
    sta zp_memPtr
    lda #>.diskname
    sta zp_memPtr+1
    jsr printHeaderLineUntilTab

    lda #<.txtDash
    sta zp_memPtr
    lda #>.txtDash
    sta zp_memPtr+1
    jsr printHeaderLineUntilTab

; parsing dir entries until end of dir
-   jsr readNextByte    ;$01
    jsr readNextByte    ;$01

    jsr readNextByte
    sta .entryBlocks
    jsr readNextByte
    sta .entryBlocks+1
    lda .entryBlocks
    ldx .entryBlocks+1
    jsr makeItDec
    jsr .skipZeroes
    sty zp_tempX

    jsr readNextByte    ; space if dir entry, B ($42) if end of dir (B of BLOCKS FREE)
    cmp #' '
    bne +
    jsr .handleDirEntry ; name and type is parsed here
    jmp -

; parsing dir entries done
; entryBlocks already contains the nr of free bytes
+   sta zp_tempA
    lda .entryBlocks
    ldx .entryBlocks+1
    jsr makeItDec
    jsr .skipZeroes

    clc
    tya
    adc #<decResult
    sta zp_memPtr
    lda #>decResult
    adc #0
    sta zp_memPtr+1
    jsr printHeaderLineUntilTab

    lda #' '
    jsr printAcc

    jsr .handleDirEnd

    lda #<.blocksFree
    sta zp_memPtr
    lda #>.blocksFree
    sta zp_memPtr+1
    jsr printHeaderLineUntilTab

    +writeLnToDir txtEmptyLine
    +writeLnToDir txtEmptyLine
    +writeLnToDir txtDot
    
    rts

.handleDirEntry   ;blocks, name, type
    lda #'i'
    jsr writeToDirectory

    ; write blocks. zp_tempX was written after .skipZeroes
-   ldy zp_tempX
    lda decResult,y
    beq +
    jsr writeToDirectory
    inc zp_tempX
    jmp -

-   jsr readNextByte    ; the first byte should be a quote char
    beq +
    jsr writeToDirectory
    jmp -

+   +writeLnToDir txtTrail
    rts


; we should write the diskname to the headerline
.handleDiskName
    ; write I and header
    jsr writeToDirectory

    ldx #0
    stx zp_tempX
-   jsr readNextByte    ; this should be a quote char
    beq +
    ldx zp_tempX
    sta .diskname,x
    inc zp_tempX
    jmp -

+   rts

; string is also 24 bytes long. BLOCKS FREE with trailing spaces
.handleDirEnd
    ldx #0
    stx zp_tempX
    lda zp_tempA
    sta .blocksFree,x
    inc zp_tempX

-   jsr readNextByte    ; this should be a quote char
    beq +
    ldx zp_tempX
    sta .blocksFree,x
    inc zp_tempX
    lda zp_tempX
    cmp #26
    beq +
    jmp -

+   rts
    nop

.initDirectoryGopherOutput
    lda zp_contentAddress
    sta zp_directoryAddress
    lda zp_contentAddress+1
    sta zp_directoryAddress+1

    lda #0
    sta zp_linecount
    sta zp_linecount+1
    jsr initRamLeft

    lda #$31
    sta zp_pageType

    rts

writeToDirectory
    ldx zp_contentBank
    ldy #0
    jsr c_stash

    inc zp_directoryAddress
    bne +
    inc zp_directoryAddress+1
    
+   inc zp_responseSize
    bne +
    inc zp_responseSize+1

+   rts

.skipZeroes
    ; skip leading zeroes
    ldy #0
    ldx #0
-   lda decResult,x
    beq ++  ; null byte found, we're done
    cmp #$30
    bne +
    iny
+   inx
    jmp -
++  rts

.diskname       !fill 26,0
.blocksFree     !fill 26,0
.entryBlocks    !word 0
.txtDirOfDisk   !text "Directory of disk: ",0
.txtDash        !text " - ",0