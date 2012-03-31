LIBRARY IEEE;
LIBRARY ALTERA_MF;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ALTERA_MF.ALTERA_MF_COMPONENTS.ALL;
USE LPM.LPM_COMPONENTS.ALL;


ENTITY SCOMP IS
  PORT(
    CLOCK    : IN    STD_LOGIC;
    RESETN   : IN    STD_LOGIC;
    PC_OUT   : OUT   STD_LOGIC_VECTOR( 9 DOWNTO 0);
    AC_OUT   : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0);
    MDR_OUT  : OUT   STD_LOGIC_VECTOR(15 DOWNTO 0);
    MAR_OUT  : OUT   STD_LOGIC_VECTOR( 9 DOWNTO 0);
    MW_OUT   : OUT   STD_LOGIC;
    FETCH_OUT: OUT   STD_LOGIC;
    IO_WRITE : OUT   STD_LOGIC;
    IO_CYCLE : OUT   STD_LOGIC;
    IO_ADDR  : OUT   STD_LOGIC_VECTOR( 7 DOWNTO 0);
    IO_DATA  : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END SCOMP;


ARCHITECTURE a OF SCOMP IS
  TYPE STATE_TYPE IS (
    RESET_PC,
    FETCH,
    DECODE,
    EX_LOAD,
    EX_STORE,
    EX_STORE2,
    EX_ADD,
    EX_SUB,
    EX_JUMP,
    EX_JNEG,
    EX_JPOS,
    EX_JZERO,
    EX_AND,
    EX_OR,
    EX_XOR,
    EX_SHIFT,
    EX_ADDI,
    EX_ILOAD,
    EX_ISTORE,
    EX_CALL,
    EX_RETURN,
    EX_IN,
    EX_OUT,
    EX_OUT2,
    EX_LOADX,
    EX_LOADY,
    EX_STOREX,
    EX_STOREY,
    EX_INCX,
    EX_INCY,
    EX_LOADI,
    EX_MULT,
    EX_MLO,
    EX_MHI
    EX_SHIFT2
  );

  TYPE STACK_TYPE IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(9 DOWNTO 0);

  SIGNAL STATE        : STATE_TYPE;
  SIGNAL PC_STACK     : STACK_TYPE;
  SIGNAL IO_IN        : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL AC           : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL AC_SHIFTED   : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL AC_SHIFTED_2 : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL IR           : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL MDR          : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL PC           : STD_LOGIC_VECTOR( 9 DOWNTO 0);
  SIGNAL MEM_ADDR     : STD_LOGIC_VECTOR( 9 DOWNTO 0);
  SIGNAL MW           : STD_LOGIC;
  SIGNAL IO_WRITE_INT : STD_LOGIC;
  SIGNAL XREG		  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL YREG		  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL HI			  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL LO			  : STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL RESULT		  : STD_LOGIC_VECTOR(31 DOWNTO 0);


  BEGIN
    -- Use altsyncram component for unified program and data memory
    MEMORY : altsyncram
    GENERIC MAP (
      intended_device_family => "Cyclone",
      width_a          => 16,
      widthad_a        => 10,
      numwords_a       => 1024,
      operation_mode   => "SINGLE_PORT",
      outdata_reg_a    => "UNREGISTERED",
      indata_aclr_a    => "NONE",
      wrcontrol_aclr_a => "NONE",
      address_aclr_a   => "NONE",
      outdata_aclr_a   => "NONE",
      init_file        => "test.mif",
      lpm_hint         => "ENABLE_RUNTIME_MOD=NO",
      lpm_type         => "altsyncram"
    )
    PORT MAP (
      wren_a    => MW,
      clock0    => NOT(CLOCK),
      address_a => MEM_ADDR,
      data_a    => AC,
      q_a       => MDR
    );

    -- Use LPM function to shift AC using the SHIFT instruction
    SHIFTER: LPM_CLSHIFT
    GENERIC MAP (
      lpm_width     => 16,
      lpm_widthdist => 4,
      lpm_shifttype => "LOGICAL"
    )
    PORT MAP (
      data      => AC,
      distance  => IR(3 DOWNTO 0),
      direction => IR(4),
      result    => AC_SHIFTED
    );
    -- Variable shifter
    SHIFTER2: LPM_CLSHIFT
    GENERIC MAP (
      lpm_width     => 16,
      lpm_widthdist => 8,
      lpm_shifttype => "LOGICAL"
    )
    PORT MAP (
      data      => AC,
      distance  => MDR(7 DOWNTO 0),
      direction => MDR(9),
      result    => AC_SHIFTED_2
    );

    -- Use LPM function to drive I/O bus
    IO_BUS: LPM_BUSTRI
    GENERIC MAP (
      lpm_width => 16
    )
    PORT MAP (
      data     => AC,
      enabledt => IO_WRITE_INT,
      tridata  => IO_DATA
    );


MULTIPLIER: LPM_MULT
generic map(
	LPM_WIDTHA => 16,
	LPM_WIDTHB => 16,
	LPM_WIDTHP => 32,
	LPM_REPRESENTATION => "SIGNED"
	)
