; taken from https://codebase.c64.org/doku.php?id=base:reu_detect
!zone reu

!addr
    REU_END_ADDRESS = $fff0
    reu_command     = $df01
    REUCOMMAND_STASH    = $80   ; on $ff00, no reload
    REUCOMMAND_FETCH    = $81   ; on $ff00, no reload
!addr {
    reu_c64addr_lo      = $df02
    reu_c64addr_hi      = $df03
    reu_extaddr_lo      = $df04
    reu_extaddr_hi      = $df05
    reu_extaddr_bank    = $df06
    reu_len_lo      = $df07
    reu_len_hi      = $df08
    reu_irq           = $df09
    reu_addr_ctrl       = $df0a 
}


initReu
    lda #%10010000  ; only increment REU Address
    sta reu_addr_ctrl

    sec
    lda zp_reu_blocks
    sbc #1
    sta .reuBlock

.resetReuExtAddr
    lda #0
    sta reu_irq ; don't trigger any interrupts
    sta reu_extaddr_lo
    sta reu_extaddr_hi

    rts

storeInReu

    
    ; have reu auto-increment the write address
    lda .reuBlock
    sta reu_extaddr_bank

    ; nr of bytes to copy
    lda packBytes       ; dmacopy 240 bytes from response to reu
    sta reu_len_lo
    lda #0
    sta reu_len_hi

    lda #<response
    sta reu_c64addr_lo
    lda #>response
    sta reu_c64addr_hi

    ldy #REUCOMMAND_STASH
    ldx #1
    lda mmuBankConfig,x

    jsr DMA

    ;clc
    ;lda packBytes
    ;adc zp_contentAddress
    ;sta zp_contentAddress
    ;bcc +
    ;inc zp_contentAddress+1
    lda reu_extaddr_lo
    sta zp_contentAddress
    lda reu_extaddr_hi
    sta zp_contentAddress+1

; check if we reached the end of available RAM
+   lda #>REU_END_ADDRESS
    cmp zp_contentAddress+1
    bcs .exitRamLeft
    lda #<REU_END_ADDRESS
    cmp zp_contentAddress
    bcs .exitRamLeft
    
    ; end of ram of this bank
    ; check if more banks available
    ; this works for banks 0-255 (ie 16 MB REU)
    sec
    lda .reuBlock
    sbc #1
    sta .reuBlock
    bcc .exitEndOfRam

    jsr .resetReuExtAddr
    jmp .exitRamLeft

.exitEndOfRam
    sec
    rts
    nop

; exit with ram left
.exitRamLeft
    clc
    lda packBytes
    adc zp_responseSize
    sta zp_responseSize
    bcc +
    inc zp_responseSize+1

+   clc
    rts
    nop



readFromReu
    ; go to initial bank (the highest one)
    sec
    lda zp_reu_blocks
    sbc #1
    sta reu_extaddr_bank

    ; read from the beginning of the reu-bank
    lda #0
    sta reu_extaddr_lo
    sta reu_extaddr_hi

    ; write to $0400 in bank 1
    lda #<CONTENT_ADDRESS
    sta reu_c64addr_lo
    lda #>CONTENT_ADDRESS
    sta reu_c64addr_hi

    lda zp_responseSize
    sta reu_len_lo
    lda zp_responseSize+1
    sta reu_len_hi

    ldx #1
    lda mmuBankConfig,x
    ldy REUCOMMAND_FETCH
    jsr DMA


    rts
    nop


; returns:
;   Carry = 0, A = 0    NO REU detected
;   Carry = 1, A = 0    256 Banks (16MB)
;   else Carry = 0, A = number of RAM banks found in REU
detectREU
        ldx #0  ; pre-init
        stx zp_reu_blocks
        stx zp_reu_blocks+1
        ; first write signatures to banks in *descending* order (banks 255..0):
----    dex
        stx banknum
        lda #<signature_start
        ldx #>signature_start
        ldy #REUCOMMAND_STASH
        jsr set_registers_AXY
        ; all banks written?
        ldx banknum
        bne ----

        ; now check signatures in *ascending* order:
; (checking signatures could be shortened by using the REC's "verify" command,
; but I'm reluctant to use this function in a "REU detect" routine: it could
; be buggy in modern FPGA implementations because it is so seldomly used)
        ; banknum just became zero so no need to init it
----    lda #<sig_candidate_start
        ldx #>sig_candidate_start
        ldy #REUCOMMAND_FETCH
        jsr set_registers_AXY
        ; compare data
        ldx #SIGNATURE_LENGTH_LOW - 1
--      lda sig_candidate_start, x
        cmp signature_start, x
        bne @failed
        dex
        bpl --
    ; bank has correct signature
        inc banknum ; next bank (== number of banks already found)
        bne ----

        ; there are actually 256 banks!
        sec
        lda banknum
        sta zp_reu_blocks
        bcc +
        lda #1
        sta zp_reu_blocks+1
+       jmp .exitReu
 
@failed 
    clc
    lda banknum
    sta zp_reu_blocks

.exitReu
    lda zp_reu_blocks+1
    bne +
    lda zp_reu_blocks
    bne +
    rts

+   lda #1
    sta zp_perm_target
    rts

set_registers_AXY ; setup REU registers (used for both reading and writing)
; A/X: c64 address
; Y: REU command
    sta reu_c64addr_lo
    stx reu_c64addr_hi
    ldx #0
    stx reu_extaddr_lo
    stx reu_extaddr_hi
    lda banknum
    sta reu_extaddr_bank
    lda #SIGNATURE_LENGTH_LOW
    sta reu_len_lo
    stx reu_len_hi
    sty reu_command
    rts
 
; signature we write to REU banks, first byte is bank number
signature_start
banknum     !tx 0, "bliblablub"
    SIGNATURE_LENGTH_LOW = * - signature_start
 
; target buffer when reading signatures back from REU
sig_candidate_start
        !tx "XBLIBLABLUB"   ; must be same length as signature above, obviously
sig_candidate_end
    SIGNATURE_LENGTH_LOW = * - sig_candidate_start

.reuBlock   !byte 0