; this contains code to detect the c128 configuration and available hardware
; 2 or 4 banks of RAM
; 16 or 64 kb of VRAM
; WiC64
; GeoRAM
; REU
; Ultimate-II
; Disk drives

!zone c128detect

c128detect
    jsr doSlow
    jsr .detectWiC64

;    jsr detectREU
    nop

 ;   jsr doFast
    rts

; proper WiC64 usage requires:
; - wic64 plugged in ()
.detectWiC64
    +print txtDetect
    +wic64_detect
    +print txtDone
    bcc +
    jmp .noWicDetected
+   beq +
    jmp .legacyFirmware
;+   +wic64_set_error_handler .handleWic64Error
+   +print txtConnected
    +wic64_execute wic64IsConnected, connectResponse, 10
    bcs .connTimeout
    bne .notConnected

    +print txtDone
    rts

.connTimeout
    +print txtTimeout
    +wic64_finalize
    rts

.notConnected
    +print txtNotConnected
    +wic64_finalize
    rts

.noWicDetected
    jsr k_primm
    !text "No WiC64 detected!",$d,0
    rts

.legacyFirmware
    jsr k_primm
    !text "Firmware too old!",$d,0
    
    rts