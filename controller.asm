.NOLIST
.INCLUDE "m48def.inc"
.INCLUDE "scancodes.inc"

.equ CLK_PIN = 5
.equ DAT_PIN = 4

.equ SS_PIN = 0		; 'СС'
.equ US_PIN = 1		; 'УС'
.equ RUS_LAT_PIN = 2	; 'РУС/ЛАТ'
.equ RESET_PIN = 3


; Ожидание нуля на линии CLK
.MACRO wait_CLK_0
wait_clk0_loop_%:
	if (io[PINC].CLK_PIN) goto wait_clk0_loop_%
.ENDMACRO

; Ожидание единицы на линии CLK
.MACRO wait_CLK_1
wait_clk1_loop_%:
	if (!io[PINC].CLK_PIN) goto wait_clk1_loop_%
.ENDMACRO

.MACRO wait_DAT_0
wait_dat0_loop_%:
	if (io[PINC].DAT_PIN) goto wait_dat0_loop_%
.ENDMACRO

.LIST

; ---------------------------------------------------------------------------
.DSEG
.org SRAM_START

.extern data_array_1, data_array_2 : ptr

data_array_1:
	.byte 0x100
data_array_2:
	.byte 8	; ????	


; ===========================================================================

; Segment type:	Pure code
.CSEG ;	ROM

.org 0
		rjmp	__RESET		; External Pin,	Power-on Reset,	Brown-out

INT0_:			; External Interrupt Request 0
		reti

INT1_:
		reti

PCINT0_:		; Pin change interrupt request 0
		reti

PCINT1_:		; Pin change interrupt request 1
		reti

PCINT2_:		; Pin change interrupt request 2
		r28 = io[PIND]

WDT:		; Watchdog time-out interrupt
		r20 = ram[Y]

TIMER2_COMPA:		; Timer/Counter2 compare match A
		io[PORTB] = r20
		
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti
		reti

; =============== S U B R O U T I N E =======================================

.use r16 as r16_mask



__RESET:				; CODE XREF: ROM:0000j
	; Setup stack, SP = 0x2ff
	io[SPL] = r18 = 0xff
	io[SPH] = r18 = 2
	; DDRD = 0	
	r4 = r18 = 0
	io[DDRD] = r18
	r3 = r18 = 0xff
	io[PORTD] = r18
	io[DDRB] = r18
	io[PORTB] = r18
	io[DDRC] = r18 = 0xF
	io[PORTC] = r18 = 0x3F
	io[ACSR] = r18 = 0x80		; Bit 7 - ACD: Analog Comparator Disable - Запрет аналогового компаратора

	r18 = 4
;  58:	00 68 93 20	sts	0x0068, R18
	sts	PCICR, r18	; PCICR = 4 (PCIE2)
	; PCICR – Pin change interrupt control register	
	; When the PCIE2 bit is set (one) and the I-bit in the status register (SREG) is set (one), pin change interrupt 2 is enabled. Any change on any enabled 
	; PCINT23..16 pin will cause an interrupt. The corresponding interrupt of pin change interrupt request is executed from the PCI2 interrupt vector. PCINT23..16 pins 
	; are enabled individually by the PCMSK2 register.
;   5c:	00 6d 92 30	sts	0x006d, R3
	; PCMSK2 – Pin change mask register 2
	sts	PCMSK2, r3		; PCMSK2 = 0
	

	; формируем положительный импульс на выходе RESET длительностью 0.5 сек.
	io[PORTC].RESET_PIN = 0
	rcall	delay_500ms	; delay 0.5 сек
	io[PORTC].RESET_PIN = 1

keyboard_reset:					; CODE XREF: __RESET+1Cj
	rcall	send_command_to_keyboard (0xff)		; 0xFF - команда сборса клавиатуры
	if (!F_ZERO) goto keyboard_reset
		
	rcall	read_keyboard	; приём байта от клавиатуры в r21

	; моргаем индикатором NumLock
	rcall	set_keyboard_leds (KEY_LED_NUM_LOCK)
	rcall	delay_500ms
	rcall	set_keyboard_leds (0)

	; Команда 0xFO позволяет установить один из трех наборов скан-кодов, используемых для передачи данных от клавиатуры 
	; Команда двухбайтная — байт данных должен следовать за байтом команды и содержать номер устанавливаемого набора (1,2 или 3). 
	; Клавиатура реагирует на команду следующим образом:
	; •    посылает байт АСК в компьютер;
	; •    очищает выходной буфер;
	; •    принимает байт данных, содержащий номер устанавливаемого режима;
	; •    устанавливает новый режим.
	rcall	send_command_to_keyboard (CMD_SELECT_CODES_SET)
	rcall	send_command_to_keyboard (3)

	; Команда 0xF8 - Разрешить для всех клавиш посылку кодов нажатия и отпускания
	rcall	send_command_to_keyboard (0xF8)
		
	r16_mask = 0
	//    r16[1] - признак отпускания кнопки
	//    r16[4] - SHIFT
	//    r16[5] - CTRL

