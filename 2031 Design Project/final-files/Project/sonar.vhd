-- SONAR.VHD (a peripheral module for SCOMP)
-- 2011.06.13
--
-- Provided as a template for the summer 2011 project.
-- When complete, it should sequence between the 8 sonar
--  transducers, emitting a ping, waiting for an echo,
--  and repeating for the next sonar.    It should also
--  (at least) respond to IN commands, returning a specified
--  sonar value (the most recent measurement).
-- The constant pinging should be INDEPENDENT of any interaction
--  with the I/O bus.  As a VHDL device, it is possible
--  to take advantage of hardware concurrency.
-- Additional features are optional.

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE LPM.LPM_COMPONENTS.ALL;


ENTITY SONAR IS
  PORT(CLOCK,    -- 10 kHz
       RESETN,   -- active-low reset
       CS,       -- device select for I/O operations (should be high when I/O address is 0xA0 through 0xA7, and
                 --   also when an IO_CYCLE is ongoing
       IO_WRITE, -- indication of OUT (vs. IN), when I/O operation occurring
       ECHO      : IN    STD_LOGIC;   -- active-high indication of echo (remains high until INIT lowered)
       ADDR      : IN    STD_LOGIC_VECTOR(4 DOWNTO 0);  -- select one of eight internal registers for I/O, assuming
                            -- that device in fact supports usage of multiple registers between 0xA0 and 0xA7
       INIT      : OUT   STD_LOGIC;        -- initiate a ping (hold high until completion of echo/no-echo cycle)
       LISTEN    : OUT   STD_LOGIC;        -- listen (raise after INIT, allowing for blanking interval)
       SONAR_NUM : OUT   STD_LOGIC_VECTOR(2 DOWNTO 0);  -- select a sonar transducer for pinging
       IO_DATA   : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0) );  -- I/O data bus for host operations
END SONAR;


