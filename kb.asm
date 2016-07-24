.NOLIST
.INCLUDE "m48def.inc"
.INCLUDE "scancodes.inc"

; Ожидание нуля на линии CLK
.MACRO wait_CLK_0
wait_clk0_loop_%:
	sbic		PINC, 5
	rjmp		wait_clk0_loop_%
.ENDMACRO

; Ожидание единицы на линии CLK
.MACRO wait_CLK_1
wait_clk1_loop_%:
	sbis		PINC, 5
	rjmp		wait_clk1_loop_%
.ENDMACRO

.MACRO wait_DAT_0
wait_dat0_loop_%:
	sbic	PINC, 4
	rjmp	wait_dat0_loop_%
.ENDMACRO

.MACRO set_reset_out_to_0
	cbi	PORTC, 3
.ENDMACRO

.MACRO set_reset_out_to_1
	sbi	PORTC, 3
.ENDMACRO	

.MACRO set_ruslat_out_to_0
	cbi	PORTC, 2		; Клавиша 'РУС/ЛАТ'
.ENDMACRO

.MACRO set_ruslat_out_to_1
	sbi	PORTC, 2		; Клавиша 'РУС/ЛАТ'
.ENDMACRO

.MACRO set_DAT_to_1
	sbi	PORTC, 4
.ENDMACRO

.MACRO set_DAT_to_0
	cbi	PORTC, 4
.ENDMACRO

.MACRO config_DAT_as_input
	cbi	DDRC, 4
.ENDMACRO

.MACRO config_DAT_as_output
	sbi	DDRC, 4
.ENDMACRO

.MACRO config_CLK_as_input
	cbi	DDRC, 5
.ENDMACRO

.MACRO config_CLK_as_output
	sbi	DDRC, 5
.ENDMACRO

.LIST

; ===========================================================================

;; PC5 - CLK
;; PC4 - DAT

; Segment type:	Pure code
.CSEG ;	ROM

.org 0
		rjmp	__RESET		; External Pin,	Power-on Reset,	Brown-out

.org 1
INT0_:			; External Interrupt Request 0
		reti

.org 2			; External Interrupt Request 1
INT1_:
		reti

.org 3
PCINT0_:		; Pin change interrupt request 0
		reti

.org 4			
PCINT1_:		; Pin change interrupt request 1
		reti

.org 5
PCINT2_:		; Pin change interrupt request 2
		in	r28, PIND	

.org 6
WDT:		; Watchdog time-out interrupt
		ld	r20, Y

.org 7
TIMER2_COMPA:		; Timer/Counter2 compare match A
		out	PORTB, r20
		
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

; External Pin,	Power-on Reset,	Brown-out

		; public __RESET
__RESET:				; CODE XREF: ROM:0000j
	; Setup stack, SP = 0x2ff
		ser	r18
		out	SPL, r18
		ldi	r18, 2
		out	SPH, r18
	; DDRD = 0	
		clr	r18
		mov	r4, r18	; r4 = 0
		out	DDRD, r18
		ser	r18
		mov	r3, r18	; r3 = 0xff
	; PORTD = 0xFF	
		out	PORTD, r18
		out	DDRB, r18
	; PORTB = 0xff	
		out	PORTB, r18
		ldi	r18, 0xF
		out	DDRC, r18
	; PORTC = 0x3F	
		ldi	r18, 0x3F
		out	PORTC, r18
	; Bit 7 - ACD: Analog Comparator Disable - Запрет аналогового компаратора
		ldi	r18, 0x80
		out	ACSR, r18	

		ldi	r18, 4
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
		set_reset_out_to_0
		rcall	delay_500ms	; delay 0.5 сек
		set_reset_out_to_1

keyboard_reset:					; CODE XREF: __RESET+1Cj
		; 0xFF - команда сборса клавиатуры
		ser		r21
		rcall	send_command_to_keyboard
		brne		keyboard_reset
		
		rcall	read_keyboard	; приём байта от клавиатуры в r21

		; моргаем индикатором NumLock
		ldi		r21, KEY_LED_NUM_LOCK
		rcall	set_keyboard_leds
		rcall	delay_500ms
		ldi		r21, 0
		rcall	set_keyboard_leds

		; Команда 0xFO позволяет установить один из трех наборов скан-кодов, используемых для передачи данных от клавиатуры 
		; Команда двухбайтная — байт данных должен следовать за байтом команды и содержать номер устанавливаемого набора (1,2 или 3). 
		; Клавиатура реагирует на команду следующим образом:
		; •    посылает байт АСК в компьютер;
		; •    очищает выходной буфер;
		; •    принимает байт данных, содержащий номер устанавливаемого режима;
		; •    устанавливает новый режим.
		ldi		r21, CMD_SELECT_CODES_SET
		rcall	send_command_to_keyboard
		ldi		r21, 3
		rcall	send_command_to_keyboard

		; Команда 0xF8 - Разрешить для всех клавиш посылку кодов нажатия и отпускания
		ldi		r21, 0xF8
		rcall	send_command_to_keyboard
		
		clr		r16

