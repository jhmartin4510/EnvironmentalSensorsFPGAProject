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
           uart_tx_out : out STD_LOGIC;
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
signal adc_data : std_logic_vector(15 downto 0);  --WHAT is this doing(?) 
signal xadc_ready : std_logic; --xadc is ready to sample
signal data_reg : std_logic_vector(15 downto 0) := (others => '0'); --Look up function
signal test_eoc : STD_LOGIC; 
signal xadc_eos : STD_LOGIC;
 
--state machine signals
type adc_state_type is (
IDLE, --not sampling
WAIT_DRDY, --wait for data ready
SAVE_DATA --data is saved to our register 
);
signal adc_state: adc_state_type := IDLE;

signal rst_internal : STD_LOGIC;



--UART implementation
--sync flag for UART to send a new sample
signal new_sample_ready : STD_LOGIC:= '0';


--UART Transmitter Signals (115,200 BAUD @ 100 MHz clk)

--Baud rate timing
constant BIT_PERIOD : integer := 868; --100_000_000/115_200 = 868 clock cycles each bit
signal clk_count : integer range 0 to BIT_PERIOD := 0;
signal bit_index : integer range 0 to 9 := 0; --start + 8-bit data + stop

--UART FSM Signals
type uart_state_type is (
TX_IDLE, --when no process is active
SEND_START, --prepare to send data
SEND_HIGH, --
SEND_LOW,
SEND_STOP,
TRANSMIT_BYTE
);

signal uart_state : uart_state_type := TX_IDLE;
signal next_uart_state : uart_state_type := TX_IDLE;


signal tx_data_byte : STD_LOGIC_VECTOR(7 downto 0) := (others=>'0');
signal tx_start_pulse : STD_LOGIC := '0';
signal tx_busy : STD_LOGIC := '0';
signal tx_shift_reg : STD_LOGIC_VECTOR(9 downto 0) := (others=>'0');
signal uart_sig : STD_LOGIC := '1';


--timer register signal for UART transfer
signal uart_timer_count : unsigned(26 downto 0) := (others=>'0');
signal send_trigger : STD_LOGIC := '0';

begin


--XADC Control and Data Latching Process
process(clk)
begin
    if rising_edge(clk) then
        new_sample_ready <= '0'; --pulse low until sample is ready
        case adc_state is
            when IDLE => 
                if xadc_eos = '1' then
                    adc_state <= WAIT_DRDY;
                else
                    adc_state <= IDLE;
                end if;                                    
        
--          when READ_REQ =>
--              xadc_en <= '1';
--              next_state <= WAIT_DRDY;
            when WAIT_DRDY =>
                if xadc_ready = '1' then
                    adc_state <= SAVE_DATA;
                else
                    adc_state <= WAIT_DRDY;
                end if;
            when SAVE_DATA =>
                data_reg <= adc_data; --
                new_sample_ready <= '1'; --enable the UART by pulsing HIGH
                adc_state <= WAIT_DRDY; --repeat process
            when others =>
                adc_state <= IDLE;                                                         
        end case;        
    end if;
end process;

--MQ3 Sensor Instatiation
MQ3_XADC: xadc_mq3_sensor port map(
    daddr_in => "0010011",
    dclk_in => clk,
    den_in => test_eoc,
    di_in => x"0000",
    dwe_in => '0',
    drdy_out => xadc_ready,
    do_out => adc_data,
    vauxp3 => vauxp3,
    vauxn3 => vauxn3,
    vp_in => '0',
    vn_in => '0',
    reset_in => '0',
    user_temp_alarm_out => open,
    vccint_alarm_out=>open,
    vccaux_alarm_out=>open,
    channel_out=> open,
    eoc_out=> test_eoc,
    alarm_out => open,
    eos_out=>xadc_eos,
    busy_out=>open
);


--UART TIMER for Pulse Generation
process(clk)
begin
    if rising_edge(clk) then
        send_trigger <= '0';
        if uart_timer_count < 20000000 then
            uart_timer_count <= uart_timer_count + 1;
        else
            uart_timer_count <= (others => '0');
            send_trigger <= '1';
        end if;
    end if;
