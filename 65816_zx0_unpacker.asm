; ============================================================
; ZX0_DECOMPRESS_V2 by Michael J Archer 30th March 2026
; ============================================================
;
; 65816 depacker for ZX0 v2 streams.
;
; This version is written for clarity and practical performance:
;   - match copies use MVN
;   - literal runs use MVN through a per-bank jump table
;   - bit fetch is inlined through a macro
;
; Entry:
;   X = source offset 16bit
;   A = source bank 16bit or could be 8 make sure you enter as LongAI
;
; Output:
;   Decompressed data is written to UNPACK_BUFFER
;
; Requirements:
;   - Source stream must remain within its current source bank
;   - UNPACK_BUFFER must reside in a single WRAM bank
;   - The virtual direct-page variables below must exist
;
; Format notes:
;   - Repeated matches use the previous OFFSET value
;   - New offsets are stored as negative 16-bit offsets
;   - The low byte of a new offset also contains the first
;     bit of the match length
;
; Source was written with 64TASS. Can easily be amended to suit others
; ============================================================


; ------------------------------------------------------------
; Handy manifest constants for use with 65816
; ------------------------------------------------------------

Cflag	=	$01
Zflag	=	$02
Iflag	=	$04
Dflag	=	$08
Xflag	=	$10
Mflag	=	$20
Vflag	=	$40
Nflag	=	$80


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


; ------------------------------------------------------------
; Virtual RAM zero-page workspace
; ------------------------------------------------------------
;
; LZ_SRC / LZ_SRC_BANK form the long source pointer used by
; [LZ_SRC].  The extra byte after LZ_SRC_BANK is padding so the
; bank value can safely live next to the word pointer layout.
;
; LITERAL_VEC is a jump vector to a bank-specific MVN literal
; copy stub, selected once at entry.
; ------------------------------------------------------------

	.virtual $0000

LZ_SRC:	.word ?	; source pointer low/high
LZ_SRC_BANK:	.byte ?	; source bank byte (must follow LZ_SRC)
	.byte ?	; padding byte for simple 16-bit increment usage

LITERAL_VEC	.word ?	; 16bit jump vector for literal MVN copy helper

OFFSET	.word ?	; current negative match offset
LENGTH	.word ?	; current literal/match length
BITBUF	.byte ?	; current bit queue
OFFHI	.byte ?	; temporary high-byte decode for new offset