wait_next_char_code:					; CODE XREF: __RESET+2Dj __RESET+89j ...
	rcall	sub_11D		; выводит PORTB = 0xff и заполняет память

; начало цикла функции main()
main_loop:					; CODE XREF: __RESET+31j __RESET+41j ...
	rcall	read_keyboard					; приём байта от клавиатуры в r21
	if (r21 == 0) goto wait_next_char_code		; если ничего не нажато, читаем заново

	if (r21 == KEY_RELEASE_CODE) {
		r16_mask[1] = 1				; r16[1] - признак отпускания клавиши
		rjmp	main_loop
	}
	if (r21 == KEY_CTRL_R) {
		r21 = KEY_CTRL_L
	}
	if (r21 == KEY_SHIFT_R) {
		r21 = KEY_SHIFT_L
	}
	if (r21 == KEY_KEYPAD_MINUS) {
		r21 = 9	; F10 ??
	}
	if (r21 >= KEY_WIN_L) {
		r21 -= 0x81
	}
	if (!r16_mask[1]) {		; если кнопка была нажата а не отпущена
		if (r5 == r21) goto main_loop		; если эта же самая кнопка была нажата ранее, то игнорируем её
		r5 = r21
		if (r21 == KEY_PRINTSCR) {
			; При нажатии 'Print Screen' формируем положительный импульс на выходе RESET
			io[PORTC].RESET_PIN = 0
			rcall	delay_10ms
			io[PORTC].RESET_PIN = 1		
			rjmp	main_loop
		}
		if (r21 == KEY_SCROLLLOCK) {
			r21 = r17
			r18 = KEY_LED_SCROLL_LOCK
enable_led_and_continue:
			eor		r21, r18
			rcall	set_keyboard_leds
			rjmp		main_loop
		}
	
		if (r21 == KEY_SHIFT_L) {
			r16_mask[4] = 1		;  r16[4] - SHIFT
			rjmp	loc_A3
		}
		if (r21 == KEY_NUMLOCK) {
			r21 = r17
			r18 = KEY_LED_NUM_LOCK
			rjmp	enable_led_and_continue
		}
		if (r21 == KEY_CAPSLOCK) {
			io[PORTC].RUS_LAT_PIN = 0
			r21 = r17
			r18 = KEY_LED_CAPS_LOCK
			rjmp	enable_led_and_continue
		}
		if (r21 == KEY_CTRL_L) {
			io[PORTC].US_PIN = 0
			r16_mask[5] = 1			; r16[5] - CTRL
			rjmp	loc_A3
		}
		X = data_array_2
loop_7F:
		r18 = ram[X++]
		if (r18 == 0) {
			ram[--X] = r21
			rjmp	loc_A3
		}
		if (!r26[3]) goto loop_7F
		rjmp	main_loop
	}
	r16_mask[1] = 0				; очищаем флаг отпускания клавиши
	if (r21 == KEY_SHIFT_L) {
		r16_mask[0] = 1
		rjmp	loc_A3
	}
	if (r21 == KEY_CTRL_L) {
		r16_mask[5] = 0
		io[PORTC].US_PIN = 1		; Клавиша 'УС'
		rjmp	loc_A3
	}
	if (r21 == KEY_CAPSLOCK) {
		io[PORTC].RUS_LAT_PIN = 1
		rjmp	loc_A3
	}
	X = data_array_2
	r16_mask[2] = 1

loc_98:					; CODE XREF: __RESET+87j
	r18 = ram[X++]
	if (r18 == r21) {
		ram[--X] = r5 = 0
		r16_mask[2] = 0
		r26++
	}
	if (!r26[3]) goto loc_98
	if (r16_mask[2]) goto wait_next_char_code

loc_A3:
	X = 0x08				; PORTC -> PIND -> DDRD

loop_A5:					; CODE XREF: __RESET+8Ej
	ram[X++] = r3
	if (!r26[4]) goto loop_A5
	r16_mask[6] = 0
	r16_mask[3] = 0		; TODO !!!	
	X = data_array_2
