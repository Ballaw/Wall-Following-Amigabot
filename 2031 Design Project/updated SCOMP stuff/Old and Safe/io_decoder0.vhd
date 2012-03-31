-- IO DECODER for SCOMP
-- This eliminates the need for a lot of NAND decoders or Comparators 
--    that would otherwise be spread around the SCOMP BDF

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity io_decoder0 is

  port
  (
    IO_ADDR       : in std_logic_vector(7 downto 0);
    IO_CYCLE      : in std_logic;
    SWITCH_EN     : out std_logic;
    LED_EN        : out std_logic;
    TIMER_EN      : out std_logic;
    DIG_IN_EN     : out std_logic;
    HEX_EN        : out std_logic;
    HEX2_EN		  : out std_logic;
    LCD_EN        : out std_logic;
    GLED_EN		  : out std_logic;
    L_POSLOW_EN   : out std_logic; 
    L_POSHIGH_EN  : out std_logic;
    L_VEL_EN      : out std_logic;
    L_VELCTRL_EN  : out std_logic;
    R_POSLOW_EN   : out std_logic; 
    R_POSHIGH_EN  : out std_logic;
    R_VEL_EN      : out std_logic;
    R_VELCTRL_EN  : out std_logic;
    SONAR_EN      : out std_logic
  );

end entity;

architecture a of io_decoder0 is

  signal  IO_INT  : integer range 0 to 511;
  
begin

  IO_INT <= TO_INTEGER(UNSIGNED(IO_CYCLE & IO_ADDR));
  -- note that this results in a three-digit hex number whose 
  --  upper digit is 1 if IO_CYCLE is asserted, and whose
  --  lower two digits are the I/O address being presented
  -- The lines below decode each valid I/O address ...
        
  SWITCH_EN <= '1'    when IO_INT = 16#100# else '0';
  LED_EN <= '1'       when IO_INT = 16#101# else '0';
  TIMER_EN <= '1'     when IO_INT = 16#102# else '0';
  DIG_IN_EN <= '1'    when IO_INT = 16#103# else '0';
  HEX_EN <= '1'       when IO_INT = 16#104# else '0';
  HEX2_EN <= '1'	  when IO_INT = 16#105# else '0';
  LCD_EN <= '1'       when IO_INT = 16#106# else '0';
  GLED_EN <= '1'	  when IO_INT = 16#108# else '0';
  L_POSLOW_EN <= '1'  when IO_INT = 16#180# else '0';
  L_POSHIGH_EN <= '1' when IO_INT = 16#181# else '0';
  L_VEL_EN <= '1'     when IO_INT = 16#182# else '0';
  L_VELCTRL_EN <= '1' when IO_INT = 16#183# else '0';
  R_POSLOW_EN <= '1'  when IO_INT = 16#188# else '0';
  R_POSHIGH_EN <= '1' when IO_INT = 16#189# else '0';
  R_VEL_EN <= '1'     when IO_INT = 16#18A# else '0';
  R_VELCTRL_EN <= '1' when IO_INT = 16#18B# else '0';
  SONAR_EN <= '1'     when ((IO_INT >= 16#1A0#) AND (IO_INT < 16#1B7#) ) else '0';

      
end a;
