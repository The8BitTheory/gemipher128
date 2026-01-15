; checking for filename?
F3EF: 20 45 E5	JSR $E545	; Set serial bus output to high (cia #2 port A, bit 4 to 0 - inverted)
F3F2: 20 C3 E5	JSR $E5C3	; set serial device for fast serial input
F3F5: 2C 0D DC	BIT $DC0D   ; interrupt stuff (on fast flag on serial line?)
F3F8: 20 03 F5	JSR $F503	; Toggle Clock Line - reverse cia#2 port A bit 4. this is burstmode handshake
F3FB: 20 BA F4	JSR $F4BA	; Get Serial Byte - wait for interrupt to happen and write byte to Acc
F3FE: C9 02	CMP #$02        ; 02 means file not found
F400: D0 08	BNE $F40A
F402: 20 8C F4	JSR $F48C	; Close Off Serial
F405: 68	PLA
F406: 68	PLA
F407: 4C 85 F6	JMP $F685	; Print 'file not found'

; 
F40A: 48	PHA
F40B: C9 1F	CMP #$1F        ; 
F40D: D0 0B	BNE $F41A
F40F: 20 03 F5	JSR $F503	; Toggle Clock Line - burstmode handshake
F412: 20 BA F4	JSR $F4BA	; Get Serial Byte   - 
F415: 85 A5	STA $A5         ; in burst, contains nr of bytes to read (or having read) of current sector
F417: 4C 21 F4	JMP $F421

F41A: C9 02	CMP #$02
F41C: 90 03	BCC $F421
F41E: 68	PLA
F41F: B0 77	BCS $F498

F421: 20 33 F5	JSR $F533	; Print 'loading'
F424: 20 03 F5	JSR $F503	; Toggle Clock Line
F427: 20 BA F4	JSR $F4BA	; Get Serial Byte
F42A: 85 AE	STA $AE 	; Tape end address / End of program
F42C: 20 03 F5	JSR $F503	; Toggle Clock Line
F42F: 20 BA F4	JSR $F4BA	; Get Serial Byte
F432: 85 AF	STA $AF
F434: A6 9E	LDX $9E
F436: D0 08	BNE $F440
F438: A5 C3	LDA $C3
F43A: A6 C4	LDX $C4
F43C: 85 AE	STA $AE 	; Tape end address / End of program
F43E: 86 AF	STX $AF

F440: A5 AE	LDA $AE 	; Tape end address / End of program
F442: A6 AF	LDX $AF
F444: 85 AC	STA $AC
F446: 86 AD	STX $AD
F448: 68	PLA
F449: C9 1F	CMP #$1F
F44B: F0 32	BEQ $F47F
F44D: 20 03 F5	JSR $F503	; Toggle Clock Line
F450: A9 FC	LDA #$FC
F452: 85 A5	STA $A5

F454: 20 3D F6	JSR $F63D	; Watch For RUN or Shift
F457: 20 E1 FF	JSR $FFE1	; (istop)       Test-Stop Vector [F66E]
F45A: F0 4A	BEQ $F4A6
F45C: 20 C5 F4	JSR $F4C5	; Receive Serial Byte
F45F: B0 51	BCS $F4B2
F461: 20 BA F4	JSR $F4BA	; Get Serial Byte
F464: C9 02	CMP #$02
F466: 90 06	BCC $F46E
F468: C9 1F	CMP #$1F
F46A: F0 0B	BEQ $F477
F46C: D0 2A	BNE $F498

F46E: 20 03 F5	JSR $F503	; Toggle Clock Line
F471: A9 FE	LDA #$FE
F473: 85 A5	STA $A5
F475: D0 DD	BNE $F454

F477: 20 03 F5	JSR $F503	; Toggle Clock Line
F47A: 20 BA F4	JSR $F4BA	; Get Serial Byte
F47D: 85 A5	STA $A5

F47F: 20 03 F5	JSR $F503	; Toggle Clock Line
F482: 20 C5 F4	JSR $F4C5	; Receive Serial Byte
F485: B0 2B	BCS $F4B2
F487: A9 40	LDA #$40
F489: 20 57 F7	JSR $F757	; Set Status Bit
