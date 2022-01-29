Autotune Procedure
==================

***note: currently, OpenKiln2 is using a modified version of the [node-red-contrib-pid-autotune](https://flows.nodered.org/node/node-red-contrib-pid-autotune) project. You will need to manually replace 2 files in the library.

I plan to create a pull request in the future to add this to the codebase once it has been fully tested.

Navigate to /home/pi/.node-red/node_modules/node-red-contrib-pid-autotune and replace the 2 files named pid-autotune.html and pid-autotune.js with the 2 files in the folder where this procedure is stored with the same name.