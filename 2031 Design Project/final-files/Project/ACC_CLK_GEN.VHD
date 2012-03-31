LIBRARY IEEE;
USE  IEEE.STD_LOGIC_1164.all;
USE  IEEE.STD_LOGIC_ARITH.all;
USE  IEEE.STD_LOGIC_UNSIGNED.all;

-- This is an improved version of the ACC_CLK_GEN provided for Lab 8.

ENTITY acc_clk_gen IS

	PORT
	(
		clock_50Mhz			  : IN	STD_LOGIC;
		clock_17KHz				: OUT	STD_LOGIC;
		clock_10KHz				: OUT	STD_LOGIC;
		clock_100Hz				: OUT	STD_LOGIC;
		clock_10Hz				: OUT	STD_LOGIC
	);
	
END acc_clk_gen;

ARCHITECTURE a OF acc_clk_gen IS

	SIGNAL	count_10hz      : STD_LOGIC_VECTOR(22 DOWNTO 0); 
	SIGNAL	count_100hz     : STD_LOGIC_VECTOR(18 DOWNTO 0);
	SIGNAL  count_10Khz     : STD_LOGIC_VECTOR(12 DOWNTO 0); 
	SIGNAL  count_17Khz     : STD_LOGIC_VECTOR(10 DOWNTO 0); 
	SIGNAL	clock_10hz_int  : STD_LOGIC; 
	SIGNAL	clock_100hz_int : STD_LOGIC;
	SIGNAL  clock_10Khz_int : STD_LOGIC; 
	SIGNAL  clock_17Khz_int : STD_LOGIC; 
BEGIN
	clock_10Khz <= clock_10Khz_int;
	clock_100hz <= clock_100hz_int;
	clock_10hz <= clock_10hz_int;
	clock_17Khz <= clock_17Khz_int;
	
	PROCESS 
	BEGIN
		WAIT UNTIL clock_50Mhz'EVENT and clock_50Mhz = '1';
			IF count_10hz < 2499999 THEN
				count_10hz <= count_10hz + 1;
			ELSE
				count_10hz <= "00000000000000000000000";
				clock_10hz_int <= NOT(clock_10hz_int);
			END IF;
			IF count_100hz < 249999 THEN
				count_100hz <= count_100hz + 1;
			ELSE
				count_100hz <= "0000000000000000000";
				clock_100hz_int <= NOT(clock_100hz_int);
			END IF;	
			IF count_10Khz < 2499 THEN
				count_10Khz <= count_10Khz + 1;
			ELSE
				count_10Khz <= "0000000000000";
				clock_10Khz_int <= NOT(clock_10Khz_int);
			END IF;	
			IF count_17Khz < 1470 THEN
				count_17Khz <= count_17Khz + 1;
			ELSE
				count_17Khz <= "00000000000";
				clock_17Khz_int <= NOT(clock_17Khz_int);
			END IF;
	END PROCESS;	
END a;

