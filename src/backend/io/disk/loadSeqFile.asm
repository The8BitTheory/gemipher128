; this is currently only intended to load the charset.
; if used otherwise, overwriting of existing memory locations might cause problems

!zone loadcontent
.load_address = $0400  ; make sure file size doesn't run over 4kb.


loadSeqFromDisk
        lda #0
        sta fileOpError
        sta .byteCount

        LDA diskFilenameLength
        LDX #<diskFilename
        LDY #>diskFilename

        jsr prepareLoadOpen
        stx zp_memPtr
        sty zp_memPtr+1
        
        ; do OPEN to read the first two bytes
        jsr $ffc0       ; open

        ; x: filenumber
        ldx #$02
        jsr $ffc9       ; jchkout
        bcs .error

        lda #zp_memPtr
        sta c_stash_zp

        ldy #32

        ldx #0
-       jsr $ffd2       ; jbasout
        sta .scratchArea,x
        inx
        dey
        bne -
        
        
.concludeLoadOpen
        ;bcs .error

        ; write to content address here
        ; the error page writes the correct contentAddress itself
        lda $ae
        sta zp_contentAddress
        lda $af
        sta zp_contentAddress+1

.close
        LDA #$02      ; filenumber 2
        JSR $FFC3     ; call CLOSE

        JSR $FFCC     ; call CLRCHN
        RTS

.error
        ; Accumulator contains BASIC error code
        sta fileOpError

        ; most likely errors:
        ; A = $05 (DEVICE NOT PRESENT)

        ; for further information, the drive error channel has to be read
        jsr readStatusChannel
        ;jsr printDiskStatus
        
        Jsr .close    ; even if OPEN failed, the file has to be closed
        jmp createFileNotFoundPage

.readerror
        ;... error handling for read errors ...
        sta fileOpError

        ; for further information, the drive error channel has to be read
        jsr readStatusChannel
        ;jsr printDiskStatus

        Jsr .close
        jmp createFileNotFoundPage

.byteCount      !byte 0
.maxBytes = 24
.filenameDirectory  !text '$'
.scratchArea    !fill 32