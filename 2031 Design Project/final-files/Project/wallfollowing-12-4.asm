;;	Wall following program
;;	By Christopher Hood, Matthew McGraw, Stuart Kent, and Anya S.
	
;; 	Demo speed: 11000
	
	ORG	&H000		; Start at 0
Start:	LOAD	RDY_ST		; RDY! code for LCD decoder
	OUT	LCD		; Make LCD display RDY!
	LOAD	NTY		; Load the turning constant
	DIV	SEVEN		; Divide by 7
	STORE	HA		; Store in constant used for GLED bar graph
	IN	XIO		; In keys
        AND     Key3Mask  	; Is the user pressing key 3?
        JPOS   	Start      	; If not, wait. If yes, go on
	IN	SWITCHES	; Get speeds and right follow or left
	AND	Spdmask		; Only 7 bits
	STORE	SSPD		; Store for future reference
	SHIFT	&B10011		; Divide by a lot
	STORE 	k1		; Store in adjustment contents
	STORE	k2		; "
	IN	SWITCHES	; In all the switch positions
	AND	Sw15Mask	; Change for automatic wall switching on
				; startup using sonar sensor
	JPOS	lSTRT		; If SW10 is up, follow left wall
	JUMP	rSTRT		; If SW10 is down, follow right wall

	;; Right wall following subprogram		
rSTRT:	LOAD	EnSonar2 	; Enable sonars
	OR      EnSonar3	; "
	OR	EnSonar4	; "
	OR	EnSonar5	; "
	OUT	SONAREN		; Enable them!
		
rSafe:	LOAD	KEY2_ST		; Load code for "KEY2"
	OUT	LCD		; Output so LCD displays string "KEY2"
	IN	DIST2		; Start and display dists
	CALL	NORMD		; Normalizes so not FFFF
	OUT	SEVENSEG	; Out on seven segment 1
	CALL	rMinR1		; Get minimum of s4 and s4
	OUT	SEVENSEG2	; Out on seben seg 2
	IN	XIO		; Get some switches
	AND	Key2Mask	; Get key2
	JPOS	rSafe		; If key2 pressed, continue

	LOAD	RGHT_ST		; Load code for "RGHT"
	OUT	LCD		; Output so LCD displays "RGHT"
rFORW:	LOAD	SSPD		; Load the forward speed
	OUT	RVELCMD		; output to wheels
	OUT	LVELCMD		; "
	STORE	LW		; Store in left vel and right vel
	STORE	RW		; "
	CALL	DSPSPD		; Display  the speeds on LCDs and red LEDs
	CALL	rMinR2		; get mine of s2 anf s3
	SUB	IT_THR		; Subtract threshold
	JNEG	rIT		; Jump to inside turn state if dist is less than threshpld
	CALL	rMinR1		; take min of s4 and s5		
	SUB	t18		; if min(s4,s5) is less than 19cm
	JNEG	rAdjO		; adjust out
	IN	DIST5		; Just get DIST5 this time
	CALL	NORMD		; Normalize so not FFFF
	SUB	t22		;
	JPOS	rAdjI		; if DIST5 is greater than 21cm adjust in
	JUMP	rForw		; if didn't change states go back to forward state

	
	;; Inside turn state
rIT:	CALL	INITP		; Get initia;l positions of wheels stored in RP_0 and LP_0

rITlp:	LOAD	IT_OS		; inside turn outside wheel speed
	OUT	LVELCMD		; Wheel speeds out (left is outside for right wall)
	STORE	LW		; store!
	LOAD	IT_IS		; Inside turn inside wheel speed
	OUT	RVELCMD		; out!
	STORE	RW		; store!
	CALL	DSPSPD		; Display wheel speeds of LCD and red LEDs
	IN	LPOSLOW		; Get the new positions of left wheel
	SHIFT	&B11000		; and shift (recall if fifth bit is 0 then left shift, v-v)
	STORE	LP		; store in LP
	IN	LPOSHIGH	; Get high 16 bits of pos
	SHIFT	&B01000		; Shift 8 bits, other firection
	OR	LP		; Combine with lower 16 bits shifted
	STORE	LP		; to get the middle 16 bits of position. Store.
	IN	RPOSLOW		; Right wheel
	SHIFT	&B11000		; same
	STORE	RP		; same
	IN	RPOSHIGH	; same
	SHIFT	&B01000		; same
	OR	RP		; same
	SUB	RP_0		; See if have travelled enough to
	ADD	LP		; stop turning. Recall that RP is
	SUB	LP_0		; actually neg. if right wheel has
	ADD	NTY		; moved forward.
	;; do some LED stuff
	STORE	LP 		; not lp, just using register temporarily
	DIV	HA		; divide by that constant that's based on NTY 
	STORE	SHIFT_LDB	; store in amount to shift by later
	LOAD	LED_BG		; load the base pattern for leds (all on)
	SHIFT2	SHIFT_LDB	; shift right by set amount
	OUT	GLED		; output to gleds
	LOAD	LP		; load that difference again
	JPOS	rITlp		; if it's still pos, jump back to turn some more
	LOAD	ZERO		; if not, 
	OUT	GLED		; set all the gleds to zero
	JUMP	rFORW		; and go back to forward
	
	;; Adjust out state 
