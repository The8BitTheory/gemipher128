!zone directory

; this triggers loading the directory. the contents are loaded into $1:0400 just like any other content
; after that, the directory-parser will generate a gopher structure of the directory while building up
; the zp_linktable entries just like for any regular gopher page.
; finally, regular gopher routines for copying to vram and scrolling and selecting entries can be used.

createDirectoryPage
    jsr loadDirectoryFromDisk

    jsr parseDirectory

    rts