loc_43:					; CODE XREF: __RESET+2Dj __RESET+89j ...
		rcall	sub_11D	; выводит PORTB = 0xff и заполняет память

; начало цикла функции main()
main_loop:					; CODE XREF: __RESET+31j __RESET+41j ...
		rcall	read_keyboard	; приём байта от клавиатуры в r21
		tst		r21
		breq		loc_43	; если ничего не нажато, читаем заново
		cpi		r21, 0xF0 ; F0 - код отпускания
		brne		check_code_0
		
		ori	r16, 2	; r16[2] - признак отпускания клавиши
		rjmp	main_loop
; ---------------------------------------------------------------------------

check_code_0:
		cpi	r21, KEY_CTRL_R
		brne	check_code_1
		ldi	r21, KEY_CTRL_L

check_code_1:
		cpi	r21, KEY_SHIFT_R
		brne	check_code_2
		ldi	r21, KEY_SHIFT_L

check_code_2:
		cpi	r21, 0x84 	; 'Keypad -'
		brne	check_code_3
		ldi	r21, 9		; ???

check_code_3:
		cpi	r21, 0x8B 	; 'L-WIN'
		brcs	check_code_4	; if r21 < 0x8B
		subi	r21, 0x81		;-0x7F ; '?'

check_code_4:
		sbrc	r16, 1		
		rjmp	loc_87		; если нажат shift (?)
		cp	r5, r21		; r5 - предыдущая кнопка (?)
		breq	main_loop		; если эта же самая кнопка была нажата ранее, то игнорируем её
		mov	r5, r21
		cpi	r21, KEY_PRINTSCR
		brne	check_code_5

		; При нажатии 'Print Screen' формируем положительный импульс на выходе RESET
		set_reset_out_to_0
		rcall	delay_10ms
		set_reset_out_to_1
		
		rjmp	main_loop
; ---------------------------------------------------------------------------

check_code_5:
		cpi	r21, KEY_SCROLLLOCK
		brne	check_code_6
		mov	r21, r17
		ldi	r18, KEY_LED_SCROLL_LOCK

enable_led_and_continue:
		eor		r21, r18
		rcall	set_keyboard_leds
		rjmp		main_loop
; ---------------------------------------------------------------------------

check_code_6:
		cpi	r21, KEY_SHIFT_L
		brne	check_code_7
		ori	r16, 0b00010000	;  r16[4] - SHIFT
		rjmp	loc_A3
; ---------------------------------------------------------------------------

check_code_7:					; CODE XREF: __RESET+51j
		cpi	r21, KEY_NUMLOCK
		brne	check_code_8
		mov	r21, r17
		ldi	r18, KEY_LED_NUM_LOCK
		rjmp	enable_led_and_continue
; ---------------------------------------------------------------------------

check_code_8:					; CODE XREF: __RESET+55j
		cpi	r21, KEY_CAPSLOCK
		brne	check_code_9
		set_ruslat_out_to_0
		mov	r21, r17
		ldi	r18, KEY_LED_CAPS_LOCK
		rjmp	enable_led_and_continue
; ---------------------------------------------------------------------------

check_code_9:					; CODE XREF: __RESET+5Aj
		cpi	r21, KEY_CTRL_L
		brne	loc_7D
		cbi	PORTC, 1		; Клавиша 'УС'
		ori	r16, 0b00100000		; r16[5] - CTRL
		rjmp	loc_A3
; ---------------------------------------------------------------------------

loc_7D:					; CODE XREF: __RESET+60j
		ldi	r27, 2
		ldi	r26, 0		; X(r27:r26) = 0x200

loc_7F:					; CODE XREF: __RESET+6Cj
		ld	r18, X+
		tst	r18
		brne	loc_84
		st	-X, r21
		rjmp	loc_A3
; ---------------------------------------------------------------------------

loc_84:					; CODE XREF: __RESET+68j
		sbrs	r26, 3
		rjmp	loc_7F
		rjmp	main_loop
; ---------------------------------------------------------------------------

