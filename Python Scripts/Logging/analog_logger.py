import serial
import time
import csv
import sys
import argparse
from analog_conversions import process_adc_data


##The terminal argument functions
parser = argparse.ArgumentParser(description ="FPGA ADC Serial logger")
parser.add_argument("sensor", type=str, help="Sensor type (e.g. 'mq3', 'mq135', 'ir')")
parser.add_argument("--port", type=str, default = "COM4", help="Serial COM Port (adjust for your computer)") #change this argument for your computer
args = parser.parse_args()


SERIAL_PORT = args.port #change the COM Port to correct COM port for your machine. 
BAUD_RATE = 115200
LOG_FILE = f"{args.sensor}_sensor_log.csv"

#This is the first run to retrieve headers for initialization
_, _, headers, _ = process_adc_data(args.sensor, 0.0001)

#preparing for CSV file writing
with open(LOG_FILE, mode = 'w', newline = '') as file:
    writer = csv.writer(file)
    writer = writer.writerow(headers) #obtaining the header for csv file according to sensor



print(f"Logging {args.sensor.upper()} data from {SERIAL_PORT} to {LOG_FILE}.... Press ctrl + C to stop. \n")

#reading from the serial port 
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

                    #convert this data to measurement data
                    sensor_voltage, log_data, _, display_str = process_adc_data(args.sensor, true_12bit)

                    timestamp = time.strftime('%Y-%m-%d %H:%M:%S')
                    print(f"[{timestamp}] {display_str}")
                        
                    with open(LOG_FILE, mode = 'a', newline='') as file:
                        writer = csv.writer(file)
                        writer.writerow([timestamp] + log_data)
                else:
                    ser.reset_input_buffer()

except KeyboardInterrupt:
    print("\nData logging safely stopped.")

