# Sensors with Analog Signals

This is directory of projects for programming the A7-T100 FPGA with Analog Sensors and considerations. Each of these projects depend on the implementation fo the XADC 

## Electrical Considerations
Before connecting the sensor to the FPGA,  **the voltage range to safely connect to the FPGAs XADC is between 0-1 V relative to the analog ground.** You will need to look at the range of the analog output from the sensor to ensure that the signal is in this safe range. 

For these examples, the README file in the particular directory explains the voltage divider circuit used to safely read data from the sensor, if needed. Please make sure to observe that the analog signal is within this range. 

## Implementing the XADC Block  
Each of these pojects ultize the XADC analog-to-digital converter embedded on the FPGA through the dynamic reconfiguration port (DRP) bus interface. This converts to the analog singal to a 12-bit bus. 

For implementing the XADC, the XADC Wizard tool that is a part of the Vivado environment was used for configuration of the XADC IP core. More details on using the XADC Wizard and navigating the several settings and decisions can be found in the attached Word document. 

Here is a brief summary of the decisions made for creating the .xci file for the MQ3. 

## Reading the 12-bit Sensor Data and Making Meaning of the Reading
Fortunately, this .xci file was used and tested on for the MQ135 sensor AND the IR distance (SHARP) sensor. All worked fine with converting the analog signal to a digital binary signal, but each sensor has particular specifications for making meaning out of the analog sensor reading. For the example provided, a leveled approach was used to classify the level of alcohol gas from low level (2-4 LEDs ON) to high levels (6-9 LEDs ON). The level shift approach was only used for testing and confirming that board is receiving a reading from the sensor. 

Many analog sensor have transfers functions described in their datasheets for estimating measurements. This type of measurement conversion is part of the task for the python script particularly if the objective is recording analytical information. While vhdl code can be used to convert the the 12-bit data to a meaningful measurement value, this approach can be resource intensive and require steps for conversion that could be computing uisng a module OR creating a look up table for all possible 4095 values and then if using the 7-segment display, decoding the value to BCD and a multiplexer for reading each digit simultaneously.

To simplify the approach, the FPGAs sole purpose is to read the analog signal and convert it to a 12-bit dgital value. This digital value can be passed to a python script that converts the value to a relavent meauserment (ppm) and records that value in a csv file. The information from the csv file can then be used for visualization and monitoring. 

## The MQ3 Directory
This contains the design source file (.vhd), the constraint file (.xdc), an the XADC IP core (.xci) file used for the MQ3 sensor (alcohol gas sensor). However, those same files were successfully used for reading from the MQ135 sensor (gas sensor), and the IR distance sensor. The added python scripts perform the task of decoding the 12-bit data into the respective measurement via the transfer function for their respective datasheets.   