loc_AC:					; CODE XREF: __RESET+9Fj
	r18 = ram[X++]
	if (r18 != 0) {
		r18 <<= 1
		Z = 0x400
		ZL += r18
		if (r17[0]) ZL++
		rcall	sub_E4 (prg[Z])
	}
	if (!r26[3]) goto loc_AC
	if (!r16_mask[3]) {
		rcall	sub_E6
		if (!r16_mask[4]) goto wait_next_char_code
	}
	Z = 0x100

loop_C0:					; CODE XREF: __RESET+BAj
	r19 = 0xff
	if (!r30[0]) r19 &= r8
	if (!r30[1]) r19 &= r9
	if (!r30[2]) r19 &= r10
	if (!r30[3]) r19 &= r11
	if (!r30[4]) r19 &= r12
	if (!r30[5]) r19 &= r13
	if (!r30[6]) r19 &= r14
	if (!r30[7]) r19 &= r15
	ram[Z] = r19
	ZL++
	if (!F_ZERO) goto loop_C0

	io[PORTC].SS_PIN = !r16_mask[4]		; Клавиша 'СС'
	if (r16_mask[6]) {
		io[PORTC].US_PIN = 0			; Клавиша 'УС'
		rjmp	main_loop
	}
	io[PORTC].US_PIN = !r16_mask[5]		; Клавиша 'УС'
	r28 = io[PIND]
	io[PORTB] = r18 = ram[Y]
	rjmp	main_loop
; End of function __RESET




.proc sub_E4 (v: r0)
	r0++
	if (!F_ZERO) goto loc_EC
.endproc

; =============== S U B R O U T I N E =======================================


sub_E6:					; CODE XREF: __RESET+A2p
	if (!r16_mask[0]) ret
	r16_mask[0] = 0
	r16_mask[4] = 0
	io[PORTC].SS_PIN = 1		; Клавиша 'СС'
	ret
; End of function sub_E6

; ---------------------------------------------------------------------------

loc_EC:					; CODE XREF: sub_E4+1j
	r0--
	if (r0[7]) {
		if (r0[6]) goto loc_F5
	}
	rcall	sub_E6
	if (r16_mask[4]) r16_mask[4] = 1		; WTF !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ?!?!?!? if (r16[4] == 1) r16[4] := 1 
	rjmp	loc_100
; ---------------------------------------------------------------------------

loc_F5:					; CODE XREF: sub_E4+Cj
	r18 = r0 & 0b00111111
	r18 <<= 1
	Z = 0x500
	ZL += r18
	r0 = prg[Z]
	if (r16_mask[4]) {		; r16[4] - SHIFT
		ZL++
		r0 = prg[Z]
	}
loc_100:
	push	r27 r26
	r16_mask[3] = 1
	if (r0[7]) r16_mask[6] = 1
	if (r0[6]) r16_mask[4] = 1
	r18 = r0 & 0b00000111
	r1 = r18 + 1
	r18 = 0xFE

	loop {
		r1--
		if (F_ZERO) break
		F_CARRY = 1
		rol	r18
	}

	XH = 0
	XL = r0
	XL <<= 1
	swap	XL
	XL &= 0b00000111
	XL -= 0b11111000
	ram[X] = r1 = ram[X] & r18
	pop	r26 r27
	ret
; END OF FUNCTION CHUNK	FOR sub_E4

; =============== S U B R O U T I N E =======================================


.proc sub_11D
	cli
	io[PORTB] = r18 = 0xff
	
	; for (X = 0x200; X < 0x200+8; X++) ram[X] = 0
	X = data_array_2
	r18 = 0	
@loop_1:
	ram[X++] = r18	
	if (!XL[3]) goto @loop_1

	; for (Z = 0x100; Z < 0x200; Z++) mem[Z] = 0xFF
	Z = data_array_1
	r18 = 0xff
@loop_2:
	ram[Z] = r18
	ZL++			; устанавливает F_ZERO если ZL == 0
	if (!F_ZERO) goto @loop_2
	
	r5 = 0
	r29 = 1
	sei
	ret
.endproc


