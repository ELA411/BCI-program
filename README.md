# ganglion_stream
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

## Brainflow installation ubuntu
Clone the brainflow repository
```
git clone git@github.com:brainflow-dev/brainflow.git
```
cd into the repository
```
cd brainflow
```
create a build directory
```
mkdir build && cd build
```
build the directory
```
cmake ../
```
```
make -si
```

Start matlab and include in matlab path
```
/home/{user}/brainflow/matlab_package/brainflow
```
