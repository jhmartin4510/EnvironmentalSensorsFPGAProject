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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Top is
    Port ( 
        CLK100MHZ   : in    STD_LOGIC;                      -- 100 MHz System Clock
        CPU_RESETN  : in    STD_LOGIC;                      -- Active low reset button
        veml_sda    : inout STD_LOGIC;                      -- I2C SDA
        veml_scl    : inout STD_LOGIC;                      -- I2C SCL
        led         : out   STD_LOGIC_VECTOR (15 downto 0); -- board LEDS
        uart_tx_pin : out   STD_LOGIC                       -- UART pin
    );
end Top;

architecture Structural of Top is

    -- 1. VEML7700 I2C Controller Component
    component VEML7700_i2cmaster is
        Port (
            clk        : in    STD_LOGIC;
            reset_n    : in    STD_LOGIC;
            scl        : inout STD_LOGIC;
            sda        : inout STD_LOGIC;
            als_out    : out   STD_LOGIC_VECTOR(15 downto 0);
            data_ready : out   STD_LOGIC
        );
    end component;

    -- 2. Data Register Latch Component
    component veml7700_data_register is
        Port ( 
            clk         : in  STD_LOGIC;
            reset_n     : in  STD_LOGIC;
            we          : in  STD_LOGIC;
            input_data  : in  STD_LOGIC_VECTOR (15 downto 0);
            output_data : out STD_LOGIC_VECTOR (15 downto 0);
            ready_pulse : out STD_LOGIC
        );
    end component;

    -- UART Transmitter
    component uart_tx is
        Port (
            clk        : in  STD_LOGIC;
            reset_n    : in  STD_LOGIC;
            tx_trigger : in  STD_LOGIC;
            data_in    : in  STD_LOGIC_VECTOR(15 downto 0);
            tx_out     : out STD_LOGIC
        );
    end component;

    -- the ALS data signal
    signal w_als_raw    : std_logic_vector(15 downto 0);
    signal w_ready_tick : std_logic;                     -- TRIGGER PULSE

    signal w_final_data : std_logic_vector(15 downto 0); --final signal sent to LED

begin

    -- I2C Master: pulses 'data_ready' when a 16-bit word is complete
    I2C: VEML7700_i2cmaster 
        port map (
            clk        => CLK100MHZ,
            reset_n    => CPU_RESETN,
            sda        => veml_sda,
            scl        => veml_scl,
            als_out    => w_als_raw,
            data_ready => w_ready_tick -- Driven high for 1 clock cycle upon completed read
        );

    -- Data Register: for LED stability
    LOGGER: veml7700_data_register 
        port map (
            clk         => CLK100MHZ,
            reset_n     => CPU_RESETN,
            we          => w_ready_tick, -- Write enable
            input_data  => w_als_raw,
            output_data => w_final_data,
            ready_pulse => open
        );

    -- UART Logger: 'w_ready_tick' to immediately start serial packet transfer
    UART_LOGGER: uart_tx
        port map (
            clk        => CLK100MHZ,
            reset_n    => CPU_RESETN,
            tx_trigger => w_ready_tick, -- Listens to the same ready flag
            data_in    => w_final_data, -- Reads newly latched 16-bit word
            tx_out     => uart_tx_pin
        );

    -- Drive onboard LEDs with real-time latched reading
    led <= w_final_data;

end Structural;