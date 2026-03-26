; ===========================================================================
; SNES_IO.asm
; ===========================================================================
; Super Nintendo / Super Famicom hardware register manifest.
;
; Purpose
; -------
; This file defines the main SNES I/O register addresses and a small set of
; commonly used bit masks. It is intended as a readable reference layer so
; game code can use symbolic names instead of raw hardware addresses.
;
; Scope
; -----
; Includes:
;   - PPU registers ($2100-$213F)
;   - APU communication ports ($2140-$2143)
;   - WRAM access port ($2180-$2183)
;   - CPU / interrupt / joypad / math registers ($4200-$421F)
;   - DMA / HDMA channel register base layout ($4300+)
;   - Joypad button bit masks
;
; Notes
; -----
; - Many PPU writes are only safe during VBlank, HBlank, or forced blank.
; - VRAM, OAM, and CGRAM are normally updated through their data ports,
;   often via DMA during VBlank.
; - DMA channel registers are repeated every $10 bytes from $4300-$437F.
; - Joypad auto-read places controller results into JOY1-4 at $4218-$421F.
; - This file is a manifest, not a full hardware manual. Comments are kept
;   practical and aimed at day-to-day development.
;
; Naming conventions
; ------------------
; - Upper-case names generally follow common SNES documentation.
; - A few legacy lower-case names are preserved where already used by code.
; - DMAx offsets (DMA0..DMA7) are intended to be added onto $4300-based
;   channel registers, e.g. DMA_A1ADDR+DMA2.
; ===========================================================================


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; PPU segment
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; The Picture Processing Unit controls screen brightness, background modes,
; tilemap locations, character data locations, scrolling, windows, colour
; math, Mode 7, and access to VRAM / OAM / CGRAM.
;
; Important:
; - VRAM, OAM, and CGRAM are not plain RAM addresses. They are accessed
;   through data ports and address registers.
; - Bulk updates are normally done with DMA during VBlank.
; - Some read ports are only reliable during HBlank / VBlank / forced blank.
;

	; -------------------------------------------------------------------
	; Display control / object setup
	; -------------------------------------------------------------------
INIDISP	=	$2100	; Forced blank + brightness
OBJSEL	=	$2101	; Object size, object data area

	; -------------------------------------------------------------------
	; OAM access (sprite attribute memory)
	; -------------------------------------------------------------------
OAMADDL	=	$2102	; Address to read/write in OAM (low)
OAMADDH	=	$2103	; Address to read/write in OAM (high)
OAMDATA	=	$2104	; Write OAM data (low then high, VBlank/forced blank safest)

	; -------------------------------------------------------------------
	; Background mode / tilemap / character data selection
	; -------------------------------------------------------------------
BGMODE	=	$2105	; Screen mode, BG3 priority, BG char size
MOSAIC	=	$2106	; Mosaic screen
BG1SC	=	$2107	; BG1 size and VRAM base address
BG2SC	=	$2108	; BG2 size and VRAM base address
BG3SC	=	$2109	; BG3 size and VRAM base address
BG4SC	=	$210A	; BG4 size and VRAM base address
BG12NBA	=	$210B	; BG1&2 bases for character data
BG34NBA	=	$210C	; BG3&4 bases for character data

	; -------------------------------------------------------------------
	; Scroll registers
	; Each scroll position is written as two successive writes.
	; -------------------------------------------------------------------
BG1HOFS	=	$210D	; BG1 horizontal scroll (low then high)
BG1VOFS	=	$210E	; BG1 vertical scroll (low then high)
BG2HOFS	=	$210F	; BG2 horizontal scroll (low then high)
BG2VOFS	=	$2110	; BG2 vertical scroll (low then high)
BG3HOFS	=	$2111	; BG3 horizontal scroll (low then high)
BG3VOFS	=	$2112	; BG3 vertical scroll (low then high)
BG4HOFS	=	$2113	; BG4 horizontal scroll (low then high)
BG4VOFS	=	$2114	; BG4 vertical scroll (low then high)

	; -------------------------------------------------------------------
	; VRAM access
	; VMADD sets the VRAM address.
	; VMDATA writes data to VRAM using the increment mode in VMAINC.
	; -------------------------------------------------------------------
VMAINC	=	$2115	; VRAM address increment mode
VMADDL	=	$2116	; Address to read/write in VRAM (low)
VMADDH	=	$2117	; Address to read/write in VRAM (high)
VMDATAL	=	$2118	; Write VRAM data low (VBlank safest)
VMDATAH	=	$2119	; Write VRAM data high (VBlank safest)

	; -------------------------------------------------------------------
	; Mode 7 / matrix registers
	; M7A..M7D form the matrix, M7X/M7Y are the centre position registers.
	; These also drive the 16x8 multiply result visible at $2134-$2136.
	; -------------------------------------------------------------------
