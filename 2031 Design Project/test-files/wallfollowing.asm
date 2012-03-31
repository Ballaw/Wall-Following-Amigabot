;;	Wall following program

		ORG     &H000
Start:	IN      XIO
        AND     Key3Mask  		; Is the user pressing key 3?
        JPOS    Start      		; If not, wait
		IN		SWITCHES		; Get speeds and right follow or left
		AND		Spdmask
		STORE	SSPD
		IN		SWITCHES
		AND		Sw15Mask		; Change for automatic wall switching on startup using sonar sensor
		JPOS	rSTRT
		JUMP	lSTRT

	;; Right wall following subprogram		
rSTRT:	LOAD	EnSonar3
		AND		EnSonar5
		OUT		SONAREN
rFORW:	LOAD	SSPD
		OUT		RVELCMD
		OUT		LVELCMD
		IN		DIST5		; check for OT
		SUB		FFFF
		JZERO	rOT
		ADD		FFFF
		SUB		OT_THR
		JPOS	rOT
		IN		DIST3		; check for IT
		SUB		IT_THR
		JNEG	rIT
		IN 		DIST5		; check for adj. out and in
		SUB		t18
		JNEG	rAdjO
		SUB		t22-18
		JPOS	rAdjI
		JUMP	rForw
		
		
rOT:	NOP
		
		JUMP	rFORW

rIT:	NOP
		
		JUMP	rFORW
		
rAdjO:	LOAD	SSPD
		SHIFT	8
		STORE	IW
		STORE	OW
rAOlp:	IN		DIST5
		SUB		t20
		MULT	k1
		ADD		IW
		STORE	IW
		SHIFT	-8
		OUT		RVELCMD
		IN		DIST5
		SUB		t20
		MULT	k2
		MULT	NEGONE
		ADD		OW
		STORE	OW
		SHIFT	-8
		OUT		LVELCMD
		IN		DIST5
		SUB		t18
		JNEG	rAOlp
		JUMP	rForw

rAdjI:	NOP

		JUMP	rForw

		
	;; left wall following subprogram
lSTRT:	LOAD	EnSonar0
		AND		EnSonar2
		OUT		SONAREN
		JUMP	Start
		
		
		
		
		
		
		
		
		
		
		
ONESEC:     DW  10
ZERO:		DW	&H0000
Key3Mask:   DW  &B00000100
SpdMask:	DW	&b01111111
Sw15Mask:	DW	&h8000
EnSonar0:   DW  &B00000001
EnSonar2:   DW  &B00000100
EnSonar3:   DW  &B00001000
EnSonar5:   DW  &B00100000
LP:			DW	0
RP:			DW	0
LP_0:		DW	0
RP_0:		DW	0
NTY:		DW	&H00B5
NEGONE:		DW	&HFFFF
LT_LS:		DW	&H0000		;Left-turn left-wheel speed
LT_RS:		DW	&H0040		;etc.
RT_LS:		DW	&H0040
RT_RS:		DW	&H0000
SSPD:		DW	&H0040		; Straight speed
IW:			DW	0			; inside and outside adjustable wheel speeds
OW:			DW	0			
t18:		DW	&H00B4
t22:		DW	&H00DC
t22-18:		DW	&H0028
t20:		DW	&H00C8
IT_THR:		DW	&H0142		; 32.2 cm
OT_THR:		DW	&H0320		; 80cm
FFFF:		DW	&HFFFF
k1:			DW	&H0001		; adjustment constants
k2:			DW	&H0001

	
; IO address space map
SWITCHES:    EQU   &H00  ; slide switches
LEDS:        EQU   &H01  ; red LEDs
TIMER:       EQU   &H02  ; timer, usually running at 10 Hz
XIO:         EQU   &H03  ; pushbuttons and some misc. I/0
SEVENSEG:    EQU   &H04  ; seven-segment display (4-digits only)
LCD:         EQU   &H06  ; primitive 4-digit LCD display
LPOSLOW:     EQU   &H80  ; left wheel encoder feedback
LPOSHIGH:    EQU   &H81  ; ...
LVEL:        EQU   &H82  ; ...
LVELCMD:     EQU   &H83  ; left wheel velocity command
RPOSLOW:     EQU   &H88  ; same four values for right wheel
RPOSHIGH:    EQU   &H89  ; ...
RVEL:        EQU   &H8A  ; ...
RVELCMD:     EQU   &H8B  ; ...
SONAR:       EQU   &HA0  ; base address for more than 16 registers....
DIST0:       EQU   &HA8  ; the eight sonar distance readings
DIST1:       EQU   &HA9  ; ...
DIST2:       EQU   &HAA  ; ...
DIST3:       EQU   &HAB  ; ...
DIST4:       EQU   &HAC  ; ...
DIST5:       EQU   &HAD  ; ...
DIST6:       EQU   &HAE  ; ...
DIST7:       EQU   &HAF  ; ...
SONAREN:     EQU   &HB2  ; register to control which sonars are enabled
