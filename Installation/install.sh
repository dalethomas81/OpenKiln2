#!/bin/bash

# OpenKiln2 Automated Installer
# ====================================
# For Raspberry Pi OS
#
# to install run:
# curl -sSL https://raw.githubusercontent.com/dalethomas81/OpenKiln2/main/install.sh | bash
#

set -e

echo "============================================"
echo "   OpenKiln2 - Automated Installer"
echo "============================================"






echo "[0/8] Enabling SPI interface..."
# Ensure the line exists and is set to 'on' in /boot/firmware/config.txt
if grep -q "^dtparam=spi=" /boot/firmware/config.txt; then
    sudo sed -i "s/^dtparam=spi=.*/dtparam=spi=on/" /boot/firmware/config.txt
else
    echo "dtparam=spi=on" | sudo tee -a /boot/firmware/config.txt
fi

# Ensure spi-dev loads on boot
if ! grep -q "^spi-dev" /etc/modules; then
    echo "spi-dev" | sudo tee -a /etc/modules
fi

# Load the kernel module immediately (optional, so user doesn't have to reboot)
sudo modprobe spi_bcm2835 || true

echo "SPI interface has been enabled. A reboot may be required to fully apply the change."






# [0/8] Install Git (needed for cloning the repo)
echo "[0/8] Installing Git..."
sudo apt update && sudo apt install -y git






# ------------------------------
# Update & Upgrade
# ------------------------------
echo "[1/8] Updating system..."
sudo apt update && sudo apt upgrade -y






# ------------------------------
# [2/8] Install Node.js & Node-RED (manual, robust)
# ------------------------------
echo "[2/8] Installing Node.js & Node-RED manually..."

# Install Node.js (via NodeSource)
curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs build-essential

# Install Node-RED globally
sudo npm install -g --unsafe-perm node-red






# Create settings.js with telemetry OFF and custom contextStorage
echo "[2/8] Creating settings.js..."
mkdir -p ~/.node-red

if [ ! -f ~/.node-red/settings.js ]; then
  curl -sL https://raw.githubusercontent.com/node-red/node-red/master/packages/node_modules/node-red/settings.js -o ~/.node-red/settings.js
  sed -i 's/enableTelemetry: true/enableTelemetry: false/' ~/.node-red/settings.js

  # Remove any existing contextStorage and insert your custom block
  sed -i '/^contextStorage:/,/},/d' ~/.node-red/settings.js
  sed -i '/functionGlobalContext:/a \
    contextStorage: {\n\
        default: {\n\
            module: "memory"\n\
        },\n\
        memoryOnly: {\n\
            module: "memory"\n\
        },\n\
        disk: {\n\
            module: "localfilesystem"\n\
        }\n\
    },\n' ~/.node-red/settings.js
fi






# Create the systemd service unit
echo "[2/8] Creating systemd unit for Node-RED..."
sudo bash -c 'cat <<EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED
After=network.target

[Service]
ExecStart=/usr/bin/env node-red
WorkingDirectory=/home/pi
User=pi
Group=pi
Nice=10
Environment="NODE_OPTIONS=--max_old_space_size=256"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF'

# Reload and enable the service
sudo systemctl daemon-reload
sudo systemctl enable nodered.service
sudo systemctl start nodered.service






# ------------------------------
# Install InfluxDB
# ------------------------------
echo "[3/8] Installing InfluxDB..."
sudo apt install -y influxdb influxdb-client
sudo systemctl unmask influxdb
sudo systemctl enable influxdb
sudo systemctl start influxdb






# ------------------------------
# Create InfluxDB database, user, retention policies, and continuous queries
# ------------------------------
echo "[4/8] Setting up InfluxDB database, user, retention policies, and continuous queries..."

# Wait for InfluxDB to start up
sleep 5

# Create database 'home'
influx -execute "CREATE DATABASE home"

# Create admin user
influx -execute "CREATE USER admin WITH PASSWORD 'OpenKiln@12' WITH ALL PRIVILEGES"
influx -execute "GRANT ALL PRIVILEGES ON home TO admin"

# Create retention policies
influx -execute "CREATE RETENTION POLICY \"30_days\" ON \"home\" DURATION 30d REPLICATION 1 DEFAULT"
influx -execute "CREATE RETENTION POLICY \"6_months\" ON \"home\" DURATION 26w REPLICATION 1"
influx -execute "CREATE RETENTION POLICY \"infinite\" ON \"home\" DURATION INF REPLICATION 1"

# Create continuous queries
influx -execute "CREATE CONTINUOUS QUERY \"cq_30m_upper\" ON \"home\" BEGIN SELECT mean(\"value\") AS \"mean_Kiln_01_UpperTemperature\" INTO \"30_days\".\"downsampled_temps\" FROM \"Kiln_01_UpperTemperature\" GROUP BY time(30m) END"

influx -execute "CREATE CONTINUOUS QUERY \"cq_30m_lower\" ON \"home\" BEGIN SELECT mean(\"value\") AS \"mean_Kiln_01_LowerTemperature\" INTO \"30_days\".\"downsampled_temps\" FROM \"Kiln_01_LowerTemperature\" GROUP BY time(30m) END"






