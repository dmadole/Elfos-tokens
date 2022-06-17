;  Copyright 2022, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


            ; Include kernal API entry points

include     include/bios.inc
include     include/kernel.inc


            ; Hooks for loadable token routines

o_findtkn:  equ   0030h
o_idnum:    equ   0033h


            ; VDP port assignments

#define     EXP_PORT  1                 ; port expander address if in use
#define     VDP_GROUP 1                 ; port group of the video card

#define     VDP_REG 7                   ; address of the 9918 register port
#define     VDP_RAM 6                   ; address of the 9918 memory port

#define     VDP_RAM_R 00h               ; flag for memory read operation
#define     VDP_RAM_W 40h               ; flag for memory write operation
#define     VDP_REG_W 80h               ; flag for register write operation

#define     PS2_P b2                    ; ps/2 port positive polarity test
#define     PS2_N bn2                   ; ps/2 port negative polarity test

#define     null 0                      ; better for empty pointers than 0


            ; 9918 constant values

blue:       equ   4
red:        equ   6
green:      equ   12
gray:       equ   14
white:      equ   15

fgcolor:    equ   white
bgcolor:    equ   blue


            ; Control characters

etx:        equ   3
bs:         equ   8
lf:         equ   10
cr:         equ   13
del:        equ   127


            ; table constants and locations

rows:       equ   24
cols:       equ   40
chars:      equ   rows*cols

pattern:    equ   3800h                 ; character set in video memory
names:      equ   3c00h                 ; display data in video memory


            ; Executable program header

            org   2000h - 6
            dw    start
            dw    end-start
            dw    start

start:      br    main


            ; Build information

            db    6+80h                 ; month
            db    3                     ; day
            dw    2022                  ; year
            dw    2                     ; build

            db    'See github.com/dmadole/Elfos-pstwo for more info',0


            ; Check minimum kernel version we need before doing anything else,
            ; in particular we need support for the heap manager to allocate
            ; memory for the persistent module to use.

main:       ldi   k_ver.1               ; get pointer to kernel version
            phi   r7
            ldi   k_ver.0
            plo   r7

            lda   r7                    ; if major is non-zero we are good
            lbnz  chkopts

            lda   r7                    ; if major is zero and minor is 4
            smi   4                     ;  or higher we are good
            lbdf  chkopts

            sep   scall                 ; if not meeting minimum version
            dw    o_inmsg
            db    'ERROR: Needs kernel version 0.4.0 or higher',cr,lf,0
            sep   sret


            ; Check for any command line options and set flags accordingly.

chkopts:    ldi   0                     ; clear flag for uninstall
            plo   rd


skipspc:    lda   ra                    ; skip any leading spaces
            lbz   chkpatch
            sdi   ' '
            lbdf  skipspc

            smi   ' '-'-'               ; is an option lead-in?
            lbnz  badusage

            lda   ra                    ; is it a -u option?
            smi   'u'
            lbnz  badusage

            glo   rd                    ; set uninstall flag
            ori   1
            plo   rd

            lda   ra                    ; if end of line, done, if space,
            lbz   chkpatch              ;  check for another option
            sdi   ' '
            lbdf  skipspc

badusage:   sep   scall                 ; if incorrect syntax then quit
            dw    o_inmsg
            db    'ERROR: Usage: pstwo [-u]',cr,lf,0
            sep   sret


            ; Check to see if our module is already installed by comparing
            ; the code at the patch points to the code of our module. Only
            ; checking the first few bytes of each is good enough.

chkpatch:   ldi   patchtbl.1            ; Get point to table of patch points
            phi   r7
            ldi   patchtbl.0
            plo   r7

            sex   r9                    ; comparison below against m(r9)

            lda   r7                    ; get address of kernel vector
ckloop1:    phi   r8
            lda   r7
ckloop2:    plo   r8

            inc   r8                    ; skip jump opcode, get address 
            lda   r8                    ;  vector points to
            phi   r9
            lda   r8
            plo   r9

            lda   r7                    ; get address of routine in code
            phi   r8                    ;  program memory
            lda   r7
            plo   r8

            ldi   10                    ; check just first 10 bytes
            plo   re

chkbyte:    lda   r8                    ; compare pointed-to code to ours,
            sm                          ;  if no match, then install
            inc   r9
            lbnz  install

            dec   re                    ; continue if not all bytes checked
            glo   re
            lbnz  chkbyte

            ghi   r8
            plo   re
            
            lda   r7                    ; continue if not all hooks checked
            lbnz  ckloop1
            phi   r8
            lda   r7
            lbnz  ckloop2


            ; If we are already installed, check if -u option given, and if
            ; so, then uninstall.

            glo   rd
            ani   1
            lbnz  uninst

            sep   scall                 ; if incorrect syntax then quit
            dw    o_inmsg
            db    'ERROR: Already loaded, use [-u] to unload.',cr,lf,0
            sep   sret


            ; We verified module is already loaded and uninstall was
            ; requested, so go ahead and restore the kernel vectors as
            ; they were before we installed folm saved copy in module.

