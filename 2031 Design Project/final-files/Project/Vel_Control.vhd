-- VEL_CONTROL.VHD
-- 04/03/2011
-- This was the velocity controller for the AmigoBot project. 
-- Team Flying Robots
-- ECE2031 L05  (minor mods by T. Collins, plus major addition of closed-loop control)

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE LPM.LPM_COMPONENTS.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY VEL_CONTROL IS
  PORT(PWM_CLK,    -- must be an 400 MHz clock signal to get ~100 kHz PWM frequency
       RESETN,
       CS,       -- chip select, asserted when new speed is input
       IO_WRITE : IN    STD_LOGIC;  -- asserted when being written to
       IO_DATA  : IN    STD_LOGIC_VECTOR(15 DOWNTO 0);  -- commanded speed from SCOMP (only lower 8 bits used)
       VELOCITY : IN    STD_LOGIC_VECTOR(11 DOWNTO 0); -- actual velocity of motor, for closed loop control 
       CTRL_CLK : IN    STD_LOGIC;  -- clock that determines control loop sampling rate (~10 Hz)
       DIR      : IN    STD_LOGIC;  -- '1' if CCW is forward, '0' if CW is forward
       NMOTOR_EN, -- turns the motor on/off, this will be a PWM signal
       MOTOR_DIR : OUT  STD_LOGIC; -- direction the wheel will rotate
       WATCHDOG  : OUT  STD_LOGIC  -- safety feature       
       );
END VEL_CONTROL;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

