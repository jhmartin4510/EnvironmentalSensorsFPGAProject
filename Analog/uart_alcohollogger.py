import serial
import time
import csv

SERIAL_PORT = 'COM4'
BAUD_RATE = 115200
LOG_FILE = "AlcoholLogRevised.csv"

VoltMultiplier = 5.0
RL_LOAD_RESISTOR = 10000
V_IN =5.0

#Datasheet values 
PPM_A_COEFFICIENT = 270.0
PPM_B_EXPONENT = -1.607


#Clean Air Baseline
V_CLEAN_AIR = 0.394

#Calibrate Rs in Clean Air
rs_air = RL_LOAD_RESISTOR * ((V_IN - V_CLEAN_AIR) / V_CLEAN_AIR)

R0 = rs_air / 60.0

with open(LOG_FILE, mode = 'w', newline = '') as file:
    writer = csv.writer(file)
    writer.writerow(["Timestamp", "Sensor_Voltage_V","Rs/R0_Ratio","Concentration_PPM", "Concentration_mg_L"])
print(f"Obtain data from {SERIAL_PORT} at {BAUD_RATE} baud")
print(f"Logging Data to {LOG_FILE}. Press ctrl + C to stop. \n")


try:
    ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)

    ser.reset_input_buffer()

    while True:
        start_byte = ser.read(1)
        #check this line if it is working or not 
        if start_byte == b'\xAA':

            payload = ser.read(3)

            if len(payload) ==3:
                high_byte = payload[0]
                low_byte = payload[1]
                stop_byte = payload[2]
            
                if stop_byte == 0x55:

                    raw_16bit= (high_byte << 8) | low_byte

                    true_12bit = (raw_16bit >>4) & 0x0FFF

                    fpga_pin_voltage = (true_12bit/ 4095.0)*1.0

                    sensor_voltage = fpga_pin_voltage * VoltMultiplier

                    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
                    print(f"[{timestamp}] Raw Hex: 0x{raw_16bit:04X} | 12-Bit: {true_12bit:4d} | Sensor: {sensor_voltage:.3f} V")

                    with open(LOG_FILE, mode = 'a', newline='') as file:
                        writer = csv.writer(file)
                        writer.writerow([
                            timestamp,
                            f"0x{raw_16bit:04X}",
                            true_12bit,
                            f"{sensor_voltage:.3f}"
                        ])


                else:
                    ser.reset_input_buffer()

except serial.SerialException as e:
    print(f"\nSerial Port error: {e}")
    print("Please check COM port number and ensure no other terminal is using it")
except KeyboardInterrupt:
    print("\nData logging safely stopped.")

