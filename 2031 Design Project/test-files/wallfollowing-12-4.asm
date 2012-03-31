;;	Wall following program

;;GOOD SPEED (works) 10011
;;also possibly 11001
;;also possibly 11011
	
	ORG	&H000
Start:	LOAD	RDY_ST
	OUT	LCD
	IN	XIO
        AND     Key3Mask  		; Is the user pressing key 3?
        JPOS   	Start      		; If not, wait
	IN	SWITCHES		; Get speeds and right follow or left
	AND	Spdmask
	STORE	SSPD
	SHIFT	&B10011
	STORE 	k1
	STORE	k2
	IN	SWITCHES
	AND	Sw15Mask		; Change for automatic wall switching on
								; startup using sonar sensor
	JPOS	lSTRT
	JUMP	rSTRT

;;; 
	;; Right wall following subprogram		
rSTRT:	LOAD	EnSonar2 		; Enable sonars
	OR      EnSonar3
	OR	EnSonar4
	OR	EnSonar5
	OUT	SONAREN
		
rSafe:	LOAD	KEY2_ST
	OUT	LCD	
	IN	DIST2			; Start and display dists
	CALL	NORMD
	OUT	SEVENSEG
	CALL	rMinR1
	OUT	SEVENSEG2
	IN	XIO
	AND	Key2Mask
	JPOS	rSafe

	LOAD	RGHT_ST
	OUT	LCD
rFORW:	LOAD	SSPD			; Once key3 is pressed again, begin wall following
	OUT	RVELCMD
	OUT	LVELCMD
	STORE	LW
	STORE	RW
	CALL	DSPSPD
	;IN	DIST2			; check for IT
	;CALL	NORMD
	CALL	rMinR2
	SUB	IT_THR
	JNEG	rIT
	CALL	rMinR1			;take min of s4 and s5		
	SUB	t18				; if DIST5 is less than 18cm adjust out
	JNEG	rAdjO
	IN	DIST5
	CALL	NORMD
	SUB	t22		
	JPOS	rAdjI			; if DIST5 is greater than 22cm adjust in
	JUMP	rForw			; if didn't change states go back to forward state

	
	;; Inside turn state
rIT:	CALL	INITP

rITlp:	LOAD	IT_OS			;Set the wheel speeds
	OUT	LVELCMD
	STORE	LW
	LOAD	IT_IS
	OUT	RVELCMD
	STORE	RW
	CALL	DSPSPD
	IN	LPOSLOW			;Get the new positions
	SHIFT	&B11000			;and shift (recall if fifth
	STORE	LP				;bit is 0 then left shift, v-v)
	IN	LPOSHIGH
	SHIFT	&B01000
	OR	LP
	STORE	LP		
	IN	RPOSLOW			;Right wheel
	SHIFT	&B11000
	STORE	RP
	IN	RPOSHIGH
	SHIFT	&B01000
	OR	RP		
	SUB	RP_0			;See if have travelled enough to
	ADD	LP				;stop turning. Recall that RP is
	SUB	LP_0			;actually neg. if right wheel has
	ADD	NTY				;moved forward.
	;; do some LED stuff
	STORE	LP 		;not lp, just using register temporarily
	DIV	HA
	STORE	SHIFT_LDB
	LOAD	LED_BG
	SHIFT2	SHIFT_LDB
	OUT	GLED
	LOAD	LP
	JPOS	rITlp
	LOAD	ZERO
	OUT	GLED
	JUMP	rFORW
	
	;; Adjust out state 
rAdjO:	LOAD	SSPD
	SHIFT	&B01000			; Left shift by 8 (multiply by 256)
	STORE	IW				; Inside wheel angular velocity
	STORE	OW				; Outside
		
rAOlp:	CALL	rMinR1
	CALL	CAP
	SUB	t20
	MULT	k1
	MLO
	ADD	OW
	STORE	OW
	SHIFT	&B11000		; Right shift by 8 (divide by 256), return back to motor range
	OUT	LVELCMD
	STORE	LW
	CALL	rMinR1
	CALL	CAP
	SUB	t20
	MULT	k2
	MLO
	CALL	INVERT
	ADD	IW
	STORE	IW
	SHIFT	&B11000			; Right shift by 8 (divide by 256)
	OUT	RVELCMD
	STORE	RW
	CALL	DSPSPD
	CALL	WAITR
	IN	DIST5			;Check if return to forward state
	CALL	NORMD
	SUB	t18
	JNEG	rAOlp
	JUMP	rForw
	
	;; Adjust in state