M7SEL	=	$211A	; Mode 7 attribute selection
M7A	=	$211B	; Matrix A / multiply operand (low then high)
M7B	=	$211C	; Matrix B / multiply operand
M7C	=	$211D	; Matrix C
M7D	=	$211E	; Matrix D
M7X	=	$211F	; Mode 7 centre X
M7Y	=	$2120	; Mode 7 centre Y

	; -------------------------------------------------------------------
	; CGRAM access (palette RAM)
	; Colour entries are written as low/high byte pairs.
	; -------------------------------------------------------------------
CGADD	=	$2121	; Address to read/write in CG RAM
CGDATA	=	$2122	; Write CG RAM data (low/high, blanking period safest)

	; -------------------------------------------------------------------
	; Window system
	; -------------------------------------------------------------------
W12SEL	=	$2123	; Window masks for BG1, BG2
W34SEL	=	$2124	; Window masks for BG3, BG4
WOBJSEL	=	$2125	; Window masks for objects, colour window
WH0	=	$2126	; Window 1 left position
WH1	=	$2127	; Window 1 right position
WH2	=	$2128	; Window 2 left position
WH3	=	$2129	; Window 2 right position
WBGLOG	=	$212A	; Mask logic for BG windowing
WOBJLOG	=	$212B	; Mask logic for OBJ / colour window

	; -------------------------------------------------------------------
	; Main/sub screen designation and colour math
	; -------------------------------------------------------------------
TM	=	$212C	; Designate main screen
TS	=	$212D	; Designate sub screen
TMW	=	$212E	; Window mask selection for main screen
TSW	=	$212F	; Window mask selection for sub screen
CGSWSEL	=	$2130	; Main/sub/constant colour/direct colour selection
CGADSUB	=	$2131	; Enable add/sub for BG1-4, OBJ, BACK
COLDATA	=	$2132	; Fixed colour data
SETINI	=	$2133	; Screen setup (overscan, interlace, etc.)

	; -------------------------------------------------------------------
	; PPU readback / status
	; -------------------------------------------------------------------
MPYL	=	$2134	; Multiply result low
MPYM	=	$2135	; Multiply result mid
MPYH	=	$2136	; Multiply result high
SLHV	=	$2137	; Latch horizontal / vertical counters
OAMDATA2	=	$2138	; Read OAM data (low then high, blanking period safest)
VMDATAL2	=	$2139	; Read VRAM data low
VMDATAH2	=	$213A	; Read VRAM data high
CGDATA2	=	$213B	; Read CG RAM data (low/high)
OPHCT	=	$213C	; Latched horizontal counter (low then high)
OPVCT	=	$213D	; Latched vertical counter (low then high)
STAT77	=	$213E	; PPU1 status / version
STAT78	=	$213F	; PPU2 status / version

	; -------------------------------------------------------------------
	; CPU <-> APU communication ports
	; Four software-defined ports shared with the sound CPU.
	; -------------------------------------------------------------------
APUIO0	=	$2140	; APU communication port 0
APUIO1	=	$2141	; APU communication port 1
APUIO2	=	$2142	; APU communication port 2
APUIO3	=	$2143	; APU communication port 3

	; -------------------------------------------------------------------
	; WRAM access port
	; Provides indirect access to work RAM via $2180.
	; -------------------------------------------------------------------
WMDATA	=	$2180	; Data to read/write to WRAM
WMADDL	=	$2181	; WRAM address low
WMADDM	=	$2182	; WRAM address mid
WMADDH	=	$2183	; WRAM address high


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Controller segment
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Manual serial joypad access exists at $4016/$4017, but most code uses
; automatic joypad reading enabled through NMITIMEN. In that mode the latched
; controller results appear in JOY1L/H ... JOY4L/H at $4218-$421F.
;
; $4016 reads serially from controllers 1 and 3
; $4016 writes strobe / clock-related control bits
; $4017 reads serially from controllers 2 and 4
;


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; CPU segment
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; These registers control interrupts, hardware multiply/divide, DMA/HDMA,
; memory timing, joypad auto-read, and status flags.
;

NMITIMEN	=	$4200	; Enable NMI, IRQ, auto-controller read
WRIO	=	$4201	; Write to programmable I/O port
WRMPYA	=	$4202	; 8-bit multiply operand A
WRMPYB	=	$4203	; 8-bit multiply operand B (starts multiply)
WRDIVL	=	$4204	; 16-bit dividend low
WRDIVH	=	$4205	; 16-bit dividend high
WRDIVB	=	$4206	; 8-bit divisor (starts divide)
HTIMEL	=	$4207	; H counter IRQ target low
HTIMEH	=	$4208	; H counter IRQ target high
VTIMEL	=	$4209	; V counter IRQ target low
VTIMEH	=	$420A	; V counter IRQ target high
MDMAEN	=	$420B	; General-purpose DMA start
HDMAEN	=	$420C	; HDMA channel enable
MEMSEL	=	$420D	; Memory speed selection (FastROM control)

