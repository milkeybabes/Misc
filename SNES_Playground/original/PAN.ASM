65C816

	#INCLUDE "816CONST.ASM"
	#INCLUDE "MACROS.ASM"
	#INCLUDE "SNES_IO.ASM"
	LONGS
	

	SEGMENT	'banklowRAM'	; for zero page


.ROTATE	DS.W		; rotate angle
.JOY_PAD1	DS.W
.WORLD_X	DS.W
.WORLD_Y	DS.W
.SYNC	DS.W

	DS.W
	DS.W

.HDMAT1	DS.B
	DS.W
	DS.B
	DS.W
	DS.B
	DS.W
	DS.B

.HDMAT2	DS.B
	DS.W
	DS.B
	DS.W
	DS.B
	DS.W
	DS.B


.TEMP1	DS.W
.TEMP2	DS.W


;**-	RAM BANK 7E
	SEGMENT	'bank7ERAM'	; user ram area

.USER_RAM1

;**-	RAM BANK 7F
	SEGMENT 'bank7FRAM'	; where map is to sit
.USER_RAM2

;**-	Start of Command RAM

	SEGMENT 'bankcommon'
.COMMON_BANK



;**-	Main Bank 0 Start
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Vector entry points - must be in bank 0
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	SEGMENT	'bank0ROM'
.FIRST_BANK



	#INCLUDE "backchan.asm"
	#INCLUDE "bchcomms.asm"


;**-	IRQ Handler
IRQentry	ShortA
	PHA
	PHB
	PHK
	PLB
	LDA	|TIMEUP
	LDA	#%00001111
EDGE_WAIT	BIT	|HVBJOY
	BVC	EDGE_WAIT
	STA	|INIDISP
	PLB
	PLA
	RTI


;**-	NMI Handler

NMIentry	PHP
	LongAI
	PHB
	PHA
	PHX
	PHY
	ShortA
	PHK
	PLB
	LDA	|RDNMI	; Clear NMI
	INC	<SYNC

	;STZ	|INIDISP

	LDA	<WORLD_X	; xscroll low
	STA	|BG1HOFS
	LDA	<WORLD_X+1	; xscroll high
	STA	|BG1HOFS
	LDA	<WORLD_Y	; yscroll low
	STA	|BG1VOFS
	LDA	<WORLD_Y+1	; yscroll high
	STA	|BG1VOFS
	LongA
	LDA	<WORLD_X
	CLC
	ADC	#$80
	AND	#$3FF
	ShortA
	STA	|M7X
	XBA
	STA	|M7X
	LongA
	LDA	<WORLD_Y
	CLC
	ADC	#$B0
	AND	#$3FF
	ShortA
	STA	|M7Y
	XBA
	STA	|M7Y


ADD_FIRST	EQU	4	; dma entry
ADD_SECOND	EQU	7	; next one

	LongA
	LDA	<ROTATE
	ASL	A
	ASL	A
	ASL	A	; C=0
	TAX
	LDA	|ALL_TABLE AND $FFFF,X
	STA	<HDMAT1+ADD_FIRST
	ADC	#$E0
	STA	<HDMAT1+ADD_SECOND
	LDA	|ALL_TABLE+6 AND $FFFF,X
	STA	<HDMAT2+ADD_FIRST
	ADC	#$E0
	STA	<HDMAT2+ADD_SECOND
	LDA	|ALL_TABLE+2 AND $FFFF,X
	ShortA
	STA	|DMA_HBANK+DMA0
	XBA
	STA	|DMA_HBANK+DMA1
	LDA	|ALL_TABLE+4 AND $FFFF,X
	STA	|DMA_HBANK+DMA2
	LDA	|ALL_TABLE+5 AND $FFFF,X
	STA	|DMA_HBANK+DMA3
	LongA
joywaitloop	LDA	|HVBJOY
	AND	#%00000001
	BNE	joywaitloop
	LDA	|JOY1L
	STA	<JOY_PAD1

	PLY
	PLX
	PLA
	PLB
	PLP
	RTI


;**+	Init ALL

