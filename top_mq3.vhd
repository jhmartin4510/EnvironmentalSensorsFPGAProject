----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/05/2026 09:45:30 PM
-- Design Name: 
-- Module Name: top_mq3 - Behavioral
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
use IEEE.NUMERIC_STD.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity top_mq3 is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           --analog input signals
           vauxp3 : in STD_LOGIC; --to A0
           vauxn3 : in STD_LOGIC; -- to GND
           led : out STD_LOGIC_VECTOR (15 downto 0));
end top_mq3;

architecture Behavioral of top_mq3 is

COMPONENT xadc_mq3_sensor
  PORT (
    di_in : IN STD_LOGIC_VECTOR(15 DOWNTO 0); --input data bus for the DRP
    daddr_in : IN STD_LOGIC_VECTOR(6 DOWNTO 0); --address bus for the DRP
    den_in : IN STD_LOGIC;  --enable signal for DRP
    dwe_in : IN STD_LOGIC;  --write enable for the DRP
    drdy_out : OUT STD_LOGIC;   --ready enabled when process is complete
    do_out : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); --stores the data from the sensor (12 bits used)
    dclk_in : IN STD_LOGIC; --clock input for the DRP
    reset_in : IN STD_LOGIC; --reset signal for hte XADC control logic
    vp_in : IN STD_LOGIC; --analog input pair 
    vn_in : IN STD_LOGIC; --analog input pair
    vauxp3 : IN STD_LOGIC; --aux analog input pairs
    vauxn3 : IN STD_LOGIC; --aux analog input pairs
    
    --status flags and alarms
    user_temp_alarm_out : OUT STD_LOGIC;
    vccint_alarm_out : OUT STD_LOGIC;
    vccaux_alarm_out : OUT STD_LOGIC;
    channel_out : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
    eoc_out : OUT STD_LOGIC;
    alarm_out : OUT STD_LOGIC;
    eos_out : OUT STD_LOGIC;
    busy_out : OUT STD_LOGIC
  );
END COMPONENT;


--XADC signals
signal xadc_en : std_logic; --enable the xadc
signal xadc_ready : std_logic; --xadc is ready to sample
signal do_out : std_logic_vector(15 downto 0); --this is the data register
signal adc_data : std_logic_vector(11 downto 0)  := (others => '0'); --this is the vector that contains non-zero values (true alcohol data)
 
--state machine signals
type state_type is (
IDLE, --not sampling
READ_REQ, --reading ready
WAIT_DRDY, --wait for data ready
SAVE_DATA --data is saved to our register 
);
signal curr_state, next_state: state_type := IDLE;


signal rst_internal : STD_LOGIC;
signal test_eoc : STD_LOGIC;
signal eoc_toggle: STD_LOGIC := '0';
signal xadc_eos : STD_LOGIC;
signal eoc_counter : integer range 0 to 25000000 := 0;
begin

rst_internal <= not reset;
--rst_internal <= '0';
--clocking procedure and state advancement

process(clk, rst_internal)
begin
    if rst_internal = '1'then  
        curr_state <= IDLE;
    elsif rising_edge(clk) then
        curr_state <= next_state;
    end if;                             
end process;

process(curr_state, xadc_ready)
begin
    next_state <= curr_state;
    case curr_state is
        when IDLE => 
            if xadc_eos = '1' then
                next_state <= WAIT_DRDY;
            else
                next_state <= IDLE;
            end if;                                    
        
--        when READ_REQ =>
--            xadc_en <= '1';
--            next_state <= WAIT_DRDY;
        when WAIT_DRDY =>
            if xadc_ready = '1' then
                next_state <= SAVE_DATA;
            else
                next_state <= WAIT_DRDY;
            end if;
        when SAVE_DATA =>
            next_state <= WAIT_DRDY;
        when others =>
            next_state <= IDLE;                                                         
    end case;        
end process;

--saving the data
process(clk)
begin
    if rising_edge(clk) then
        if curr_state = SAVE_DATA then
            adc_data <= do_out(15 downto 4);
        end if;
    end if;
end process;

MQ3_XADC: xadc_mq3_sensor port map(
    daddr_in => "0010011",
    dclk_in => clk,
    den_in => test_eoc,
    di_in => x"0000",
    dwe_in => '0',
    drdy_out => xadc_ready,
    do_out => do_out,
    vauxp3 => vauxp3,
    vauxn3 => vauxn3,
    vp_in => '0',
    vn_in => '0',
    reset_in => rst_internal,
    user_temp_alarm_out => open,
    vccint_alarm_out=>open,
    vccaux_alarm_out=>open,
    channel_out=> open,
    eoc_out=> test_eoc,
    alarm_out => open,
    eos_out=>xadc_eos,
    busy_out=>open
);




CLEAN_DISPLAY: process(adc_data)
begin
    led(11 downto 0) <= (others => '0');
    
    if unsigned(adc_data) > 3685 then
        led(11 downto 0) <= "111111111111";
    elsif unsigned(adc_data) > 3276 then
        led(9 downto 0) <= (others=> '1');
    elsif unsigned(adc_data) > 2867 then
        led(7 downto 0) <= (others => '1');
    elsif unsigned(adc_data) > 2457 then
        led(5 downto 0) <= (others => '1');
    elsif unsigned(adc_data) > 2048 then
        led(3 downto 0) <= (others => '1');
    elsif unsigned(adc_data) > 1228 then
        led(1 downto 0) <= (others=> '1');
    elsif unsigned(adc_data) > 409 then
        led(0) <= '1';
    end if;    
end process CLEAN_DISPLAY;

--PROCESS_EOC_DEBUG: process(clk)
--begin
--    if rising_edge(clk) then
--        if test_eoc = '1' then
--            if eoc_counter = 25000000 then
--                eoc_counter <= 0;
--                eoc_toggle <= not eoc_toggle;
--            else
--                eoc_counter <= eoc_counter + 1;
--            end if;            
--        end if;        
--    end if;
--end process PROCESS_EOC_DEBUG; 

--led(15) <= eoc_toggle;

end Behavioral;
