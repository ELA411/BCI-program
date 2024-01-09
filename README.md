# BCI-program
## Dependencies
- Brainflow API
  
**Matlab Addons**
- Data Acquisition Toolbox
- Data Acquisition Support Package for National Instruments NI-DAQmx Devices
- Parallel Computing Toolbox
- ROS Toolbox
- Common Spatial Patterns
  

## Project structure
```
├── Datasets
├── DebugScripts
├── Functions
├── Logs
├── main.m
├── README.md
└── Recording
```
### main.m
Main script to run the program.
### Datasets
Contains the datasets for EEG and EMG.
### Functions
Scripts used to run the BCI concurrently.
### Logs
Contains log files from running the program.
### Recording
Scripts used to record datasets for EEG and EMG.

# Hardware setup
**myDAQ and Grove EMG sensors**
- Grove EMG sensors connects to analog input channels 0 and 1
- Grove EMG sensors are powered with myDAQs 5V out
- Check so both channels has ~1.5V output when powered using elvisMX oscilloscope instrument

**Ganglion Board**
- Connect the BLED112 bluetooth dongle to the laptop and check so that it has a COM* port specified. Change the port value in main.m to this value
- Flip the dipswitches to downwards position on the ganglion board to combine the references
- Connect electrodes to ports 1, 2, 3, 4, D_G, and ref
- Test the connection first using the OpenBCI_GUI, if the connection is working close the session
