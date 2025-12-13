; this is currently only intended to load the charset.
; if used otherwise, overwriting of existing memory locations might cause problems

!zone loadfile
;load_address = $b000  ; make sure file size doesn't run over 4kb.

loadCharsetFromDisk
        LDA #.filenameLength
        LDX #<.filenameCharset
        LDY #>.filenameCharset
        jmp .loadRoutine

loadSwiftlinkDriverFromDisk
        lda #.filenameSwiftlinkLength
        ldx #<.filenameSwiftlink
        ldy #>.filenameSwiftlink

.loadRoutine
        JSR $FFBD     ; call SETNAM

        lda #1
        sta fileOpError
        lda #0
        sta .byteCount

        LDA #$02      ; file number 2
        LDX $BA       ; last used device number
        BNE +
        LDX #$08      ; default to device 8
+       LDY #$01      ; secondary address 2 (0=relocated load, 1=load to position in fileheader)
        JSR $FFBA     ; call SETLFS

        lda #0
        ldx #0
        jsr $ff68 ; call SETBNK

;        ldx #<load_address
;        ldy #>load_address
        lda #0
        
        jsr $ffd5       ;BLOAD
        
        bcs .error
        rts

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

.filenameCharset     !pet "latin9ui.char"
.filenameLength=*-.filenameCharset

.filenameSwiftlink      !pet "swiftlib128"
.filenameSwiftlinkLength=*-.filenameSwiftlink
