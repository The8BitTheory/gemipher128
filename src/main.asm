; ------------
; memory map
; ------------
; $0.1c01 - $0.bfff: programcode. only enable basic-rom when needed


; configuration constants
; CONTENT describes one full gopher page
CONTENT_BANK = 1
CONTENT_ADDRESS = $0400

; bank 1 used for data
;  no clue yet whether to work with indirect kernal routines, or with common memory
;  speed is not essential, so I guess we'll go with indirect routines
;  will need to either copy data to bank 0 for VDC-related things, or make VDC libs interact with bank 1

; zero page addresses. we use $0a-$8f ($80 and up is used by vdc-basic)
zp_contentAddress = $0a
zp_linecount = $0c
zp_tempX = $0e      ; used to hold x register when working with FAR routines
zp_tempY = $0f    ; used to hold y register when working with FAR routines

zp_contentBank  = $10

; common memory area below $0400
c_stash = $02af

; basic rom lo $4000-$7fff
b_fast = $77b3
b_slow = $77c4

; basic rom hi $8000-$bfff

; monitor, screen editor $c000-$cfff

; i/o $d000-$dfff

; kernal $e000-$ffff
k_primm = $ff7d
k_getin = $eeeb
bsout = $ffd2

!macro print textaddress {
    pha
    txa
    pha

    ldx #0
-   lda textaddress,x
    beq +
    jsr bsout
    inx
    jmp -

+   pla
    tax
    pla
}

*=$1c01
;!byte $1c,$1c,$0a,$00
;!byte $fe,$11,$22,$56,$44,$43,$42,$41,$53,$49,$43,$32
;!byte $47,$2e,$31,$33,$30,$30,$22,$2c,$42,$30,$00   ;bload vdcbasic
;!byte $2c,$1c,$14,$00
;!byte $9e,$20,$d1,$28,$22,$31,$33,$30,$30,$22,$29,$00   ; sys dec("1300")
;!byte $49,$1c,$19,$00
;!byte $fe,$11,$22,$41,$53,$43,$49,$49,$32   
;!byte $2e,$43,$48,$52,$22,$2c,$42,$30           ;bload ascii2
;!byte $2c,$50,$31,$36,$33,$38,$34,$00
;!byte $63,$1c,$1e,$00
;!byte $fe,$31,$20,$31,$36,$33,$38,$34,$2c
;!byte $d1,$28,$22,$33,$30,$30,$30,$22
;!byte $29,$2c,$39,$36,$00                       ;vcc
;!byte $6e,$1c,$b5
;!byte $07,$9e,$20,$37,$34,$32,$34,$00       ;sys 7424
;!byte $00,$00
!byte $0b,$1c,$b5,$07,$9e,$20,$37,$34,$32,$34,$00,$00,$00

*=$1d00
main
;    jsr k_primm
;    !pet "pet klein GROSS",0
;    jsr k_primm
;    !text "ascii klein GROSS",0

    jsr disableBasicRom

    jsr saveZp

    jsr initVdc

    jsr .initContentAddress

    lda #14
    jsr bsout

    jsr loadGopherPage

    ; set zp_content to beginning of content so we can start parsing that now
    jsr .initContentAddress

    lda #$0d
    jsr bsout
    jsr doFast
    jsr parseGopher
    jsr doSlow

    jsr recoverZp
    rts
    nop


.initContentAddress
;    lda #0
;    sta zp_linecount
;    sta zp_linecount+1

    lda #<CONTENT_ADDRESS
    sta zp_contentAddress
    lda #>CONTENT_ADDRESS
    sta zp_contentAddress+1
    rts



; used for regular runtime (should leave us with $1c01 - $bfff for program code. close to 42 kB )
disableBasicRom
    lda #%00001110
    sta $ff00
    rts

; used for slow/fast
enableBasicLo
    lda #%00000000
    sta $ff00
    rts

doFast
    jsr enableBasicLo
    jsr b_fast
    jmp disableBasicRom

doSlow
    jsr enableBasicLo
    jsr b_slow
    jmp disableBasicRom

k_indsta
    pha
    lda mmuBankConfig,x	; MMU Bank Configuration Values
    tax
    pla
    jmp $02AF	; Bank Poke Subroutine

; stores $0a-$8f to somewhere else
saveZp
    ldx #$0a
    ldy #0
-   lda $0,x
    sta zpStore,y
    iny
    inx
    cpx #$8f+1
    bne -
    rts

recoverZp
    ldx #$0a
    ldy #0
-   lda zpStore,y
    sta $0,x
    iny
    inx
    cpx #$8f+1
    bne -
    rts

!src "src/file/load.asm"
!src "src/vdc.asm"
!src "src/network/networkWic.asm"
!src "src/parseGopher.asm"
!src "src/wic64/wic64.asm"

; these are the mappings from basic's bank command to the actual mmu config-register values
mmuBankConfig       !byte $3F,$7F,$BF,$FF,$16,$56,$96,$D6,$2A,$6A,$AA,$EA,$06,$0A,$01,$00

; this is used to keep an original copy of the zero-page range we're using. is restored when program ends
zpStore             !fill 134


fileOpError         !byte 0
filenameCharset     !pet "ascii2.chr"
filenameLength=*-filenameCharset

; this contains the vectors to all information per line
; start address (beginning of first line) is written after content is completely stored in 'permResponse'
; 10 bytes per line
; type, text, selector, host, port
; this could be kept at 4kb below I/O space at $c000 (2kb of table space is good for 200 lines)
linkTable           !word 0

;permResponse        !byte 0