RESETentry      SEI
	CLC
	XCE
	LongI
	LDX	#$1ff
	TXS
	LongAI
	LDA	#0	; init Direct Page
	TCD
	ASSUME	DATABANK FIRST_BANK AND $FF0000
	ShortA
	PHK
	PLB		; select data bank $00
	ShortAI
	;Initial_Settings
	LDA	#$8F
	STA	|INIDISP
	STZ	|OBJSEL
	STZ	|OAMADDL
	STZ	|OAMADDH
	;STZ	|OAMDATA	; no need to write data
	LDA	#7
	STA	|BGMODE
	STZ	|MOSAIC
	STZ	|BG1SC
	STZ	|BG2SC
	STZ	|BG3SC
	STZ	|BG4SC
	STZ	|BG12NBA
	STZ	|BG34NBA
	STZ	|BG1HOFS
	STZ	|BG1HOFS
	STZ	|BG1VOFS
	STZ	|BG1VOFS
	STZ	|BG2HOFS
	STZ	|BG2HOFS
	STZ	|BG2VOFS
	STZ	|BG2VOFS
	STZ	|BG3HOFS
	STZ	|BG3HOFS
	STZ	|BG3VOFS
	STZ	|BG3VOFS
	STZ	|BG4HOFS
	STZ	|BG4HOFS
	STZ	|BG4VOFS
	STZ	|BG4VOFS
	LDA	#$80
	STA	|VMAINC
	STZ	|VMADDL
	STZ	|VMADDH
	STZ	|M7SEL
	LDA	#$01
	STZ	|M7A
	STA	|M7A
	STZ	|M7B
	STZ	|M7B
	STZ	|M7C
	STZ	|M7C
	STZ	|M7D
	STA	|M7D
	STZ	|M7X
	STZ	|M7X
	STZ	|M7Y
	STZ	|M7Y
	STZ	|CGADD
	STZ	|W12SEL
	STZ	|W34SEL
	STZ	|WOBJSEL
	STZ	|WH0
	STZ	|WH1
	STZ	|WH2
	STZ	|WH3
	STZ	|WBGLOG
	STZ	|WOBJLOG
	STZ	|TM
	STZ	|TS
	STZ	|TMW
	LDA	#$30
	STA	|CGSWSEL
	STZ	|CGADSUB
	LDA	#$E0
	STA	|COLDATA
	STZ	|SETINI
	STZ	|NMITIMEN
	LDA	#$FF
	STA	|WRIO
	STZ	|WRMPYA
	STZ	|WRMPYB
	STZ	|WRDIVL
	STZ	|WRDIVH
	STZ	|WRDIVB
	STZ	|HTIMEL
	STZ	|HTIMEH
	STZ	|VTIMEL
	STZ	|VTIMEH
	STZ	|MDMAEN
	STZ	|HDMAEN
	LDA	#1
	STA	|MEMSEL

	LongAI

	ASSUME	databank COMMON_BANK AND $FF0000

	LDX	#0
MOVEHD	LDA	|HDMA_TABLE1 AND $FFFF,X
	STA	<HDMAT1,X
	LDA	|HDMA_TABLE2 AND $FFFF,X
	STA	<HDMAT2,X
	INX
	INX
	CPX	#10
	BCC	MOVEHD

	LDX	#GET_LENGTH-FIRST_BIT-2
