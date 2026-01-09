!zone directory

; this triggers loading the directory. the contents are loaded into $1:0400 just like any other content
; after that, the directory-parser will generate a gopher structure of the directory while building up
; the zp_linktable entries just like for any regular gopher page.
; finally, regular gopher routines for copying to vram and scrolling and selecting entries can be used.

createDirectoryPage
    jsr doFast

    ; this puts the regular $ response into contentAddress ($1:0400 per default)
    jsr loadDirectoryFromDisk   

    ; creates a Gopher page structure for representing the disk directory
    ; reads from contentAddress and writes Gopher to the area after contentAddress (ie end of $ response)
    jsr parseDirectory  

    ; this is the regular parseGopher,
    ; just starting with the pointer at the directoryAddress instead of $1:0400
    ; this is where the zp_linkTablePosition table is built
    jsr parseDirectoryIntoGopherFormat  

    ; at this point, we should have a linkpointer table that points at the generated Gopher memory area
    jsr setToFirstContentLine
    lda #10
    sta zp_linkTableIncr
    jsr copyGopherDirToVram

    lda #1
    sta shouldWriteGopherToHeadline

    jmp copyGopherDone



dirAddress     !word 0 ;used to restore to start address after parsing
