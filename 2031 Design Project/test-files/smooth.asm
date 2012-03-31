;;	Smooth wall following program (as backup)

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
	JPOS		rSTRT
	JUMP		lSTRT

;;; 
	;; Right wall following subprogram		
rSTRT:	LOAD		EnSonar3
	AND		EnSonar5
	OUT		SONAREN
rFORW:	LOAD		SSPD
	OUT		RVELCMD
	OUT		LVELCMD




	
	;; Left wall following subprogram
lSTRT:	NOP
	JUMP		Start
		
	;; Registers
ZERO:		DW	&H0000
Key3Mask:   	DW  	&B00000100
SpdMask:	DW	&b01111111
Sw15Mask:	DW	&h8000
EnSonar0:  	DW  	&B00000001
EnSonar1:  	DW  	&B00000010
EnSonar2:	DW  	&B00000100
EnSonar3:  	DW  	&B00001000
EnSonar4:	DW  	&B00010000
EnSonar5:	DW  	&B00100000
SSPD:		DW	&H0040		; Straight speed
IW:		DW	0		; inside and outside adjustable wheel speeds
OW:		DW	0			
t20:		DW	&H00C8
FFFF:		DW	&HFFFF
k1:		DW	&H00F0		; adjustment constants
k2:		DW	&H00F0

	
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