port map( 
	DATAA => MDR,
	DATAB => AC,
	RESULT => RESULT
	);

    PC_OUT   <= PC;
    AC_OUT   <= AC;
    MDR_OUT  <= MDR;
    MAR_OUT  <= MEM_ADDR;
    MW_OUT   <= MW;
    IO_ADDR  <= IR(7 DOWNTO 0);

    WITH STATE SELECT
      MEM_ADDR <= PC WHEN FETCH,
                  IR(9 DOWNTO 0) WHEN OTHERS;

    WITH STATE SELECT
      IO_CYCLE <= '1' WHEN EX_IN,
                  '1' WHEN EX_OUT2,
                  '0' WHEN OTHERS;
                  
    WITH STATE SELECT
      IO_WRITE <= '1' WHEN EX_OUT2,
                  '0' WHEN OTHERS;

    WITH STATE SELECT
      FETCH_OUT <= '1' WHEN FETCH,
                   '0' WHEN OTHERS;


    PROCESS (CLOCK, RESETN)
      BEGIN
        IF (RESETN = '0') THEN          -- Active low, asynchronous reset
          STATE <= RESET_PC;
        ELSIF (RISING_EDGE(CLOCK)) THEN
          CASE STATE IS
            WHEN RESET_PC =>
              MW        <= '0';          -- Clear memory write flag
              PC        <= "0000000000"; -- Reset PC to the beginning of memory, address 0x000
              AC        <= x"0000";      -- Clear AC register
              STATE     <= FETCH;

            WHEN FETCH =>
              MW           <= '0';             -- Clear memory write flag
              IO_WRITE_INT <= '0';
              IR           <= MDR;             -- Latch instruction into the IR
              PC           <= PC + 1;          -- Increment PC to next instruction address
              STATE        <= DECODE;

            WHEN DECODE =>
              CASE IR(15 downto 10) IS
                WHEN "000000" =>       -- No Operation (NOP)
                  STATE <= FETCH;
                WHEN "000001" =>       -- LOAD
                  STATE <= EX_LOAD;
                WHEN "000010" =>       -- STORE
                  STATE <= EX_STORE;
                WHEN "000011" =>       -- ADD
                  STATE <= EX_ADD;
                WHEN "000100" =>       -- SUB
                  STATE <= EX_SUB;
                WHEN "000101" =>       -- JUMP
                  STATE <= EX_JUMP;
                WHEN "000110" =>       -- JNEG
                  STATE <= EX_JNEG;
                WHEN "000111" =>       -- JPOS
                  STATE <= EX_JPOS;
                WHEN "001000" =>       -- JZERO
                  STATE <= EX_JZERO;
                WHEN "001001" =>       -- AND
                  STATE <= EX_AND;
                WHEN "001010" =>       -- OR
                  STATE <= EX_OR;
                WHEN "001011" =>       -- XOR
                  STATE <= EX_XOR;
                WHEN "001100" =>       -- SHIFT
                  STATE <= EX_SHIFT;
                WHEN "001101" =>       -- ADDI
                  STATE <= EX_ADDI;

                WHEN "001110" =>       -- ILOAD
                  STATE <= EX_ILOAD;
                WHEN "001111" =>       -- ISTORE
                  STATE <= EX_ISTORE;
                WHEN "010000" =>       -- CALL
                  STATE <= EX_CALL;
                WHEN "010001" =>       -- RETURN
                  STATE <= EX_RETURN;
                WHEN "010010" =>       -- IN
                  STATE <= EX_IN;
                WHEN "010011" =>       -- OUT
                  IO_WRITE_INT <= '1';
                  STATE <= EX_OUT;
                WHEN "010100" =>		-- LOADX
					STATE <= EX_LOADX;
                WHEN "010101" =>		-- LOADY
					STATE <= EX_LOADY;
                WHEN "010110" =>		-- STOREX
					STATE <= EX_STOREX;
                WHEN "010111" =>		-- STOREY
					STATE <= EX_STOREY;
                WHEN "011000" =>		-- INCX
					STATE <= EX_INCX;
                WHEN "011001" =>		-- INCY
					STATE <= EX_INCY;
				WHEN "011010" =>
					STATE <= EX_LOADI;  -- LOADI
				WHEN "011011" =>
					STATE <= EX_MULT;  -- LOADI 
				WHEN "011100" =>
					STATE <= EX_MLO;  -- LOADI 
				WHEN "011101" =>
					STATE <= EX_MHI;  -- LOADI 
                when "011110"   =>
                  STATE <= EX_SHIFT2;
            
                                        

                WHEN OTHERS =>
                  STATE <= FETCH;      -- Invalid opcodes default to NOP
              END CASE;

            WHEN EX_LOAD =>
              AC    <= MDR;            -- Latch data from MDR (memory contents) to AC
              STATE <= FETCH;

            WHEN EX_STORE =>
              MW    <= '1';            -- Raise MW to write AC to MEM
              STATE <= EX_STORE2;

            WHEN EX_STORE2 =>
              MW    <= '0';            -- Drop MW to end write cycle
              STATE <= FETCH;

            WHEN EX_ADD =>
              AC    <= AC + MDR;
              STATE <= FETCH;

            WHEN EX_SUB =>
              AC    <= AC - MDR;
              STATE <= FETCH;

            WHEN EX_JUMP =>
              PC    <= IR(9 DOWNTO 0);
              STATE <= FETCH;

            WHEN EX_JNEG =>
              IF (AC(15) = '1') THEN
                PC    <= IR(9 DOWNTO 0);
              END IF;

              STATE <= FETCH;

            WHEN EX_JPOS =>
              IF ((AC(15) = '0') AND (AC /= x"0000")) THEN
                PC    <= IR(9 DOWNTO 0);
              END IF;

              STATE <= FETCH;

            WHEN EX_JZERO =>
              IF (AC = x"0000") THEN
                PC    <= IR(9 DOWNTO 0);
              END IF;

              STATE <= FETCH;

            WHEN EX_AND =>
              AC    <= AC AND MDR;
              STATE <= FETCH;

            WHEN EX_OR =>
              AC    <= AC OR MDR;
              STATE <= FETCH;

            WHEN EX_XOR =>
              AC    <= AC XOR MDR;
              STATE <= FETCH;

            WHEN EX_SHIFT =>
              AC    <= AC_SHIFTED;
              STATE <= FETCH;

            WHEN EX_ADDI =>
              AC    <= AC + (IR(9) & IR(9) & IR(9) & IR(9) &
                             IR(9) & IR(9) & IR(9 DOWNTO 0));
              STATE <= FETCH;


            WHEN EX_ILOAD =>
              IR(9 DOWNTO 0) <= MDR(9 DOWNTO 0);
              STATE          <= EX_LOAD;

            WHEN EX_ISTORE =>
              IR(9 DOWNTO 0) <= MDR(9 DOWNTO 0);
              STATE          <= EX_STORE;

            WHEN EX_CALL =>
              FOR i IN 0 TO 6 LOOP
                PC_STACK(i + 1) <= PC_STACK(i);
              END LOOP;

              PC_STACK(0) <= PC;
              PC          <= IR(9 DOWNTO 0);
              STATE       <= FETCH;

            WHEN EX_RETURN =>
              FOR i IN 0 TO 6 LOOP
                PC_STACK(i) <= PC_STACK(i + 1);
              END LOOP;

              PC          <= PC_STACK(0);
              STATE       <= FETCH;

            WHEN EX_IN =>
              AC    <= IO_DATA;
              STATE <= FETCH;

            WHEN EX_OUT =>
              IO_WRITE_INT <= '1';
              STATE <= EX_OUT2;

            WHEN EX_OUT2 =>
              IO_WRITE_INT <= '0';
              STATE <= FETCH;
              
            WHEN EX_LOADX =>
			   AC <= XREG;
			   STATE <= FETCH;	
			
            WHEN EX_LOADY =>
			   AC <= YREG;
			   STATE <= FETCH;
			   
			WHEN EX_STOREX =>
				XREG <= AC;
				STATE <= FETCH;
			
			WHEN EX_STOREY =>
				YREG <= AC;
				STATE <= FETCH;
				
			WHEN EX_INCX =>
				XREG <= XREG + '1';
				STATE <= FETCH;
				
			WHEN EX_INCY =>
				YREG <= YREG + '1';
				STATE <= FETCH;

			WHEN EX_LOADI =>
				AC <= MDR;
				STATE <= FETCH;

			WHEN EX_MULT =>
				--RESULT <= AC * MDR;
				--LO <= RESULT(15 DOWNTO 0);
				--HI <= RESULT(31 DOWNTO 16);
				--RESULT <= x"00000000";
				--FOR i IN 0 TO 15 LOOP
				--IF MDR(i) = '1' THEN
				--RESULT((i+16) DOWNTO i) <= RESULT((i+16) DOWNTO i) + AC;
				--END IF;
				--END LOOP;
				LO <= RESULT(15 DOWNTO 0);
				HI <= RESULT(31 DOWNTO 16);
				STATE <= FETCH;
				
			WHEN EX_MLO =>
				--AC <= LO;
				--AC <= RESULT(15 DOWNTO 0);
				--LO <= RESULT(15 DOWNTO 0);
				AC <= LO;
				STATE <= FETCH;
				
			WHEN EX_MHI =>
				--AC <= HI;
				--AC <= RESULT(31 DOWNTO 16);
				--HI <= RESULT(15 DOWNTO 0);
				AC <= HI;
				STATE <= FETCH;

            when EX_SHIFT2 =>
              AC <= AC_SHIFTED_2;
              STATE <= FETCH;

            WHEN OTHERS =>
              STATE <= FETCH;          -- If an invalid state is reached, return to FETCH
          END CASE;
        END IF;
      END PROCESS;
  END a;
