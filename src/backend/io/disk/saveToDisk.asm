!zone saveToDisk

; the different of this to "saveContentToDisk" is
; - writing the value in Acc to disk directly
; - no pre-defined diskWriteEndAddress. We write until either disk is full or download is done
downloadDirectlyToDisk
    jsr selectorToFilename
    jsr .prepareDiskWrite
    ; writing to disk is called by the wic64 store instruction
    jmp downloadWic2disk

finishDownload
    jmp .close


selectorToFilename
;    lda #zp_currentSelectorPtr
;    sta c_fetch_zp
    ;lda #<address
    lda zp_currentSelectorPtr
    sta zp_memPtr
    ;lda #>address
    lda zp_currentSelectorPtr+1
    sta zp_memPtr+1

    ldy #0
    sty .diskFilenameSlashPos

-   lda (zp_memPtr),y
    beq .writeDiskFilename
    cmp #$09    ; tab ends the selector string
    beq .writeDiskFilename
    cmp #'/'
    bne +   ; no /, go to next line
    sty .diskFilenameSlashPos   ; store current position as slashPos
+   iny
    beq .writeDiskFilename
    jmp -

.writeDiskFilename
    ldx #0
    stx zp_tempX
    ldy .diskFilenameSlashPos
    iny ; skip the /
    sty zp_tempY
-   ldy zp_tempY
    lda (zp_memPtr),y
    beq +
    cmp #$09
    beq +
    cmp #$0d
    beq +
    ldx zp_tempX
    sta diskFilename,x
    inc zp_tempY
    inc zp_tempX

    jmp -

+   inx
    stx diskFilenameLength
    rts

saveContentToDisk
; saves content from ram to disk.
; size of data is known upfront
; calculate filename
;  this is a 6-byte hash-value, generated from gopher host:port/selector
;  hash is converted to base-36 with 13 characters length (allows for ca 67 bits. 64 are used for 8-byte has)
;  44 bits are used for the filename hash
;  

;   bsave requires last byte value to be 1 byte beyond the last byte to write
    clc
    lda zp_contentAddress
    adc #1
    sta diskWriteEndAddress
    lda zp_contentAddress+1
    adc #0
    sta diskWriteEndAddress+1

    ;for now, use chars after the last slash of selector for filename
    jsr selectorToFilename

;   we start saving from $0400 in bank 1 (bank is set down below with SETBNK)
    lda #$00
    sta zp_memPtr
    lda #$04
    sta zp_memPtr+1

    jmp .doDiskIO


.prepareDiskWrite
        lda #0
        sta fileOpError

        LDA diskFilenameLength
        LDX #<diskFilename
        LDY #>diskFilename
        JSR $FFBD     ; call SETNAM

        LDA #$02      ; file number 2
        LDX $BA       ; last used device number
        BNE +
        LDX #$08      ; default to device 8
+       LDY #$00      ; secondary address 2. irrelevant for saves to serial devices
        JSR $FFBA     ; call SETLFS

        lda #1  ; bank to save data from $c6
        ldx #0  ; bank of filename $c7
        jsr $ff68 ; call SETBNK

        lda $0332
        sta .vectorSave
        lda $0333
        sta .vectorSave+1

        lda #<.saveRaw
        sta $0332
        lda #>.saveRaw
        sta $0333

        ; x/y = end address+1 of write operation (lb/hb)
        ; a = zp location holding the start address of the write operation
        ldx diskWriteEndAddress
        ldy diskWriteEndAddress+1
        lda #zp_memPtr

        rts

.doDiskIO
        jsr .prepareDiskWrite
        ;jsr .saveRaw
        jsr $ffd8       ;BSAVE (does jmp f53e)
        
        bcs .error

.close
        LDA #$02      ; filenumber 2
        JSR $FFC3     ; call CLOSE

        JSR $FFCC     ; call CLRCHN

        lda .vectorSave
        sta $0332
        lda .vectorSave+1
        sta $0333

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

.writeerror
        ;... error handling for write errors ...
        sta fileOpError

        ; for further information, the drive error channel has to be read
        jsr readStatusChannel
        jsr printDiskStatus

        JMP .close

; save to disk without writing the address to the first two bytes
.saveRaw

    lda $ba     ; current device
    cmp #$04    ; only allow devices >= 4
    bcs +
    
    ; error messages. prints need to be replaced with ui-friendly routines later
    jmp $f694   ; print 'illegal device no'
.printMissingFilename
    jmp $f691
.printFileNotFound
    jmp $f685

+   ldy $b7 ;nr of chars in filename
    beq .printMissingFilename
    lda #$61
    sta $b9     ; current secondary address
    jsr $f0cb   ; check serial open
    ;jsr $f5bc   ; print 'saving'
    lda $ba     ; current device
    jsr $e33e   ; - listen -
    lda $b9     ; current secondary address
    jsr $e4d2   ; - second -
    ldy #$00
    jsr $ed51   ; reset pointer
    
    jmp $f586   ; continue at kernal routine for bsave


.vectorSave             !word 0
.diskFilenameSlashPos   !byte 0

diskWriteEndAddress     !word 0
diskFilename            !fill 18
diskFilenameLength      !byte 0

; not used yet. would be used later for deciding, where to write the file to
;  besides disk, this will likely be Ultimate-II DMA write
diskWriteHost           !text "device",$9
diskWritePort           !text "8\r\n"
