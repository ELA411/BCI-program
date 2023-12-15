d = daq("ni");
d.Rate = 1000;
ch = addinput(d,"myDAQ1",0:1,"Voltage");
start(d, "Continuous");
voltage = [];
starttime = tic();
runtime = tic();
while toc(runtime)<=9
    [scanData, timeStamp] = read(d, seconds(1),"Outputformat", "Matrix");
    voltage = [voltage; scanData, timeStamp];
end
endtime = toc(starttime);
fprintf("Sample rate: %d\n", int64(1/(endtime/size(voltage,1))));
stop(d);