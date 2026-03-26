;==============================================================================
; PAN.ASM  -- SNES Mode 7 “drive around” demo (Mario Kart-style)
;
; Controls (JOY_PAD1 bits assumed from included constants):
;   Left/Right : rotate view (angle 0..$BF)
;   Up/Down    : increase/decrease speed (rate-limited by SPEED_DELAY)
;
; Core idea:
;   - Use Mode 7 (BG1) with a prebuilt map/graphics and palette.
;   - Maintain a world position (WORLD_X/WORLD_Y) and an angle (ROTATE).
;   - Each frame:
;       - NMI updates BG scroll + Mode7 rotation center (M7X/M7Y)
;       - ROTATE selects which precomputed HDMA “profile” tables to use
;         for writing Mode 7 matrix values per scanline.
;       - Main loop reads pad, updates ROTATE/SPEED, and moves WORLD_X/Y.
;
; Fixed-point conventions:
;   - FRACTION_X / FRACTION_Y are 8-bit fractional accumulators.
;     The movement result is accumulated into FRACTION_X/Y (16-bit add),
;     and carry/borrow is applied into WORLD_X+1 / WORLD_Y+1 as the coarse
;     scroll component.
;   - FRACTION.TAB contains signed 16-bit values in 8.8 style:
;       $0100 = +1.0, $FF00 = -1.0
;     SPEED is multiplied by this to produce per-frame deltas.
;
; HDMA usage:
;   - Channels 0..3 feed Mode 7 matrix registers ($211B..$211E = M7A..M7D).
;   - The per-scanline data lives in ROTATE.TAB as “profiles”.
;     Each profile is $160 bytes = 176 WORDs = 176 scanlines of 16-bit values:
;       +$000..+$0DF : 112 WORDs ($E0 bytes)   -> first HDMA run (112 lines)
;       +$0E0..+$15F :  64 WORDs ($80 bytes)   -> second HDMA run (64 lines)
;     HDMA list uses two repeated runs: 112 lines then 64 lines.
;   - Each frame, ROTATE selects which profile bank/offset each channel reads.
;   - Channel 4 is a small test/extra HDMA list (TEST_HDMA).
;
; Toolchain:
;   - Original code with Crash Barrier METAi assembler/linker (AS/LYN + OBSEND).
;   - Updated to assemble using 64tass.exe (windows version for me!)
;==============================================================================


.AS
.XS
.AUTSIZ
.DATABANK $00
.DPAGE $0000

; ------------------------------------------------------------
; HDMA pointer offsets inside the RAM shadow tables
; Offsets inside HDMAT1/HDMAT2 structures.
; These point at the WORD fields used as HDMA data pointers.
; ------------------------------------------------------------
ADD_FIRST	=	4
ADD_SECOND	=	7

; ------------------------------------------------------------
; CPU mode helper macros
; ------------------------------------------------------------
ShortAI	.MACRO
	SEP	#(Mflag|Xflag)
	.AS
	.XS
	.ENDM

LongAI	.MACRO
	REP	#(Mflag|Xflag)
	.AL
	.XL
	.ENDM

ShortA	.MACRO
	SEP	#Mflag
	.AS
	.ENDM

LongA	.MACRO
	REP	#Mflag
	.AL
	.ENDM

ShortI	.MACRO
	SEP	#Xflag
	.XS
	.ENDM

LongI	.MACRO
	REP	#Xflag
	.XL
	.ENDM

ShortA_LongI	.MACRO
	SEP	#Mflag
	.AS
	REP	#Xflag
	.XL
	.ENDM

LongA_ShortI	.MACRO
	REP	#Mflag
	.AL
	SEP	#Xflag
	.XS
	.ENDM

;------------------------------------------------------------------------------
; IRQ handler
; Appears to be an experiment using TIMEUP + HVBJOY edge wait, then forces
; INIDISP brightness to $0F.
;------------------------------------------------------------------------------
IRQentry:
	ShortA
	PHA
	PHB
	PHK
	PLB
	LDA	TIMEUP
	LDA	#%00001111

EDGE_WAIT:
	BIT	HVBJOY
	BVC	EDGE_WAIT
	STA	INIDISP

	PLB
	PLA
	RTI


;------------------------------------------------------------------------------
; NMI handler (runs once per frame)
; - Clears NMI flag
; - Increments SYNC (frame tick)
; - Updates BG1 scroll (BG1HOFS/BG1VOFS)
; - Updates Mode7 rotation center (M7X/M7Y) from WORLD position + offsets
; - Updates HDMA source bank selections and profile pointers based on ROTATE
; - Reads controller (JOY1L)
;------------------------------------------------------------------------------

