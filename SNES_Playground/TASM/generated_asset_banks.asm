; ============================================================
; AUTO-GENERATED ASSET BANK LAYOUT
; ============================================================

; ------------------------------------------------------------
; ROM bank 81
; file $008000-$00FFFF
; cpu  $818000-$81FFFF
; ------------------------------------------------------------

	* = $008000
	.logical $818000

TEST_DATA:
	.BINARY LEVEL_MAP

	.here

; ------------------------------------------------------------
; ROM bank 82
; file $010000-$017FFF
; cpu  $828000-$82FFFF
; ------------------------------------------------------------

	* = $010000
	.logical $828000

;   176 words per profile
;   total = $4360 bytes
;
; Formula:
;  uses value = round((32000 / (2*line + 25)) * sin(step * pi / 96))

FIRST_BIT:
	.BINARY "TABLES/ROTATE.TAB"
FIRST_BIT_END:

ROTATE_TAB_SIZE = FIRST_BIT_END - FIRST_BIT

PALETTE:
	.BINARY LEVEL_PAL

	.here
   