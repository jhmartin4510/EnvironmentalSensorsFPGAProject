## Logging and Data Analytics Scripts

These are python scripts written to read from the UART transmit line of the FPGA. Since the interpretation of the raw data received from the FPGA can vary for different sensors such as the number of serial reads for the data to be read AND converting that data to meaningful value (PPM, cm, etc.) for the purpose the sensor is being used for. 

Additionally, there WILL BE A directory functions that the laoder will accesss to ensure running correct conversion and configurations

Additional statistical function: 
* Plotting the data in real time according to sampling rate (1 s reading)
* Anomaly detection for thresholds provided (depending on sensor reading)
* Moving average
* standard deviation 
* Others to be considered: min-hold filter for tracking the lowest recorded baseline value and using that for adapting to different environmonets 

*NOTE: There WILL NEED TO BE AN initialization folder that loads the correct type of logging parameters for a given sensor. 

Here you will find the following:

* **Logging Scripts** adapted for a particular sensor. Future design ideas: instead of making multiple logging scripts, adapting a general script and configuring to a sensor by intializing reading via a terminal input or a JSON configuraiton script is the next approach

* **Sensor Conversion Script** : containing the conversions from the sensor voltage to the measurement reading for a particular sensor. 

* **Analytical Functions Script:** : contains any analytical functions called by the logging script to report quick statistics to the terminal and plot data onto a live graph for understanding data representation. 