ARCHITECTURE a OF VEL_CONTROL IS
  SIGNAL COUNT  : STD_LOGIC_VECTOR(11 DOWNTO 0); -- counter output
  SIGNAL IO_DATA_INT: STD_LOGIC_VECTOR(15 DOWNTO 0); -- internal speed value
  SIGNAL NMOTOR_EN_INT: STD_LOGIC; --  internal enable signal
  SIGNAL LATCH: STD_LOGIC;
  SIGNAL PWM_CMD: STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL WATCHDOG_INT: STD_LOGIC;
  
  BEGIN 
    -- Use LPM counter megafunction to make a divide by 4096 counter
    counter: LPM_COUNTER
    GENERIC MAP(
      lpm_width => 12,
      lpm_direction => "UP"
    )
    PORT MAP(
      clock => PWM_CLK,
      q => COUNT
    );

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!
          
    -- Use LPM compare megafunction to produce desired duty cycle
    compare: LPM_COMPARE
    GENERIC MAP(
	  lpm_width => 12,
	  lpm_representation => "UNSIGNED"
	)
	PORT MAP(
      dataa => COUNT,
      datab =>  PWM_CMD(11 DOWNTO 0),  
      ageb => NMOTOR_EN_INT
    );

	-- the enable and watchdog bits are outputs, but since they are read
  --   internally, they require "shadow" equivalents for read/write
  -- Here, they are used to drive the actual output pins
    NMOTOR_EN <= NMOTOR_EN_INT;
    WATCHDOG <= WATCHDOG_INT;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!
    
    LATCH <= CS AND IO_WRITE; -- part of IO fix (below) -- TRC
    
    PROCESS (RESETN, LATCH)
      BEGIN
        -- set speed to 0 after a reset
        IF RESETN = '0' THEN
          IO_DATA_INT <= "0000000000000000";
          WATCHDOG_INT <= '0';
        -- keep the IO command (velocity command) from SCOMP in an internal register IO_DATA_INT
        ELSIF RISING_EDGE(LATCH) THEN   -- fixed unreliable OUT operation - TRC
	        -- handle the case of the max negative velocity
				  IF IO_DATA(7 DOWNTO 0) = "10000000" THEN
						IO_DATA_INT <= "0000000000000000";  -- req'd behavior for -128 (treat as zero)
					ELSIF DIR = '0' THEN  -- right wheel (fwd motion is +, which is CW)
	          IO_DATA_INT <=  NOT(IO_DATA(7))&NOT(IO_DATA(7))&NOT(IO_DATA(7))&NOT(IO_DATA(7))&NOT(IO_DATA(7))&NOT(IO_DATA(7))&NOT(IO_DATA(7))&NOT(IO_DATA(7))&
	                          STD_LOGIC_VECTOR(-SIGNED(IO_DATA(7 DOWNTO 0)));  
	        ELSE                  -- left wheel (fwd motion is +, which is CCW)
						IO_DATA_INT <= IO_DATA(7)&IO_DATA(7)&IO_DATA(7)&IO_DATA(7)&IO_DATA(7)&IO_DATA(7)&IO_DATA(7)&IO_DATA(7)&
	                          IO_DATA(7 DOWNTO 0);
					END IF;
					WATCHDOG_INT <= NOT WATCHDOG_INT;		-- toggle the watchdog timer any time a command is received
	      END IF;
    END PROCESS;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!
    
  -- added closed loop control so that motor will try to achieve exactly the value commanded - TRC
    PROCESS (CTRL_CLK, RESETN)
      VARIABLE CMD_VEL, VEL_ERR, CUM_VEL_ERR: INTEGER;
      VARIABLE SATURATION: INTEGER := 1024; --256;  -- Limits effect of integrator "windup"
      VARIABLE EPSILON:  INTEGER := 2;  -- Used to reset integrator
      VARIABLE DVEL, LASTVEL: INTEGER := 0;
      VARIABLE LIMIT:     SIGNED(15 DOWNTO 0) := x"0FFF";
      VARIABLE KP, KF, KI, KD: INTEGER := 0;  -- Gains 
      VARIABLE MOTOR_CMD: SIGNED(15 DOWNTO 0); 
      VARIABLE PROP_CTRL, INT_CTRL, DERIV_CTRL: SIGNED(15 DOWNTO 0); 
      VARIABLE FF_CTRL: SIGNED(15 DOWNTO 0);

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

      BEGIN 
        IF RESETN = '0' THEN
          PWM_CMD <= "0000000000000000"; -- at startup, motor should be off
          CUM_VEL_ERR := 0;
          LASTVEL := 0;
          DVEL := 0;
        ELSIF RISING_EDGE(CTRL_CLK) THEN   -- determine a control signal at each control cycle
          KP := 9;   
          KI := 3;   
          KD := 0;    
          KF := 16;    -- 4 => 2^4 => *16, so +127 command (0x7F) translates to 0x7F0, about half of range
          DVEL := TO_INTEGER(SIGNED(VELOCITY)) - LASTVEL;
          LASTVEL := TO_INTEGER(SIGNED(VELOCITY));
          CMD_VEL := TO_INTEGER(SIGNED(IO_DATA_INT(7 DOWNTO 0))); 
          VEL_ERR := CMD_VEL - TO_INTEGER(SIGNED(VELOCITY));  -- a commanded vel of 127 should result in scaled vel of 127
          CUM_VEL_ERR := CUM_VEL_ERR + VEL_ERR;   -- perform the integration, if not near setpoint
          IF (CUM_VEL_ERR > SATURATION) THEN
            CUM_VEL_ERR := SATURATION;
          ELSIF (VEL_ERR < -SATURATION) THEN
            CUM_VEL_ERR := -SATURATION;
          END IF;
          PROP_CTRL := TO_SIGNED( VEL_ERR * KP, 16 );   -- The "P" component of the PID controller  4
          INT_CTRL  := TO_SIGNED( CUM_VEL_ERR * KI, 16);   -- The "I" component  2
          DERIV_CTRL := TO_SIGNED( DVEL * KD, 16);-- The "D" component 
          FF_CTRL := TO_SIGNED(CMD_VEL * KF, 16);   -- FeedForward component...
          MOTOR_CMD := FF_CTRL + PROP_CTRL + INT_CTRL - DERIV_CTRL;
          IF (MOTOR_CMD > LIMIT) THEN
            MOTOR_CMD := LIMIT; 
          ELSIF (MOTOR_CMD < -LIMIT) THEN
            MOTOR_CMD := -LIMIT;
          END IF;
          PWM_CMD <= STD_LOGIC_VECTOR  (ABS (MOTOR_CMD));
          MOTOR_DIR <= NOT(MOTOR_CMD(15)); 
        END IF; 
    END PROCESS;
    
END a;

-- DO NOT ALTER ANYTHING IN THIS FILE.  IT IS EASY TO CREATE POSITIVE FEEDBACK, 
--  INSTABILITY, AND RUNAWAY ROBOTS!!

