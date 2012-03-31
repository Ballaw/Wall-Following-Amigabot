; Test program for testing limits of optical wheel encoder. Also includes sample wall-switching.

        ORG     &H000   ;Begin program at x000
Start:  NOP
	LOAD 	SWITCHES
	AND	EnSonar0
	JZERO	Rstart		; Follows right wall if switch 0 is down, follows left if up.
Lstart:	NOP
Rstart:	LOAD    One
        OUT     LCD      ; an indicator that the program has started
        CALL    Wait1
        LOAD    Two      ; just a progress indicator for user to see
        OUT     SEVENSEG
        CALL    Wait1
        IN      SWITCHES ; prove that the switches and LEDs work..
        OUT     LEDS
        CALL    Wait1
Loop:   IN      LPOSLOW
	OUT	SEVENSEG
	IN	RPOSLOW
	OUT	LCD
	JUMP	Loop


Wait1:  OUT     TIMER      ; One second pause subroutine
Wloop:  IN      TIMER
        SUB     ONESEC
        JNEG    Wloop
        RETURN

ONESEC:      DW    10
Zero:        DW    0
One:         DW    1
Two:         DW    2
Three:       DW    3
Four:        DW    4
Five:        DW    5
Six:         DW    6
Seven:       DW    7
Eight:       DW    8
Nine:        DW    9
Ten:         DW    10
EnSonar0:    DW    &B00000001
EnSonar1:    DW    &B00000010
EnSonar2:    DW    &B00000100
EnSonar3:    DW    &B00001000
EnSonar4:    DW    &B00010000
EnSonar5:    DW    &B00100000
EnSonar6:    DW    &B01000000
EnSonar7:    DW    &B10000000

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


; Note the direct correlation between these EQU definitions of IO addresses and the chip select
; lines that were created in the IO_DECODER.VHD file (repeated here as comments)
; The extra leading "1" (e.g., 16#100# instead of 16#00#) is used in that VHDL file to compare
;  to IO_CYCLE, making sure that it really is an I/O command
;  SWITCH_EN <= '1'    when IO_INT = 16#100# else '0';
;  LED_EN <= '1'       when IO_INT = 16#101# else '0';
;  TIMER_EN <= '1'     when IO_INT = 16#102# else '0';
;  DIG_IN_EN <= '1'    when IO_INT = 16#103# else '0';
;  HEX_EN <= '1'       when IO_INT = 16#104# else '0';
;  LCD_EN <= '1'       when IO_INT = 16#106# else '0';
;  L_POSLOW_EN <= '1'  when IO_INT = 16#180# else '0';
;  L_POSHIGH_EN <= '1' when IO_INT = 16#181# else '0';
;  L_VEL_EN <= '1'     when IO_INT = 16#182# else '0';
;  L_VELCTRL_EN <= '1' when IO_INT = 16#183# else '0';
;  R_POSLOW_EN <= '1'  when IO_INT = 16#188# else '0';
;  R_POSHIGH_EN <= '1' when IO_INT = 16#189# else '0';
;  R_VEL_EN <= '1'     when IO_INT = 16#18A# else '0';
;  R_VELCTRL_EN <= '1' when IO_INT = 16#18B# else '0';
;  SONAR_EN <= '1'     when ((IO_INT >= 16#1A0#) AND (IO_INT < 16#1B7#) ) else '0';
