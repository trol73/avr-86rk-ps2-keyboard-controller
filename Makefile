all: 
	#avra -I /Users/trol/bin/avr-builder/asm/include fcount.asm
	builder 
	avr-disasm build/controller.hex > build/controller.list
	#diff fcount.hex build/f-counter.hex
	diff kb-org.list build/controller.list
