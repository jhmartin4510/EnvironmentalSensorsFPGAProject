----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:
-- Design Name: 
-- Module Name: 
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
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
--REVISION: This has been adjusted to accommodate the VEML 7700 sensor :
--State Machine Guides:
--1.POWER_ON_INIT, --this is for reset before talking with VEML 7700
--2. START_GEN, --START condition
--3. REP_START_GEN, --repeat START condition. Testing for separation of warmup start and reading start
--4. SEND_BYTE, --transmit a byte out of tx_shift_reg
--5. RX_ACK, --check for slave ACK
--6. READ_LSB_BYTE, -- read 1st data byte (LSB)
--7. TX_ACK, --fpga send ACK (SDA low)
--8. READ_MSB_BYTE, --read 2nd data byte (MSB)
--9. TX_NACK, --Master sends NACK (SDA high)
--10. STOP_GEN, --generate STOP condition
--11. WAIT_INTEGRATION --wait 100ms before next sample
-----------------------------------------------------------------------------------

entity VEML7700_i2cmaster is
    Port (
        --system signals
           clk : in STD_LOGIC;   --100 MHz system clock
           reset_n : in STD_LOGIC;
           
           --I2C bus signals
           scl : inout STD_LOGIC;
           sda : inout STD_LOGIC;
           
           als_out : out STD_LOGIC_VECTOR(15 downto 0); --changed to 16-bit data
           data_ready : out STD_LOGIC
           );
end VEML7700_i2cmaster;

architecture Behavioral of VEML7700 is

--Timing Logic
constant TICK_MAX : integer := 250; --pulse 4x faster than bit rate. tick pulses 4xper bit.keep
signal tick_cnt : integer range 0 to TICK_MAX := 0; 
signal i2c_tick : std_logic := '0'; --pulses once per i2c bit period


--I2C state machine states
--Revised: added configuration steps for warming up device before reading sensor data
type i2c_state_t is(
    POWER_ON_INIT, --this is for reset before talking with VEML 7700

    START_GEN, --START condition
    REP_START_GEN, --repeat START condition. Testing for separation of warmup start and reading start
    SEND_BYTE, --transmit a byte out of tx_shift_reg
    RX_ACK, --check for slave ACK
    READ_LSB_BYTE, -- read 1st data byte (LSB)
    TX_ACK, --fpga send ACK (SDA low)
    READ_MSB_BYTE, --read 2nd data byte (MSB)
    TX_NACK, --Master sends NACK (SDA high)
    STOP_GEN, --generate STOP condition
    WAIT_INTEGRATION --wait 100ms before next sample 
);

-- FSM State Signal
signal current_state : i2c_state_t := POWER_ON_INIT;
signal next_step : i2c_state_t := POWER_ON_INIT;

signal sub_state : integer range 0 to 3 := 0; --making states for the scl clock to ensure correct data is read 
signal bit_idx : integer range 0 to 7 := 7;
signal delay_cnt : integer range 0 to 40000 := 0; -- Used for millisecond timing delays

--Bidirectional SDA Control
signal sda_en : STD_LOGIC := '0'; --1= drive '0', 0 = 'Z' due to open drain
signal scl_en : STD_LOGIC := '0';

signal tx_shift_reg : std_logic_vector(7 downto 0) := (others => '0');
signal lsb_data_reg : std_logic_vector(7 downto 0) := (others => '0');
signal msb_data_reg : std_logic_vector(7 downto 0) := (others => '0');

--Addresses for Writing and Reading from the VEML7700
constant SLAVE_ADDR_WRITE : std_logic_vector(7 downto 0) := "00100000"; -- 0x20 for write
constant SLAVE_ADDR_READ  : std_logic_vector(7 downto 0) := "00100001"; -- 0x21 for read
constant 

-- VEML7700 Internal Registers
constant REG_CONF     : std_logic_vector(7 downto 0) := "00000000"; -- Reg 0x00 (Config)
constant REG_ALS_DATA : std_logic_vector(7 downto 0) := "00000100"; -- Reg 0x04 (Light Data)

--Synchronized SDA input for reading
signal sda_in : std_logic := '1';



begin

