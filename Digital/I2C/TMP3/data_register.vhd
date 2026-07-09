----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/28/2026 11:00:39 AM
-- Design Name: 
-- Module Name: data_register - Behavioral
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

entity data_register is
    Port ( clk : in STD_LOGIC;
           we : in STD_LOGIC;
           input_data : in STD_LOGIC_VECTOR (7 downto 0);
           output_data : out STD_LOGIC_VECTOR (7 downto 0);
           ready_pulse : out STD_LOGIC);
end data_register;

architecture Behavioral of data_register is

signal storage_reg : std_logic_vector(7 downto 0) := (others => '0');

begin

process(clk)
begin
    if rising_edge(clk) then
        if we = '1' then
            storage_reg <= input_data;
            ready_pulse <= '1'; 
        else
            ready_pulse <= '0'; 
        end if;
    end if;                    
end process;

output_data <= storage_reg;

end Behavioral;
