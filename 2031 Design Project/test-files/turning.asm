
	;; Turning subroutine(s)	
LTURN:	CALL	INITP		;Get initial positions
XLTURN:	LOAD	LT_LS		;Set the wheel speeds
	OUT	LVELCMD
	LOAD	LT_RS
	OUT	RVELCMD
	IN	LPOSLOW		;Get the new positions
	SHIFT	&B11000		;and shift (recall if fifth
	STORE	LP		;bit is 0 then left shift, v-v)
	IN	LPOSHIGH
	SHIFT	&B01000
	AND	LP
	STORE	LP		
	IN	RPOSLOW		;Right wheel
	SHIFT	&B11000
	STORE	RP
	IN	RPOSHIGH
	SHIFT	&B01000
	AND	RP		
	SUB	RP_0		;See if have travelled enough to
	ADD	LP		;stop turning. Recall that RP is
	SUB	LP_0		;actually neg. if right wheel has
	ADD	NTY		;moved forward.
	JPOS	XLTURN
	LOAD	SSPD		;Continue with forward speed
	OUT	RVELCMD
	OUT	RVELCMD
	RETURN
	

RTURN:	CALL	INITP
XRTURN:	NOP
	RETURN

	;; Initial positions subroutine
INITP:	IN	LPOSLOW		;Get the initial positions
	SHIFT	&B11000		;and shift them to desired range
	STORE	LP_0
	IN	LPOSHIGH
	SHIFT	&B01000
	AND	LP_0
	STORE	LP_0
	IN	RPOSLOW		;Right wheel
	SHIFT	&B11000
	STORE	RP_0
	IN	RPOSHIGH
	SHIFT	&B01000
	AND	RP_0
	STORE	RP_0
	RETURN

ZERO:	DW	&H0000
LP:	DW	0
RP:	DW	0
LP_0:	DW	0
RP_0:	DW	0
NTY:	DW	&H00D5
NEGONE:	DW	&HFFFF
LT_LS:	DW	&H0000		;Left-turn left-wheel speed
LT_RS:	DW	&H0040		;etc.
RT_LS:	DW	&H0040
RT_RS:	DW	&H0000
SSPD:	DW	&H0000		;Straight speed
	
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
