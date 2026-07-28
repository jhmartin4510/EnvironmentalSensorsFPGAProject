# EnvironmentalSensorsFPGAProject
This is a repository that contains projects for implementing reading from sensors for the Artix-7-T100 FPGA.


## 1. Installation Considerations
Each of these module run thorugh the use of software: Vivado and Pyhon (via Anaconda). You can follow these installation steps from the Installations folder that contain info for downloading and preparing development environment.

Refer to this directory first if you do not have the needed software downloaded yet. 

*Note: Future designs of this are to reduce the number of components such as: 
* alternatives for power source. This would enable the possibility of moving the FPGA to the field and less dependence on a computer that requires vivado for loading program onto FPGA. 
* considering flash storage implementation of reading program and writing to SD. This allows for FPGA to move in the field with Vivado needing to load the bitsream. it can also be useful for loading readings onto an SD card. 

*Note: Vivado is only able to be used on a Mac using a Windows emulator. Please refer to those set-up instructions and be mindful about configuring drivers so program can speak to FPGA. 