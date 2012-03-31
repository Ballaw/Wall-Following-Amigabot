; Test program for SCOMP to verify motor control is working
; 

        ORG     &H000   ;Begin program at x000
Start:  NOP
        LOAD    One
        OUT     LCD      ; an indicator that the program has started
        CALL    Wait1
Safe:   IN      XIO
        AND     Key3Mask  ; Is the user pressing key 3?
        JPOS    Safe      ; If not, wait
        
        LOAD    EnSonar0
        OR      EnSonar5 ; Enable only sonar 0 & 5, or'ing the two enable bits
        OUT     SONAREN  ; Sonar has one control register, used to enable/disable 
        CALL    Wait1
        LOAD    Two      ; just a progress indicator for user to see
        OUT     SEVENSEG
        CALL    Wait1
        IN      SWITCHES ; prove that the switches and LEDs work..
        OUT     LEDS
        CALL    Wait1        
        
        LOAD    HALFSPEED     ; load 0.5 speed (about 0.3 m/s) value
        STORE   RightVel      ; store it in memory locations we will use to keep
        STORE   LeftVel       ;     the current commanded speeds for each wheel
        CALL    WaitAndWatch  ; this is similar to the Wait1 routine, but it continously
                              ;     sends velocity commands, over and over.  This keeps
                              ;     the watchdog timer from timing out.
        CALL    WAIT1         ; Give it one second to reach 0.5 speed

Safe2:  IN      XIO           ; Don't anything until key pressed again
        AND     Key3Mask      ; Is the user pressing key 3?
        JPOS    Safe2         ; If not, wait

                              ; Now, go to a loop where robot spins in place at a speed
                              ;    selected by the user with SW7-0        
Loop:   IN      SWITCHES
        AND     LOWBYTE
        OUT     RVELCMD
        STORE   RightVel
        LOAD    Zero
        SUB     RightVel
        OUT     LVELCMD
        
        IN      DIST0    ; read distance calculated for sonar 0 (left side)
        OUT     LCD      ; display it
        IN      DIST5    ; read distance calculated for sonar 5 (right side)
        OUT     SEVENSEG ; display it somewhere else
        JUMP    Loop     ; do this forever


Wait1:  OUT     TIMER      ; One second pause subroutine
Wloop:  IN      TIMER
        SUB     ONESEC
        JNEG    Wloop
        RETURN

WaitAndWatch:  NOP
        OUT  TIMER  ; Pause routine that assumes constant motor vels are stored in LeftVel and RightVel
WWloop: LOAD    LeftVel
        OUT     LVELCMD
        LOAD    RightVel
        OUT     RVELCMD
        IN      TIMER
        SUB     ONESEC
        JNEG    WWloop
        RETURN
                

ONESEC:      DW    10
LOWBYTE:     DW    &H00FF
TRUE:        DW    1
FALSE:       DW    -1
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
RNEG:        DW    0
Key3Mask:    DW    &B00000100
Key1Mask:    DW    &B00000001
HALFSPEED:   DW    &H0040
FULLSPEED:   DW    &H007F
LeftVel:     DW    0
RightVel:    DW    0

; IO address space map
SWITCHES:    EQU   &H00
LEDS:        EQU   &H01
TIMER:       EQU   &H02
XIO:         EQU   &H03
SEVENSEG:    EQU   &H04
LCD:         EQU   &H06
LPOSLOW:     EQU   &H80
LPOSHIGH:    EQU   &H81
LVEL:        EQU   &H82
LVELCMD:     EQU   &H83
RPOSLOW:     EQU   &H88
RPOSHIGH:    EQU   &H89
RVEL:        EQU   &H8A
RVELCMD:     EQU   &H8B
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