NMIentry:
	PHP
	LongAI
	PHB
	PHA
	PHX
	PHY

	ShortA
	PHK
	PLB

	LDA	RDNMI	; read to clear NMI latch
	INC	SYNC

; --- BG1 scroll (Mode 7 uses BG1) ---
	LDA	WORLD_X
	STA	BG1HOFS
	LDA	WORLD_X+1
	STA	BG1HOFS

	LDA	WORLD_Y
	STA	BG1VOFS
	LDA	WORLD_Y+1
	STA	BG1VOFS

; --- Mode 7 rotation center ---
; M7X/M7Y are 10-bit values, written low then high.
; Adding constants offsets the center so rotation looks natural.
	LongA
	LDA	WORLD_X
	CLC
	ADC	#$0080
	AND	#$03FF
	ShortA
	STA	M7X
	XBA
	STA	M7X

	LongA
	LDA	WORLD_Y
	CLC
	ADC	#$00B0
	AND	#$03FF
	ShortA
	STA	M7Y
	XBA
	STA	M7Y

	; --- Select per-frame HDMA profile based on ROTATE ---
	; Each ALL_TABLE record is 8 bytes (hence ROTATE * 8).
	LongA
	LDA	ROTATE
	ASL A
	ASL A
	ASL A
	TAX

	; Each profile is $160 bytes and split into:
	; --------------------------------------------------------
	; Patch HDMA pointer for single continuous profile
	; ALL_TABLE now holds one pointer per profile instead of two
	; --------------------------------------------------------

	; Load 16-bit pointer to this rotation's continuous profile
	; Patch HDMAT1 pointers
	LDA	ALL_TABLE,X
	STA	HDMAT1+ADD_FIRST
	CLC
	ADC	#$00E0
	STA	HDMAT1+ADD_SECOND

	LDA	ALL_TABLE+6,X
	STA	HDMAT2+ADD_FIRST
	CLC
	ADC	#$00E0
	STA	HDMAT2+ADD_SECOND

; Update HDMA source banks (DMA_HBANK) for channels 0..3
	LDA	ALL_TABLE+2,X
	ShortA
	STA	DMA_HBANK+DMA0
	XBA
	STA	DMA_HBANK+DMA1
	LDA	ALL_TABLE+4,X
	STA	DMA_HBANK+DMA2
	LDA	ALL_TABLE+5,X
	STA	DMA_HBANK+DMA3

; --- Read joypad (safe window) ---
	LongA
joywaitloop:
	LDA	HVBJOY
	AND	#%00000001
	BNE	joywaitloop

	LDA	JOY1L
	STA	JOY_PAD1

	PLY
	PLX
	PLA
	PLB
	PLP
	RTI


; ============================================================
; RESET
; ------------------------------------------------------------
; Cold boot:
; - Switch to native mode
; - Init PPU
; - Upload graphics + palette
; - Setup HDMA
; ============================================================

RESETentry:
	ShortAI
	SEI
	CLC
	XCE

	LongI
	LDX	#$01FF
	TXS

	LongAI
	LDA	#$0000
	TCD

	ShortA
	PHK
	PLB
	ShortAI

; --- PPU init ---
	LDA	#$8F
	STA	INIDISP

	STZ	OBJSEL
	STZ	OAMADDL
	STZ	OAMADDH

	LDA	#7
	STA	BGMODE
	STZ	MOSAIC

	STZ	BG1SC
	STZ	BG2SC
	STZ	BG3SC
	STZ	BG4SC
	STZ	BG12NBA
	STZ	BG34NBA

	STZ	BG1HOFS
	STZ	BG1HOFS
	STZ	BG1VOFS
	STZ	BG1VOFS
	STZ	BG2HOFS
	STZ	BG2HOFS
	STZ	BG2VOFS
	STZ	BG2VOFS
	STZ	BG3HOFS
	STZ	BG3HOFS
	STZ	BG3VOFS
	STZ	BG3VOFS
	STZ	BG4HOFS
	STZ	BG4HOFS
	STZ	BG4VOFS
	STZ	BG4VOFS

	LDA	#$0080
	STA	VMAINC
	STZ	VMADDL
	STZ	VMADDH