--SDA tristate buffer
sda <= '0' when sda_en = '1' else 'Z';
scl <= '0' when scl_en = '1' else 'Z';


--Synchronize asynchronous SDA input
process(clk)
begin
	if rising_edge(clk) then
		sda_in <= sda;
	end if;
end process;




---------------------------------------------
--Clock Divider: 400 kHz i2c_tick
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
  --state machine logic (i2c controller)
 -----------------------------------------------             
    process(clk,reset_n)
    begin
        if reset_n = '0' then
            --reset all signals
            current_state <= POWER_ON_INIT;
            next_step <= POWER_ON_INIT;
            sda_en <= '0';
            scl_en <= '0';
            sub_state <= 0;
            bit_idx <= 7;
            delay_cnt <= 0;
            data_ready <= '0';
            als_out <= (others => '0')
        elsif rising_edge(clk) then
            if i2c_tick = '1' then
                case current_state is
                    
                	--Power-On Delay
                    when POWER_ON_INIT => 
                        sda_en <= '0'; 
                        scl_en <= '0';
                        if delay_cnt < 1000 then --1000 ticks = 2.5 ms
                        	delay_cnt <= delay_cnt +1; --counts up to 1000 for power up
                    	else
                    		delay_cnt <= 0;
                    		tx_shift_reg <= SLAVE_ADDR_WRITE;
                    		next_step <= CONFIG_SEND_REG;
                    		current_state <= START_GEN
                		end if;

                	--generate START Condition
            		when START_GEN =>
            			case sub_state is
            				when 0 => 
            					sda_en <= '1'; --sda drops
            					scl_en <= '0'; --scl high
        					when 1 => 
        						scl_en <= '1';
    						when 2 => null; --hold sig
    						when 3 => 
    							sub_state <= 0;
    							bit_idx <= 7;
    							current_state <= SEND_BYTE;
							when others => null;
						end case;
						if sub_state /= 3 then 
							sub_state <= sub_state + 1;
						end if;

					--transmit 8 bits out to tx_shift_reg
					when SEND_BYTE => 
						case sub_state is
							when 0 =>
								sda_en <= not tx_shift_reg(bit_idx); --set data bit 
							when 1 => 
								scl_en <= '0'; --release scl high
							when 2 => null;
							when 3 =>
								scl_en <= '1';
								if bit_idx = 0 then
									sub_state <= 0;
									current_state <= RX_ACK;
								else
									bit_idx <= bit_idx -1;
									sub_state <= 0;
								end if;
							when others => null;
						end case;


					--check state ACK
					when RX_ACK => 
						case sub_state is
							when 0 => 
								sda_en <= '0'; --release SDA line to read ACK
							when 1 => 
								scl_en <= '0'; --relaese scl high
							when 2 => null;
							when 3 => 
								scl_en <= '1'; --drive SCL low 
								sub_state <= 0;
								bit_idx <= 7;

								--sequencing logic: choose what byte comes next
								case next_step is
									when CONFIG_SEND_REG =>
										tx_shift_reg <= REG_CONF;
										next_step <= CONFIG_SEND_LSB;
										current_state <= SEND_BYTE;
									
									when CONFIG_SEND_LSB =>
										tx_shift_reg <= CONF_LSB_DATA;
										next_step <= CONFIG_SEND_MSB;
										current_state <= SEND_BYTE;
									
									when CONFIG_SEND_MSB => 
										tx_shift_reg <= CONF_MSB_DATA;
										next_step <= READ_START;
										current_state <= SEND_BYTE;
									
									when READ_START =>  
										current_state <= STOP_GEN;

									when READ_SEND_REG => 
										tx_shift_reg <= REG_ALS_DATA;
										next_step <= READ_REP_START;
										current_state <= SEND_BYTE;

									when READ_REP_START => 
										current_state <= REP_START_GEN;

									when READ_LSB_BYTE => 
										current_state <= READ_LSB_BYTE;

									when others => 
										current_state <= STOP_GEN;
								end case;
							when others => null;
						end case;
						if sub_state /= 3 then
							sub_state <= sub_state + 1;
						end if;


					when REP_START_GEN => 
						case sub_state is
							when 0 => 
								--SDA and SCL lines are high
								sda_en <= '0'; 
								scl_en <= '0';
							when 1 => 
								sda_en <= '1'; --sda drops, scl high
							when 2 => 
								scl_en <= '1'; --scl falls
							when 3 => 
								sub_state <= 0;
								bit_idx <= 7;
								tx_shift_reg <= SLAVE_ADDR_READ;
								next_step <= READ_LSB_BYTE;
								current_state <= SEND_BYTE;
							when others => null;
						end case;
						if sub_state /= 3 then 
							sub_state <= sub_state + 1;
						end if;

					--read first byte
					when READ_LSB_BYTE => 
						case sub_state is 
							when 0 => 
								sda_en <= '0'; --release SDA line
							when 1 => 
								scl_en <= '0'; --SCL high
							when 2 =>
								lsb_data_reg(bit_idx) <= to_x01(sda_in); --sample data
							when 3 => 
								scl_en <= '1'; --scl low
								if bit_idx = 0 then
									sub_state <= 0;
									current_state <= TX_ACK;
								else
									bit_idx <= bit_idx - 1;
									sub_state <= 0;
								end if;
							when others => null;
						end case;
						if sub_state /= 3 then
							sub_state <= sub_state + 1;
						end if;

					--Master sends ACK (sda driven low)
					when TX_ACK => 
						case sub_state is
							when 0 => 
								sda_en <= '1'; --drive SDA low
							when 1 => 
								scl_en <= '0'; --SCL high
							when 2 => null;
							when 3 => 
								scl_en <= '1'; SCL low
								sub_state <= 0;
								bit_idx <= 7;
								current_state <= READ_MSB_BYTE;
							when others => null;
						end case;
						if sub_state /= 3 then
							sub_state <= sub_sate + 1;
						end if; 


					--read 2nd byte
					when READ_MSB_BYTE => 
						case sub_state is
							when 0 =>
								sda_en <= '0'; --release SDA line
							when 1 => 
								scl_en <= '0'; --SCL high
							when 2 =>
								msb_data_reg(bit_idx) <= to_x01(sda_in); --sample data
							when 3 =>
								scl_en <= '1'; --SCL low
								if bit_idx = 0 then
									sub_state <= 0; 
									current_state <= TX_NACK;
								else 
									bit_idx <= bit_idx -1;
									sub_state <= 0;
								end if;
							when others => null;
						end case;
						if sub_state /= 3 then
							sub_state <= sub_state + 1; 
						end if;

					--FPGA send NACK
					when TX_NACK => 
						case sub_state is
							when 0 => 
								sda_en <= '0'; --release SDA High
							when 1 => 
								scl_en <= '0'; --SCL high
							when 2 => null;
							when 3 => 
								scl_en <= '1'; -- scl low
								sub_state <= 0;
								current_state <= STOP_GEN;
							when others => null;
						end case;
						if sub_state /= 3 then
							sub_state <= sub_state + 1;
						end if;

					--generate STOP condition
					when STOP_GEN => 
						case sub_state is
							when 0 => 
								sda_en <= '1'; --SDA low
							when 1 => 
								scl_en <= '0'; --SCL high
							when 2 =>
								sda_en <= '0'; --SDA rise
							when 3 => 
								sub_state <= 0;
								if next_step = READ_START then
									--initialization done, now reading from sensor
									tx_shift_reg <= SLAVE_ADDR_WRITE;
									next_step <= READ_SEND_REG;
									current_state <= WAIT_INTEGRATION;
								else
									--data sequence complete
									als_out <= msb_data_reg & Lsb_data_reg; --concatenate
									data_ready <= '1';
									tx_shift_reg <= SLAVE_ADDR_WRITE;
									next_step <= READ_SEND_REG;
									current_state <= WAIT_INTEGRATION;
								end if;
							when others => null;
						end case;
						if sub_state /= 3 then
							sub_state <= sub_state + 1;
						end if;

					when WAIT_INTEGRATION => 
						data_ready <= '0';
						--wait interval
						if delay_cnt < 40000 then 
							delay_cnt <= delay_cnt + 1;
						else
							delay_cnt <= 0;
							current_state <= START_GEN;
						end if;
				end case;
			end if;
		end if;
	end process;
end Behavioral; 