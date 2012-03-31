;;	Wall following program

	ORG     	&H000
Start:	IN      	XIO
        AND     	Key3Mask  		; Is the user pressing key 3?
        JPOS    	Start      		; If not, wait
	IN		SWITCHES		; Get speeds and right follow or left
	AND		Spdmask
	STORE		SSPD
	IN		SWITCHES
	AND		Sw15Mask		; Change for automatic wall switching on
						; startup using sonar sensor
	JPOS		lSTRT
	JUMP		rSTRT

;;; 
	;; Right wall following subprogram		
rSTRT:	LOAD		EnSonar2 ; Enable sonars
	OR		EnSonar4
	OR		EnSonar5
	OUT		SONAREN
rSafe:	IN		DIST2	; Start and display dists
	CALL		NORMD
	OUT		SEVENSEG
	;IN		DIST5
	;CALL		NORMD
	CALL		rMinR1
	OUT		SEVENSEG2
	IN		XIO
	AND		Key2Mask
	JPOS		rSafe
rFORW:	LOAD		ONE
	OUT		SEVENSEG
	LOAD		SSPD	; Once key3 is pressed again, begin wall following
	OUT		RVELCMD
	OUT		LVELCMD
	;IN		DIST5		; check for OT
	;CALL		NORMD
	;SUB		FFFF		; if the sensor is invalid (FFFF) jump to outside turn
	;JZERO		rOT
	;ADD		FFFF
	;SUB		OT_THR		; also jump to out. turn if DIST5 is greater than OT_THR
	;JPOS		rOT
	IN		DIST2		; check for IT
	CALL		NORMD
	SUB		IT_THR
	JNEG		rIT
	;IN 		DIST5		; check for adj. out and in
	CALL		rMinR1		;take min of s4 and s5		
	;CALL		NORMD
	SUB		t18		; if DIST5 is less than 18cm adjust out
	JNEG		rAdjO
	IN		DIST5
	CALL		NORMD
	SUB		t22		
	JPOS		rAdjI		; if DIST5 is greater than 22cm adjust in
	JUMP		rForw		; if didn't change states go back to forward state


	;; Outside turn state
rOT:	CALL		INITP
rOTfw1:	LOAD		SSPD		; go forward 20cm plus L
	OUT		LVELCMD
	OUT		RVELCMD
	IN		LPOSLOW		;Get the new positions
	SHIFT		&B11000		;and shift (recall if fifth
	STORE		LP		;bit is 0 then left shift, v-v)
	IN		LPOSHIGH
	SHIFT		&B01000
	OR		LP
	SUB		LP_0
	SUB		d20+L
	JNEG		rOTfw1

	CALL		INITP		;turning
rOTtrn:	LOAD		TWO
	OUT		SEVENSEG
	LOAD		OT_OS		;Set the wheel speeds
	OUT		LVELCMD
	LOAD		OT_IS
	OUT		RVELCMD
	IN		LPOSLOW		;Get the new positions
	SHIFT		&B11000		;and shift (recall if fifth
	STORE		LP		;bit is 0 then left shift, v-v)
	IN		LPOSHIGH
	SHIFT		&B01000
	OR		LP
	STORE		LP		
	IN		RPOSLOW		;Right wheel
	SHIFT		&B11000
	STORE		RP
	IN		RPOSHIGH
	SHIFT		&B01000
	OR		RP		
	SUB		RP_0		;See if have travelled enough to
	ADD		LP		;stop turning. Recall that RP is
	SUB		LP_0		;actually neg. if right wheel has
	SUB		NTY		;moved forward.
	JNEG		rOTtrn

	CALL		INITP
rOTfw2:	LOAD		SSPD		; go forward 20cm minus L
	OUT		LVELCMD
	OUT		RVELCMD
	IN		LPOSLOW		;Get the new positions
	SHIFT		&B11000		;and shift (recall if fifth
	STORE		LP		;bit is 0 then left shift, v-v)
	IN		LPOSHIGH
	SHIFT		&B01000
	OR		LP
	SUB		LP_0
	SUB		d20-L
	JNEG		rOTfw2
	JUMP		rFORW
	
	;; Inside turn state
