; this is currently only intended to load the charset.
; if used otherwise, overwriting of existing memory locations might cause problems

!zone loadfile
;load_address = $b000  ; make sure file size doesn't run over 4kb.

loadCharsetFromDisk
        LDA #.filenameLength
        LDX #<.filenameCharset
        LDY #>.filenameCharset
        jmp .loadRoutine

.loadRoutine
        JSR $FFBD     ; call SETNAM


        lda #0
        sta .byteCount
        sta fileOpError

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
        

.close
        LDA #$02      ; filenumber 2
        JSR $FFC3     ; call CLOSE

        JSR $FFCC     ; call CLRCHN
        lda fileOpError
        RTS
.error
        ; Akkumulator contains BASIC error code
        sta fileOpError
        ; most likely errors:
        ; A = $05 (DEVICE NOT PRESENT)

        ;... error handling for open errors ...
        jsr readStatusChannel
        jsr printDiskStatus
        
        JMP .close    ; even if OPEN failed, the file has to be closed
.readerror
        sta fileOpError

        ; for further information, the drive error channel has to be read
        jsr readStatusChannel
        jsr printDiskStatus
        ;... error handling for read errors ...
        
        JMP .close


.byteCount      !byte 0
.maxBytes = 24

.filenameCharset     !pet "latin9ui.char"
.filenameLength=*-.filenameCharset
