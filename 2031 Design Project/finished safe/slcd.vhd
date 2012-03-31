-- SLCD.VHD (a peripheral module for SCOMP)
-- 2009.10.10
--
-- The simple LCD controller displays a single 16 bit register on the top line
--   of the LCD.
-- It sends an initialization string to the LCD, then repeatedly writes a four-
--   digit hex value to a fixed location in the display.  The value is latched
--   whenever the device is selected by CS.
-- See datasheets for the HD44780 or equivalent LCD controller.  

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE LPM.LPM_COMPONENTS.ALL;


ENTITY SLCD IS
  PORT(
    CLOCK_10KHZ : IN  STD_LOGIC;
    RESETN      : IN  STD_LOGIC;
    CS          : IN  STD_LOGIC;
    IO_DATA     : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
    LCD_RS      : OUT STD_LOGIC;
    LCD_RW      : OUT STD_LOGIC;
    LCD_E       : OUT STD_LOGIC;
    LCD_D       : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END SLCD;


ARCHITECTURE a OF SLCD IS
  TYPE STATE_TYPE IS (
    RESET,
    INIT,
    INIT_CLOCK,
    CURPOS,
    CURPOS_CLOCK,
    SWRITE,
    SWRITE_CLOCK
  );

  TYPE MOVE_STATE_TYPE IS (
    --FORWARD,
    --TURN,
    --ADJUST,
    --NUMBERS
    RDY,
    KEY2,
    RGHT,
    LFT
  );

  TYPE CSTR127_TYPE IS ARRAY (0 TO 127) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  TYPE CSTR15_TYPE IS ARRAY (0 TO 15) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  TYPE CSTR08_TYPE IS ARRAY (0 TO  7) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  TYPE CSTR04_TYPE IS ARRAY (0 TO  3) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

  SIGNAL move_state : MOVE_STATE_TYPE;
  SIGNAL lcd_state : STD_LOGIC_VECTOR(3 DOWNTO 0);
  SIGNAL state   : STATE_TYPE;
  SIGNAL full_ascii : CSTR127_TYPE;
  SIGNAL ascii   : CSTR15_TYPE;
  SIGNAL cstr    : CSTR04_TYPE;
  SIGNAL istr    : CSTR08_TYPE;
  SIGNAL count   : INTEGER RANGE 0 TO 1000;
  SIGNAL delay   : INTEGER RANGE 0 TO 100;
  SIGNAL data_in : STD_LOGIC_VECTOR(15 DOWNTO 0);


  BEGIN
    -- LCD initialization string
    istr(0) <= x"38"; -- Wakeup
    istr(1) <= x"38"; -- Wakeup
    istr(2) <= x"38"; -- Wakeup
    istr(3) <= x"38"; -- Function set: 2 lines, 5x8 dot font
    istr(4) <= x"08"; -- Display off
    istr(5) <= x"01"; -- Clear display
    istr(6) <= x"0C"; -- Display on
    istr(7) <= x"04"; -- Entry mode set (left to right)

    ascii( 0) <= x"30"; -- ASCII table values
    ascii( 1) <= x"31";
    ascii( 2) <= x"32";
    ascii( 3) <= x"33";
    ascii( 4) <= x"34";
    ascii( 5) <= x"35";
    ascii( 6) <= x"36";
    ascii( 7) <= x"37";
    ascii( 8) <= x"38";
    ascii( 9) <= x"39";
    ascii(10) <= x"41";
    ascii(11) <= x"42";
    ascii(12) <= x"43";
    ascii(13) <= x"44";
    ascii(14) <= x"45";
    ascii(15) <= x"46";
    
    full_ascii(0) <= x"00";
    full_ascii(1) <= x"01";
    full_ascii(2) <= x"02";
    full_ascii(3) <= x"03";
    full_ascii(4) <= x"04";
    full_ascii(5) <= x"05";
    full_ascii(6) <= x"06";
    full_ascii(7) <= x"07";
    full_ascii(8) <= x"08";
    full_ascii(9) <= x"09";
    full_ascii(10) <= x"0a";
    full_ascii(11) <= x"0b";
    full_ascii(12) <= x"0c";
    full_ascii(13) <= x"0d";
    full_ascii(14) <= x"0e";
    full_ascii(15) <= x"0f";
    full_ascii(16) <= x"10";
    full_ascii(17) <= x"11";
    full_ascii(18) <= x"12";
    full_ascii(19) <= x"13";
    full_ascii(20) <= x"14";
    full_ascii(21) <= x"15";
    full_ascii(22) <= x"16";
    full_ascii(23) <= x"17";
    full_ascii(24) <= x"18";
    full_ascii(25) <= x"19";
    full_ascii(26) <= x"1a";
    full_ascii(27) <= x"1b";
    full_ascii(28) <= x"1c";
    full_ascii(29) <= x"1d";
    full_ascii(30) <= x"1e";
    full_ascii(31) <= x"1f";
    full_ascii(32) <= x"20";
    full_ascii(33) <= x"21";
    full_ascii(34) <= x"22";
    full_ascii(35) <= x"23";
    full_ascii(36) <= x"24";
    full_ascii(37) <= x"25";
    full_ascii(38) <= x"26";
    full_ascii(39) <= x"27";
    full_ascii(40) <= x"28";
    full_ascii(41) <= x"29";
    full_ascii(42) <= x"2a";
    full_ascii(43) <= x"2b";
    full_ascii(44) <= x"2c";
    full_ascii(45) <= x"2d";
    full_ascii(46) <= x"2e";
    full_ascii(47) <= x"2f";
    full_ascii(48) <= x"30";
    full_ascii(49) <= x"31";
    full_ascii(50) <= x"32";
    full_ascii(51) <= x"33";
    full_ascii(52) <= x"34";
    full_ascii(53) <= x"35";
    full_ascii(54) <= x"36";
    full_ascii(55) <= x"37";
    full_ascii(56) <= x"38";
    full_ascii(57) <= x"39";
    full_ascii(58) <= x"3a";
    full_ascii(59) <= x"3b";
    full_ascii(60) <= x"3c";
    full_ascii(61) <= x"3d";
    full_ascii(62) <= x"3e";
    full_ascii(63) <= x"3f";
    full_ascii(64) <= x"40";
    full_ascii(65) <= x"41"; --A
    full_ascii(66) <= x"42"; --B
    full_ascii(67) <= x"43"; --etc.
    full_ascii(68) <= x"44";
    full_ascii(69) <= x"45";
    full_ascii(70) <= x"46";
    full_ascii(71) <= x"47";
    full_ascii(72) <= x"48";
    full_ascii(73) <= x"49";
    full_ascii(74) <= x"4a";
    full_ascii(75) <= x"4b";
    full_ascii(76) <= x"4c";
    full_ascii(77) <= x"4d";
    full_ascii(78) <= x"4e";
    full_ascii(79) <= x"4f";
    full_ascii(80) <= x"50";
    full_ascii(81) <= x"51";
    full_ascii(82) <= x"52";
    full_ascii(83) <= x"53";
    full_ascii(84) <= x"54";
    full_ascii(85) <= x"55";
    full_ascii(86) <= x"56";
    full_ascii(87) <= x"57";
    full_ascii(88) <= x"58";
    full_ascii(89) <= x"59";
    full_ascii(90) <= x"5a";
    full_ascii(91) <= x"5b";
    full_ascii(92) <= x"5c";
    full_ascii(93) <= x"5d";
    full_ascii(94) <= x"5e";
    full_ascii(95) <= x"5f";
    full_ascii(96) <= x"60";
    full_ascii(97) <= x"61"; --a
    full_ascii(98) <= x"62"; --b
    full_ascii(99) <= x"63"; --etc.
    full_ascii(100) <= x"64";
    full_ascii(101) <= x"65";
    full_ascii(102) <= x"66";
    full_ascii(103) <= x"67";
    full_ascii(104) <= x"68";
    full_ascii(105) <= x"69";
    full_ascii(106) <= x"6a";
    full_ascii(107) <= x"6b";
    full_ascii(108) <= x"6c";
    full_ascii(109) <= x"6d";
    full_ascii(110) <= x"6e";
    full_ascii(111) <= x"6f";
    full_ascii(112) <= x"70";
    full_ascii(113) <= x"71";
    full_ascii(114) <= x"72";
    full_ascii(115) <= x"73";
    full_ascii(116) <= x"74";
    full_ascii(117) <= x"75";
    full_ascii(118) <= x"76";
    full_ascii(119) <= x"77";
    full_ascii(120) <= x"78";
    full_ascii(121) <= x"79";
    full_ascii(122) <= x"7a";
    full_ascii(123) <= x"7b";
    full_ascii(124) <= x"7c";
    full_ascii(125) <= x"7d";
    full_ascii(126) <= x"7e";
    full_ascii(127) <= x"7f";
    
    LCD_RW  <= '0';
    lcd_state <= IO_DATA(3 DOWNTO 0);
    
	--encodings for states
    --move_state <= FORWARD WHEN lcd_state="0000" ELSE
    --    			  TURN 	  WHEN lcd_state="0001" ELSE
    --    			  ADJUST  WHEN lcd_state="0010" ELSE
    --    			  NUMBERS WHEN lcd_state="1111" ELSE FORWARD;

    move_state <= RDY  when lcd_state = "0000" else
                  KEY2 when lcd_state = "0001" else
                  RGHT when lcd_state = "0010" else
                  LFT  when lcd_state = "0011" else RDY;
    
    --cstr(0) <= ascii(CONV_INTEGER(data_in( 3 DOWNTO  0)));
    --cstr(1) <= ascii(CONV_INTEGER(data_in( 7 DOWNTO  4)));
    --cstr(2) <= ascii(CONV_INTEGER(data_in(11 DOWNTO  8)));
    --cstr(3) <= ascii(CONV_INTEGER(data_in(15 DOWNTO 12)));




    -- This process latches the incoming data value on the rising edge of CS
    PROCESS (RESETN, CS)
      BEGIN
        IF (RESETN = '0') THEN
          data_in <= x"0000";
        ELSIF (RISING_EDGE(CS)) THEN
          data_in <= IO_DATA;
        END IF;
      END PROCESS;
      
     -- This processes writes the latched data values to the LCD
    PROCESS (RESETN, CLOCK_10KHZ)
      BEGIN
        IF (RESETN = '0') THEN   

        ELSIF (RISING_EDGE(CLOCK_10KHZ)) THEN
		    CASE move_state IS
                          when RDY =>
                            cstr(0) <= full_ascii(33);  -- !
                            cstr(1) <= full_ascii(89);  -- Y      --Spells RDY!
                            cstr(2) <= full_ascii(68);  -- D
                            cstr(3) <= full_ascii(82);  -- R
                          when KEY2 =>
                            cstr(0) <= full_ascii(50);  -- 2      --Spells KEY2
                            cstr(1) <= full_ascii(89);  -- Y
                            cstr(2) <= full_ascii(69);  -- E
                            cstr(3) <= full_ascii(75);  -- K
                          when RGHT =>
                            cstr(0) <= full_ascii(84);  -- T      --Spells RGHT
                            cstr(1) <= full_ascii(72);  -- H
                            cstr(2) <= full_ascii(71);  -- G
                            cstr(3) <= full_ascii(82);  -- R
                          when LFT =>
                            cstr(0) <= full_ascii(84);  -- T      --Spells LEFT
                            cstr(1) <= full_ascii(70);  -- F
                            cstr(2) <= full_ascii(69);  -- E
                            cstr(3) <= full_ascii(76);  -- L

                            
			  --WHEN FORWARD =>
			  --  -- Hard-coded states in ascii
			  --      cstr(0) <= full_ascii(68); --Spells FWRD
			  --      cstr(1) <= full_ascii(82);
			  --      cstr(2) <= full_ascii(87);
			  --      cstr(3) <= full_ascii(70);
			  --WHEN TURN =>
			  --      cstr(0) <= full_ascii(78); --Spells TURN
			  --      cstr(1) <= full_ascii(82);
			  --      cstr(2) <= full_ascii(85);
			  --      cstr(3) <= full_ascii(84);
			  --WHEN ADJUST =>
			  --      cstr(0) <= full_ascii(84); --Spells AJST
			  --      cstr(1) <= full_ascii(83);
			  --      cstr(2) <= full_ascii(74);
			  --      cstr(3) <= full_ascii(65);


                                
			  ----TURN INSIDE  TURN OUTSIDE  AJST OUTWARD/INWARD
				
			  ----additional states go here...	
			  
			  --WHEN NUMBERS => --state for displaying numbers
			  --      --cstr(0) <= ascii(CONV_INTEGER(data_in( 3 DOWNTO  0)));
			  --      --cstr(1) <= ascii(CONV_INTEGER(data_in( 7 DOWNTO  4)));
			  --      --cstr(2) <= ascii(CONV_INTEGER(data_in(11 DOWNTO  8)));
			  --      --cstr(3) <= ascii(CONV_INTEGER(data_in(15 DOWNTO 12))); 			  
				
			  --WHEN OTHERS =>
			  --      --cstr(0) <= ascii(CONV_INTEGER(data_in( 3 DOWNTO  0)));
			  --      --cstr(1) <= ascii(CONV_INTEGER(data_in( 7 DOWNTO  4)));
			  --      --cstr(2) <= ascii(CONV_INTEGER(data_in(11 DOWNTO  8)));
			  --      --cstr(3) <= ascii(CONV_INTEGER(data_in(15 DOWNTO 12))); 			  
			END CASE;
	     END IF;    
      END PROCESS;

    -- This processes writes the latched data values to the LCD
    PROCESS (RESETN, CLOCK_10KHZ)
      BEGIN
        IF (RESETN = '0') THEN
          state  <= RESET;

        ELSIF (RISING_EDGE(CLOCK_10KHZ)) THEN      
        
          CASE state IS
            WHEN RESET =>           -- wait about 0.1 sec (exceeds 15 ms requirement)
              IF (count > 999) THEN
                count <= 0;
                state <= INIT;
              ELSE
                count <= count + 1;
              END IF;

            WHEN INIT =>            -- send an init command
              LCD_RS <= '0';
              LCD_E  <= '1';
              LCD_D  <= istr(count);
              count  <= count + 1;
              delay  <= 0;
              state  <= INIT_CLOCK;

            WHEN INIT_CLOCK =>      -- latch the command and wait
              LCD_E <= '0';         --  dropping LCD_E latches
              delay <= delay + 1;

              IF (delay >= 99) THEN  -- wait about 10 ms between init commands
                IF (count < 8) THEN
                  state <= INIT;
                ELSE
                  state <= CURPOS;
                END IF;
              END IF;

            -- all remaining states have no waits.  100 us per state
            -- write (enable) states alternate with latching states

            WHEN CURPOS =>            -- Move to 11th character posn on line 1
              LCD_RS <= '0';
              LCD_E  <= '1';
              LCD_D  <= x"8A";
              state  <= CURPOS_CLOCK;

            WHEN CURPOS_CLOCK =>
              LCD_E <= '0';
              count <= 0;
              state <= SWRITE;

            WHEN SWRITE =>            -- Write (least significant digit first)
              LCD_RS <= '1';
              LCD_E  <= '1';
              LCD_D  <= cstr(count);
              count  <= count + 1;
              state <= SWRITE_CLOCK;

            WHEN SWRITE_CLOCK =>      -- Finish write (moves left on screen in chosen mode)
              LCD_E <= '0';
              IF (count >= 4) THEN
                state <= CURPOS;
              ELSE
                state <= SWRITE;
              END IF;

          END CASE;
        END IF;
      END PROCESS;
  END a;

