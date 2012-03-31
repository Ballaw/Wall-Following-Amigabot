library IEEE;
library ALTERA_MF;
library LPM;

use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ALTERA_MF.ALTERA_MF_COMPONENTS.all;
use LPM.LPM_COMPONENTS.all;


entity SCOMP is
  port(
    CLOCK     : in    std_logic;
    RESETN    : in    std_logic;
    PC_OUT    : out   std_logic_vector(9 downto 0);
    AC_OUT    : out   std_logic_vector(15 downto 0);
    MDR_OUT   : out   std_logic_vector(15 downto 0);
    MAR_OUT   : out   std_logic_vector(9 downto 0);
    MW_OUT    : out   std_logic;
    FETCH_OUT : out   std_logic;
    IO_WRITE  : out   std_logic;
    IO_CYCLE  : out   std_logic;
    IO_ADDR   : out   std_logic_vector(7 downto 0);
    IO_DATA   : inout std_logic_vector(15 downto 0)
    );
end SCOMP;


architecture a of SCOMP is
  type STATE_TYPE is (
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
    EX_MHI,
    EX_SHIFT2,
    EX_DIV,
    EX_DREM
    EX_SHIFT3
    );

  type STACK_TYPE is array (0 to 7) of std_logic_vector(9 downto 0);

  signal STATE        : STATE_TYPE;
  signal PC_STACK     : STACK_TYPE;
  signal IO_IN        : std_logic_vector(15 downto 0);
  signal AC           : std_logic_vector(15 downto 0);
  signal AC_SHIFTED   : std_logic_vector(15 downto 0);
  signal AC_SHIFTED_2 : std_logic_vector(15 downto 0);
  signal AC_SHIFTED_3 : std_logic_vector(15 downto 0);
  signal IR           : std_logic_vector(15 downto 0);
  signal MDR          : std_logic_vector(15 downto 0);
  signal PC           : std_logic_vector(9 downto 0);
  signal MEM_ADDR     : std_logic_vector(9 downto 0);
  signal MW           : std_logic;
  signal IO_WRITE_INT : std_logic;
  signal XREG         : std_logic_vector(15 downto 0);
  signal YREG         : std_logic_vector(15 downto 0);
  signal HI           : std_logic_vector(15 downto 0);
  signal LO           : std_logic_vector(15 downto 0);
  signal QQ           : std_logic_vector(15 downto 0);
  signal RR           : std_logic_vector(15 downto 0);
  signal REMAI        : std_logic_vector(15 downto 0);
  signal RESULT       : std_logic_vector(31 downto 0);


