; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

; ******************************************
; *** Check if symbol is in symbol table ***
; *** RF - pointer to ascii symbol       ***
; *** R7 - pointer to token table        ***
; *** Returns: RD - function number      ***
; ***          DF=1 - is function        ***
; ***          DF=0 - is not a function  ***
; ******************************************

findtkn:    glo   r7                    ; preserve table pointer
            stxd
            ghi   r7
            stxd

            glo   rf                    ; save start of search string
            plo   re
            ghi   rf
            str   r2

            sm                          ; load zero into function number
            plo   rd

            sex   rf                    ; compare to string, go search
            br    tkntst

tkncmp:     shr                         ; compare with string, make df=0
            xor                         ;  for if we hit end of table
            inc   rf
            bz    tkntst

tknskp:     lda   r7                    ; if no match, skip to next entry 
            sdi   7fh                   ;  make df=0 for if end of table
            bdf   tknskp

tknrst:     glo   re                    ; reset search string to start
            plo   rf
            ldn   r2
            phi   rf

            inc   rd                    ; increase function count

tkntst:     lda   r7                    ; if end of table, then exit
            bz    tknend

            shl                         ; if not last byte, loop to compare
            bnf   tkncmp

            shr                         ; if last byte no match, continue,
            sm                          ;  if it does match set df=1
            bnz   tknrst

            inc   rf                    ; advance past matching character

tknend:     inc   r2                    ; restore table pointer
            lda   r2
            phi   r7
            ldn   r2
            plo   r7

            sep   sret                  ; return to caller

