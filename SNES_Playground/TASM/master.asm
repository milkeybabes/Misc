; ============================================================
; PAN - master.asm
; Linear LoROM layout
; ============================================================

	.cpu "65816"

; handy manifest constants for use with 65816

Cflag	=	$01
Zflag	=	$02
Iflag	=	$04
Dflag	=	$08
Xflag	=	$10
Mflag	=	$20
Vflag	=	$40
Nflag	=	$80

; use to increase readability
bytesperword	=	2
bitsperbyte	=	8

; Booleans for easier-to-read conditional assembly
TRUE	=	-1
FALSE	=	0


	.include "SNES_IO.ASM"
	
; --------------------------------------------------------------------
; Assembler Level asset selection this used for demo purposes
; --------------------------------------------------------------------

; 64tass.exe -a tasm\master.asm -DLEVEL_ID=1 -o racetrack.sfc -b -X --no-caret-diag --dump-labels -l racetrack.tass -L racetrack.list --verbose-list --line-numbers

; ------------------------------------------------------------
; Default level (can be overridden externally)
; ------------------------------------------------------------

.weak
LEVEL_ID	=	0
.endweak

.IF LEVEL_ID == 0
	LEVEL_MAP	=	"MAPS/MARIO1.SCR"
	LEVEL_PAL	=	"PALETTES/MARIO1.PAL"
.ELSIF LEVEL_ID == 1
	LEVEL_MAP	=	"MAPS/BOWSER3.SCR"
	LEVEL_PAL	=	"PALETTES/BOWSER3.PAL"
.ELSIF LEVEL_ID == 2
	LEVEL_MAP	=	"MAPS/DONUT3.SCR"
	LEVEL_PAL	=	"PALETTES/DONUT3.PAL"
.ELSIF LEVEL_ID == 3
	LEVEL_MAP	=	"MAPS/BEACH2.SCR"
	LEVEL_PAL	=	"PALETTES/BEACH2.PAL"
.ELSIF LEVEL_ID == 4
	LEVEL_MAP	=	"MAPS/ICE2.SCR"
	LEVEL_PAL	=	"PALETTES/ICE2.PAL"
.ELSE
	.ERROR "Invalid LEVEL_ID"
.ENDIF

; ------------------------------------------------------------
; Virtual RAM Zero Page definitions 
; ------------------------------------------------------------

	.virtual $0000

TSTATES:	.word ?
ROTATE:	.word ?
JOY_PAD1:	.word ?

FRACTION_X:	.byte ?
WORLD_X:	.word ?
WORLD_X_HI:	.byte ?

FRACTION_Y:	.byte ?
WORLD_Y:	.word ?
WORLD_Y_HI:	.byte ?

SYNC:	.word ?
SPEED:	.word ?
SPEED_DELAY:	.word ?

HDMAT1:	.fill 10
HDMAT2:	.fill 10

	.cerror * > $0100, "Zero Page overflow"

	.endvirtual


	.virtual $7E0000
USER_RAM2:
	.fill 1
	.endvirtual


	.virtual $7E2000
USER_RAM1:
	.fill 1
DMAZero:
	.word $0000
	.endvirtual


INVERT_RAM	= $7E8000

	.virtual $7F0000
	
DECOMPRESS_RAM:
	.fill 1
	.endvirtual

; ------------------------------------------------------------
; ROM bank 80
; file $000000-$007FFF
; cpu  $808000-$80FFFF
; ------------------------------------------------------------

	* = $000000
	.logical $808000
Bank80	.binclude "main.asm"
	.here

; ------------------------------------------------------------
; Header
; file $007FC0
; cpu  $80FFC0
; ------------------------------------------------------------

	* = $007FC0
	.logical $80FFC0

	.text "GAMEXYZ TEST ROM    "
	.byte $30
	.byte $00
	.byte $08
	.byte $00
	.byte $01
	.byte $33
	.byte $00
	.word $0000
	.word $0000

	.here

; ------------------------------------------------------------
; 65816 vectors
; file $007FE4
; cpu  $80FFE4
; ------------------------------------------------------------

	* = $007FE4
	.logical $80FFE4

	.word <>Bank80.justRTI
	.word <>Bank80.justRTI
	.word <>Bank80.justRTI
	.word <>Bank80.NMIentry
	.word $0000
	.word <>Bank80.IRQentry
	
	.here

; ------------------------------------------------------------
; 6502 vectors
; file $007FF4
; cpu  $80FFF4
; ------------------------------------------------------------

	* = $007FF4
	.logical $80FFF4

	.word <>Bank80.justRTI
	.word <>Bank80.justRTI
	.word <>Bank80.justRTI
	.word <>Bank80.justRTI
	.word <>Bank80.RESETentry
	.word <>Bank80.justRTI

	.here

; ------------------------------------------------------------
; Asset banks
; ------------------------------------------------------------

	.include "generated_asset_banks.asm"
