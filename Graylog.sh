#!/usr/bin/env bash

##############################################################################
# The purpose of the script is to automate a Graylog installation on Ubuntu. #
# The script installs Java 8, Elasticsearch, MongoDB and Graylog server.     #
##############################################################################

# Declaring variables.
DISTRO=$(lsb_release -ds)
USERID=$(id -u)
ROOTPASS=$(echo -n P@ssword321 | sha256sum | cut -d" " -f1)
IPADDR=192.168.56.75
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
    apt install openjdk-11-jdk openjdk-11-jre uuid-runtime -qy
}

# MongoDB installation.
mongodb() {
    echo -e "\e[32;1;3mInstalling MongoDB\e[m"
    apt install apt-transport-https ca-certificates dirmngr gnupg software-properties-common -qy
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    add-apt-repository 'deb [arch=amd64] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse' -y
    apt install mongodb-org -qy
}

# Service file.
unit() {
    echo -e "\e[32;1;3mCreating service\e[m"
    local unit=$(cat << STOP
[Unit]
Description=MongoDB database server
After=network.target
[Service]
User=mongodb
Group=mongodb
ExecStart=/usr/bin/mongod --quiet --config /etc/mongod.conf
PIDFile=/var/run/mongodb/mongod.pid
[Install]
WantedBy=multi-user.target
STOP
)
    echo "${unit}" > /etc/systemd/system/mongodb.service
    systemctl daemon-reload
    echo -e "\e[32;1;3mStarting MongoDB\e[m"
    systemctl enable --now mongodb
    systemctl start mongodb
}

# Elasticsearch installation.
elastic() {
    echo -e "\e[32;1;3mAdding repository\e[m"
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
    echo "deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list
    echo -e "\e[32;1;3mInstalling Elasticsearch\e[m"
    apt update && apt install elasticsearch-oss -qy
    echo -e "\e[32;1;3mConfiguring Elasticsearch\e[m"
    cp -v /etc/elasticsearch/elasticsearch.{yml,orig}
    rm -f /etc/elasticsearch/elasticsearch.yml
    local elastic=$(cat << STOP
# Custom configuration.
node:
  name: "Elasticsearch"
path:
  data: /var/lib/elasticsearch
  logs: /var/log/elasticsearch
cluster:
  name: graylog
action:
  auto_create: false
network:
  host: 0.0.0.0
  bind_host: 127.0.0.1
http:
  host: ${IPADDR}
  port: ${EPORT}
discovery:
  seed_hosts: [0.0.0.0]
STOP
)
    echo "${elastic}" > /etc/elasticsearch/elasticsearch.yml
    echo -e "\e[32;1;3mResizing Heap\e[m"
    sed -i 's|-Xms1g|-Xms2g|g' /etc/elasticsearch/jvm.options
    sed -i 's|-Xmx1g|-Xmx2g|g' /etc/elasticsearch/jvm.options
    echo -e "\e[32;1;3mElasticsearch options\e[m"
    local config=$(cat << STOP
# Elasticsearch configuration.
ES_PATH_CONF=/etc/elasticsearch
ES_STARTUP_SLEEP_TIME=5
ES_USER=elasticsearch
ES_GROUP=elasticsearch
LOG_DIR=/var/log/elasticsearch
DATA_DIR=/var/lib/elasticsearch
WORK_DIR=/tmp/elasticsearch
CONF_DIR=/etc/elasticsearch
CONF_FILE=/etc/elasticsearch/elasticsearch.yml
RESTART_ON_UPGRADE=true
START_DAEMON=true
STOP
)
    echo "${config}" > /etc/default/elasticsearch
    chown -vR elasticsearch:elasticsearch /var/lib/elasticsearch/
    echo -e "\e[32;1;3mRestarting Elasticsearch\e[m"
    systemctl restart elasticsearch
}

# Graylog installation.
graylog() {
    echo -e "\e[32;1;3mInstalling Graylog\e[m"
    cd /opt
    wget --progress=bar:force https://packages.graylog2.org/repo/packages/graylog-4.2-repository_latest.deb
    dpkg -i graylog-4.2-repository_latest.deb
    apt update && apt install graylog-server pwgen -qy
    echo -e "\e[32;1;3mStarting Graylog\e[m"
    systemctl start graylog-server
    systemctl enable graylog-server
    rm -f graylog-4.2-repository_latest.deb
}

# Graylog configuration.
config() {
    echo -e "\e[32;1;3mConfiguring Graylog\e[m"
    local secret=$(pwgen -N 1 -s 96)
    cd /etc/graylog/server
    cp -v server.{conf,orig}
    rm -f server.conf
    tee server.conf << STOP
# Graylog server configuration.
is_master = true
node_id_file = /etc/graylog/server/node-id
password_secret = ${secret}
root_username = osadmin
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
    echo -e "\e[32;1;3mRestarting Graylog\e[m"
    systemctl restart graylog-server
}

# Syslog configuration.
syslog() {
    echo -e "\e[32;1;3mConfiguring Syslog\e[m"
    echo -e 'module(load="imudp")' >> /etc/rsyslog.conf
    echo -e 'input(type="imudp" port="514")' >> /etc/rsyslog.conf
    echo -e 'module(load="imtcp")' >> /etc/rsyslog.conf
    echo -e 'input(type="imtcp" port="514")' >> /etc/rsyslog.conf
    echo -e "*.*@127.0.0.1:5140" >> /etc/rsyslog.conf
    echo -e "\e[32;1;3mRestarting Syslog\e[m"
    systemctl restart rsyslog
}

# Creating exception.
firewall() {
    echo -e "\e[32;1;3mAdjusting firewall\e[m"
    ufw allow 9000/tcp
    ufw allow 9200/tcp
    echo "y" | ufw enable
    ufw reload
    echo -e "\e[32;1;3mTesting Elasticsearch\e[m"
    curl -X GET "http://${IPADDR}:${GPORT}"
    echo -e "\e[33;1;3;5mFinished, configure webUI.\e[m"
    exit
}

# Calling functions.
if [[ -f /etc/lsb-release ]]; then
    echo -e "\e[33;1;3;5mUbuntu detected, proceeding...\e[m"
    java
    elastic
    mongodb
    unit
    graylog
    config
    syslog
    firewall
fi