# ------------------------------
# Install Grafana
# ------------------------------
echo "[5/8] Installing Grafana..."
sudo apt install -y apt-transport-https software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/grafana.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update
sudo apt install -y grafana

sudo systemctl enable grafana-server
sudo systemctl start grafana-server






# ------------------------------
# Install Required Node-RED Nodes
# ------------------------------
echo "[6/8] Installing required Node-RED nodes..."
# Stop Node-RED to avoid conflicts while installing nodes
sudo systemctl stop nodered.service

cd ~/.node-red

npm install thermocouple-max31855
npm install node-red-contrib-finite-statemachine
npm install node-red-contrib-influxdb
npm install node-red-contrib-pid
npm install node-red-contrib-pid-autotune
npm install node-red-node-pidcontrol
npm install node-red-dashboard






# ------------------------------
# [7/8] Clone OpenKiln2 repo & import flows
# ------------------------------
echo "[7/8] Cloning OpenKiln2 repo and importing flows..."
cd ~

if [ -d "OpenKiln2" ]; then
  echo "pulling latest git"
  cd OpenKiln2 && git pull
else
  git config --global credential.helper ""
  GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/dalethomas81/OpenKiln2.git || {
    echo "❌ Could not clone repo anonymously. Is it public? Check the URL!"
    exit 1
  }
  cd OpenKiln2
fi

# Define flow file path (inside cloned repo)
FLOW_JSON="$HOME/OpenKiln2/flow.json"

# Copy flow.json to Node-RED user dir with correct name
#echo "Copying Node-RED flow to ~/.node-red/flows_$(hostname).json..."
#cp "$FLOW_JSON" ~/.node-red/flows_$(hostname).json
echo "Copying Node-RED flow to ~/.node-red/flows.json..."
cp "$FLOW_JSON" ~/.node-red/flows.json

# Restart Node-RED to load new flows
echo "Restarting Node-RED..."
sudo systemctl restart nodered.service






# ------------------------------
# [8/8] Provision Grafana dashboard
# ------------------------------
echo "[8/8] Provisioning Grafana dashboard..."

# 1) Create dashboards provisioning config
sudo mkdir -p /etc/grafana/provisioning/dashboards

sudo bash -c 'cat <<EOF > /etc/grafana/provisioning/dashboards/openkiln.yaml
apiVersion: 1
providers:
  - name: "OpenKiln2"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF'

# 4) Restart Grafana to apply dashboard
sudo systemctl restart grafana-server






# ------------------------------
# [8/8] provision dashboard and configure ini file
# ------------------------------
echo "[8/8] Writing OpenKiln2 Dashboard JSON..."

sudo mkdir -p /var/lib/grafana/dashboards

sudo cp $HOME/OpenKiln2/Installation/openkiln2_dashboard.json /var/lib/grafana/dashboards/

# Allow embedding
sudo sed -i '/^\[security\]/,/^\[/{s/^;*allow_embedding *= *.*/allow_embedding = true/}' /etc/grafana/grafana.ini
# Allow viewers to edit
sudo sed -i '/^\[users\]/,/^\[/{s/^;*viewers_can_edit *= *.*/viewers_can_edit = true/}' /etc/grafana/grafana.ini
# Enable anonymous
sudo sed -i '/^\[auth.anonymous\]/,/^\[/{s/^;*enabled *= *.*/enabled = true/; s/^;*org_name *= *.*/org_name = Main Org./; s/^;*org_role *= *.*/org_role = Admin/}' /etc/grafana/grafana.ini

# Restart Grafana again to load dashboard
sudo systemctl restart grafana-server





# ------------------------------
# [8/8] log2ram
# ------------------------------
echo "[8/8] Installing log2ram ..."

# Download log2ram repo
git clone https://github.com/azlux/log2ram.git || true

# Run installer
cd log2ram
sudo ./install.sh

# Clean up if you want
cd ..
rm -rf log2ram

# Enable and start log2ram service
sudo systemctl enable log2ram
sudo systemctl start log2ram





# ------------------------------
# Done!
# ------------------------------
PI_IP=$(hostname -I | awk '{print $1}')
PI_HOST=$(hostname)

echo ""
echo "============================================"
echo "✅ OpenKiln2 installation complete!"
echo ""
echo "User Interface:  http://$PI_IP:1880/ui/ (or http://$PI_HOST.local:1880/ui/)"
echo "Node-RED:  http://$PI_IP:1880 (or http://$PI_HOST.local:1880)"
echo "Grafana:   http://$PI_IP:3000 (or http://$PI_HOST.local:3000)"
echo "  Login: admin / admin"
echo ""
echo "InfluxDB Database: home"
echo "  User: admin | Password: OpenKiln@12"
echo ""
echo "Next Steps:"
echo " - Test your thermocouples and SSR outputs in Node-RED."
echo " - Check Grafana for live kiln data!"
echo ""
echo "Happy firing! 🔥"
echo "============================================"

sudo reboot now