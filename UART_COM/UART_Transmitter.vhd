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
-- Revision 
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


entity uart_tx is
    Port (
        clk        : in  STD_LOGIC;                     -- 100 MHz System Clock
        reset_n    : in  STD_LOGIC;                     -- Active-low Reset
        tx_trigger : in  STD_LOGIC;                     -- Pulse from controller
        data_in    : in  STD_LOGIC_VECTOR(15 downto 0); -- 16-bit data to transmit
        tx_out     : out STD_LOGIC                      -- UART TX pin
    );
end uart_tx;

architecture Behavioral of uart_tx is

    -- UART Transmitter Signals (115,200 BAUD @ 100 MHz clk)
    constant BIT_PERIOD : integer := 868; -- 100_000_000 / 115_200
    signal clk_count    : integer range 0 to BIT_PERIOD := 0;
    signal bit_index    : integer range 0 to 9 := 0;

    -- State Machine States
    type uart_state_type is (
        TX_IDLE, 
        SEND_START_BYTE, 
        SEND_HIGH_BYTE, 
        SEND_LOW_BYTE, 
        SEND_STOP_BYTE, 
        TRANSMIT_WAIT
    );

    signal uart_state     : uart_state_type := TX_IDLE;
    

    signal tx_data_byte   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal tx_start_pulse : STD_LOGIC := '0';
    signal tx_busy        : STD_LOGIC := '0';
    signal tx_shift_reg   : STD_LOGIC_VECTOR(9 downto 0) := (others => '0');
    signal uart_sig       : STD_LOGIC := '1';

    -- Data Latch Register
    signal latched_data   : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

    -- Trigger Rising-Edge Detector Signals
    signal trigger_d1     : STD_LOGIC := '0';
    signal trigger_d2     : STD_LOGIC := '0';
    signal trigger_pulse  : STD_LOGIC := '0';

begin

    --sending the final value back to the top module
    tx_out <= uart_sig;

    ---------------------------------------------------
    -- Edge Detection for External Trigger Signal
    --ensuring stable signal for uart processing
    ---------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            trigger_d1 <= '0';
            trigger_d2 <= '0';
        elsif rising_edge(clk) then
            trigger_d1 <= tx_trigger;
            trigger_d2 <= trigger_d1;
        end if;
    end process;

    -- Generates a single clock-cycle pulse when tx_trigger transitions low -> high
    trigger_pulse <= trigger_d1 and (not trigger_d2);

    ---------------------------------------------------
    -- UART STATE MAHCINE
    ---------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            uart_state     <= TX_IDLE;
            tx_start_pulse <= '0';
            tx_data_byte   <= (others => '0');
            latched_data   <= (others => '0');
            
        elsif rising_edge(clk) then
            tx_start_pulse <= '0';

            case uart_state is

                when TX_IDLE => 
                    -- Synchronize i2c and 
                    if trigger_pulse = '1' then
                        latched_data   <= data_in;   -- hold reading
                        tx_data_byte   <= x"AA";     -- Start byte (0xAA)
                        tx_start_pulse <= '1';
                        uart_state     <= SEND_START_BYTE;
                    end if;

                when SEND_START_BYTE => 
                    if tx_busy = '0' and tx_start_pulse = '0' then
                        tx_data_byte   <= latched_data(15 downto 8); -- Upper Byte
                        tx_start_pulse <= '1';
                        uart_state     <= SEND_HIGH_BYTE;
                    end if;

                when SEND_HIGH_BYTE => 
                    if tx_busy = '0' and tx_start_pulse = '0' then
                        tx_data_byte   <= latched_data(7 downto 0);  -- Lower Byte
                        tx_start_pulse <= '1';
                        uart_state     <= SEND_LOW_BYTE;
                    end if;

                when SEND_LOW_BYTE => 
                    if tx_busy = '0' and tx_start_pulse = '0' then
                        tx_data_byte   <= x"55";        -- End Byte (0x55)
                        tx_start_pulse <= '1';
                        uart_state     <= SEND_STOP_BYTE;
                    end if;

                when SEND_STOP_BYTE =>
                    if tx_busy = '0' and tx_start_pulse = '0' then
                        uart_state <= TRANSMIT_WAIT;
                    end if;

                when TRANSMIT_WAIT =>
                    if tx_busy = '0' then
                        uart_state <= TX_IDLE;
                    end if;

                when others =>
                    uart_state <= TX_IDLE;
                                                            
            end case;
        end if;
    end process;

    ---------------------------------------------------
    -- Serial UART Shift Register 
    ---------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            uart_sig     <= '1';
            tx_busy      <= '0';
            clk_count    <= 0;
            bit_index    <= 0;
            tx_shift_reg <= (others => '1');
            
        elsif rising_edge(clk) then
            if tx_busy = '0' then
                uart_sig <= '1';
                if tx_start_pulse = '1' then
                    tx_shift_reg <= '1' & tx_data_byte & '0';
                    tx_busy      <= '1';
                    clk_count    <= 0;
                    bit_index    <= 0;
                end if;
            else
                if clk_count < BIT_PERIOD - 1 then
                    clk_count <= clk_count + 1;
                else
                    clk_count    <= 0;
                    uart_sig     <= tx_shift_reg(0);
                    tx_shift_reg <= '1' & tx_shift_reg(9 downto 1);
                    
                    if bit_index = 9 then
                        tx_busy <= '0';
                    else
                        bit_index <= bit_index + 1;
                    end if;
                end if;     
            end if;    
        end if;
    end process;

end Behavioral;