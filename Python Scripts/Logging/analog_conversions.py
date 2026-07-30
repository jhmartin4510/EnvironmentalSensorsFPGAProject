import math

def convert_mq3(data, v_in=5.0, rl = 10000.0, v_clean_air= 0.7): #this was read from the v_clean_air reading 
    """Calculates data received by the MQ-3 data into reading: Voltage, PPM, and mg/L."""
    #Scaling voltage to the 5 V
    fpga_out = (data / 4095.0)
    ##this is a scaling factor for attenuation by the resistance from the potentiometer
    ##1.56 V (true value from multimeter)/ 0.48 V (from FPGA out)
    ##adjust this according to your sensor reading
    attenuation = 5.294
    sensor_scaled = fpga_out * attenuation

    #sensor resistance and baseline
    rs = rl * ((v_in - sensor_scaled) / sensor_scaled)
    rs_clean = rl * ((v_in - v_clean_air) / v_clean_air)
    r0 = rs_clean #divisor needs to be adjusted according clean air

    ratio = rs/ r0
    ppm = 12.5 * math.pow(ratio, -1.607)  
    mg_l = (ppm * 46.07) / 24450

    #Header for csv file
    header = ["Timestamp", "Sensor_Voltage_V", "PPM", "mg_L"]
    log_data = [f"{sensor_scaled:.3f}", f"{ppm:.1f}", f"{mg_l:.3f}"]
    display = f"Voltage: {sensor_scaled:.3f} V | PPM: {ppm:.1f} | mg/L: {mg_l:.3f}"

    return sensor_scaled, log_data, header, display


def convert_mq135(data, v_in = 5.0, rl = 10000.0, v_clean_air=0.100):
    """This converts for data reading from the MQ-135 sensor. 
    Please be advised regarding these conditions:
    1. check what the sensor reads in clean air (your environment or outside). This is needed to scale correct
    2. 
    """
    fpga_out = (data / 4095.0) * 1.0
    sensor_scaled = fpga_out * 5.0

    rs = rl * ((v_in - sensor_scaled) / sensor_scaled)

    v_clean_scaled = v_clean_air * 5.0
    rs_clean = rl * ((v_in - v_clean_scaled) / v_clean_scaled)
    r0 = rs_clean /3.6

    ratio = rs/r0

    ppm = 110.47 * math.pow(ratio, -2.862)

    header = ["Timestamp", "Sensor_Voltage_V", "PPM_CO2"]
    log_data = [f"{sensor_scaled:.3f}", f"{ppm:.1f}"]
    display = f"Voltage: {sensor_scaled:.3f} V | CO2: {ppm:.1f}"

    return sensor_scaled, log_data, header, display







SENSOR_MAP = {
    'mq3' : convert_mq3,
    'mq135' : convert_mq135
    }

def process_adc_data(sensor_name, data):
    """Function that will be called in the logger script"""
    sensor_key = sensor_name.lower()
    if sensor_key in SENSOR_MAP:
        return SENSOR_MAP[sensor_key](data)
    else:
        raise ValueError(f"Unknown sensor '{sensor_name}'. Valid Options: {list(SENSOR_MAP.keys())} ")

    