rAdjI:	LOAD	SSPD
	SHIFT	&B01000			; Left shift by 8 (multiply by 256)
	STORE	IW				; Inside wheel angular velocity
	STORE	OW				; Outside
	
rAIlp:	CALL	rMinR1
	CALL	CAP
	SUB	t20
	MULT	k1
	MLO
	ADD	OW
	STORE	OW
	SHIFT	&B11000		; Right shift by 8 (divide by 256), return back to motor range
	OUT	LVELCMD
	STORE	LW
	CALL	rMinR1
	CALL	CAP
	SUB	t20
	MULT	k2
	MLO
	CALL	INVERT
	ADD	IW
	STORE	IW
	SHIFT	&B11000			; Right shift by 8 (divide by 256)
	OUT	RVELCMD
	STORE	RW
	CALL	DSPSPD
	CALL	WAITR
	CALL	rMinR1
	SUB	t22
	JPOS	rAIlp
	JUMP	rForw
	
;;; 
	;; Left wall following subprogram		
lSTRT:	LOAD	EnSonar0 		; Enable sonars
	OR	EnSonar1
	OR	EnSonar2
	OR	EnSonar3
	OUT	SONAREN
	
lSafe:	LOAD	KEY2_ST
	OUT	LCD
	IN	DIST3			; Start and display dists
	CALL	NORMD
	OUT	SEVENSEG
	CALL	lMinR1
	OUT	SEVENSEG2
	IN	XIO
	AND	Key2Mask
	JPOS	lSafe

	LOAD	LEFT_ST
	OUT	LCD
lFORW:	LOAD	SSPD			; Once key3 is pressed again, begin wall following
	OUT	RVELCMD
	OUT	LVELCMD
	STORE	LW
	STORE	RW
	CALL	DSPSPD
	;IN	DIST3			; check for IT
	CALL	lMinR2
	;CALL	NORMD
	SUB	IT_THR
	JNEG	lIT
	CALL	lMinR1			;take min of s0 and s1		
	SUB	t18				; if DIST5 is less than 18cm adjust out
	JNEG	lAdjO
	IN	DIST0
	CALL	NORMD
	SUB	t22		
	JPOS	lAdjI			; if DIST5 is greater than 22cm adjust in
	JUMP	lForw			; if didn't change states go back to forward state
	
	;; Inside turn state
lIT:	CALL	INITP

lITlp:	LOAD	IT_OS			;Set the wheel speeds
	OUT	RVELCMD
	STORE	RW
	LOAD	IT_IS
	OUT	LVELCMD
	STORE	LW
	CALL	DSPSPD
	IN	LPOSLOW			;Get the new positions
	SHIFT	&B11000			;and shift (recall if fifth
	STORE	LP				;bit is 0 then left shift, v-v)
	IN	LPOSHIGH
	SHIFT	&B01000
	OR	LP
	STORE	LP		
	IN	RPOSLOW			;Right wheel
	SHIFT	&B11000
	STORE	RP
	IN	RPOSHIGH
	SHIFT	&B01000
	OR	RP		
	SUB	RP_0			;See if have travelled enough to
	ADD	LP				;stop turning. Recall that RP is
	SUB	LP_0			;actually neg. if right wheel has
	SUB	NTY				;moved forward.
	;; DO SOME LED STUFF
	STORE	LP 		;not lp, just using register temporarily
	CALL	INVERT
	DIV	HA
	STORE	SHIFT_LDB
	LOAD	LED_BG
	SHIFT2	SHIFT_LDB
	OUT	GLED
	LOAD	LP
	JNEG	lITlp
	LOAD	ZERO
	OUT	GLED
	JUMP	lFORW
	
	;; Adjust out state 
lAdjO:	LOAD	SSPD
	SHIFT	&B01000			; Left shift by 8 (multiply by 256)
	STORE	IW				; Inside wheel angular velocity
	STORE	OW				; Outside
	
lAOlp:	CALL	lMinR1
	CALL	CAP
	SUB	t20
	MULT	k1
	MLO
	ADD	OW
	STORE	OW
	SHIFT	&B11000		; Right shift by 8 (divide by 256), return back to motor range
	OUT	RVELCMD
	STORE	RW
	CALL	lMinR1
	CALL	CAP
	SUB	t20
	MULT	k2
	MLO
	CALL	INVERT
	ADD	IW
	STORE	IW
	SHIFT	&B11000			; Right shift by 8 (divide by 256)
	OUT	LVELCMD
	STORE	LW
	CALL	DSPSPD
	CALL	WAITL
	IN	DIST0			;Check if return to forward state
	CALL	NORMD
	SUB	t18
	JNEG	lAOlp
	JUMP	lForw
	
	;; Adjust in state
