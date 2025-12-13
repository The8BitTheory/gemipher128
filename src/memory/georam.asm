; This contains all code relating to the GeoRAM memory expansion.
; - storing to GeoRAM
; - reading from GeoRAM
; and of course
; - detect GeoRAM

!zone georam

.GEORAM_END_ADDRESS = $4000 ; one block has 16kb. we reach that, we have to switch to the next one

.GEO_HB = $dfff ; : Nr. des 16KB-Blocks
;        bei  512KB : $00 - $1f ->  32 * 16KB =  512KB
;        bei 1024KB : $00 - $3f ->  64 * 16KB = 1024KB
;        bei 2048KB : $00 - $7f -> 128 * 16KB = 2048KB

.GEO_MB = $dffe ; : Nr. des 256 Byte-Blocks im gewählten 16KB-Block
;        $00 bis $3f -> 40 * 256 Byte = 16KB

.GEO_DATA = $de00  ; to $deff

storeInGeoRam
    jsr enableIO
    ldy #0
    sty zp_tempX    

    ldy .dataOffset

-   ldx zp_tempX
    lda response,x

    sta .GEO_DATA,y
    iny
    bne +   ;if y rolls over, increase GEO_MB

    inc .mbOffset
    lda .mbOffset
    sta .GEO_MB
    bne +

    inc .hbOffset
    lda .hbOffset
    sta .GEO_HB
    
+   inc zp_tempX
    
    dec packBytes
    bne -

    sty .dataOffset

    clc
    tya
    adc zp_contentAddress
    sta zp_contentAddress
    bcc +
    inc zp_contentAddress+1

; check if we reached the end of available RAM
+   lda #>.GEORAM_END_ADDRESS
    cmp zp_contentAddress+1
    bcs +
    lda #<.GEORAM_END_ADDRESS
    cmp zp_contentAddress
    bcs +
    
    sec
    rts

+   clc
    tya
    adc zp_responseSize
    sta zp_responseSize
    bcc +
    inc zp_responseSize+1

+   clc
    rts


initGeoRam
    lda zp_georam_blocks
    sta .GEO_HB

    lda #0
    sta .GEO_MB
    sta .dataOffset
    sta .mbOffset
    sta .hbOffset

    rts

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
    sta zp_georam_blocks
    dec zp_georam_blocks

    lda #2
    sta zp_perm_target

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

.hbOffset   !byte 0
.mbOffset   !byte 0     
.dataOffset !byte 0     ;we store the current y-position between datablock writes here