loc_87:					; CODE XREF: __RESET+3Fj
		andi	r16, 0b11111101	; очищаем маску нажатия шифта
		cpi	r21, KEY_SHIFT_L
		brne	loc_8C
		ori	r16, 1		; r16[1] - SHIFT
		rjmp	loc_A3
; ---------------------------------------------------------------------------

loc_8C:					; CODE XREF: __RESET+70j
		cpi	r21, KEY_CTRL_L
		brne	loc_91
		andi	r16, 0b11011111
		sbi	PORTC, 1		; Клавиша 'УС'
		rjmp	loc_A3
; ---------------------------------------------------------------------------

loc_91:					; CODE XREF: __RESET+74j
		cpi	r21, KEY_CAPSLOCK
		brne	loc_95
		set_ruslat_out_to_1
		rjmp	loc_A3
; ---------------------------------------------------------------------------

loc_95:					; CODE XREF: __RESET+79j
		ldi	r27, 2
		ldi	r26, 0		; X(r27:r26) = 0x200
		ori	r16, 4

loc_98:					; CODE XREF: __RESET+87j
		ld	r18, X+
		cp	r18, r21
		brne	loc_9F
		clr	r5
		st	-X, r5
		andi	r16, 0b11111011
		inc	r26

loc_9F:					; CODE XREF: __RESET+81j
		sbrs	r26, 3
		rjmp	loc_98
		sbrc	r16, 2
		rjmp	loc_43

loc_A3:					; CODE XREF: __RESET+53j __RESET+63j ...
		clr	r27			
		ldi	r26, 8		; X(r27:r26) = 0x008

loc_A5:					; CODE XREF: __RESET+8Ej
		st	X+, r3
		sbrs	r26, 4
		rjmp	loc_A5
		andi	r16, 0xBF
		andi	r16, 0xF7
		ldi	r27, 2
		ldi	r26, 0		; X(r27:r26) = 0x200

loc_AC:					; CODE XREF: __RESET+9Fj
		ld	r18, X+
		tst	r18
		breq	loc_B7
		lsl	r18
		ldi	r31, 4
		ldi	r30, 0
		add	r30, r18
		sbrc	r17, 0
		inc	r30
		lpm
		rcall	sub_E4

loc_B7:					; CODE XREF: __RESET+95j
		sbrs	r26, 3
		rjmp	loc_AC
		sbrc	r16, 3
		rjmp	loc_BE
		rcall	sub_E6
		sbrs	r16, 4
		rjmp	loc_43

loc_BE:					; CODE XREF: __RESET+A1j
		ldi	r31, 1
		ldi	r30, 0

loc_C0:					; CODE XREF: __RESET+BAj
		ser	r19
		sbrs	r30, 0
		and	r19, r8
		sbrs	r30, 1
		and	r19, r9
		sbrs	r30, 2
		and	r19, r10
		sbrs	r30, 3
		and	r19, r11
		sbrs	r30, 4
		and	r19, r12
		sbrs	r30, 5
		and	r19, r13
		sbrs	r30, 6
		and	r19, r14
		sbrs	r30, 7
		and	r19, r15
		st	Z, r19
		inc	r30
		brne	loc_C0
		sbrs	r16, 4
		sbi	PORTC, 0	; Клавиша 'СС'
		sbrc	r16, 4
		cbi	PORTC, 0	; Клавиша 'СС'
		sbrs	r16, 6
		rjmp	loc_DC
		cbi	PORTC, 1		; Клавиша 'УС'
		rjmp	main_loop
; ---------------------------------------------------------------------------

loc_DC:					; CODE XREF: __RESET+C0j
		sbrs	r16, 5
		sbi	PORTC, 1	; Клавиша 'УС'
		sbrc	r16, 5
		cbi	PORTC, 1	; Клавиша 'УС'
		in	r28, PIND	; 9
		ld	r18, Y
		out	PORTB, r18	; 5
		rjmp	main_loop
; End of function __RESET


; =============== S U B R O U T I N E =======================================


sub_E4:					; CODE XREF: __RESET+9Dp

; FUNCTION CHUNK AT 00EC SIZE 00000031 BYTES

		inc	r0
		brne	loc_EC
; End of function sub_E4


; =============== S U B R O U T I N E =======================================


sub_E6:					; CODE XREF: __RESET+A2p
					; sub_E4:loc_F1p
		sbrs	r16, 0
		ret
		andi	r16, 0b11111110
		andi	r16, 0b11101111
		sbi	PORTC, 0		; Клавиша 'СС'
		ret
; End of function sub_E6

; ---------------------------------------------------------------------------
; START	OF FUNCTION CHUNK FOR sub_E4