lAdjI:	LOAD	SSPD
	SHIFT	&B01000			; Left shift by 8 (multiply by 256)
	STORE	IW				; Inside wheel angular velocity
	STORE	OW				; Outside
		
lAIlp:	CALL	lMinR1
	CALL	CAP
	SUB	t20
	MULT	k1
	MLO
	ADD	OW
	STORE	OW
	SHIFT	&B11000		; Right shift by 8 (divide by 256), return back to motor range
	OUT	RVELCMD
	STORE	RW
	CALL	lMinR1
	CALL	CAP
	SUB	t20
	MULT	k2
	MLO
	CALL	INVERT
	ADD	IW
	STORE	IW
	SHIFT	&B11000			; Right shift by 8 (divide by 256)
	OUT	LVELCMD
	STORE	LW
	CALL	DSPSPD
	CALL	WAITL
	CALL	lMinR1
	SUB	t22
	JPOS	lAIlp
	JUMP	lForw
	
		
	
;;;
	;; Initial positions subroutine
INITP:	IN	LPOSLOW			;Get the initial positions
	SHIFT	&B11000			;and shift them to desired range
	STORE	LP_0
	IN	LPOSHIGH
	SHIFT	&B01000
	OR	LP_0
	STORE	LP_0
	IN	RPOSLOW			;Right wheel
	SHIFT	&B11000
	STORE	RP_0
	IN	RPOSHIGH
	SHIFT	&B01000
	OR	RP_0
	STORE	RP_0
	RETURN

	;; Inverting subroutine
INVERT:	STORE	INVR
	LOAD	ZERO
	SUB	INVR
	RETURN

	;; Waiting subroutines
WAITR:	OUT	TIMER
WRLOOP:	IN	DIST2			; check for IT
	CALL	NORMD
	SUB	IT_THR
	JNEG	rIT
	IN      TIMER
        SUB     TIME
        JNEG    WRLOOP
        RETURN

WAITL:	OUT	TIMER
WLLOOP:	IN	DIST3			; check for IT
	CALL	NORMD
	SUB	IT_THR
	JNEG	lIT
	IN      TIMER
        SUB     TIME
        JNEG    WLLOOP
        RETURN

	;; maps FFFF to 7FFF
NORMD:	SUB	FFFF
	JZERO	nm1
	ADD	FFFF
	RETURN
nm1:	LOAD	H7FFF
	RETURN

	;; caps AC at DMAX
CAP:	SUB	DMAX
	JPOS	CAP1
	ADD	DMAX
	RETURN		
CAP1:	LOAD	DMAX
	RETURN

	;; Polls s4 and s5, takes min
rMinR1:	IN	DIST4
	CALL	NORMD
	STORE	MRR
	IN	DIST5
	CALL	NORMD
	SUB	MRR
	JPOS	rS4				; if DIST4 < DIST5 JUMP
	ADD	MRR				; if not, out DIST5
	RETURN		

	;; polls s3 and s2, takes min
rMinR2:	IN	DIST3
	CALL	NORMD
	STORE	MRR
	IN	DIST2
	CALL	NORMD
	SUB	MRR
	JPOS	rS4				; if DIST3 < DIST2 JUMP
	ADD	MRR				; if not, out DIST5
	RETURN				
	
rS4:	LOAD	MRR				; if DIST4 < DIST out DIST4
	RETURN

	;; polls s1 and s0, takes min
lMinR1:	IN	DIST1
	CALL	NORMD
	STORE	MRR
	IN	DIST0
	CALL	NORMD
	SUB	MRR
	JPOS	lS4				; if DIST1 < DIST0 JUMP
	ADD	MRR				; if not, out DIST0
	RETURN	

	;; polls s2 and s3, takes min
lMinR2:	IN	DIST2
	CALL	NORMD
	STORE	MRR
	IN	DIST3
	CALL	NORMD
	SUB	MRR
	JPOS	lS4				; if DIST1 < DIST0 JUMP
	ADD	MRR				; if not, out DIST0
	RETURN					
	
lS4:	LOAD	MRR				; if DIST1 < DIST out DIST1
	RETURN

	;; Display speeds on both sevensegs. Assumes speeds stored in LW and RW
	;; displays a pattern on red leds
