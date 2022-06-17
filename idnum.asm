; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

; ***********************************************
; *** identify symbol as decimal, hex, or non ***
; *** RF - pointer to symbol                  ***
; *** Returns: D=0 - decimal number           ***
; ***          D=1 - hex number               ***
; ***          DF=1 - non numeric             ***
; ***          DF=0 - is numeric              ***
; ***********************************************

idnum:     glo     rf                  ; save position
           stxd
           ghi     rf
           stxd
           ldn     rf                  ; get first byte
           sep     scall               ; must be numeric
           dw      f_isnum
           bdf     idlp1               ; jump if it was
idnumno:   smi     0                   ; signal non-numeric
           lskp
idnumyes:  adi     0                   ; signal numeric
           plo     re                  ; save number
           irx                         ; recover RF
           ldxa
           phi     rf
           ldx
           plo     rf
           glo     re                  ; recover number
return:    sep     sret                ; and return to caller
idlp1:     lda     rf                  ; get next byte
           sep     scall               ; check for symbol terminator
           dw      f_isterm
           bdf     iddec               ; signal decimal number
           sep     scall               ; see if char is numeric
           dw      f_isnum
           bdf     idlp1               ; jump if so
           dec     rf                  ; move back to char
idlp2:     lda     rf                  ; get next byte
           sep     scall               ; see if terminator
           dw      f_isterm
           bdf     idnumno             ; jump if term found before h
           sep     scall               ; check for hex character
           dw      f_ishex
           bdf     idlp2               ; loop back if so
           smi     'H'                 ; check for final H
           bz      idhex               ; jump if hex
           smi     32                  ; check for h
           bz      idhex
           br      idnumno             ; was not proper number
iddec:     ldi     0                   ; signal decimal number
           br      idnumyes            ; and return
idhex:     ldi     1                   ; signal hex number
           br      idnumyes            ; and return

