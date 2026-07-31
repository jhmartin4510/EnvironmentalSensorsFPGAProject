library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity veml7700_data_register is
    Port ( 
        clk         : in  STD_LOGIC;
        reset_n     : in  STD_LOGIC;
        we          : in  STD_LOGIC;                      -- contollers data ready
        input_data  : in  STD_LOGIC_VECTOR (15 downto 0); -- 16-bit ALS data from VEML7700
        output_data : out STD_LOGIC_VECTOR (15 downto 0); -- Held steady for top-level display/UART
        ready_pulse : out STD_LOGIC                       -- Single-cycle pulse indicating new data
    );
end veml7700_data_register;

architecture Behavioral of veml7700_data_register is

    signal storage_reg : std_logic_vector(15 downto 0) := (others => '0');

begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            storage_reg <= (others => '0');
            ready_pulse <= '0';
            
        elsif rising_edge(clk) then
            if we = '1' then
                storage_reg <= input_data; -- Latch new 16-bit sample
                ready_pulse <= '1';        -- pulse for 1 cycle
            else
                ready_pulse <= '0';        -- Clear pulse 
            end if;
        end if;                    
    end process;

    -- Continuous assignment to output
    output_data <= storage_reg;

end Behavioral;