RDNMI	=	$4210	; NMI flag and CPU version
TIMEUP	=	$4211	; Timer IRQ status
HVBJOY	=	$4212	; HBlank / VBlank status, joypad auto-read active flag
RDIO	=	$4213	; Read from programmable I/O port
RDDIVL	=	$4214	; 16-bit quotient low
RDDIVH	=	$4215	; 16-bit quotient high
RDMPYL	=	$4216	; Multiply result or divide remainder low
RDMPYH	=	$4217	; Multiply result or divide remainder high

	; -------------------------------------------------------------------
	; Joypad auto-read results
	; Each controller returns a 16-bit button state.
	; -------------------------------------------------------------------
JOY1L	=	$4218	; Controller 1 data low
JOY1H	=	$4219	; Controller 1 data high
JOY2L	=	$421A	; Controller 2 data low
JOY2H	=	$421B	; Controller 2 data high
JOY3L	=	$421C	; Controller 3 data low
JOY3H	=	$421D	; Controller 3 data high
JOY4L	=	$421E	; Controller 4 data low
JOY4H	=	$421F	; Controller 4 data high


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; PPU helper aliases
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

PPU_MATRIXLOW	=	M7Y  	; Low byte of any Mode 7 matrix low/high pair
; Useful for storing low byte only in M=16 code.
; WARNING: a 16-bit store here also writes the following register.


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; DMA / HDMA segment
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; DMA channel registers repeat every $10 bytes:
;   Channel 0 = $4300-$430A
;   Channel 1 = $4310-$431A
;   ...
;   Channel 7 = $4370-$437A
;
; Typical usage:
;   lda #mode
;   sta DMA_SETUP+DMA0
;   lda #target_register
;   sta DMA_BADDR+DMA0
;   lda #<source
;   sta DMA_A1ADDR+DMA0
;   lda #>source
;   sta DMA_A1ADDR_H+DMA0
;   lda #^source
;   sta DMA_A1ADDRB+DMA0
;   lda #<count
;   sta DMA_COUNT+DMA0
;   lda #>count
;   sta DMA_COUNT_H+DMA0
;   lda #%00000001
;   sta MDMAEN
;

DMA_SETUP	=	$4300	; DMA control / transfer mode for each channel
DMA_BADDR	=	$4301	; B-bus target register (low byte, bank fixed by hardware)
DMA_A1ADDR	=	$4302	; A-bus source address low
DMA_A1ADDR_H	=	$4303	; A-bus source address high
DMA_A1ADDRB	=	$4304	; A-bus source bank
DMA_COUNT	=	$4305	; Transfer count low for general DMA
DMA_COUNT_H	=	$4306	; Transfer count high / HDMA indirect bank usage
DMA_HBANK	=	$4307	; HDMA indirect bank
DMA_A2ADDR	=	$4308	; HDMA table / indirect address low
DMA_A2ADDR_H	=	$4309	; HDMA table / indirect address high
DMA_HLINE	=	$430A	; HDMA line count / repeat flag state

	; Channel offset values, added onto $4300-based registers
DMA0	=	$00
DMA1	=	$10
DMA2	=	$20
DMA3	=	$30
DMA4	=	$40
DMA5	=	$50
DMA6	=	$60
DMA7	=	$70


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Generic 16-bit bit masks
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

BIT0	=	%0000000000000001
BIT1	=	%0000000000000010
BIT2	=	%0000000000000100
BIT3	=	%0000000000001000
BIT4	=	%0000000000010000
BIT5	=	%0000000000100000
BIT6	=	%0000000001000000
BIT7	=	%0000000010000000
BIT8	=	%0000000100000000
BIT9	=	%0000001000000000
BITA	=	%0000010000000000
BITB	=	%0000100000000000
BITC	=	%0001000000000000
BITD	=	%0010000000000000
BITE	=	%0100000000000000
BITF	=	%1000000000000000


; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; Joypad bit masks
; +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
; Button mapping for the 16-bit values read from JOY1L/H ... JOY4L/H.
; These are arranged to match the hardware auto-read result format.
;

Joy_R	=	BIT4	; R button
Joy_L	=	BIT5	; L button
Joy_X	=	BIT6	; X button
Joy_A	=	BIT7	; A button
Joy_Right	=	BIT8	; D-pad right
Joy_Left	=	BIT9	; D-pad left
Joy_Down	=	BITA	; D-pad down
Joy_Up	=	BITB	; D-pad up
Joy_Start	=	BITC	; Start button
Joy_Select	=	BITD	; Select button
Joy_Y	=	BITE	; Y button
Joy_B	=	BITF	; B button