----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/28/2026 11:08:37 AM
-- Design Name: 
-- Module Name: Top - Structural
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Top is
    Port ( CLK100MHZ : in STD_LOGIC;
           CPU_RESETN : in STD_LOGIC;
           tmp3_sda : inout STD_LOGIC;
           tmp3_scl : inout STD_LOGIC;
           led : out STD_LOGIC_VECTOR (7 downto 0));
end Top;

architecture Structural of Top is

component TMP3_i2cmaster is
    Port(
           clk : in STD_LOGIC;   --100 MHz system clock
           reset_n : in STD_LOGIC;
           
           --I2C bus signals
           scl : out STD_LOGIC;
           sda : inout STD_LOGIC;
           
           temp_out : out STD_LOGIC_VECTOR(7 downto 0);
           data_ready : out STD_LOGIC
    );
end component;

component data_register is
    Port ( clk : in STD_LOGIC;
           we : in STD_LOGIC;
           input_data : in STD_LOGIC_VECTOR (7 downto 0);
           output_data : out STD_LOGIC_VECTOR (7 downto 0);
           ready_pulse : out STD_LOGIC);
end component;


signal w_temp_raw : std_logic_vector(7 downto 0);
signal w_ready_tick : std_logic;
signal w_final_data : std_logic_vector(7 downto 0);

begin

--runs the I2c protocol for 

I2C: TMP3_i2cmaster port map(
    clk => CLK100MHZ,
    reset_n => CPU_RESETN,
    temp_out => w_temp_raw,
    data_ready => w_ready_tick,
    sda => tmp3_sda,
    scl => tmp3_scl
);

LOGGER: data_register port map(
    clk => CLK100MHZ,
    we => w_ready_tick,
    input_data => w_temp_raw,
    output_data => w_final_data,
    ready_pulse => open
);

led <= w_final_data;

end Structural;
