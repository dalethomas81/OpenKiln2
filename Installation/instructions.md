!!!!! ATTENTION: THIS INSTALLER FILE IS A WORK IN PROGRESS AND WILL NOT RUN YET !!!!!
the general instructions are here now but the idea is to turn this into a script that 
will install OpenKiln2 for you.

curl -sSL https://raw.githubusercontent.com/dalethomas81/OpenKiln2/main/install.sh | bash


#!/bin/sh
# installer.sh will install the necessary packages to run OpenKiln2

# sudo raspi-config
	#interface options -> SPI -> enable -> I2C -> enable

# install node-red
	sudo apt install build-essential git curl
	
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)

# enable node-red service
	sudo systemctl enable nodered.service

	node-red-start (you can control-c and it wont stop node-red)

# configure node-red
	node-red admin init

    # choose to use projects (you will need a github account for this)
    
	sudo nano /home/pi/.node-red/settings.js

    #add the below to the runtime settings section
    #contextStorage: {
    #default: {
    #    module: "memory"
    #},
    #memoryOnly: {
    #   module: "memory"
    #},
    #disk: {
    #    module: "localfilesystem"
    #}

    control+x

    y

    enter

    node-red-restart

# install thermocouple-max31855
	sudo npm install thermocouple-max31855

# install node-red nodes
    # open a browser and navigate to node-red using the hostname you chose earlier
    http://OpenKiln2:1880
    # install these from the pallete manager
	#node-red-contrib-finite-statemachine
	#node-red-contrib-influxdb
	#node-red-contrib-pid
	#node-red-contrib-pid-autotune
	#node-red-node-pidcontrol
	#node-red-dashboard

# install influxdb
# https://pimylifeup.com/raspberry-pi-influxdb/
    
    sudo apt upgrade
    
    curl https://repos.influxdata.com/influxdb.key | gpg --dearmor | sudo tee /usr/share/keyrings/influxdb-archive-keyring.gpg >/dev/null
    
    echo "deb [signed-by=/usr/share/keyrings/influxdb-archive-keyring.gpg] https://repos.influxdata.com/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

    sudo apt update

    sudo apt install influxdb

    sudo systemctl unmask influxdb

    sudo systemctl enable influxdb

    sudo systemctl start influxdb

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

    [monitor]
    store-enabled = false in the config file under 
    [http] # https://stackoverflow.com/questions/60269275/influxdb-keeps-appending-to-var-log-syslog
    flux-log-enabled = false
    suppress-write-log = true
    access-log-status-filters = ["5xx", "4xx"]

    control+x

    y

    enter

    sudo service influxdb restart

# install grafana
    #https://brettbeeson.com.au/grafana-and-influxdb-in-pi-zero-w/
    #pi zero gen 1
    sudo apt --fix-broken install
    wget https://dl.grafana.com/oss/release/grafana-rpi_6.4.4_armhf.deb

    #pi zero gen 2
	wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
    sudo apt update && sudo apt install -y grafana

    #all versions of pi
    sudo systemctl unmask grafana-server.service
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server.service

# configure grafana
	sudo /bin/systemctl stop grafana-server

    sudo nano /etc/grafana/grafana.ini

    //[security]
    allow_embedding=true

    //[users]
    viewers_can_edit=true

    //[auth.anonymous]
    enabled=true
    org_name = Main Org.
    org_role = Admin

    //[log]
    mode = console

    control+x

    y

    enter

    sudo /bin/systemctl start grafana-server

    /////// add datasource
    # navigate to grafana using hostname
    http://OpenKiln2:3000
    choose influx
    url http://localhost:8086
    database home
    user admin
    password OpenKiln@12
    click save and test

    click plus button to create a new dashboard
    

# install pi sugar
    wget http://cdn.pisugar.com/release/pisugar-power-manager.sh

    bash pisugar-power-manager.sh -c release

    sudo nc -U /tmp/pisugar-server.sock

    set_auth

    ctrl+c

    #visit pi sugar
    http://OpenKiln2:8421

# clone repository
    #more on this later. for now you you search "node-red projects" and learn how to clone a git repo in Node-RED
    #navigate back to node-red and it should be asking you to either create a project or clone one
    #clone this repo (https://github.com/dalethomas81/OpenKiln2.git) || (git@github.com:dalethomas81/OpenKiln2.git)
    #follow the prompts and log in using your git SSH key (create one if needed)

# restart node red
	node-red-restart

# install log2ram to reduce sd card wear from log writes
    git clone https://github.com/azlux/log2ram && cd log2ram

    chmod +x install.sh && sudo ./install.sh

    cd .. && rm -r log2ram

# navigate to OpenKiln dashboard
    http://OpenKiln2:1880/ui