; --- Mode 7 defaults (A=1, D=1) ---
	STZ	M7SEL
	LDA	#$0001
	STZ	M7A
	STA	M7A
	STZ	M7B
	STZ	M7B
	STZ	M7C
	STZ	M7C
	STZ	M7D
	STA	M7D
	STZ	M7X
	STZ	M7X
	STZ	M7Y
	STZ	M7Y

	STZ	CGADD
	STZ	W12SEL
	STZ	W34SEL
	STZ	WOBJSEL
	STZ	WH0
	STZ	WH1
	STZ	WH2
	STZ	WH3
	STZ	WBGLOG
	STZ	WOBJLOG
	STZ	TM
	STZ	TS
	STZ	TMW
	STZ	TSW

	LDA	#$0030
	STA	CGSWSEL
	STZ	CGADSUB
	LDA	#$00E0
	STA	COLDATA

	STZ	SETINI
	STZ	NMITIMEN

	LDA	#$00FF
	STA	WRIO

	STZ	WRMPYA
	STZ	WRMPYB
	STZ	WRDIVL
	STZ	WRDIVH
	STZ	WRDIVB

	STZ	HTIMEL
	STZ	HTIMEH
	STZ	VTIMEL
	STZ	VTIMEH

	STZ	MDMAEN
	STZ	HDMAEN

	LDA	#1
	STA	MEMSEL

	LongAI

; ------------------------------------------------------------
; Copy HDMA template tables to RAM shadow copies
; ------------------------------------------------------------
	LDX	#0

MOVEHD:
	LDA	HDMA_TABLE1,X
	STA	HDMAT1,X
	LDA	HDMA_TABLE2,X
	STA	HDMAT2,X
	INX
	INX
	CPX	#10
	BCC	MOVEHD

; Build a negated copy of the ROTATE table into RAM ($7E8000).
; This is useful for rotation quadrants: swap bank pointers between
; ROM (original) and RAM (negated) instead of storing separate tables.
	LDX	#(ROTATE_TAB_SIZE-2)

INVERT:
	LDA	FIRST_BIT,X
	EOR	#$FFFF
	INC A
	STA	INVERT_RAM,X
	DEX
	DEX
	BPL	INVERT

	ShortI

; ------------------------------------------------------------
; DMA: upload map/graphics to VRAM
; ------------------------------------------------------------
	LDA	#$1801
	STA	DMA_SETUP+DMA7
	STZ	VMADDL
	LDA	#32768
	STA	DMA_COUNT+DMA7
	LDA	#<>TEST_DATA
	STA	DMA_A1ADDR+DMA7
	LDX	#`TEST_DATA
	STX	DMA_A1ADDRB+DMA7
	LDX	#BIT7
	STX	MDMAEN

; ------------------------------------------------------------
; DMA: upload palette to CGRAM
; ------------------------------------------------------------
	LDA	#$2200
	STA	DMA_SETUP+DMA6
	LDX	#0
	STX	CGADD
	LDA	#256
	STA	DMA_COUNT+DMA6
	LDA	#<>PALETTE
	STA	DMA_A1ADDR+DMA6
	LDX	#`PALETTE
	STX	DMA_A1ADDRB+DMA6
	LDX	#BIT6
	STX	MDMAEN

; ------------------------------------------------------------
; Setup HDMA channels 0..3 for Mode 7 matrix regs
; ------------------------------------------------------------
	LDA	#$1B42
	STA	DMA_SETUP+DMA0
	LDA	#$1C42
	STA	DMA_SETUP+DMA1
	LDA	#$1D42
	STA	DMA_SETUP+DMA2
	LDA	#$1E42
	STA	DMA_SETUP+DMA3

	LDA	#<>HDMAT1
	STA	DMA_A1ADDR+DMA0
	LDA	#<>HDMAT2
	STA	DMA_A1ADDR+DMA1
	LDA	#<>HDMAT2
	STA	DMA_A1ADDR+DMA2
	LDA	#<>HDMAT1
	STA	DMA_A1ADDR+DMA3

	LDX	#`HDMAT1
	STX	DMA_A1ADDRB+DMA0
	STX	DMA_A1ADDRB+DMA1
	STX	DMA_A1ADDRB+DMA2
	STX	DMA_A1ADDRB+DMA3

	LDX	#`FIRST_BIT
	STX	DMA_HBANK+DMA0
	STX	DMA_HBANK+DMA1
	STX	DMA_HBANK+DMA2
	STX	DMA_HBANK+DMA3

; ------------------------------------------------------------
; HDMA channel 4 test list NOT USED*
; ------------------------------------------------------------
	LDA	#$0000
	STA	DMA_SETUP+DMA4
	LDA	#<>TEST_HDMA
	STA	DMA_A1ADDR+DMA4

	LDX	#`TEST_HDMA
	STX	DMA_A1ADDRB+DMA4
	LDX	#`TEST_HDMA
	STX	DMA_HBANK+DMA4