WRAM_BANK	=	`UNPACK_BUFFER	; bank containing decompression buffer


; ------------------------------------------------------------
; GET_BIT_INLINE
; ------------------------------------------------------------
;
; Fetch one bit from the compressed stream.
;
; Carry on exit:
;   C = decoded bit
;
; BITBUF acts as a shift register.  When empty, a new source
; byte is read, rotated once, and stored back into BITBUF so
; subsequent ASL operations feed bits into carry.
; ------------------------------------------------------------

GET_BIT_INLINE	.MACRO
	ASL	BITBUF
	BNE	done

	LDA	[LZ_SRC]		; refill bit queue from source stream
	ROL	A
	STA	BITBUF

	LongA
	INC	LZ_SRC		; advance source pointer within bank
	ShortA

done
	.ENDM


; ============================================================
; Entry point
; ============================================================

ZX0_DECOMPRESS_V2:

	STX	LZ_SRC		; initial source offset
	STA	LZ_SRC_BANK		; initial source bank

	; --------------------------------------------------------
	; Select the literal-copy MVN stub once.
	;
	; Banks $80-$89 are supported by the table below.
	; The bank number is doubled to form a word index.
	; The table base is intentionally biased so no explicit
	; --------------------------------------------------------

	ASL	A
	TAY
	LDA	LITERAL_TABLE-$100,Y	; banks start $80 * 2 = $100 hence the -
	STA	LITERAL_VEC

	; --------------------------------------------------------
	; From this point onward:
	;   A = 8-bit by default
	;   X/Y = 16-bit
	; --------------------------------------------------------

	ShortA_LongI

	; --------------------------------------------------------
	; Set destination data bank to UNPACK_BUFFER bank.
	; All output and match copies operate inside this bank.
	; --------------------------------------------------------

	LDA	#`UNPACK_BUFFER
	PHA
	PLB
	.databank	`UNPACK_BUFFER

	LDY	#<>UNPACK_BUFFER	; Y is the live output pointer

	LDA	#$80
	STA	BITBUF		; initialise empty bit queue sentinel

	LDX	#-1		; default repeated offset = -1
	STX	OFFSET


; ------------------------------------------------------------
; ZX0_LITERALS
; ------------------------------------------------------------
;
; Decode a literal run length, then copy that many bytes from
; the compressed source stream into UNPACK_BUFFER.
;
; Literals use MVN through a preselected bank-specific stub.
; ------------------------------------------------------------

ZX0_LITERALS:
	JSR	ZX0_GET_ELIAS		; LENGTH = literal count

	LongA
	LDA	LENGTH
	BEQ	ZX0_AFTER_LITERALS
	DEC	A		; MVN uses count-1

	LDX	LZ_SRC
	JSR	LITERAL_COPY_HELPER
	STX	LZ_SRC		; save updated source pointer
	ShortA


; ------------------------------------------------------------
; After literals:
;   0 = repeated match using previous OFFSET
;   1 = new offset follows
; ------------------------------------------------------------

ZX0_AFTER_LITERALS:
	GET_BIT_INLINE
	BCS	ZX0_NEW_OFFSET
	BRA	ZX0_REP_MATCH


; ------------------------------------------------------------
; ZX0_REP_MATCH
; ------------------------------------------------------------
;
; Decode a match length using the current repeated OFFSET, then
; fall through to the common match-copy routine.
; ------------------------------------------------------------

ZX0_REP_MATCH:
	JSR	ZX0_GET_ELIAS
	BRA	ZX0_DO_COPY


; ------------------------------------------------------------
; ZX0_NEW_OFFSET
; ------------------------------------------------------------
;
; Decode a new negative match offset, then decode the match
; length associated with it.
;
; The new-offset format is:
;   - high byte from interlaced Elias code
;   - low byte from source stream
;   - low byte also carries the first length bit
;
; After decode:
;   OFFSET = negative 16-bit match offset
;   LENGTH = full match length
; ------------------------------------------------------------

ZX0_NEW_OFFSET:

	; --------------------------------------------------------
	; Decode the high byte of the new negative offset.
	; Seed starts at $FE, then the Elias loop extends it.
	; After increment:
	;   00 = end-of-stream marker
	;   otherwise = final negative high byte
	; --------------------------------------------------------

	LDA	#$FE
	STA	OFFHI
	JSR	ZX0_GET_OFFSET_HI

	LDA	OFFHI
	INC	A
	BEQ	ZX0_EOF
	STA	OFFSET+1

	; --------------------------------------------------------
	; Read low byte of offset.
	; Bit 0 of this byte is also the first length bit.
	;
	; LENGTH starts at 1 here.  The final +1 adjustment is
	; applied after the optional extra Elias decode.
	; --------------------------------------------------------

	LDA	[LZ_SRC]
	STA	OFFSET

	LongA
	INC	LZ_SRC
	LDA	#$0001
	STA	LENGTH

	; --------------------------------------------------------
	; Arithmetic right shift of the negative 16-bit OFFSET.
	; Carry receives the first length bit.
	; --------------------------------------------------------

	LDA	OFFSET
	PHA
	LSR	A		; carry = first length bit
	STA	OFFSET
	PLA
	BIT	#$8000
	BEQ	ZX0_NO_SIGN_FILL
	LDA	OFFSET
	ORA	#$8000
	STA	OFFSET

ZX0_NO_SIGN_FILL:

	BCS	ZX0_NEW_OFFSET_LEN_READY	; first length bit already set
	ShortA

	; --------------------------------------------------------
	; Otherwise continue Elias decoding for the remaining
	; length bits.
	; --------------------------------------------------------

	JSR	ZX0_ELIAS_BT

ZX0_NEW_OFFSET_LEN_READY:
	LongA
	INC	LENGTH		; new-offset matches are minimum length 2


; ------------------------------------------------------------
; ZX0_DO_COPY
; ------------------------------------------------------------
;
; Copy LENGTH bytes from the already decompressed output buffer,
; using OFFSET as a negative backreference.
;
; X becomes the source pointer inside UNPACK_BUFFER.
; Y is already the live destination pointer.
; MVN performs the actual block copy.
; ------------------------------------------------------------

ZX0_DO_COPY:
	TYA
	CLC
	ADC	OFFSET
	TAX			; X = source offset inside UNPACK_BUFFER

	LDA	LENGTH
	BEQ	ZX0_AFTER_MATCH
	DEC	A		; MVN uses count-1

	MVN	#WRAM_BANK,#WRAM_BANK

	ShortA


; ------------------------------------------------------------
; After a match:
;   0 = literals follow
;   1 = another new offset follows
; ------------------------------------------------------------

ZX0_AFTER_MATCH:
	GET_BIT_INLINE
	BCS	+
	BRL	ZX0_LITERALS
+	BRA	ZX0_NEW_OFFSET


; ------------------------------------------------------------
; End of compressed stream
; ------------------------------------------------------------

ZX0_EOF:
	RTS


; ============================================================
; ZX0_GET_ELIAS
; ============================================================
;
; Decode an interlaced Elias gamma value into LENGTH.
;
; LENGTH starts at 1.
; A control bit of 1 ends the decode.
; Each control bit of 0 is followed by one data bit, which is
; shifted into LENGTH.
; ============================================================

ZX0_GET_ELIAS:
	LongA
	LDA	#$0001
	STA	LENGTH
	ShortA

ZX0_ELIAS_LOOP:
	GET_BIT_INLINE
	BCS	ZX0_ELIAS_DONE	; control bit 1 = finished

	GET_BIT_INLINE		; data bit
	LongA
	ROL	LENGTH
	ShortA
	BRA	ZX0_ELIAS_LOOP

ZX0_ELIAS_DONE:
	RTS


; ============================================================
; ZX0_ELIAS_BT
; ============================================================
;
; Continue Elias decode after the low offset byte when the
; first embedded length bit was clear.
; ============================================================

ZX0_ELIAS_BT:
	GET_BIT_INLINE		; immediate data bit
	LongA
	ROL	LENGTH
	ShortA
	BRA	ZX0_ELIAS_LOOP


; ============================================================
; ZX0_GET_OFFSET_HI
; ============================================================
;
; Decode the high byte of a new negative offset into OFFHI.
; Seed value is supplied by caller (normally $FE).
; ============================================================

ZX0_GET_OFFSET_HI:
	GET_BIT_INLINE
	BCS	ZX0_OFFSET_HI_DONE

	GET_BIT_INLINE
	LDA	OFFHI
	ROL	A
	STA	OFFHI
	BRA	ZX0_GET_OFFSET_HI

ZX0_OFFSET_HI_DONE:
	RTS


; ------------------------------------------------------------
; LITERAL_COPY_HELPER
; ------------------------------------------------------------
;
; Jump through the preselected literal MVN vector.
; The selected stub copies from a fixed source bank into
; WRAM_BANK, then returns here via RTS.
; ------------------------------------------------------------

LITERAL_COPY_HELPER:
	JMP	(LITERAL_VEC)


; ------------------------------------------------------------
; Literal MVN jump table
;
; One entry per supported source ROM bank. 
; Add / remove banks as you need.
; ------------------------------------------------------------

LITERAL_TABLE:
	.word	<>MVN_BANK80
	.word	<>MVN_BANK81
	.word	<>MVN_BANK82
	.word	<>MVN_BANK83
	.word	<>MVN_BANK84
	.word	<>MVN_BANK85
	.word	<>MVN_BANK86
	.word	<>MVN_BANK87
	.word	<>MVN_BANK88
	.word	<>MVN_BANK89

; ------------------------------------------------------------
; Bank-specific literal copy stubs
; You can remove this if you needs are only inside one bank
; ------------------------------------------------------------

MVN_BANK80:	MVN	#$80,#WRAM_BANK
	RTS
MVN_BANK81:	MVN	#$81,#WRAM_BANK
	RTS
MVN_BANK82:	MVN	#$82,#WRAM_BANK
	RTS
MVN_BANK83:	MVN	#$83,#WRAM_BANK
	RTS
MVN_BANK84:	MVN	#$84,#WRAM_BANK
	RTS
MVN_BANK85:	MVN	#$85,#WRAM_BANK
	RTS
MVN_BANK86:	MVN	#$86,#WRAM_BANK
	RTS
MVN_BANK87:	MVN	#$87,#WRAM_BANK
	RTS
MVN_BANK88:	MVN	#$88,#WRAM_BANK
	RTS
MVN_BANK89:	MVN	#$89,#WRAM_BANK
	RTS
		