INVERT	LDA	>FIRST_BIT,X
	EOR	#$FFFF
	INC	A
	STA	>$7E8000,X
	DEX
	DEX
	BPL	INVERT

	ShortI

	LDA	#$1801	; $2118 VRAM ,word write
	STA	|DMA_SETUP+DMA7	; use DMA 7
	STZ	|VMADDL	; vram start write
	LDA	#32768
	STA	|DMA_COUNT+DMA7	; amount unpacked
	LDA	#OFFSET TEST_DATA
	STA	|DMA_A1ADDR+DMA7	; start address for read
	LDX	#SEG TEST_DATA	; bank 1 for character set
	STX	|DMA_A1ADDRB+DMA7
	LDX	#BIT7
	STX	|MDMAEN	; set channel 7 going?

	LDA	#$2200	; $2122 CG-RAM, byte store
	STA	|DMA_SETUP+DMA6	; use DMA 6
	LDX	#0
	STX	|CGADD	; start of pallete colours
	LDA	#256	; 16 palettes for 256 BG mode
	STA	|DMA_COUNT+DMA6
	LDA	#OFFSET PALETTE
	STA	|DMA_A1ADDR+DMA6
	LDX	#SEG PALETTE
	STX	|DMA_A1ADDRB+DMA6
	LDX	#BIT6
	STX	|MDMAEN

	LDA	#$1B42
	STA	|DMA_SETUP+DMA0
	LDA	#$1C42
	STA	|DMA_SETUP+DMA1
	LDA	#$1D42
	STA	|DMA_SETUP+DMA2
	LDA	#$1E42
	STA	|DMA_SETUP+DMA3

	LDA     #OFFSET HDMAT1
	STA	|DMA_A1ADDR+DMA0
	LDA	#OFFSET HDMAT2
	STA	|DMA_A1ADDR+DMA1
	LDA     #OFFSET HDMAT2
	STA	|DMA_A1ADDR+DMA2
	LDA	#OFFSET HDMAT1
	STA	|DMA_A1ADDR+DMA3

	LDX	#SEG HDMAT1
	STX	|DMA_A1ADDRB+DMA0
	STX	|DMA_A1ADDRB+DMA1
	STX	|DMA_A1ADDRB+DMA2
	STX	|DMA_A1ADDRB+DMA3

	LDX	#SEG FIRST_BANK
	STX	|DMA_HBANK+DMA0	; bank for data
	STX	|DMA_HBANK+DMA1	; bank for data
	STX	|DMA_HBANK+DMA2	; bank for data
	STX	|DMA_HBANK+DMA3	; bank for data

	LDA	#$0000
	STA	|DMA_SETUP+DMA4
	LDA     #OFFSET TEST_HDMA
	STA	|DMA_A1ADDR+DMA4

	LDX	#SEG TEST_HDMA
	STX	|DMA_A1ADDRB+DMA4
	LDX	#SEG FIRST_BANK
	STX	|DMA_HBANK+DMA4


	LDX	#BIT0+BIT1+BIT2+BIT3+BIT4
	STX	|HDMAEN

	;LDA	#$B0
	;STA	|HTIMEL
	;LDA	#$2F
	;STA	|VTIMEL
	ShortA
	LDA	#%11000000	; black outside
	STA	|M7SEL
	LDA	#%00001	; BG1 only & OBJ
	STA	|TM
	STZ	|TMW	; make sure no windows effects 
	LDA	#15
	STA	|INIDISP
	;LDA	#%10110001
	LDA	#%10000001
	STA	|NMITIMEN
	LongAI
	STZ	<WORLD_X	; init all
	STZ	<WORLD_Y
	STZ	<ROTATE

	;CLI

;**+	Main Loop

	AssertM16X16
OVER_SPEED	EQU	2	;2	; pixels movement

OMAX_X	EQU	1024-256
OMAX_Y	EQU	848+8

OVER_LOOP	LDX	#0

	TXY
	LDA	<JOY_PAD1
	BIT	#Joy_Right	; right?
	BEQ	no_right
	LDX	#OVER_SPEED
no_right	BIT	#Joy_Left	; left?
	BEQ	no_left
	LDX	#-OVER_SPEED
no_left	BIT	#Joy_Down	; down?
	BEQ	no_down
	LDY	#OVER_SPEED
no_down	BIT	#Joy_Up	; up?
	BEQ	no_up
	LDY	#-OVER_SPEED
no_up	TXA
	CLC
	ADC	<WORLD_X
	STA	<WORLD_X
no_savex1	TYA
	CLC
	ADC	<WORLD_Y
	STA	<WORLD_Y
NO_SCR	LDA	<JOY_PAD1
	BIT	#Joy_R
	BEQ	NORR
	LDA	<ROTATE
	INC	A
	CMP	#$C0
	BCC	SMA
	LDA	#0
SMA	STA	<ROTATE

NORR	LDA	<JOY_PAD1
	BIT	#Joy_L
	BEQ	NORL
	LDA	<ROTATE
	DEC	A
	CMP	#$C0
	BCC	LES
	LDA	#$C0-1
LES	STA	<ROTATE

NORL	JSR	|FIFTY
	JMP	|OVER_LOOP

FIFTY	PHP
	LongA
WAIT_S	LDA	<SYNC
	BEQ	WAIT_S
	STZ	<SYNC
	PLP
	RTS	


TEST_HDMA	BYTE	$2F
	BYTE	0
	BYTE	$70
	BYTE	%00001111
	BYTE	0


