!zone diskProblems

handleDiskProblem
    cmp #04 ; device not present, no disk in drive
    bne +
    +print .msgDiskDeviceNotPresent

-   jsr key
    cmp #' '
    bne +
    lda #0       ; space pressed. 
    rts
+   cmp #'X'     ; stop key pressed
    bne -
    lda #$ff    ; make sure negative flag is set
    rts


.msgDiskDeviceNotPresent    !pet "Please insert disk.",$0d
                            !pet "Press SPACE to try again,",$0d
                            !pet "or X to exit.",$0d,$0
