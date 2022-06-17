
tokens.bin: tokens.asm findtkn.asm idnum.asm include/bios.inc include/kernel.inc
	asm02 -b -L tokens.asm

clean:
	-rm -f *.bin *.lst