; Enable HDMA channels 0..4
	LDX	#BIT0+BIT1+BIT2+BIT3+BIT4
	STX	HDMAEN

; ------------------------------------------------------------
; Final display setup
; ------------------------------------------------------------
	ShortA
	LDA	#%11000000
	STA	M7SEL

	LDA	#%00000001
	STA	TM
	STZ	TMW

	LDA	#15
	STA	INIDISP

	LDA	#%10000001
	STA	NMITIMEN

; ------------------------------------------------------------
; Init movement state
; ------------------------------------------------------------
	STZ	FRACTION_X
	STZ	FRACTION_Y

	LongAI
	STZ	WORLD_X
	STZ	WORLD_Y
	STZ	ROTATE
	LDA	#0
	STA	SPEED
	LDA	#20
	STA	SPEED_DELAY


OMAX_X	=	1024-256
OMAX_Y	=	1024-256

; ============================================================
; MAIN LOOP
; ============================================================

OVER_LOOP:
	LDX	JOY_PAD1
	TXA

; Right: rotate clockwise (decrement), clamp to $C0-1
	BIT	#Joy_Right
	BEQ	no_right
	LDA	ROTATE
	DEC A
	CMP	#$C0
	BCC	LES
	LDA	#$C0-1
LES:
	STA	ROTATE

no_right:
; Left: rotate counter-clockwise (increment), wrap at $C0
	TXA
	BIT	#Joy_Left
	BEQ	no_left
	LDA	ROTATE
	INC A
	CMP	#$C0
	BCC	SMA
	LDA	#0
SMA:
	STA	ROTATE

no_left:
; --- speed changes are rate-limited ---
	DEC	SPEED_DELAY
	BNE	NO_SCR

	LDA	#20
	STA	SPEED_DELAY

	TXA
	BIT	#Joy_Down
	BEQ	no_down
	LDA	SPEED
	BEQ	no_down
	DEC A
	STA	SPEED

no_down:
	BIT	#Joy_Up
	BEQ	no_up
	INC	SPEED

no_up:
NO_SCR:
	JSR	MOVE_IT

; world clamp experiment left commented out
KEEP1:
KEEP2:
	JSR	FIFTY
	JMP	OVER_LOOP

;------------------------------------------------------------------------------
; MOVE_IT
; Move forward in direction ROTATE, scaled by SPEED.
;
; Implementation:
;   - Uses SNES HW multiplier (WRMPYA/WRMPYB, result in RDMPYL).
;   - Uses FRACTION_T lookup table indexed by angle and angle +/- $30
;     to get X and Y motion components.
;   - Adds into FRACTION_X/Y and applies carry/borrow into WORLD_X+1/Y+1.
;------------------------------------------------------------------------------

MOVE_IT:
	ShortA
	LDA	SPEED
	STA	WRMPYA
	LongA
	BNE	MOVETHEN
	RTS

MOVETHEN:
	LDA	#$BF
	SEC
	SBC	ROTATE
	TAY
	ASL A
	TAX

; --- X component ---
	LDA	FRACTION_T,X
	BEQ	SLOW_DOWN
	BMI	WORSE_CASE
	CMP	#$100
	BNE	MUL
	LDA	SPEED
	XBA
	BRA	ADD_THIS

MUL:
	ShortA
	STA	WRMPYB
	LongA
	LDA	rdmpyl

ADD_THIS:
	CLC
	ADC	FRACTION_X
	STA	FRACTION_X
	LDA	WORLD_X+1
	ADC	#0
	STA	WORLD_X+1
	BRA	SLOW_DOWN

WORSE_CASE:
	EOR	#$FFFF
	INC A
	CMP	#$100
	BNE	MUL2
	LDA	SPEED
	XBA
	BRA	ADD_THIS2

MUL2:
	ShortA
	STA	WRMPYB
	LongA
	LDA	rdmpyl

ADD_THIS2:
	EOR	#$FFFF
	INC A
	CLC
	ADC	FRACTION_X
	STA	FRACTION_X
	LDA	WORLD_X+1
	SBC	#0
	STA	WORLD_X+1

        ; Y component uses angle offset by $30 (~90 degrees in 192-step space)
SLOW_DOWN:
	TYA
	SEC
	SBC	#$30
	BCS	NOOV
	ADC	#$C0
NOOV:
	ASL A
	TAX

	LDA	FRACTION_T,X
	BEQ	NO_MOVED
	BMI	WORSE_CASE2
	CMP	#$100
	BNE	MUL3
	LDA	SPEED
	XBA
	BRA	ADD_THIS3

