; this is currently only intended to load the charset.
; if used otherwise, overwriting of existing memory locations might cause problems

!zone loadcontent
.load_address = $0400  ; make sure file size doesn't run over 4kb.

loadContentFromDisk
        lda #1
        sta fileOpError
        lda #0
        sta .byteCount

        LDA diskFilenameLength
        LDX #<diskFilename
        LDY #>diskFilename
        JSR $FFBD     ; call SETNAM

        LDA #$02      ; file number 2
        ;LDX $BA       ; last used device number
        ldx deviceNumber
        BNE +
        LDX #$08      ; default to device 8
+       LDY #$00      ; secondary address 0     ; 0=load to x/y address, 1=load to header address
        JSR $FFBA     ; call SETLFS

        lda #1  ; bank to load data to
        ldx #0  ; bank of filename and drive pointer
        jsr $ff68 ; call SETBNK

        ldx #<.load_address
        ldy #>.load_address
        lda #0  ; 0=load, else=verify)
        
        ; we can't use BLOAD, as it can't go without two header bytes
        jsr $ffd5       ;BLOAD
        
        
        bcs .error
        rts

.close
        LDA #$02      ; filenumber 2
        JSR $FFC3     ; call CLOSE

        JSR $FFCC     ; call CLRCHN
        RTS
.error
        ; Accumulator contains BASIC error code

        ; most likely errors:
        ; A = $05 (DEVICE NOT PRESENT)

        ;... error handling for open errors ...
        lda #0
        sta fileOpError
        JMP .close    ; even if OPEN failed, the file has to be closed
.readerror
        ; for further information, the drive error channel has to be read

        ;... error handling for read errors ...
        lda #0
        sta fileOpError
        JMP .close




.byteCount      !byte 0
.maxBytes = 24

