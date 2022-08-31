#!/usr/bin/env bash

##############################################################################
# The purpose of the script is to automate a Graylog installation on Ubuntu. #
# The script installs Java 11, Elasticsearch, MongoDB and Graylog server 4.  #
##############################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)
ROOTPASS=$(echo -n P@ssword321 | sha256sum | cut -d" " -f1)
SECRET=$(pwgen -N 1 -s 96)
IPADDR=192.168.56.70
GUSER="osadmin"
EMAIL="sk3ma87@gmail.com"
EPORT=9200
GPORT=9000

# Sanity checking.
if [[ ${USERID} -ne "0" ]]; then
    echo -e "\e[31;1;3mYou must be root, exiting.\e[m"
    exit 1
fi

# Java installation.
java() {
    echo -e "\e[96;1;3mDistribution: ${DISTRO}\e[m"
    echo -e "\e[32;1;3mUpdating repositories\e[m"
    apt update
    echo -e "\e[32;1;3mInstalling Java\e[m"
    apt install openjdk-11-jdk openjdk-11-jre-headless uuid-runtime -qy
}

# MongoDB installation.
mongo() {
    echo -e "\e[32;1;3mInstalling MongoDB\e[m"
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
    echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.0.list
    apt update && apt install mongodb-org -qy
    echo -e "\e[32;1;3mRestarting service\e[m"
    systemctl daemon-reload
    systemctl enable --now mongod && systemctl restart mongod
}

# Elasticsearch installation.
elastic() {
    echo -e "\e[32;1;3mInstalling Elasticsearch\e[m"
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
    echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list
    apt update && apt install elasticsearch-oss -qy
    echo -e "\e[32;1;3mConfiguring Elasticsearch\e[m"
    cd /etc/elasticsearch
    cp -v elasticsearch.{yml,orig}; rm -f elasticsearch.yml
    local elastic=$(cat << STOP
node:
  name: elasticsearch
path:
  data: /var/lib/elasticsearch
  logs: /var/log/elasticsearch
cluster:
  name: graylog
action.auto_create_index: false
STOP
)
    echo "${elastic}" > elasticsearch.yml
    sed -i 's|-Xms1g|-Xms2g|g' jvm.options
    sed -i 's|-Xmx1g|-Xmx2g|g' jvm.options
    echo -e "\e[32;1;3mRestarting service\e[m"
    systemctl daemon-reload
    systemctl enable --now elasticsearch && systemctl restart elasticsearch
}

# Graylog installation.
server() {
    echo -e "\e[32;1;3mInstalling Graylog\e[m"
    cd /opt
    wget --progress=bar:force https://packages.graylog2.org/repo/packages/graylog-4.3-repository_latest.deb
    dpkg -i graylog-4.3-repository_latest.deb
    apt update && apt install graylog-server graylog-enterprise-plugins graylog-integrations-plugins graylog-enterprise-integrations-plugins pwgen -qy
    echo -e "\e[32;1;3mEnabling service\e[m"
    systemctl daemon-reload
    systemctl enable --now graylog-server && systemctl start graylog-server
    echo -e "\e[32;1;3mConfiguring Graylog\e[m"
    cd /etc/graylog/server
    cp -v server.{conf,orig}; rm -f server.conf
    tee server.conf << STOP
is_master = true
node_id_file = /etc/graylog/server/node-id
password_secret = ${SECRET}
root_username = ${GUSER}
root_password_sha2 = ${ROOTPASS}
root_email = ${EMAIL}
bin_dir = /usr/share/graylog-server/bin
data_dir = /var/lib/graylog-server
plugin_dir = /usr/share/graylog-server/plugin
rotation_strategy = count
elasticsearch_max_docs_per_index = 20000000
elasticsearch_max_number_of_indices = 20
retention_strategy = delete
elasticsearch_shards = 4
elasticsearch_replicas = 0
elasticsearch_index_prefix = graylog
allow_leading_wildcard_searches = false
allow_highlighting = false
elasticsearch_analyzer = standard
http_bind_address = ${IPADDR}:${GPORT}
output_batch_size = 500
output_flush_interval = 1
output_fault_count_threshold = 5
output_fault_penalty_seconds = 30
processbuffer_processors = 5
outputbuffer_processors = 3
processor_wait_strategy = blocking
ring_size = 65536
inputbuffer_ring_size = 65536
inputbuffer_processors = 2
inputbuffer_wait_strategy = blocking
message_journal_enabled = true
message_journal_dir = /var/lib/graylog-server/journal
lb_recognition_period_seconds = 3
mongodb_uri = mongodb://localhost/graylog
mongodb_max_connections = 1000
mongodb_threads_allowed_to_block_multiplier = 5
proxied_requests_thread_pool_size = 32
STOP
    echo -e "\e[32;1;3mRestarting service\e[m"
    systemctl restart graylog-server
    rm -rf /opt/graylog-4.3-repository_latest.deb
}

# Syslog configuration.
gray() {
    echo -e "\e[32;1;3mConfiguring syslog\e[m"
    echo -e 'module(load="imudp")' >> /etc/rsyslog.d/10-graylog.conf
    echo -e 'input(type="imudp" port="514")' >> /etc/rsyslog.d/10-graylog.conf
    echo -e 'module(load="imtcp")' >> /etc/rsyslog.d/10-graylog.conf
    echo -e 'input(type="imtcp" port="514")' >> /etc/rsyslog.d/10-graylog.conf
    echo -e "*.*@127.0.0.1:5140:RSYSLOG_SyslogProtocol23Format" >> /etc/rsyslog.d/10-graylog.conf
    echo -e "\e[32;1;3mRestarting service\e[m"
    systemctl restart rsyslog
    logger "Sample: Testing log file."
}

# Creating exception.
fire() {
    echo -e "\e[32;1;3mAdjusting firewall\e[m"
    ufw allow 5140/udp
    ufw allow 9000/tcp
    ufw allow 9200/tcp
    echo "y" | ufw enable
    ufw reload
    echo -e "\e[33;1;3;5mFinished, installation complete.\e[m"
    exit
}

## Sidecar installation:
#agent() {
#    echo -e "\e[32;1;3mInstalling Sidecar\e[m"
#    cd /opt
#    sudo wget https://packages.graylog2.org/repo/packages/graylog-sidecar-repository_1-2_all.deb
#    sudo dpkg -i graylog-sidecar-repository_1-2_all.deb
#    sudo apt update && sudo apt install graylog-sidecar -y
#    echo -e 'server_url: "http://192.168.56.70:9000/api/"' >> /etc/graylog/sidecar/sidecar.yml
#    echo -e 'server_api_token: "mkc8r6hilv3t444k0d530fp9hic8bv2niaqrdnm449hee54v1mn"' >> /etc/graylog/sidecar/sidecar.yml
#    echo -e 'node_name: "Portainer"' >> /etc/graylog/sidecar/sidecar.yml
#    sudo graylog-sidecar -service install
#    sudo systemctl enable graylog-sidecar && sudo systemctl start graylog-sidecar
#    sudo ufw allow 9000/tcp
#    echo "y" | ufw enable
#    sudo ufw reload
#    sudo rm -rf graylog-sidecar-repository_1-2_all.deb
#    echo -e "\e[33;1;3;5mFinished, agent installed.\e[m"
#}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[35;1;3;5mUbuntu detected, proceeding...\e[m"
    java
    mongo
    elastic
    server
    gray
    fire
#    agent
fi
