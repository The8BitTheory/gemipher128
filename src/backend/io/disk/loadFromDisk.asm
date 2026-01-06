; this is currently only intended to load the charset.
; if used otherwise, overwriting of existing memory locations might cause problems

!zone loadcontent
.load_address = $0400  ; make sure file size doesn't run over 4kb.

loadContentFromDisk
        lda #0
        sta fileOpError
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
        jsr printDiskStatus
        
        
        JMP .close    ; even if OPEN failed, the file has to be closed
.readerror
        ;... error handling for read errors ...
        sta fileOpError

        ; for further information, the drive error channel has to be read
        jsr readStatusChannel
        jsr printDiskStatus

        JMP .close




.byteCount      !byte 0
.maxBytes = 24