begin
  -- Use altsyncram component for unified program and data memory
  MEMORY : altsyncram
    generic map (
      intended_device_family => "Cyclone",
      width_a                => 16,
      widthad_a              => 10,
      numwords_a             => 1024,
      operation_mode         => "SINGLE_PORT",
      outdata_reg_a          => "UNREGISTERED",
      indata_aclr_a          => "NONE",
      wrcontrol_aclr_a       => "NONE",
      address_aclr_a         => "NONE",
      outdata_aclr_a         => "NONE",
      init_file              => "wallfollowing-12-4.mif",
      lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
      lpm_type               => "altsyncram"
      )
    port map (
      wren_a    => MW,
      clock0    => not(CLOCK),
      address_a => MEM_ADDR,
      data_a    => AC,
      q_a       => MDR
      );

  -- Use LPM function to shift AC using the SHIFT instruction
  SHIFTER : LPM_CLSHIFT
    generic map (
      lpm_width     => 16,
      lpm_widthdist => 4,
      lpm_shifttype => "LOGICAL"
      )
    port map (
      data      => AC,
      distance  => IR(3 downto 0),
      direction => IR(4),
      result    => AC_SHIFTED
      );
  -- Variable shifter
  SHIFTER2 : LPM_CLSHIFT
    generic map (
      lpm_width     => 16,
      lpm_widthdist => 4,
      lpm_shifttype => "LOGICAL"
      )
    port map (
      data      => AC,
      distance  => MDR(3 downto 0),
      direction => NOT(MDR(4)),         -- 0 is right shift
      result    => AC_SHIFTED_2
      );
  
  -- Variable rotater shifter
  SHIFTER3 : LPM_CLSHIFT
    generic map (
      lpm_width     => 16,
      lpm_widthdist => 4,
      lpm_shifttype => "ROTATE"
      )
    port map (
      data      => AC,
      distance  => MDR(3 downto 0),
      direction => NOT(MDR(4)),         -- 0 is right shift
      result    => AC_SHIFTED_3
      );

  
  -- Use LPM function to drive I/O bus
  IO_BUS : LPM_BUSTRI
    generic map (
      lpm_width => 16
      )
    port map (
      data     => AC,
      enabledt => IO_WRITE_INT,
      tridata  => IO_DATA
      );


  MULTIPLIER : LPM_MULT
    generic map(
      LPM_WIDTHA         => 16,
      LPM_WIDTHB         => 16,
      LPM_WIDTHP         => 32,
      LPM_REPRESENTATION => "SIGNED"
      )
    port map(
      DATAA  => MDR,
      DATAB  => AC,
      RESULT => RESULT
      );
  
  DIVIDER : LPM_DIVIDE
    generic map(
      LPM_WIDTHN         => 16,
      LPM_WIDTHD         => 16,
      LPM_NREPRESENTATION => "SIGNED",
      LPM_DREPRESENTATION => "SIGNED"
      )
    port map(
      NUMER    => AC,
      DENOM    => MDR,
      QUOTIENT => QQ,
      REMAIN   => RR
      );

  PC_OUT  <= PC;
  AC_OUT  <= AC;
  MDR_OUT <= MDR;
  MAR_OUT <= MEM_ADDR;
  MW_OUT  <= MW;
  IO_ADDR <= IR(7 downto 0);

  with STATE select
    MEM_ADDR <= PC when FETCH,
    IR(9 downto 0) when others;

  with STATE select
    IO_CYCLE <= '1' when EX_IN,
    '1'             when EX_OUT2,
    '0'             when others;
  
  with STATE select
    IO_WRITE <= '1' when EX_OUT2,
    '0'             when others;

  with STATE select
    FETCH_OUT <= '1' when FETCH,
    '0'              when others;


  process (CLOCK, RESETN)
  begin
    if (RESETN = '0') then              -- Active low, asynchronous reset
      STATE <= RESET_PC;
    elsif (RISING_EDGE(CLOCK)) then
      case STATE is
        when RESET_PC =>
          MW    <= '0';                 -- Clear memory write flag
          PC    <= "0000000000";  -- Reset PC to the beginning of memory, address 0x000
          AC    <= x"0000";             -- Clear AC register
          STATE <= FETCH;

        when FETCH =>
          MW           <= '0';          -- Clear memory write flag
          IO_WRITE_INT <= '0';
          IR           <= MDR;          -- Latch instruction into the IR
          PC           <= PC + 1;  -- Increment PC to next instruction address
          STATE        <= DECODE;

        when DECODE =>
          case IR(15 downto 10) is
            when "000000" =>            -- No Operation (NOP)
              STATE <= FETCH;
            when "000001" =>            -- LOAD
              STATE <= EX_LOAD;
            when "000010" =>            -- STORE
              STATE <= EX_STORE;
            when "000011" =>            -- ADD
              STATE <= EX_ADD;
            when "000100" =>            -- SUB
              STATE <= EX_SUB;
            when "000101" =>            -- JUMP
              STATE <= EX_JUMP;
            when "000110" =>            -- JNEG
              STATE <= EX_JNEG;
            when "000111" =>            -- JPOS
              STATE <= EX_JPOS;
            when "001000" =>            -- JZERO
              STATE <= EX_JZERO;
            when "001001" =>            -- AND
              STATE <= EX_AND;
            when "001010" =>            -- OR
              STATE <= EX_OR;
            when "001011" =>            -- XOR
              STATE <= EX_XOR;
            when "001100" =>            -- SHIFT
              STATE <= EX_SHIFT;
            when "001101" =>            -- ADDI
              STATE <= EX_ADDI;

            when "001110" =>            -- ILOAD
              STATE <= EX_ILOAD;
            when "001111" =>            -- ISTORE
              STATE <= EX_ISTORE;
            when "010000" =>            -- CALL
              STATE <= EX_CALL;
            when "010001" =>            -- RETURN
              STATE <= EX_RETURN;
            when "010010" =>            -- IN
              STATE <= EX_IN;
            when "010011" =>            -- OUT
              IO_WRITE_INT <= '1';
              STATE        <= EX_OUT;
            when "010100" =>            -- LOADX
              STATE <= EX_LOADX;
            when "010101" =>            -- LOADY
              STATE <= EX_LOADY;
            when "010110" =>            -- STOREX
              STATE <= EX_STOREX;
            when "010111" =>            -- STOREY
              STATE <= EX_STOREY;
            when "011000" =>            -- INCX
              STATE <= EX_INCX;
            when "011001" =>            -- INCY
              STATE <= EX_INCY;
            when "011010" =>
              STATE <= EX_LOADI;        -- LOADI
            when "011011" =>
              STATE <= EX_MULT;         -- MULT 
            when "011100" =>
              STATE <= EX_MLO;          -- MLO 
            when "011101" =>
              STATE <= EX_MHI;          -- MHI 
            when "011110" =>            -- SHIFT2
              STATE <= EX_SHIFT2;
            when "011111" =>            -- DIV
              STATE <= EX_DIV;
            when "100000" =>            -- DREM
              STATE <= EX_DREM;
            when "100001" =>
              STATE <= EX_SHIFT3        -- SHIFT3
              
            when others =>
              STATE <= FETCH;           -- Invalid opcodes default to NOP
          end case;

        when EX_LOAD =>
          AC    <= MDR;  -- Latch data from MDR (memory contents) to AC
          STATE <= FETCH;

        when EX_STORE =>
          MW    <= '1';                 -- Raise MW to write AC to MEM
          STATE <= EX_STORE2;

        when EX_STORE2 =>
          MW    <= '0';                 -- Drop MW to end write cycle
          STATE <= FETCH;

        when EX_ADD =>
          AC    <= AC + MDR;
          STATE <= FETCH;

        when EX_SUB =>
          AC    <= AC - MDR;
          STATE <= FETCH;

        when EX_JUMP =>
          PC    <= IR(9 downto 0);
          STATE <= FETCH;

        when EX_JNEG =>
          if (AC(15) = '1') then
            PC <= IR(9 downto 0);
          end if;

          STATE <= FETCH;

        when EX_JPOS =>
          if ((AC(15) = '0') and (AC /= x"0000")) then
            PC <= IR(9 downto 0);
          end if;

          STATE <= FETCH;

        when EX_JZERO =>
          if (AC = x"0000") then
            PC <= IR(9 downto 0);
          end if;

          STATE <= FETCH;

        when EX_AND =>
          AC    <= AC and MDR;
          STATE <= FETCH;

        when EX_OR =>
          AC    <= AC or MDR;
          STATE <= FETCH;

        when EX_XOR =>
          AC    <= AC xor MDR;
          STATE <= FETCH;

        when EX_SHIFT =>
          AC    <= AC_SHIFTED;
          STATE <= FETCH;

        when EX_ADDI =>
          AC <= AC + (IR(9) & IR(9) & IR(9) & IR(9) &
                         IR(9) & IR(9) & IR(9 downto 0));
          STATE <= FETCH;


        when EX_ILOAD =>
          IR(9 downto 0) <= MDR(9 downto 0);
          STATE          <= EX_LOAD;

        when EX_ISTORE =>
          IR(9 downto 0) <= MDR(9 downto 0);
          STATE          <= EX_STORE;

        when EX_CALL =>
          for i in 0 to 6 loop
            PC_STACK(i + 1) <= PC_STACK(i);
          end loop;

          PC_STACK(0) <= PC;
          PC          <= IR(9 downto 0);
          STATE       <= FETCH;

        when EX_RETURN =>
          for i in 0 to 6 loop
            PC_STACK(i) <= PC_STACK(i + 1);
          end loop;

          PC    <= PC_STACK(0);
          STATE <= FETCH;

        when EX_IN =>
          AC    <= IO_DATA;
          STATE <= FETCH;

        when EX_OUT =>
          IO_WRITE_INT <= '1';
          STATE        <= EX_OUT2;

        when EX_OUT2 =>
          IO_WRITE_INT <= '0';
          STATE        <= FETCH;
          
        when EX_LOADX =>
          AC    <= XREG;
          STATE <= FETCH;
          
        when EX_LOADY =>
          AC    <= YREG;
          STATE <= FETCH;
          
        when EX_STOREX =>
          XREG  <= AC;
          STATE <= FETCH;
          
        when EX_STOREY =>
          YREG  <= AC;
          STATE <= FETCH;
          
        when EX_INCX =>
          XREG  <= XREG + '1';
          STATE <= FETCH;
          
        when EX_INCY =>
          YREG  <= YREG + '1';
          STATE <= FETCH;

        when EX_LOADI =>
          AC    <= MDR;
          STATE <= FETCH;

        when EX_MULT =>
          --RESULT <= AC * MDR;
          --LO <= RESULT(15 DOWNTO 0);
          --HI <= RESULT(31 DOWNTO 16);
          --RESULT <= x"00000000";
          --FOR i IN 0 TO 15 LOOP
          --IF MDR(i) = '1' THEN
          --RESULT((i+16) DOWNTO i) <= RESULT((i+16) DOWNTO i) + AC;
          --END IF;
          --END LOOP;
          LO    <= RESULT(15 downto 0);
          HI    <= RESULT(31 downto 16);
          STATE <= FETCH;
          
        when EX_MLO =>
          --AC <= LO;
          --AC <= RESULT(15 DOWNTO 0);
          --LO <= RESULT(15 DOWNTO 0);
          AC    <= LO;
          STATE <= FETCH;
          
        when EX_MHI =>
          --AC <= HI;
          --AC <= RESULT(31 DOWNTO 16);
          --HI <= RESULT(15 DOWNTO 0);
          AC    <= HI;
          STATE <= FETCH;

        when EX_SHIFT2 =>
          AC    <= AC_SHIFTED_2;
          STATE <= FETCH;

        when EX_DIV =>
          AC <= QQ;
          REMAI <= RR;
          STATE <= FETCH;

        when EX_DREM =>
          AC <= REMAI;
          STATE <= FETCH;

        when EX_SHIFT3 =>
          AC <= AC_SHIFTED_3;
          STATE <= FETCH

        when others =>
          STATE <= FETCH;  -- If an invalid state is reached, return to FETCH
      end case;
    end if;
  end process;
end a;