ARCHITECTURE behavior OF SONAR IS
  SIGNAL TRIGGER_CYCLE : STD_LOGIC; --INIT_INT OR DISABLE_SON.  Used for triggering selection of enabled sonar
  SIGNAL INIT_INT : STD_LOGIC;  -- Local (to architecture) copy of INIT
  SIGNAL DISABLE_SON : STD_LOGIC;  -- 1: disables all sonar activity 0: enables sonar scanning
  SIGNAL SONAR_EN : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Stores 8 flags to determine whether a sonar is enabled
  SIGNAL DISTANCE : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- Used to store calculated distance at each iteration
  SIGNAL TIME_SHIFTED4 : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- Used to store echo time shifted to left 4
  TYPE SONAR_DATA IS ARRAY (17 DOWNTO 0) OF STD_LOGIC_VECTOR(15 DOWNTO 0);  -- declare an array type
    -- 17 = object_detected, 16 = alarms, 15 DOWNTO 8 = distance, 7 DOWNTO 0 = echo time
  SIGNAL SONAR_RESULT : SONAR_DATA;      -- and use it to store a sonar value (distance) for each sonar transducer
  SIGNAL SELECTED_SONAR : STD_LOGIC_VECTOR(2 DOWNTO 0);    -- At a given time, one sonar is going to be of interest
  SIGNAL ECHO_TIME : STD_LOGIC_VECTOR(15 DOWNTO 0); -- This will be used to time the echo
  SIGNAL PING_TIME : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- This will be used to time the pinger process
  SIGNAL ALARM_DIST : STD_LOGIC_VECTOR(15 DOWNTO 0);  -- Stores maximum distance where alarm is triggered
  -- These three constants assume a 10Khz clock, and would need to be changed if the clock changes
  CONSTANT MAX_DIST  : STD_LOGIC_VECTOR(15 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400+100, 16);  -- ignore echos after ~40 ms  
  CONSTANT OFF_TIME  : STD_LOGIC_VECTOR(15 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(100, 16);  -- creates the 80% observed duty cycle
  CONSTANT BLANK_TIME  : STD_LOGIC_VECTOR(15 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(8+100, 16);  -- Ignore early false echoes (was 11+100)

  CONSTANT NO_ECHO  : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"FFFF";  -- use 0xFFFF (-1) as an indication that no echo was detected
  SIGNAL IO_IN : STD_LOGIC;      -- a derived signal that shows an IN is requested from this device (and it should drive IO data bus)
  SIGNAL LATCH  : STD_LOGIC;      -- a signal that goes high when the host (SCOMP) does an IO_OUT to this device
  SIGNAL PING_STARTED : STD_LOGIC;     -- an indicator that a ping is in progress
  SIGNAL PING_DONE : STD_LOGIC;  -- an indicator that a ping has resulted in an echo, or too much time has passed for an echo
  SIGNAL I : INTEGER;          -- note that we CAN use actual integers.  This will be used as an index below.  Because it does
                               --   not actually need to be implemented as a "real" signal, it can be replaced with a VARIABLE
                               --   declaration within the PROCESS where it is used below.

  BEGIN
    -- Use LPM_CLSHIFT function to shift TIME for distance calculations
    SHIFTER : LPM_CLSHIFT
    GENERIC MAP (
      lpm_width       => 16,
      lpm_widthdist   => 4,
      lpm_shifttype   => "LOGICAL"
    )
    PORT MAP (
      data        => ECHO_TIME,
      distance    => "0100",
      direction   => '0',
      result      => TIME_SHIFTED4
    );
    
    -- Use LPM function to create bidirectional I/O data bus
    IO_BUS: lpm_bustri
    GENERIC MAP (
      lpm_width => 16
    )
    PORT MAP (
      data     => SONAR_RESULT( CONV_INTEGER(ADDR)), -- this assumes that during an IN operation, the lowest five address bits 
                                                     --    specify the value of interest.  See definition of SONAR_RESULT above.
                                                     --  The upper address bits are decoded to produce the CS signal used below
      enabledt => IO_IN,  -- based on CS (see below)
      tridata  => IO_DATA
    );

    IO_IN <= (CS AND NOT(IO_WRITE));  -- Drive IO_DATA bus (see above) when this
                                       --   device is selected (CS high), and
                                       --   when it is not an OUT command.
    LATCH <= CS AND IO_WRITE;   -- Similarly, this produces a high (and a rising
                                --   edge suitable for latching), but only when an OUT command occurs       

    WITH SELECTED_SONAR SELECT  -- SELECTED_SONAR is the internal signal with a sonar mapping that makes more logical sense.
      SONAR_NUM <= "000" WHEN "001",
                   "001" WHEN "101",
                   "010" WHEN "011",
                   "011" WHEN "111",
                   "100" WHEN "000",
                   "101" WHEN "100",
                   "110" WHEN "010",
                   "111" WHEN "110",
                   "000" WHEN OTHERS;

    INIT <= INIT_INT;
    
    DISTANCE <= TIME_SHIFTED4 + ECHO_TIME;
    
    TRIGGER_CYCLE <= INIT_INT OR DISABLE_SON;
    
    WITH SONAR_EN SELECT
      DISABLE_SON <= '1' WHEN "00000000",
                     '0' WHEN OTHERS;
                                                
    CYCLE: PROCESS (TRIGGER_CYCLE, RESETN)  -- This process cycles through all the enabled sonars
      BEGIN
		IF (RESETN = '0') THEN
          IF (DISABLE_SON = '0') THEN
            IF (SONAR_EN(0) = '1') THEN
              SELECTED_SONAR <= "000";
            ELSIF (SONAR_EN(1) = '1') THEN
              SELECTED_SONAR <= "001";
            ELSIF (SONAR_EN(2) = '1') THEN
              SELECTED_SONAR <= "010";
            ELSIF (SONAR_EN(3) = '1') THEN
              SELECTED_SONAR <= "011";
            ELSIF (SONAR_EN(4) = '1') THEN
              SELECTED_SONAR <= "100";
            ELSIF (SONAR_EN(5) = '1') THEN
              SELECTED_SONAR <= "101";
            ELSIF (SONAR_EN(6) = '1') THEN
              SELECTED_SONAR <= "110";
            ELSIF (SONAR_EN(7) = '1') THEN
              SELECTED_SONAR <= "111";
            ELSE
              SELECTED_SONAR <= "000";
            END IF;
          END IF;
          
        ELSIF (FALLING_EDGE(TRIGGER_CYCLE)) THEN
          CASE SELECTED_SONAR IS
            WHEN "000" =>
			  IF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "001" =>
			  IF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "010" =>
			  IF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "011" =>
			  IF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "100" =>
			  IF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "101" =>
			  IF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "110" =>
			  IF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSIF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;

            WHEN "111" =>
			  IF (SONAR_EN(0) = '1') THEN
			    SELECTED_SONAR <= "000";
			  ELSIF (SONAR_EN(1) = '1') THEN
			    SELECTED_SONAR <= "001";
			  ELSIF (SONAR_EN(2) = '1') THEN
			    SELECTED_SONAR <= "010";
			  ELSIF (SONAR_EN(3) = '1') THEN
			    SELECTED_SONAR <= "011";
			  ELSIF (SONAR_EN(4) = '1') THEN
			    SELECTED_SONAR <= "100";
			  ELSIF (SONAR_EN(5) = '1') THEN
			    SELECTED_SONAR <= "101";
			  ELSIF (SONAR_EN(6) = '1') THEN
			    SELECTED_SONAR <= "110";
			  ELSIF (SONAR_EN(7) = '1') THEN
			    SELECTED_SONAR <= "111";
			  ELSE
			    SELECTED_SONAR <= "000";
			  END IF;
            
          END CASE;
        END IF;
            
      END PROCESS;
      
    PINGER: PROCESS (CLOCK, RESETN)   -- This process issues a ping after a PING_START signal and times the return

      BEGIN
        IF (RESETN = '0' OR DISABLE_SON = '1') THEN  -- after reset, do NOT ping, and set all stored echo results to NO_ECHO 
          SONAR_RESULT( 16 ) <= x"0000"; --Least significant 8 bits used for alarm triggers
          SONAR_RESULT( 17 ) <= x"0000"; --Least significant 8 bits used for objects detected
          PING_TIME <= x"0000";
          ECHO_TIME <= x"0000";
          LISTEN <= '0';
          INIT_INT <= '0';                       
          PING_STARTED <= '0';
          PING_DONE <= '0';
        -- INITIALIZING SONAR timing values....  
        -- These next few lines of code are something new for this class.  Beware of thinking of
        --   this as equivalent to a series of 8 statements executed SEQUENTIALLY, with an integer "I"
        --   stored somewhere.  A VHDL synthesizer, such as that within Quartus, will create hardware 
        --   that assigns each of the 8 SONAR_RESULT values to NO_ECHO *concurrently* upon reset.  In
        --   other words, the FOR LOOP is a convenient shorthand notation to make 8 parallel assignments.
          FOR I IN 0 to 7 LOOP
            SONAR_RESULT( I ) <= NO_ECHO;   -- "I" was declared as an INTEGER SIGNAL.  Could have been a VARIABLE.
          END LOOP;
        -- However, it is worth noting that if the statement in the loop had been
        --  SONAR_RESULT( I ) <= SONAR_RESULT( (I-1) MOD 8 )
        -- then something else entirely would happen.  First, it would be a circular buffer (like
        -- a series of shift registers with the end wrapped around to the beginning).  Second, it
        -- would not be possible to implement it as a purely combinational logic assignment, since
        -- it would infer some sort of latch (using some "current" values of SONAR_RESULT on
        -- the right-hand side to define "next" values on the right-hand side).          
          
        ELSIF (RISING_EDGE(CLOCK)) THEN
          FOR I IN 0 to 7 LOOP
            IF (( SONAR_EN(I) = '0') AND (CONV_INTEGER(SELECTED_SONAR) /= I) ) THEN
              SONAR_RESULT( 16 )( I ) <= '0';
              SONAR_RESULT( 17 )( I ) <= '0';
              SONAR_RESULT( I ) <= x"FFFF";
              SONAR_RESULT( I + 8 ) <= x"FFFF";
            END IF;
          END LOOP;
          IF (PING_STARTED = '0') THEN  -- a new ping should start
            PING_STARTED <= '1';
            PING_DONE <= '0';
            PING_TIME <= x"0000";
            ECHO_TIME <= x"0000";
            LISTEN <= '0';  -- Blank on (turn off after 1.2 ms)
          ELSIF (PING_STARTED = '1') THEN       -- Handle a ping already in progress
            PING_TIME <= PING_TIME + 1;    --   ... increment time counter (ALWAYS)
            IF (PING_TIME >= OFF_TIME) THEN
              ECHO_TIME <= ECHO_TIME + 1;
            END IF;
            IF ( (ECHO = '1') AND (PING_DONE = '0') ) THEN        --   Save the result of a valid echo
              PING_DONE <= '1';
              -- Set alarm flag to 1 if within the programmed ALARM_DIST range.
              IF ( (DISTANCE >= 10#0#) AND (DISTANCE <= CONV_INTEGER(ALARM_DIST)) ) THEN
                SONAR_RESULT( 16 )( CONV_INTEGER(SELECTED_SONAR) ) <= '1';
              ELSE  -- Set alarm flag to 0 otherwise
			    SONAR_RESULT( 16 )( CONV_INTEGER(SELECTED_SONAR) ) <= '0';
              END IF;
              SONAR_RESULT( 17 )( CONV_INTEGER(SELECTED_SONAR) ) <= '1';
              SONAR_RESULT( CONV_INTEGER(SELECTED_SONAR) ) <= ECHO_TIME;   
              SONAR_RESULT( CONV_INTEGER(SELECTED_SONAR) + 8 ) <= DISTANCE - 50;
            END IF;
            IF (PING_TIME = OFF_TIME) THEN  -- Wait for OFF_TIME to pass before starting the ping
              INIT_INT <= '1';  -- Issue a ping.  This must stay high at least until the echo comes back
            ELSIF (PING_TIME = BLANK_TIME) THEN  --   ... turn off blanking at 1.1, going on 1.2 ms
              LISTEN <= '1';
            ELSIF (PING_TIME = MAX_DIST) THEN   -- Stop listening at a specified distance
              INIT_INT <= '0';
              LISTEN <= '0';
              IF (PING_DONE = '0' ) THEN     -- And if echo not found earlier, set NO_ECHO indicator
                SONAR_RESULT( 16 )( CONV_INTEGER(SELECTED_SONAR) ) <= '0';
                SONAR_RESULT( 17 )( CONV_INTEGER(SELECTED_SONAR) ) <= '0';
                SONAR_RESULT( CONV_INTEGER(SELECTED_SONAR)) <= NO_ECHO;
                SONAR_RESULT( CONV_INTEGER(SELECTED_SONAR) + 8) <= NO_ECHO;
              END IF;
              PING_STARTED <= '0';
            END IF;
          END IF;
        END IF;
      END PROCESS;

    INPUT_HANDLER: PROCESS (RESETN, LATCH)  -- write to address 0x12 (offset from base of 0xA0) will
                                            --   set the enabled sonars.  Writing to address offset 0x10     
                                            --   will set the alarm distance.              
      BEGIN                  
        IF (RESETN = '0' ) THEN
          SONAR_EN <= x"00";
          ALARM_DIST <= x"0000";
        ELSIF (RISING_EDGE(LATCH)) THEN   -- an "OUT" to this device has occurred
		  IF (ADDR = "10010") THEN
            SONAR_EN <= IO_DATA(7 DOWNTO 0);
          END IF;
		  IF (ADDR = "10000") THEN
            ALARM_DIST <= IO_DATA;
          END IF;
        END IF;
      END PROCESS;
          
END behavior;
  
 



