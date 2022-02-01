Calibrating OpenKiln
====================

Calibrating OpenKiln is very important so that you can hit your desired temperatures and not ruin your batch. Some glazes with run and even change colors depending on your temperature. This is especially important if you are attempting to repeat your results.  

OpenKiln utilizes a 2 point linear calibration but may include additional points in a future update. The values 'xmin', 'ymin', 'xmax', and 'ymax' will be used to calculate the span and offset on the Utility screen.  

There are 2 methods that I have used to calibrate the thermocouples on OpenKiln. If you are good you can accomplish both methods simultaneously. I'll explain this later. But first, let's go over them.  

***Method 1: Center Cone Targeting***  
To perform this procedure, you pick a target temperature (preferably close to where you will normally run) and place 5 cones near the thermocouple with ratings that will center the target temperature on the middle cone.  

For example, you can place cones with values 4, 5, 6, 7, and 8 near the thermocouple and set the target temperature at 2232 @ 108 degrees/hour (cone 6). This way if the target is above or below, you can still capture the peak temperature of the schedule.  

However, if the calibration is way off then you may miss this window all together. For this, you may combine Method 2 (below).  

***Method 2: Constant Monitoring***  
With this method, you are basically performing Method 1 but constantly monitor the cones so that you can record the temperature readout on the kiln as soon as the drop.  

The temperature that OpenKiln reads when the cone drops will be recorded as the 'xmax' and the temperature rating of the cone will be recorded at the 'ymax'.  

***Entering the Data***  
Once you have the data, open the Utility tab and and view the Inputs card. Here you can choose an input and enter the calibration data in the respective fields. Once the data is entered, press the calculate button to have OpenKiln calculate the span and offset.  