MUL3:
	ShortA
	STA	WRMPYB
	LongA
	LDA	rdmpyl

ADD_THIS3:
	CLC
	ADC	FRACTION_Y
	STA	FRACTION_Y
	LDA	WORLD_Y+1
	ADC	#0
	STA	WORLD_Y+1
NO_MOVED:
	RTS

WORSE_CASE2:
	EOR	#$FFFF
	INC A
	CMP	#$100
	BNE	MUL4
	LDA	SPEED
	XBA
	BRA	ADD_THIS4

MUL4:
	ShortA
	STA	WRMPYB
	LongA
	LDA	rdmpyl

ADD_THIS4:
	EOR	#$FFFF
	INC A
	CLC
	ADC	FRACTION_Y
	STA	FRACTION_Y
	LDA	WORLD_Y+1
	SBC	#0
	STA	WORLD_Y+1
	RTS


;------------------------------------------------------------------------------
; FIFTY - frame wait
; Waits for SYNC to be incremented by NMI, then clears it.
; Stores loop count in TSTATES (debug-ish).
;------------------------------------------------------------------------------
FIFTY:
	PHP
	LongA
	LDX	#0

WAIT_S:
	INX
	LDA	SYNC
	BEQ	WAIT_S

	STZ	SYNC
	STX	TSTATES
	PLP
	RTS

; ============================================================
; DATA / TABLES
; ============================================================

; FRACTION lookup table: 192 entries (0..$BF) of signed 8.8 values

FRACTION_T:
	.BINARY "TABLES/FRACTION.TAB"

; Not used
TEST_HDMA:
	.BYTE	$2F
	.BYTE	0
	.BYTE	$70
	.BYTE	%00001111
	.BYTE	0

;------------------------------------------------------------------------------
; HDMA_TABLE1 / HDMA_TABLE2
;
; HDMA table format:
;   BYTE lineCount
;   WORD dataPointer
;   BYTE lineCount
;   WORD dataPointer
;   BYTE 0          ; end
;
; lineCount:
;   bit7 = 1 => repeat mode
;   bits0-6 = number of scanlines
;
; Here:
;   $F0 = repeat + $70 = 112 lines
;   $C0 = repeat + $40 =  64 lines
; Total = 176 scanlines.
;
; Pointers are into a ROTATE profile:
;   FIRST_BIT         -> first 112 WORDs
;   FIRST_BIT + $E0   -> next  64 WORDs
;------------------------------------------------------------------------------

HDMA_TABLE1:
	.BYTE	$2F
	.WORD	<>BLANK
	.BYTE	$F0
	.WORD	<>FIRST_BIT
	.BYTE	$C0
	.WORD	<>(FIRST_BIT+$00E0)
	.BYTE	0

HDMA_TABLE2:
	.BYTE	$2F
	.WORD	<>BLANK
	.BYTE	$F0
	.WORD	<>FIRST_BIT
	.BYTE	$C0
	.WORD	<>(FIRST_BIT+$00E0)
	.BYTE	0

BLANK:
	.WORD	0

; ------------------------------------------------------------
; Rotation selector table
; Selects:
;   - base pointer inside ROTATE profile table
;   - source banks for HDMA channels
; ------------------------------------------------------------
ALL_TABLE:
	.FOR T1 = 0, T1 < 48, T1 += 1
		.WORD ((48 - T1) * $160) + $8000
		.BYTE `FIRST_BIT
		.BYTE `FIRST_BIT
		.BYTE $7E
		.BYTE `FIRST_BIT
		.WORD (T1 * $160) + $8000
	.NEXT

	.FOR T2 = 0, T2 < 48, T2 += 1
		.WORD (T2 * $160) + $8000
		.BYTE $7E
		.BYTE `FIRST_BIT
		.BYTE $7E
		.BYTE $7E
		.WORD ((48 - T2) * $160) + $8000
	.NEXT

	.FOR T3 = 0, T3 < 48, T3 += 1
		.WORD ((48 - T3) * $160) + $8000
		.BYTE $7E
		.BYTE $7E
		.BYTE `FIRST_BIT
		.BYTE $7E
		.WORD (T3 * $160) + $8000
	.NEXT

	.FOR T4 = 0, T4 < 48, T4 += 1
		.WORD (T4 * $160) + $8000
		.BYTE `FIRST_BIT
		.BYTE $7E
		.BYTE `FIRST_BIT
		.BYTE `FIRST_BIT
		.WORD ((48 - T4) * $160) + $8000
	.NEXT

justRTI:
	RTI