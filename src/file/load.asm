!zone loadfile
load_address = $4000  ; just an example

loadFromDisk
        lda #1
        sta fileOpError
        lda #0
        sta .byteCount

        LDA #filenameLength
        LDX #<filenameCharset
        LDY #>filenameCharset
        JSR $FFBD     ; call SETNAM

        LDA #$02      ; file number 2
        LDX $BA       ; last used device number
        BNE +
        LDX #$08      ; default to device 8
+       LDY #$00      ; secondary address 2
        JSR $FFBA     ; call SETLFS

        lda #0
        ldx #0
        jsr $ff68 ; call SETBNK

        ldx #<load_address
        ldy #>load_address
        lda #0
        jsr $ffd5       ;BLOAD
        
        bcs .error
        rts


;        JSR $FFC0     ; call OPEN
;        BCS .error    ; if carry set, the file could not be opened

        ; check drive error channel here to test for
        ; FILE NOT FOUND error etc.

;        LDX #$02      ; filenumber 2
;        JSR $FFC6     ; call CHKIN (file 2 now used as input)

;        LDA #<load_address
;        STA $AE
;        LDA #>load_address
;        STA $AF

;        LDY #$00
;-       JSR $FFB7     ; call READST (read status byte)
;        BNE .eof      ; either EOF or read error
;        JSR $FFCF     ; call CHRIN (get a byte from file)
;        STA ($AE),Y   ; write byte to memory
;        INC $AE
;        BNE +
;        INC $AF

;+       inc .byteCount
;        ldx .byteCount
;        cpx #.maxBytes
;        beq .eof        ; if we have reached 24 bytes, stop loading
;        JMP -     ; next byte

;.eof
;        AND #$40      ; end of file?
;        BEQ .readerror
.close
        LDA #$02      ; filenumber 2
        JSR $FFC3     ; call CLOSE

        JSR $FFCC     ; call CLRCHN
        RTS
.error
        ; Akkumulator contains BASIC error code

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