end process;


--UART State Machine
process(clk)
begin
    if rising_edge(clk) then
        tx_start_pulse <= '0';
        
        case uart_state is
            when TX_IDLE => 
                if send_trigger ='1' then --this is to synchronize with the XADC flag
                    tx_data_byte <= x"AA"; --start byte 1010101010 for synchronization. "WAKE UP"
                    tx_start_pulse <= '1';
                    uart_state <= SEND_HIGH; --this is the next state after start byte sent
                    --uart_state <= TRANSMIT_BYTE;     --sending for transmission
                end if;
            when SEND_HIGH => 
                if tx_busy ='1' then
                    tx_data_byte <= data_reg(15 downto 8); -- upper bits of the data 
                elsif tx_busy ='0' and tx_start_pulse ='0' then
                    tx_start_pulse <= '1'; --pulse high again
                    --next_uart_state <= SEND_STOP;
                    uart_state <= SEND_LOW;
                end if;            
            when SEND_LOW => 
                if tx_busy ='1' then
                    tx_data_byte <= data_reg(7 downto 0); --lower bits of the data
                elsif tx_busy='0' and tx_start_pulse ='0' then
                    tx_start_pulse <= '1';
                    --next_uart_state <= SEND_STOP;
                    uart_state <= SEND_STOP;
                end if;
            when SEND_STOP=>
                if tx_busy ='1' then
                    tx_data_byte <= x"55"; --stop sync 0101 0101
                elsif tx_busy='0' and tx_start_pulse ='0' then
                    tx_start_pulse <= '1';
                    --next_uart_state <= TX_IDLE;
                    uart_state <= TRANSMIT_BYTE;
                end if;
            when TRANSMIT_BYTE =>
                --hold state until the underlying physical shift register is done
                if tx_busy = '0' and tx_start_pulse ='0' then
                    uart_state <= TX_IDLE;
                end if;
            when others =>
                uart_state <= TX_IDLE;                                                 
        end case;
    end if;
end process;


--UART serial transmitter
process(clk)
begin
    if rising_edge(clk) then
        if tx_busy ='0' then
            uart_sig <= '1';
            if tx_start_pulse = '1' then
                tx_shift_reg <= '1' & tx_data_byte & '0';
                tx_busy <='1';
                clk_count <= 0;
                bit_index <= 0;
            end if;
        else
            if clk_count < BIT_PERIOD -1 then
                clk_count <= clk_count+1;
            else
                clk_count <= 0;
                uart_sig <= tx_shift_reg(0); 
                tx_shift_reg <= '1' & tx_shift_reg(9 downto 1);
                
                if bit_index = 9 then
                    tx_busy <= '0';
                else
                    bit_index <= bit_index+1;
                end if;
            end if;     
        end if;    
    end if;
end process;



CLEAN_DISPLAY: process(data_reg)
    variable data_12bit : unsigned(11 downto 0);
begin
    data_12bit := unsigned(data_reg(15 downto 4));
    
    --led(15 downto 12) <= (others => '0');
    led(11 downto 0) <= (others => '0');
    
    if data_12bit > 3685 then
        led(11 downto 0) <= (others=>'1');
    elsif data_12bit > 3276 then
        led(9 downto 0) <= (others=> '1');
    elsif data_12bit > 2867 then
        led(7 downto 0) <= (others => '1');
    elsif data_12bit > 2457 then
        led(5 downto 0) <= (others => '1');
    elsif data_12bit > 2048 then
        led(3 downto 0) <= (others => '1');
    elsif data_12bit > 1228 then
        led(1 downto 0) <= (others=> '1');
    elsif data_12bit > 409 then
        led(0) <= '1';
    end if;    
end process CLEAN_DISPLAY;

uart_tx_out <= uart_sig;

led(15) <= uart_sig;
led(14) <= tx_busy;
led(13) <= new_sample_ready;



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