DSPSPD: LOAD	LW
	SHIFT	&H08
	OR	RW
	OUT	SEVENSEG
	LOAD	LW
	ADD	RW
	SHIFT	&H02		;div by 2
	OUT	SEVENSEG2
	LOAD	LW
	SUB	RW
	STORE	GLD_DF
	SHIFT	&H1F		;get top bit
	SHIFT	&H04		;move to correct spot for shifter dir
	STORE	GLD_DIR		
	LOAD	GLD_DF		;the difference
	CALL	ABS		;magnitude
	DIV	GLD_K		
	AND	GLD_MSK		;get first four bits
	OR	GLD_DIR		;attach the direction
	STORE	GLD_SHIFT	
	LOAD	GLD_0		;the base pattern for the leds
	SHIFT3	GLD_SHIFT
	OUT	LEDS
	RETURN

	;; absolute value
ABS:	JNEG	ABS1
	RETURN
ABS1:	CALL	INVERT
	RETURN

	
	;; Registers
GLD_SHIFT:	DW	&H0000
GLD_MSK:	DW	&H000F
GLD_K:		DW	&H0004
GLD_DIR:	DW	&H0000
GLD_DF:		DW	&H0000
GLD_0:		DW	&B0000000110000000
RDY_ST:		DW	&H0000
KEY2_ST:	DW	&H0001
RGHT_ST:	DW	&H0002
LEFT_ST:	DW	&H0003
DMAX:		DW	&H0140
TIME:		DW	&H0001
INVR:		DW	&H0000
ONESEC:     	DW	10
ZERO:		DW	&H0000
ONE:		DW	&H0001
TWO:		DW	&H0002
Key3Mask:   	DW  	&B00000100
Key2Mask:  	DW  	&B00000010
SpdMask:	DW	&b01111111
;;Sw15Mask:	DW	&h8000
Sw15Mask:	DW	&h0400
EnSonar0:  	DW  	&B00000001
EnSonar1:	DW	&B00000010
EnSonar2:	DW  	&B00000100
EnSonar3:	DW  	&B00001000
EnSonar4:	DW	&B00010000
EnSonar5:	DW  	&B00100000
LP:		DW	0				;left wheel position
RP:		DW	0				;right wheel position
LP_0:		DW	0
RP_0:		DW	0
NTY:		DW	&H00A2 			; a little less
IT_OS:		DW	&H0000			;Iniside-turn outside-wheel speed
IT_IS:		DW	&H0040			;etc.
OT_OS:		DW	&H0040
OT_IS:		DW	&H0000
SSPD:		DW	&H0040			; Straight speed
IW:		DW	0				; inside and outside adjustable wheel speeds
OW:		DW	0			
t18:		DW	&H00B4
t22:		DW	&H00DC
t20:		DW	&H00C8
IT_THR:		DW	&H0142			; 32.2 cm
OT_THR:		DW	&H03E8			; 100cm
FFFF:		DW	&HFFFF
H7FFF:		DW	&H7FFF
k1:		DW	&H001A			; adjustment constants
k2:		DW	&H001A
MRR:		DW	&H0000
HA:		DW	&H0017
SHIFT_LDB:	DW	&H0000
LED_BG:		DW	&H00FF
LW:		DW	&H0000
RW:		DE	&H0000
	
; IO address space map
SWITCHES:  	EQU 	&H00  		; slide switches
LEDS:      	EQU  	&H01  		; red LEDs
TIMER:     	EQU   	&H02  		; timer, usually running at 10 Hz
XIO:       	EQU   	&H03  		; pushbuttons and some misc. I/0
SEVENSEG:  	EQU   	&H04  		; seven-segment display (4-digits only)
SEVENSEG2:	EQU	&H05
LCD:   		EQU   	&H06  		; primitive 4-digit LCD display
GLED:           EQU   	&H08 
LPOSLOW:   	EQU   	&H80  		; left wheel encoder feedback
LPOSHIGH:  	EQU   	&H81  		; ...
LVEL:      	EQU   	&H82  		; ...
LVELCMD:   	EQU   	&H83  		; left wheel velocity command
RPOSLOW:   	EQU   	&H88  		; same four values for right wheel
RPOSHIGH:  	EQU   	&H89  		; ...
RVEL:      	EQU   	&H8A  		; ...
RVELCMD:    	EQU   	&H8B  		; ...
SONAR:    	EQU   	&HA0  		; base address for more than 16 registers....
DIST0:   	EQU   	&HA8  		; the eight sonar distance readings
DIST1:   	EQU   	&HA9  		; ...
DIST2:   	EQU   	&HAA  		; ...
DIST3:   	EQU   	&HAB  		; ...
DIST4:   	EQU   	&HAC  		; ...
DIST5:     	EQU   	&HAD  		; ...
DIST6:     	EQU   	&HAE  		; ...
DIST7:     	EQU   	&HAF  		; ...
SONAREN:   	EQU   	&HB2  		; register to control which sonars are enabled