loc_EC:					; CODE XREF: sub_E4+1j
		dec	r0
		sbrs	r0, 7
		rjmp	loc_F1
		sbrc	r0, 6
		rjmp	loc_F5

loc_F1:					; CODE XREF: sub_E4+Aj
		rcall	sub_E6
		sbrc	r16, 4
		ori	r16, 0x10
		rjmp	loc_100
; ---------------------------------------------------------------------------

loc_F5:					; CODE XREF: sub_E4+Cj
		mov	r18, r0
		andi	r18, 0b00111111
		lsl	r18
		ldi	r31, 5
		ldi	r30, 0
		add	r30, r18
		lpm
		sbrs	r16, 4
		rjmp	loc_100
		inc	r30
		lpm

loc_100:				; CODE XREF: sub_E4+10j sub_E4+19j
		push	r27
		push	r26
		ori	r16, 8
		sbrc	r0, 7
		ori	r16, 0b01000000		; 0x40
		sbrc	r0, 6
		ori	r16, 0b00010000		; 0x10
		mov	r18, r0
		andi	r18, 0b00000111		; 7
		mov	r1, r18
		inc	r1
		ldi	r18, 0xFE ; '�'

loc_10C:				; CODE XREF: sub_E4+2Cj
		dec	r1
		breq	loc_111
		sec
		rol	r18
		rjmp	loc_10C
; ---------------------------------------------------------------------------

loc_111:				; CODE XREF: sub_E4+29j
		clr	r27
		mov	r26, r0
		lsl	r26
		swap	r26
		andi	r26, 0b00000111	; 7
		subi	r26, 0b11111000	; 0xf8		; -8	; '�'
		ld	r1, X
		and	r1, r18
		st	X, r1
		pop	r26
		pop	r27
		ret
; END OF FUNCTION CHUNK	FOR sub_E4

; =============== S U B R O U T I N E =======================================


sub_11D:				; CODE XREF: __RESET:loc_43p
		cli
		ser	r18
		out	PORTB, r18	; PORTB = 0xff
		ldi	r27, 2
		ldi	r26, 0	; X(r27:r26) = 0x200
		clr	r18

loc_123:				; CODE XREF: sub_11D+8j
		st	X+, r18	; for (X = 0x200; X < 0x200+8; X++) mem[X] = 0
		sbrs	r26, 3
		rjmp	loc_123
		
		ldi	r31, 1	
		ldi	r30, 0	; Z(r31:r30) = 0x100
		ser	r18

loc_129:				; CODE XREF: sub_11D+Ej
		st	Z, r18	; for (Z = 0x100; Z < 0x200; Z++) mem[Z] = 0xFF
		inc	r30		; устанавливает флаг Z если r30 == 0
		brne	loc_129	; if Z == 0 goto loc_129
		
		clr	r5
		ldi	r29, 1
		sei
		ret
; End of function sub_11D


; =============== S U B R O U T I N E =======================================
; При передаче используется следующий протокол: сначала передается старт-бит (всегда "0"), затем восемь бит данных, 
; один бит проверки на нечетность и один стоп-бит (всегда "1"). Данные должны считываться в тот момент, когда синхросигнал 
; имеет низкое значение. Формирование синхросигнала осуществляет клавиатура. 
; Длительность как высокого, так и низкого импульсов синхросигнала обычно равняются 30-50 мкс.
;
; Биты считыываются с линии DAT когда CLK == 0
;
; приём байта от клавиатуры в r21
read_keyboard:				; CODE XREF: __RESET+1Dp
					; __RESET:main_loop...
		config_DAT_as_input
		;cbi	DDRC, 5	; CLK - вход
		config_CLK_as_input
		clr	r21

loc_133:				; CODE XREF: read_keyboard+4j
		; дожидаемся старт-бита		
		wait_DAT_0

		; дожидаемся готовности старт-бита
		wait_CLK_0

		; дожидаемся окончания передачи старт-бита
		wait_CLK_1

		; получаем биты данных от младшего к старшему
		ldi	r19, 8
loc_13A:				; CODE XREF: read_keyboard+Bj read_keyboard+13j
		wait_CLK_0

		; читаем состояние линии DAT во флаг CF
		clc
		sbic	PINC, 4
		sec	
		
		ror	r21

		; ждём пока не установится CLK
		wait_CLK_1
		
		dec	r19
		brne	loc_13A	; цикл по 8 битам


		; пропускаем бит проверки на нечетность
		wait_CLK_0
		; TODO проверять бит
		wait_CLK_1

		; пропускаем стоп-бит (единица)
		wait_CLK_0
		; TODO проверять бит
		wait_CLK_1
