#!/usr/bin/env bash
source <(curl -s https://github.com/Ep0chk/ProxmoxScripts/blob/main/misc/build.func)

# Function to display header information
function header_info {
  clear
  echo "Installing Wazuh"
}

header_info
echo -e "Loading..."

# Define variables
APP="Wazuh"
var_disk="4"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="11"

# Call functions to set up environment
variables
color
catch_errors

# Function to set default settings
function default_settings() {
  CT_TYPE="0"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

# Start the installation process
start
build_container
description


function update_script() {
header_info
if [[ ! -d /var/ossec ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating $APP LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated $APP LXC"
exit
}

# Update system and install necessary packages
apt-get update && apt-get upgrade -y && apt-get install -y curl apt-transport-https lsb-release gnupg2

# Install Wazuh manager
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt-get update && apt-get install -y wazuh-manager

# Install Filebeat
curl -s https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
apt-get update && apt-get install -y filebeat
curl -so /etc/filebeat/filebeat.yml https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/filebeat/7.x/filebeat.yml
curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/elasticsearch/7.x/wazuh-template.json
curl -s https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/filebeat/7.x/wazuh-filebeat.module.tar.gz | tar -xvz -C /usr/share/filebeat/module
systemctl daemon-reload
systemctl enable filebeat
systemctl start filebeat

# Install Elasticsearch
apt-get install -y elasticsearch=7.10.2
curl -so /etc/elasticsearch/elasticsearch.yml https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/elasticsearch/7.x/elasticsearch_all_in_one.yml
curl -so /usr/share/elasticsearch/plugins/opendistro_security/securityconfig/roles.yml https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/elasticsearch/roles/roles.yml
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

# Install Kibana
apt-get install -y kibana=7.10.2
curl -so /etc/kibana/kibana.yml https://raw.githubusercontent.com/wazuh/wazuh/4.2/extensions/kibana/7.x/kibana_all_in_one.yml
systemctl daemon-reload
systemctl enable kibana
systemctl start kibana

# Set up Kibana user authentication
echo "Please enter a username for Kibana:"
read username
echo "Please enter a password for Kibana:"
read -s password

# Hash the password
hashed_password=$(echo -n $password | openssl dgst -sha256)

# Add username and hashed password to Kibana's keystore
/usr/share/kibana/bin/kibana-keystore create
echo $username | /usr/share/kibana/bin/kibana-keystore add elasticsearch.username
echo $hashed_password | /usr/share/kibana/bin/kibana-keystore add elasticsearch.password

# Restrict access to the keystore
chown root:root /usr/share/kibana/data/kibana.keystore
chmod 600 /usr/share/kibana/data/kibana.keystore

# Restart Kibana to apply changes
systemctl restart kibana

msg_ok "Completed Successfully!\n"

# Output the status of all services
echo "Service Statuses:"
echo "Wazuh Manager: $(systemctl is-active wazuh-manager)"
echo "Filebeat: $(systemctl is-active filebeat)"
echo "Elasticsearch: $(systemctl is-active elasticsearch)"
echo "Kibana: $(systemctl is-active kibana)"

# Output credentials and URL
echo -e "\nCredentials:"
echo "Username: $username"
echo "Password: The password you entered"

echo -e "\nServices and their access URLs:"
echo "${APP} (Kibana): http://${IP}:5601" # Kibana's default port
echo "Elasticsearch: http://${IP}:9200" # Elasticsearch's default port
echo "Wazuh API: https://${IP}:55000" # Wazuh API's default port

# Note: The ports mentioned are the default ports for these services. If you have configured them to use different ports, please replace them with the correct ones.