uninst:     sex   r2

            ldi   patchtbl.1            ; pointer to table of patch points
            phi   r7
            ldi   patchtbl.0
            plo   r7

            glo   re                    ; find pages offset from program to
            str   r2                    ;  high memory module
            ghi   r9
            sm

            str   r2                    ; save offset to find block later

            adi   unpatch.1             ; pointer to saved hook value; get
            phi   r8                    ;  offset into module via adi
            ldi   unpatch.0
            plo   r8

            lda   r7                    ; pointer to kernel vector address,
unloop1:    phi   r9
            lda   r7
unloop2:    plo   r9

            inc   r9                    ; skip over lbr opcode, then
            lda   r8                    ;  restore hook to original
            str   r9
            inc   r9
            lda   r8
            str   r9

            inc   r7                    ; skip patch pointer
            inc   r7

            lda   r7                    
            lbnz  unloop1
            phi   r9
            lda   r7
            lbnz  unloop2


            ; Lastly to uninstall, recover the address of the module memory
            ; block in the heap and free it.

            ldn   r2                    ; get page offset to module

            adi   module.1              ; add to code address to get 
            phi   rf                    ;  pointer to module memory block
            ldi   module.0
            plo   rf

            sep   scall                 ; deallocate to return to heap
            dw    o_dealloc

            sep   sret                  ; return to caller


            ; If module is not installed, but uninstall option was given,
            ; emit an error and quit.

install:    glo   rd                    ; if -u not given then install
            ani   1
            lbz   allocmem

            sep   scall                 ; otherwise emit error and quit
            dw    o_inmsg
            db    'ERROR: Unload [-u] given, but not loaded.',cr,lf,0
            sep   sret


            ; Allocate memory from the heap for the driver code block, leaving
            ; address of block in register R8 and RF for copying code and
            ; hooking vectors and the length of code to copy in RB.

allocmem:   ldi   (end-module).1        ; size of permanent code module
            phi   rb
            phi   rc
            ldi   (end-module).0
            plo   rb
            plo   rc

            ldi   255                   ; request page-aligned block
            phi   r7
            ldi   4 + 64                ; request permanent + named block
            plo   r7

            sep   scall                 ; allocate block on heap
            dw    o_alloc
            lbnf  copycode

            sep   scall                 ; if unable to get memory
            dw    o_inmsg
            db    'ERROR: Unable to allocate heap memory',cr,lf,0
            sep   sret


            ; Copy the code of the persistent module to the memory block that
            ; was just allocated using RF for destination and RB for length.
            ; This burns RF and RB but R8 will still point to the block.

copycode:   ldi   module.1              ; get source address to copy from
            phi   rd
            ldi   module.0
            plo   rd

            glo   rf                    ; make a copy of block pointer
            plo   r8
            ghi   rf
            phi   r8

copyloop:   lda   rd                    ; copy code to destination address
            str   rf
            inc   rf
            dec   rc
            dec   rb
            glo   rb
            lbnz  copyloop
            ghi   rb
            lbnz  copyloop

            ghi   r8                    ; put offset between source and
            smi   module.1              ;  destination onto stack
            str   r2

            lbr   padname


            ; Pad name with zeroes to end of block.

padloop:    ldi   0                     ; pad name with zeros to end of block
            str   rf
            inc   rf
            dec   rc
padname:    glo   rc
            lbnz  padloop
            ghi   rc
            lbnz  padloop


            ; Update kernel hooks to point to our module code. Use the offset
            ; to the heap block at M(R2) to update module addresses to match
            ; the copy in the heap. If there is a chain address needed for a
            ; hook, copy that to the module first in the same way.

            ldi   patchtbl.1            ; Get point to table of patch points
            phi   r7
            ldi   patchtbl.0
            plo   r7

            ldi   unpatch.1             ; table of saved patch points in
            add                         ;  persistent memory block
            phi   r8
            ldi   unpatch.0
            plo   r8

            lda   r7                    ; get address to patch, 
patloop1:   phi   r9                    ;  skip over lbr opcode
            lda   r7
patloop2:   plo   r9
            inc   r9

            lda   r9                    ; save existing address to restore
            str   r8                    ;  if module is unloaded
            inc   r8
            ldn   r9
            dec   r9
            str   r8
            inc   r8

            lda   r7                    ; get module call point, adjust to
            add                         ;  heap, and update into vector jump
            str   r9
            inc   r9
            lda   r7
            str   r9

            lda   r7
            lbnz  patloop1
            phi   r9
            lda   r7
            lbnz  patloop2


            ; copy packed font bitmaps into pattern space

inivideo:   sep   scall                 ; display identity to indicate success
            dw    o_inmsg
            db    'Tokens Library for Elf/OS Build 1',cr,lf,0

            sep   sret                  ; done, return to elf/os


            ; Table giving addresses of jump vectors we need to update to
            ; point to us instead, and what to point them to. The patching
            ; code adjusts the target address to the heap memory block.

patchtbl:   dw    o_findtkn, findtkn
            dw    o_idnum, idnum
            dw    null


            ; Code from this point gets put into the resident driver in a
            ; heap block. Since the address of this block cannot be known,
            ; the code is written to be relocatable, so start at a new page.

            org   (($ + 0ffh) & 0ff00h)

module:

include findtkn.asm
include idnum.asm

unpatch:    dw    o_findtkn
            dw    o_idnum

            ; Include name of loadable module for display by 'minfo'.

            db    0,'Tokens',0


end:        ; That's all, folks!