HDMA_TABLE1	BYTE	$2F
	WORD	BLANK
	BYTE	$F0	;128+127; pair
	WORD	FIRST_BIT
	BYTE	$C0	;128+113
	WORD	FIRST_BIT+$E0	;254
	BYTE	0	; end of list


HDMA_TABLE2	BYTE	$2F
	WORD	BLANK
	BYTE	$F0	;128+127	; pair
	WORD	FIRST_BIT
	BYTE	$C0	;128+113
	WORD	FIRST_BIT+$E0	;254
	BYTE	0	; end of list

BLANK	WORD	0


ROT_TABLE	EQU	OFFSET FIRST_BIT

ALL_TABLE

T1	EQU	0
	REPEAT
	WORD	{{{48-T1} MULT $160}+$8000}
	BYTE	SEG FIRST_BIT
	BYTE	SEG FIRST_BIT
	BYTE	SEG USER_RAM1
	BYTE	SEG FIRST_BIT
	WORD	{{T1 MULT $160}+$8000}
T1	CEQU	T1 + 1
	UNTIL	T1 EQ 48


T2	EQU	0
	REPEAT
	WORD	{{T2 MULT $160}+$8000}
	BYTE	SEG USER_RAM1
	BYTE	SEG FIRST_BIT
	BYTE	SEG USER_RAM1
	BYTE	SEG USER_RAM1
	WORD	{{{48-T2} MULT $160}+$8000}
T2	CEQU	T2 + 1
	UNTIL	T2 EQ 48

T3	EQU	0
	REPEAT
	WORD	{{{48-T3} MULT $160}+$8000}
	BYTE	SEG USER_RAM1
	BYTE	SEG USER_RAM1
	BYTE	SEG FIRST_BIT
	BYTE	SEG USER_RAM1
	WORD	{{T3 MULT $160}+$8000}
T3	CEQU	T3 + 1
	UNTIL	T3 EQ 48

T4	EQU	0
	REPEAT
	WORD	{{T4 MULT $160}+$8000}
	BYTE	SEG FIRST_BIT
	BYTE	SEG USER_RAM1
	BYTE	SEG FIRST_BIT
	BYTE	SEG FIRST_BIT
	WORD	{{{48-T4} MULT $160}+$8000}
T4	CEQU	T4 + 1
	UNTIL	T4 EQ 48

	SEGMENT 'bank0ROM'

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Vector jumps mapped into bank 0
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	SEGMENT	'vecjmps>vjdata'

RESETjmp	JMP	>RESETentry
NMIjmp	JMP	>NMIentry
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; BRKs used for (soft) breakpointing
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
BRKentry	JMP	|unusedvec
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; unused vectors: whip into monitor
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
COPentry
ABORTentry
unusedvec
	CLC		; in case got in to emulation mode somehow
	XCE
	JMP	|unusedvec

; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; 65816 Vectors
; ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	SEGMENT 'vectors>vecdata'

COPvec	WORD	COPentry
BRKvec	WORD	BRKentry
ABRTvec	WORD	ABORTentry
NMIvec	WORD	NMIjmp
	WORD	unusedvec
IRQvec	WORD	IRQentry

	WORD	0
	WORD	0

; Now aligned to FFF4: emulation vectors
; Vectors called while E bit is set; we're only interested in RESET

	WORD	unusedvec	; COP
	WORD	unusedvec	; BRK
	WORD	unusedvec	; ABORT
	WORD	unusedvec	; NMI
RSTvec	WORD	RESETjmp
	WORD	unusedvec	; IRQ


	SEGMENT 'bank2ROM'

TEST_DATA	;#LOAD	"BEACH2.SCR"
	;#LOAD	"BOWSER3.SCR"
 	;#LOAD	"DONUT3.SCR"
	;#LOAD	"ICE2.SCR"
	#LOAD	"MARIO1.SCR"

	SEGMENT	'bank3ROM'
FIRST_BIT	#LOAD	"ROTATE.TAB"
GET_LENGTH
PALETTE	;#LOAD	"BEACH2.PAL"
	;#LOAD	"BOWSER3.PAL"
	;#LOAD	"DONUT3.PAL"
	;#LOAD	"ICE2.PAL"
	#LOAD	"MARIO1.PAL"

	END

