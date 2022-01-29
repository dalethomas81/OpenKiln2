Autotune Procedure
==================

***note: currently, OpenKiln2 is using a modified version of the [node-red-contrib-pid-autotune](https://flows.nodered.org/node/node-red-contrib-pid-autotune) project. You will need to manually add a line of code to the pid-autotune.js file. 

I plan to create a pull request in the future to add this to the codebase once it has been fully tested.

Using your favorite ssh program follow these steps:
1. sudo nano /home/pi/.node-red/node_modules/node-red-contrib-pid-autotune/pid-autotune.js
2. change line 164 from 'if (node.isRunning === false {' to 'if (node.isRunning === false && msg.cmd === "start") {'
3. press 'control x' to exit
4. type 'y' to confirm
5. type 'sudo node-red-restart' to restart node-red