; =============== S U B R O U T I N E =======================================
; При передаче используется следующий протокол: сначала передается старт-бит (всегда "0"), затем восемь бит данных, 
; один бит проверки на нечетность и один стоп-бит (всегда "1"). Данные должны считываться в тот момент, когда синхросигнал 
; имеет низкое значение. Формирование синхросигнала осуществляет клавиатура. 
; Длительность как высокого, так и низкого импульсов синхросигнала обычно равняются 30-50 мкс.
;
; Биты считыываются с линии DAT когда CLK == 0
;
; приём байта от клавиатуры в r21
.proc read_keyboard
	io[DDRC].DAT_PIN = 0
	io[DDRC].CLK_PIN = 0
	r21 = 0

	wait_DAT_0		; дожидаемся старт-бита		
	wait_CLK_0		; дожидаемся готовности старт-бита
	wait_CLK_1		; дожидаемся окончания передачи старт-бита

	; получаем биты данных от младшего к старшему
	loop (r19 = 8) {
		wait_CLK_0
		F_CARRY = io[PINC].DAT_PIN
		ror	r21
		wait_CLK_1		
	}
	
	wait_CLK_0	; пропускаем бит проверки на нечетность
	; TODO проверять бит
	wait_CLK_1
	wait_CLK_0	; пропускаем стоп-бит (единица)
	; TODO проверять бит
	wait_CLK_1
.endproc



; сбрасываем CLK и настраиваем эту линию на выход
.proc set_clk_as_out
	io[PORTC].CLK_PIN = 0
	io[DDRC].CLK_PIN = 1
	ret
.endproc


; Параметр: r21 - битовая маска включения светодиодов (младшие три бита)
; •    бит 0 — состояние индикатора Scroll Lock (0 — выключен, 1 — включен);
; •    бит 1 — состояние индикатора Num Lock (0 — выключен, 1 — включен);
; •    бит 2 — состояние индикатора Caps Lock (0 — выключен, 1 — включен);
; •    биты 3-7 не используются.
.proc set_keyboard_leds (mask: r21)
	r17 = mask
	rcall	send_command_to_keyboard (0xED)		; команда управления светодиодами
	r21 = r17
.endproc


.proc send_command_to_keyboard (cmd: r21)
	rcall	write_keyboard	(cmd)
	rcall	read_keyboard	; приём байта от клавиатуры в r21
	if (r21 == 0xFE) goto send_command_to_keyboard	; запрос на повторную передачу команды со стороны компьютера, выдается в случае возникновения ошибки передачи
	cpi	r21, 0xFA ; подтверждение приема информации (команда ACK)
	ret
.endproc


; Ведущая система может послать клавиатуре команды путем удерживания линии синхроимпульсов в низком состоянии. 
; После этого на линии данных устанавливается низкий сигнал (старт-бит). Затем линия синхронизации должна быть 
; освобождена. После этого клавиатура сформирует 10 синхроимпульсов. Данные должны быть установлены до 
; спадающего (заднего) фронта синхроимпульса. После приема десятого бита клавиатура проверяет наличие на линии 
; данных высокого сигнала (стоп-бит). При обнаружении высокого уровня на линии данных клавиатура выставляет на ней 
; низкий уровень, который сигнализирует ведущему устройству что данные получены. 

; Передаёт содержимое регистра r21 клавиатуре
.proc write_keyboard (val: r21)
	rcall	set_clk_as_out
	rcall	delay_100us	; delay 100 мкс
	; линию DAT конфигурируем на выход и сбрасываем в 0
	io[PORTC].DAT_PIN = 0
	io[DDRC].DAT_PIN = 1
	rcall	delay_5us
	io[DDRC].CLK_PIN = 0
	rcall	delay_5us

	r2 = 0	 ; r2 - счётчик единичных бит
	; цикл передачи 8 бит
	loop (r19 = 8) {
		wait_CLK_0	
		ror	r21
;		io[PORTC].DAT_PIN = !F_CARRY
		if (!F_CARRY) {
			io[PORTC].DAT_PIN = 0
		} else {
			io[PORTC].DAT_PIN = 1
			r2++
		}

		wait_CLK_1
	}

	; передаём бит бит проверки на нечётность
	wait_CLK_0
	; TODO эту команду лучше пропускать если не требуется
	io[PORTC].DAT_PIN = 1
	if (r2[0]) io[PORTC].DAT_PIN = 0
	wait_CLK_1

	; передаём стоп-бит
	wait_CLK_0
	io[PORTC].DAT_PIN = 1
	wait_CLK_1
		
	io[DDRC].DAT_PIN = 0

	wait_CLK_0
	wait_CLK_1
	ret
.endproc



.proc delay_500ms
	loop (r19 = 50) {
		rcall	delay_10ms
	}
	ret
.endproc


.proc delay_10ms
	loop (r1 = r18 = 100) {
		rcall	delay_100us
	}
	ret
.endproc

.proc delay_100us
	r18 = 200
	rjmp	delay_05us
.endproc


.proc delay_5us
	loop (r18 = 10) {
delay_05us:	; delay 0.5 мкс
		nop
	}
	ret
.endproc



