; This contains all code relating to the GeoRAM memory expansion.
; - storing to GeoRAM
; - reading from GeoRAM
; and of course
; - detect GeoRAM

!zone georam

detectGeoRAM
    jsr enableIO

    lda #$00
    sta zp_georam_blocks
    sta $dffe

    lda #%11111111
    sta $dfff
    lda #$04   ;4MB Marker
    sta $de00

    lda #%01111111
    sta $dfff
    lda #$03   ;2MB Marker
    sta $de00

    lda #%00111111
    sta $dfff
    lda #$02   ;1MB Marker
    sta $de00

    lda #%00011111
    sta $dfff
    lda #$01   ;512KB Marker
    sta $de00

    lda #%00000000
    sta $dfff

    lda #$01  ;4 Byte Magic Marker
    sta $de00
    lda #$02
    sta $de01
    lda #$03
    sta $defe
    lda #$04
    sta $deff

    lda $de00 ;Confirm 4 Byte Magic
    cmp #$01
    bne .nomem
    lda $de01
    cmp #$02
    bne .nomem
    lda $defe
    cmp #$03
    bne .nomem
    lda $deff
    cmp #$04
    beq .configMaxmem

.nomem
    lda #$05   ;GeoRAM Not Detected
    jmp .errout


    ;Config maxmem from Marker Code
.configMaxmem
    lda #%11111111
    sta $dfff
    ldx $de00

    lda .mempgs,x
    sta .maxmem+2

    ;Output Detected Memory String


    jmp disableIO
    nop
    nop

;------------------------------------------
.errout
    jmp disableIO
    rts
    nop

.strout   ;Output String to Screen
         ;Y -> String Ptr Hi Byte
         ;A -> String Ptr Lo Byte

         

         lda #13 ;Carriage Return
         jmp bsout
         nop


;------------------------------------------
.maxmem   !byte $00,$00,$00,$00
.mempgs   !byte $00,$08,$10,$20,$40

.memtab
    !word .str0mem, .str5mem, .str1mem, .str2mem, .str4mem

.str5mem  !text "GeoRAM 512K Detected "
.str1mem  !text "GeoRAM 1MB Detected "
.str2mem  !text "GeoRAM 2MB Detected "
.str4mem  !text "GeoRAM 4MB Detected "
.str0mem  !text "GeoRAM not Detected "