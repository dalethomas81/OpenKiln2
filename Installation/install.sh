!!!!! ATTENTION: THIS INSTALLER FILE IS A WORK IN PROGRESS AND WILL NOT RUN YET !!!!!
the general instructions are here now but the idea is to turn this into a script that 
will install OpenKiln2 for you.

#!/bin/sh
# installer.sh will install the necessary packages to run OpenKiln2

# sudo raspi-config
	#interface options -> SPI -> enable -> I2C -> enable

# install node-red
	sudo apt install build-essential git curl
	
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)

# configure node-red
	node-red admin init

    # choose to use projects (you will need a github account for this)
    
	sudo nano home/pi/.node-red/settings.js

    #add the below to the runtime settings section
    #contextStorage: {
    #    default: {
    #        module:"localfilesystem"
    #    },
    #    memoryOnly: {
    #        module: "memory"
    #    }
    #},

    control+x

    y

    enter

# enable node-red service
	sudo systemctl enable nodered.service

	node-red-start (you can control-c and it wont stop node-red)

# install thermocouple-max31855
	sudo npm install thermocouple-max31855

# install node-red nodes
    # install these from the pallete manager
	#node-red-contrib-finite-statemachine
	#node-red-contrib-influxdb
	#node-red-contrib-pid
	#node-red-contrib-pid-autotune
	#node-red-node-pidcontrol
	#node-red-dashboard

# install influxdb
	sudo apt update
    
    sudo apt upgrade
    
    curl https://repos.influxdata.com/influxdb.key | gpg --dearmor | sudo tee /usr/share/keyrings/influxdb-archive-keyring.gpg >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/influxdb-archive-keyring.gpg] https://repos.influxdata.com/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

    influx

    >create database home
    >use home

    >create user admin with password 'OpenKiln@12' with all privileges
    >grant all privileges on home to admin

    >CREATE RETENTION POLICY "30_days" ON "home" DURATION 30d REPLICATION 1 DEFAULT;
    >CREATE RETENTION POLICY "6_months" ON "home" DURATION 26w REPLICATION 1;
    >CREATE RETENTION POLICY "infinite" ON "home" DURATION INF REPLICATION 1;

    >CREATE CONTINUOUS QUERY "cq_30m_upper" ON "home" BEGIN SELECT mean("value") AS "mean_Kiln_01_UpperTemperature" INTO "30_days"."downsampled_temps" FROM "Kiln_01_UpperTemperature" GROUP BY time(30m) END

    >CREATE CONTINUOUS QUERY "cq_30m_lower" ON "home" BEGIN SELECT mean("value") AS "mean_Kiln_01_LowerTemperature" INTO "30_days"."downsampled_temps" FROM "Kiln_01_LowerTemperature" GROUP BY time(30m) END

    >exit

# configure influx db
    sudo nano /etc/influxdb/influxdb.conf

    // change store-enabled = false in the config file under monitor

    control+x

    y

    enter

    sudo service influxdb restart

# install grafana
	wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

    echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

    sudo apt update && sudo apt install -y grafana

    sudo systemctl unmask grafana-server.service

    sudo systemctl start grafana-server

    sudo systemctl enable grafana-server.service
    
    sudo apt update

    sudo apt install influxdb

    sudo systemctl unmask influxdb

    sudo systemctl enable influxdb

    sudo systemctl start influxdb

# configure grafana
	sudo /bin/systemctl stop grafana-server

    sudo nano /etc/grafana/grafana.ini

    //[users]
    //viewers_can_edit=true
    //[auth.anonymous]
    //enabled=true
    //[security]
    //allow_embedding=true
    //[log]
    //mode = console

    control+x

    y

    enter

    sudo /bin/systemctl start grafana-server

# install pi sugar
    wget http://cdn.pisugar.com/release/pisugar-power-manager.sh

    bash pisugar-power-manager.sh -c release

    sudo nc -U /tmp/pisugar-server.sock

    set_auth

    ctrl+c

# clone repository
    #more on this later. for now you you search "node-red projects" and learn how to clone a git repo in Node-RED

# restart node red
	node-red-restart