rIT:	CALL		INITP
rITlp:	LOAD		THREE
	OUT		SEVENSEG
	LOAD		IT_OS		;Set the wheel speeds
	OUT		LVELCMD
	LOAD		IT_IS
	OUT		RVELCMD
	IN		LPOSLOW		;Get the new positions
	SHIFT		&B11000		;and shift (recall if fifth
	STORE		LP		;bit is 0 then left shift, v-v)
	IN		LPOSHIGH
	SHIFT		&B01000
	OR		LP
	STORE		LP		
	IN		RPOSLOW		;Right wheel
	SHIFT		&B11000
	STORE		RP
	IN		RPOSHIGH
	SHIFT		&B01000
	OR		RP		
	SUB		RP_0		;See if have travelled enough to
	ADD		LP		;stop turning. Recall that RP is
	SUB		LP_0		;actually neg. if right wheel has
	ADD		NTY		;moved forward.
	OUT		SEVENSEG2
	JPOS		rITlp
	JUMP		rFORW
	
	;; Adjust out state 
rAdjO:	LOAD		SSPD
	SHIFT		&B01000	; Left shift by 8 (multiply by 256)
	STORE		IW	; Inside wheel angular velocity
	STORE		OW	; Outside
rAOlp:	LOAD		FOUR
	OUT		SEVENSEG	
	;IN		DIST5
	;CALL		NORMD
	;CALL		CAP
	CALL		rMinR1
	CALL		CAP
	SUB		t20
	MULT		k1
	MLO
	ADD		OW
	STORE		OW
	SHIFT		&B11000	; Right shift by 8 (divide by 256), return back to motor range
	OUT		LVELCMD
	;IN		DIST5
	;CALL		NORMD
	;CALL		CAP
	CALL		rMinR1
	CALL		CAP
	SUB		t20
	MULT		k2
	MLO
	;; MULT		NEGONE
	CALL		INVERT
	ADD		IW
	STORE		IW
	SHIFT		&B11000	; Right shift by 8 (divide by 256)
	OUT		RVELCMD
	CALL		WAIT
	IN		DIST5	;Check if return to forward state
	CALL		NORMD
	SUB		t18
	JNEG		rAOlp
	JUMP		rForw
	
	;; Adjust in state
rAdjI:	LOAD		SSPD
	SHIFT		&B01000	; Left shift by 8 (multiply by 256)
	STORE		IW	; Inside wheel angular velocity
	STORE		OW	; Outside
rAIlp:	LOAD		FIVE
	OUT		SEVENSEG
	;IN		DIST5
	;CALL		NORMD
	;CALL		CAP
	CALL		rMinR1
	CALL		CAP
	SUB		t20
	MULT		k1
	MLO
	ADD		OW
	STORE		OW
	SHIFT		&B11000	; Right shift by 8 (divide by 256), return back to motor range
	OUT		LVELCMD
	;IN		DIST5
	;CALL		NORMD
	;CALL		CAP
	CALL		rMinR1
	CALL		CAP
	SUB		t20
	MULT		k2
	MLO
	;; MULT		NEGONE
	CALL		INVERT
	ADD		IW
	STORE		IW
	SHIFT		&B11000	; Right shift by 8 (divide by 256)
	OUT		RVELCMD
	CALL		WAIT
	;IN		DIST5	;check if return to forward state
	;CALL		NORMD
	CALL		rMinR1
	SUB		t22
	JPOS		rAIlp
	JUMP		rForw



	
;;; 
	;; left wall following subprogram
lSTRT:	LOAD		EnSonar0 
	OR		EnSonar2
	OUT		SONAREN
lFORW:	NOP
	JUMP		Start
	
		
		



	
;;;
	;; Initial positions subroutine
INITP:	IN	LPOSLOW		;Get the initial positions
	SHIFT	&B11000		;and shift them to desired range
	STORE	LP_0
	IN	LPOSHIGH
	SHIFT	&B01000
	OR	LP_0
	STORE	LP_0
	IN	RPOSLOW		;Right wheel
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
	
WAIT:	OUT	TIMER
WLOOP:	IN		DIST2		; check for IT
	CALL		NORMD
	SUB		IT_THR
	JNEG		rIT
	IN      TIMER
        SUB     TIME
        JNEG    Wloop
        RETURN
		
NORMD:	SUB		FFFF
	JZERO		nm1
	ADD		FFFF
	RETURN