rAdjO:	LOAD	SSPD		; Forward wheel speed
	SHIFT	&B01000		; Left shift by 8 (multiply by 256)
	STORE	IW		; Inside wheel angular velocity
	STORE	OW		; Outside
		
rAOlp:	CALL	rMinR1		; Get min of lateral sensors
	CALL	CAP		; CAP EM (at 32 cm)
	SUB	t20		; subtract 20cm
	MULT	k1		; multiply by const
	MLO			; and get the product
	ADD	OW		; add the previous speed
	STORE	OW		; store!
	SHIFT	&B11000		; Right shift by 8 (divide by 256) to return back to motor range
	OUT	LVELCMD		; set actual speed
	STORE	LW		; store for displaying
	CALL	rMinR1		; same for left
	CALL	CAP		; same
	SUB	t20		; same
	MULT	k2		; same
	MLO			; same
	CALL	INVERT		; since this is getting subtracted, multiply by -1
	ADD	IW		; same
	STORE	IW		; same
	SHIFT	&B11000		; Right shift by 8 (divide by 256) to get back in motor range
	OUT	RVELCMD		; set actual speed
	STORE	RW		; store for displaying
	CALL	DSPSPD		; display speeds on sevensegs and red LEDs
	CALL	WAITR		; wait loop! don't go too fast!
	IN	DIST5		; Check if return to forward state
	CALL	NORMD		; no FFFF
	SUB	t18		; if less than 18cm from wall still
	JNEG	rAOlp		; keep going
	JUMP	rForw		; else go back to forward
	
	;; Adjust in state
rAdjI:	LOAD	SSPD		;this is like the same thing so I'm not going to comment it
	SHIFT	&B01000		; Left shift by 8 (multiply by 256)
	STORE	IW		; Inside wheel angular velocity
	STORE	OW		; Outside
	
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
	SHIFT	&B11000		; Right shift by 8 (divide by 256)
	OUT	RVELCMD
	STORE	RW
	CALL	DSPSPD
	CALL	WAITR
	CALL	rMinR1
	SUB	t22
	JPOS	rAIlp
	JUMP	rForw
	
;;; SAME AS RIGHTR EXCEPT WITH LVEL and RVEL and SENSORS MIRRORED! not going to comment it
	;; Left wall following subprogram		
lSTRT:	LOAD	EnSonar0 	; Enable sonars
	OR	EnSonar1
	OR	EnSonar2
	OR	EnSonar3
	OUT	SONAREN
	
lSafe:	LOAD	KEY2_ST
	OUT	LCD
	IN	DIST3		; Start and display dists
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
INITP:	IN	LPOSLOW			; Get the initial positions
	SHIFT	&B11000			; and shift them to desired range
	STORE	LP_0			; store for later
	IN	LPOSHIGH		; get higher 16 bits
	SHIFT	&B01000			; shift other way
	OR	LP_0			; combine with lower 8 bits
	STORE	LP_0			; store it!
	IN	RPOSLOW			; Right wheel
	SHIFT	&B11000			; shift em
	STORE	RP_0			; store em
	IN	RPOSHIGH		; high bits
	SHIFT	&B01000			; shifting
	OR	RP_0			; combine
	STORE	RP_0			; store!
	RETURN				; back from when you came, foul beast

	;; Inverting subroutine
INVERT:	STORE	INVR		; this was before I had multiply
	LOAD	ZERO		; sorry
	SUB	INVR		; there's no reason for this anymore
	RETURN			; oh, well

	;; Waiting subroutines
WAITR:	OUT	TIMER		; reset timer
WRLOOP:	;IN	DIST2		; check for IT
	CALL	rMinR2		; get min of s2 and s3
	SUB	IT_THR		; see if inside turn
	JNEG	rIT		; jump it!
	IN      TIMER		; see if time elapsed
        SUB     TIME		; ...
        JNEG    WRLOOP		; go back if not
        RETURN			; else return

WAITL:	OUT	TIMER	;same
WLLOOP:	;IN	DIST3			; check for IT
	CALL	lMinR2
	SUB	IT_THR
	JNEG	lIT
	IN      TIMER
        SUB     TIME
        JNEG    WLLOOP
        RETURN

	;; maps FFFF to 7FFF
NORMD:	SUB	FFFF		; see if FFFF
	JZERO	nm1		; if it is, jump forward
	ADD	FFFF		; if not, get the original value back
	RETURN			; and return
nm1:	LOAD	H7FFF		; if it was FFFF, load 7FFF
	RETURN			; and return 7FFF

	;; caps AC at DMAX
CAP:	SUB	DMAX		; see if greater than DMAX
	JPOS	CAP1		; if it is, jump forward
	ADD	DMAX		; if not, get the og value back
	RETURN			; and return
CAP1:	LOAD	DMAX		; if it was > DMAX
	RETURN			; return DMAX

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
	SHIFT	&B10001		; div by 2 (take average)
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
SEVEN:		DW	&H0007
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
NTY:		DW	&H009A 			; 91
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
RW:		DW	&H0000
	
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
