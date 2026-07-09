----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/08/2025 02:42:02 PM
-- Design Name: 
-- Module Name: TMP3_i2cmaster - Behavioral
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
use IEEE.NUMERIC_STD.All;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


-----------------------------------------------------------------------------------
--this module runs the I2C protocol for the TMP3 sensor:
--State Machine Guides:
--1. IDLE: the resting state where no transactions is active
--2. START: signals sensor to pay attention (SDA low/SCL high)
--3. SEND_ADDR: Sends the access of the TMP3 device (0x1001000) [JP3/JP2/JP1 set to GND]
--4. RX_ACK: acknowledgment from sensor of request (pulls SDA line low)
--5. READ_DATA: FPGA reads data from address (temperature reading in binary)
--6. TX_NACK: a mechanism for stopping to receive data (data completed)
--7. STOP: STOPS the receive transaction. sends data to logger and the raedy pulse to trigger reporting data via LED lights (binary)
-----------------------------------------------------------------------------------

entity TMP3_i2cmaster is
    Port (
        --system signals
           clk : in STD_LOGIC;   --100 MHz system clock
           reset_n : in STD_LOGIC;
           
           --I2C bus signals
           scl : out STD_LOGIC;
           sda : inout STD_LOGIC;
           
           temp_out : out STD_LOGIC_VECTOR(7 downto 0);
           data_ready : out STD_LOGIC
           );
end TMP3_i2cmaster;

architecture Behavioral of TMP3_i2cmaster is

--Timing Logic
constant TICK_MAX : integer := 250; --pulse 4x faster than bit rate
signal tick_cnt : integer range 0 to TICK_MAX := 0; 
signal i2c_tick : std_logic := '0'; --pulses once per i2c bit period


--I2C state machine states
type i2c_state_t is(
    IDLE,
    START, -- generate I2c start condition
    SEND_ADDR, --sending the address for reading 
    RX_ACK, --receive acknowledgement
    READ_DATA, --reading data from this address
    TX_NACK, --transmit Not acknowledge (sda high)
    STOP -- stop bit
);
signal current_state : i2c_state_t := IDLE;
signal sub_state : integer range 0 to 3 := 0; --making states for the scl clock to ensure correct data is read 
signal bit_idx : integer range 0 to 7 := 7;

--Bidirectional SDA Control
signal sda_en : STD_LOGIC := '0'; --1= drive '0', 0 = 'Z' due to open drain
signal scl_en : STD_LOGIC := '0';
signal data_reg : std_logic_vector(7 downto 0) := (others => '0');
signal addr_reg : std_logic_vector(7 downto 0) := "10010001"; --this is the slave address + the read bit for reading the data from there


begin

--SDA tristate buffer
sda <= '0' when sda_en = '1' else 'Z';
scl <= '0' when scl_en = '1' else 'Z';



---------------------------------------------
--Clock Divider
---------------------------------------------
process(clk, reset_n)
begin
            if reset_n = '0' then
               tick_cnt <= 0;
               i2c_tick <= '0';
            elsif rising_edge(clk) then             
                if tick_cnt = TICK_MAX - 1 then
                    tick_cnt <= 0;
                    i2c_tick <= '1'; -- pulse for one clock cycle
                else
                    tick_cnt <= tick_cnt + 1;
                    i2c_tick <= '0';
                end if;                            
            end if;
 end process;          
 ----------------------------------------------
  --state machine logic
 -----------------------------------------------             
    process(clk,reset_n)
    begin
        if reset_n = '0' then
                --reset all signals
            current_state <= IDLE;
            sda_en <= '0';
            scl_en <= '0';
            data_ready <= '0';
        elsif rising_edge(clk) then
            if i2c_tick = '1' then
                case current_state is
                    when IDLE => 
                        data_ready <= '0';
                        sda_en <= '0'; 
                        scl_en <= '0';
                        bit_idx <= 7;
                        current_state <= START;
                    when START => 
                        case sub_state is
                            when 0 => sda_en <= '1'; --Start: SDA falls while SCL is high
                            when 1 => scl_en <= '1'; --SCL falls
                                sub_state <= 0;
                                current_state <= SEND_ADDR;
                            when others => null;
                        end case;
                        if sub_state = 0 then sub_state <= 1; 
                        end if;        
                        
                    when SEND_ADDR =>
                        case sub_state is
                            when 0 => sda_en <= not addr_reg(bit_idx); --set data
                            when 1 => scL_en <= '0'; --release scl high
                            when 2 => null;
                            when 3 => scl_en <= '1';
                                if bit_idx = 0 then
                                    current_state <= RX_ACK;
                                else
                                    bit_idx <= bit_idx -1;
                                end if;                                                            
                        end case;
                        sub_state <= sub_state + 1;
                        
                    when RX_ACK => 
                        case sub_state is
                            when 0 => sda_en <= '0'; --release SDA to look for ACk
                            when 1 => scl_en <= '0'; --SCL high
                            when 2 => 
                            when 3 => scl_en <= '1';
                                        bit_idx <= 7;
                                        current_state <= READ_DATA;
                        end case;
                        sub_state <= sub_state + 1;
                    when READ_DATA => 
                        case sub_state is
                            when 0 => sda_en <= '0'; --ensure floating for read
                            when 1 => scl_en <= '0';
                            when 2 => data_reg(bit_idx) <= to_x01(sda);
                            when 3 => scl_en <= '1';
                                if bit_idx = 0 then
                                    current_state <= TX_NACK;
                                else
                                    bit_idx <= bit_idx -1;
                                end if;
                        end case;                               
                        sub_state <= sub_state + 1; 
                        
                    when TX_NACK =>
                        case sub_state is
                            when 0 => sda_en <= '0';
                            when 1 => scl_en <= '0';
                            when 2 => null;
                            when 3 => scl_en <= '1';
                                    current_state <= STOP;
                        end case;
                        sub_state <= sub_state +1;
                    
                    when STOP =>
                        case sub_state is
                            when 0 => sda_en <= '1';
                            when 1 => scl_en <= '0';
                            when 2 => sda_en <= '0';
                            when 3 => current_state <= IDLE;
                                temp_out <= data_reg;
                                data_ready <= '1';
                        end case;
                        sub_state <= sub_state + 1;
                end case; 
            end if;
        end if;
    end process;                         
end Behavioral;