nm1:	LOAD		H7FFF
	RETURN
	
CAP:	SUB		DMAX
	JPOS		CAP1
	ADD		DMAX
	RETURN
CAP1:	LOAD		DMAX
	RETURN
	
rMinR1:	IN		DIST4
	CALL		NORMD
	STORE		MRR
	IN		DIST5
	CALL		NORMD
	SUB		MRR
	JPOS		rS4	; if DIST4 < DIST5 JUMP
	ADD		MRR	; if not, out DIST5
	RETURN			
rS4:	LOAD		MRR	; if DIST4 < DIST out DIST4
	RETURN
		
	;; Registers
DMAX:		DW	&H0100
TIME:		DW	&H0005
INVR:		DW	&H0000
ONESEC:     	DW	10
ZERO:		DW	&H0000
ONE:		DW	&H0001
TWO:		DW	&H0002
THREE:		DW	&H0003
FOUR:		DW	&H0004
FIVE:		DW	&H0005
Key3Mask:   	DW  	&B00000100
Key2Mask:   	DW  	&B00000010
SpdMask:	DW	&b01111111
Sw15Mask:	DW	&h8000
EnSonar0:  	DW  	&B00000001
EnSonar1:	DW	&B00000010
EnSonar2:	DW  	&B00000100
EnSonar3:	DW  	&B00001000
EnSonar4:	DW	&B00010000
EnSonar5:	DW  	&B00100000
LP:		DW	0	;left wheel position
RP:		DW	0	;right wheel position
LP_0:		DW	0
RP_0:		DW	0
;NTY:		DW	&H00B5
NTY:		DW	&H00A2 ; a little less
NEGONE:		DW	&HFFFF
IT_OS:		DW	&H0000		;Iniside-turn outside-wheel speed
IT_IS:		DW	&H0040		;etc.
OT_OS:		DW	&H0040
OT_IS:		DW	&H0000
SSPD:		DW	&H0040		; Straight speed
IW:		DW	0		; inside and outside adjustable wheel speeds
OW:		DW	0			
t18:		DW	&H00B4
t22:		DW	&H00DC
t22-18:		DW	&H0028
t20:		DW	&H00C8
IT_THR:		DW	&H0142		; 32.2 cm
OT_THR:		DW	&H03E8		; 100cm
FFFF:		DW	&HFFFF
H7FFF:		DW	&H7FFF
k1:		DW	&H001A		; adjustment constants
k2:		DW	&H001A
d20+L:		DW	&H0080
d20-L:		DW	&H0041
MRR:		DW	&H0000

	
; IO address space map
SWITCHES:    	EQU 	&H00  ; slide switches
LEDS:        	EQU  	&H01  ; red LEDs
TIMER:       	EQU   	&H02  ; timer, usually running at 10 Hz
XIO:         	EQU   	&H03  ; pushbuttons and some misc. I/0
SEVENSEG:    	EQU   	&H04  ; seven-segment display (4-digits only)
SEVENSEG2:	EQU	&H05
LCD:   		EQU   	&H06  ; primitive 4-digit LCD display
LPOSLOW:     	EQU   	&H80  ; left wheel encoder feedback
LPOSHIGH:    	EQU   	&H81  ; ...
LVEL:        	EQU   	&H82  ; ...
LVELCMD:     	EQU   	&H83  ; left wheel velocity command
RPOSLOW:     	EQU   	&H88  ; same four values for right wheel
RPOSHIGH:    	EQU   	&H89  ; ...
RVEL:        	EQU   	&H8A  ; ...
RVELCMD:     	EQU   	&H8B  ; ...
SONAR:       	EQU   	&HA0  ; base address for more than 16 registers....
DIST0:       	EQU   	&HA8  ; the eight sonar distance readings
DIST1:       	EQU   	&HA9  ; ...
DIST2:       	EQU   	&HAA  ; ...
DIST3:       	EQU   	&HAB  ; ...
DIST4:       	EQU   	&HAC  ; ...
DIST5:       	EQU   	&HAD  ; ...
DIST6:       	EQU   	&HAE  ; ...
DIST7:       	EQU   	&HAF  ; ...
SONAREN:     	EQU   	&HB2  ; register to control which sonars are enabled
