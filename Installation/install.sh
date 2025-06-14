#!/bin/bash

# OpenKiln2 Automated Installer
# ====================================
# For Raspberry Pi OS

set -e

echo "============================================"
echo "   OpenKiln2 - Automated Installer"
echo "============================================"

# ------------------------------
# Update & Upgrade
# ------------------------------
echo "[1/8] Updating system..."
sudo apt update && sudo apt upgrade -y

# ------------------------------
# Install Node.js & Node-RED
# ------------------------------
echo "[2/8] Installing Node.js LTS & Node-RED..."
curl -sL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs build-essential
sudo npm install -g --unsafe-perm node-red
sudo systemctl enable nodered.service
sudo systemctl start nodered.service

# ------------------------------
# Install InfluxDB
# ------------------------------
echo "[3/8] Installing InfluxDB..."
sudo apt install -y influxdb
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

npm install node-red-contrib-finite-statemachine
npm install node-red-contrib-influxdb
npm install node-red-contrib-pid
npm install node-red-contrib-pid-autotune
npm install node-red-node-pidcontrol
npm install node-red-dashboard

# ------------------------------
# Clone OpenKiln2 repo & import flows
# ------------------------------
echo "[7/8] Cloning OpenKiln2 repo and importing flows..."

cd ~
if [ -d "OpenKiln2" ]; then
    echo "Repo exists. Pulling latest..."
    cd OpenKiln2 && git pull
else
    git clone https://github.com/dalethomas/OpenKiln2.git
    cd OpenKiln2
fi

#
FLOW_JSON="flow.json"

# Copy flow.json to Node-RED user dir
cp $FLOW_JSON ~/.node-red/flows_$(hostname).json

# Restart Node-RED to load new flows and new nodes
echo "Restarting Node-RED..."
sudo systemctl start nodered.service

# ------------------------------
# [8/8] Provision Grafana datasource + dashboard
# ------------------------------
echo "[8/8] Provisioning Grafana datasource and dashboard..."

# ----- 1) Datasource -----
sudo mkdir -p /etc/grafana/provisioning/datasources

cat <<EOF | sudo tee /etc/grafana/provisioning/datasources/influxdb.yaml
apiVersion: 1

datasources:
  - name: OpenKiln2 InfluxDB
    type: influxdb
    access: proxy
    url: http://localhost:8086
    database: home
    user: admin
    password: OpenKiln@12
    isDefault: true
EOF

# ----- 2) Dashboard -----
sudo mkdir -p /etc/grafana/provisioning/dashboards

# Dashboard provisioning config
cat <<EOF | sudo tee /etc/grafana/provisioning/dashboards/dashboards.yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Dashboard JSON itself
cat <<EOF | sudo tee /etc/grafana/provisioning/dashboards/openkiln2_dashboard.json
{
  "id": null,
  "uid": "openkiln2",
  "title": "OpenKiln2 Dashboard",
  "tags": ["openkiln2"],
  "timezone": "browser",
  "schemaVersion": 36,
  "version": 1,
  "refresh": "5s",
  "panels": [
    {
      "type": "timeseries",
      "title": "Upper Temperature (mean 30m)",
      "datasource": "OpenKiln2 InfluxDB",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "targets": [
        {
          "query": "SELECT mean(\\\"mean_Kiln_01_UpperTemperature\\\") FROM \\\"downsampled_temps\\\" WHERE \$timeFilter GROUP BY time(\$__interval) fill(null)",
          "rawQuery": true
        }
      ],
      "gridPos": {
        "x": 0,
        "y": 0,
        "w": 24,
        "h": 9
      }
    },
    {
      "type": "timeseries",
      "title": "Lower Temperature (mean 30m)",
      "datasource": "OpenKiln2 InfluxDB",
      "fieldConfig": {
        "defaults": {},
        "overrides": []
      },
      "targets": [
        {
          "query": "SELECT mean(\\\"mean_Kiln_01_LowerTemperature\\\") FROM \\\"downsampled_temps\\\" WHERE \$timeFilter GROUP BY time(\$__interval) fill(null)",
          "rawQuery": true
        }
      ],
      "gridPos": {
        "x": 0,
        "y": 9,
        "w": 24,
        "h": 9
      }
    }
  ]
}
EOF

# ----- Restart Grafana to apply -----
sudo systemctl restart grafana-server


# ------------------------------
# Done!
# ------------------------------
echo ""
echo "============================================"
echo "✅ OpenKiln2 installation complete!"
echo ""
echo "Node-RED:  http://<YourPiIP>:1880"
echo "Grafana:   http://<YourPiIP>:3000"
echo "  Login: admin / admin"
echo ""
echo "InfluxDB Database: kiln_data"
echo "User: kiln_user | Password: kiln_password"
echo ""
echo "Next Steps:"
echo " - Test your thermocouples and SSR outputs in Node-RED."
echo " - Check Grafana for live kiln data!"
echo ""
echo "Happy firing! 🔥"
echo "============================================"