; End of function read_keyboard


; =============== S U B R O U T I N E =======================================

; сбрасываем CLK и настраиваем эту линию на выход
sub_14C:
		cbi	PORTC, 5	; 8
		config_CLK_as_output
		ret
; End of function sub_14C


; =============== S U B R O U T I N E =======================================

; Параметр: r21 - битовая маска включения светодиодов (младшие три бита)
; •    бит 0 — состояние индикатора Scroll Lock (0 — выключен, 1 — включен);
; •    бит 1 — состояние индикатора Num Lock (0 — выключен, 1 — включен);
; •    бит 2 — состояние индикатора Caps Lock (0 — выключен, 1 — включен);
; •    биты 3-7 не используются.
set_keyboard_leds:
		mov	r17, r21
		ldi	r21, 0xED ; команда управления светодиодами
		rcall	send_command_to_keyboard
		mov	r21, r17
; End of function set_keyboard_leds


; =============== S U B R O U T I N E =======================================


send_command_to_keyboard:				; CODE XREF: __RESET+1Bp __RESET+24p ...
		rcall	write_keyboard	; (r21) 
		rcall	read_keyboard	; приём байта от клавиатуры в r21
		cpi	r21, 0xFE ; запрос на повторную передачу команды со стороны компьютера, выдается в случае возникновения ошибки передачи
		breq	send_command_to_keyboard
		cpi	r21, 0xFA ; подтверждение приема информации (команда ACK)
		ret
; End of function send_command_to_keyboard


; =============== S U B R O U T I N E =======================================

; Ведущая система может послать клавиатуре команды путем удерживания линии синхроимпульсов в низком состоянии. 
; После этого на линии данных устанавливается низкий сигнал (старт-бит). Затем линия синхронизации должна быть 
; освобождена. После этого клавиатура сформирует 10 синхроимпульсов. Данные должны быть установлены до 
; спадающего (заднего) фронта синхроимпульса. После приема десятого бита клавиатура проверяет наличие на линии 
; данных высокого сигнала (стоп-бит). При обнаружении высокого уровня на линии данных клавиатура выставляет на ней 
; низкий уровень, который сигнализирует ведущему устройству что данные получены. 

; Передаёт содержимое регистра r21 клавиатуре
write_keyboard:
		rcall	sub_14C	; сбрасываем CLK и настраиваем эту линию на выход
		rcall	delay_100us	; delay 100 мкс
		; линию DAT конфигурируем на выход и сбрасываем в 0
		set_DAT_to_0
		config_DAT_as_output
		rcall	delay_5us
		config_CLK_as_input
		rcall	delay_5us

		; цикл передачи 8 бит
		ldi		r19, 8
		clr		r2	 ; r2 - счётчик единичных бит
write_keyboard_bits_loop:
		wait_CLK_0
		
		ror	r21
		brcs	write_keyboard_bit_1
		set_DAT_to_0
		rjmp	write_keyboard_bits_loop_continue
; ---------------------------------------------------------------------------

write_keyboard_bit_1:
		set_DAT_to_1
		inc	r2

write_keyboard_bits_loop_continue:
		wait_CLK_1
		dec	r19
		brne	write_keyboard_bits_loop

		; передаём бит бит проверки на нечётность
		wait_CLK_0
		; TODO эту команду лучше пропускать если не требуется
		set_DAT_to_1
		sbrc	r2, 0
		set_DAT_to_0
		wait_CLK_1

		; передаём стоп-бит
		wait_CLK_0
		set_DAT_to_1
		wait_CLK_1
		
		config_DAT_as_input

		wait_CLK_0

		wait_CLK_1
		ret
; End of function write_keyboard


; =============== S U B R O U T I N E =======================================

; задержка 0.5 сек
delay_500ms:
		ldi	r19, 50

loc_181:
		rcall	delay_10ms
		dec	r19
		brne	loc_181
		ret

; =============== S U B R O U T I N E =======================================

; delay 10 мс
delay_10ms:
		ldi	r18, 100
		mov	r1, r18
delay_10ms_loop:
		rcall	delay_100us
		dec	r1
		brne	delay_10ms_loop
		ret


; =============== S U B R O U T I N E =======================================

; delay 100 мкс
delay_100us:
		ldi	r18, 200
		rjmp	delay_05us


; =============== S U B R O U T I N E =======================================

; delay 5 мкс
delay_5us:
		ldi	r18, 10

; delay 0.5 мкс
delay_05us:
		nop
		dec	r18
		brne	delay_05us
		ret

; ---------------------------------------------------------------------------
