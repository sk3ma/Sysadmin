#!/usr/bin/env bash

# Define script variables.
PRX_CONFIG="/etc/haproxy/haproxy.cfg"
PRX_SOCKET="/var/lib/haproxy/info.sock"
ZBX_CONFIG="/etc/zabbix/zabbix_agent2.d/plugins.d/userparameter_haproxy.conf"
STATS_PORT="9000"
STATS_USER="haproxy"
STATS_PASS="1q2w3e4r5t"

# Perform sanity check.
if [[ "${EUID}" -ne "0" ]]; then
    echo
    echo "███████╗██████╗ ██████╗  ██████╗ ██████╗ "
    echo "██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔══██╗"
    echo "█████╗  ██████╔╝██████╔╝██║   ██║██████╔╝"
    echo "██╔══╝  ██╔══██╗██╔══██╗██║   ██║██╔══██╗"
    echo "███████╗██║  ██║██║  ██║╚██████╔╝██║  ██║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
    echo
    echo -e "\e[31;1;3;5m[🔴] You must be root, exiting.\e[m"
    exit 1
fi

# Install HAProxy package.
echo -e "\e[32m[🟡] Installing HAProxy...\e[0m"
dnf install haproxy socat -y
mkdir -vp /var/lib/haproxy
chown haproxy:haproxy /var/lib/haproxy
chmod 750 /var/lib/haproxy

# Configure HAProxy package.
if ! grep -q "stats socket ${PRX_SOCKET}" "${PRX_CONFIG}"; then
  echo -e "\e[32m[🟡] Configuring HAProxy for socket stats...\e[0m"
  cp -v ${PRX_CONFIG} ${PRX_CONFIG}.orig
  cat << STOP > ${PRX_CONFIG}
global
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        ${STATS_USER}
    group       ${STATS_USER}
    daemon

    stats socket /var/lib/haproxy/stats
    stats socket ${PRX_SOCKET} mode 660 user ${STATS_USER} group ${STATS_USER}

    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

listen stats
  bind *:${STATS_PORT}
  mode http
  stats enable
  stats uri /stats
  stats refresh 5s
  stats show-node
  stats auth ${STATS_USER}:${STATS_PASS}

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

frontend main
    bind *:5000
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    default_backend             app

backend static
    balance     roundrobin
    server      static 127.0.0.1:4331 check

backend app
    balance     roundrobin
    server      fe-app1 127.0.0.1:5001 check
    server      fe-app2 127.0.0.1:5002 check
    server      fe-app3 127.0.0.1:5003 check
    server      fe-app4 127.0.0.1:5004 check
STOP
  setenforce 0
  systemctl enable haproxy --now
  systemctl reload haproxy
fi

# Update Zabbix configuration.
echo -e "\e[32m[🟡] Setting up Zabbix UserParameter for HAProxy...\e[0m"
sudo chown haproxy:haproxy ${PRX_SOCKET}
cat << STOP > ${ZBX_CONFIG}
UserParameter=haproxy.stat[*],/usr/local/bin/haproxy_stats.sh ${PRX_SOCKET} \$1 \$2 \$3 \$4
STOP

# Create backends list.
cat << STOP > /etc/haproxy/servers_list.txt
blah1
blah2
blah3
STOP

# Add frontend block.
echo "frontend http_in" >> ${PRX_CONFIG}
echo "    bind *:80" >> ${PRX_CONFIG}
echo "    default_backend blah" >> ${PRX_CONFIG}
echo "" >> ${PRX_CONFIG}

# Add backend block.
echo "backend blah" >> ${PRX_CONFIG}
for SERVER in $(cat /etc/haproxy/servers_list.txt); do
  echo "    server ${SERVER} ${SERVER}:80 check" >> ${PRX_CONFIG}
done

# Create monitoring script.
echo -e "\e[32m[🟡] Setting up haproxy_stats.sh...\e[0m"
cat << 'STOP' > /usr/local/bin/haproxy_stats.sh
#!/usr/bin/env bash

SOCKET_PATH="/var/lib/haproxy/info.sock"

if [[ "${1}" == "--list" ]]; then
  echo "show stat" | socat -T1 STDIO UNIX-CONNECT:"${SOCKET_PATH}" | grep -E "$(paste -sd'|' /etc/haproxy/servers_list.txt)"
  exit 0
fi

SECTION_NAME=${1}
SERVER_NAME=${2}
STAT_FIELD=${3}

if [[ ! -s /etc/haproxy/servers_list.txt ]]; then
  echo "Error: Backend list file is not found."
  exit 1
fi

if ! grep -qx "${SERVER_NAME}" /etc/haproxy/servers_list.txt; then
  echo "'${SERVER_NAME}' is not in the monitored backends list."
  exit 0
fi

FIELD_NUM=$(case "${STAT_FIELD}" in
  status) echo 18 ;;
  qcur) echo 3 ;;
  scur) echo 4 ;;
  rate) echo 33 ;;
  *) echo "Error: Unsupported field '${STAT_FIELD}'"; exit 1 ;;
esac)

echo "show stat" | socat -T1 STDIO UNIX-CONNECT:"${SOCKET_PATH}" \
  | grep "^${SECTION_NAME},${SERVER_NAME}," \
  | cut -d, -f${FIELD_NUM}
STOP
chmod +x /usr/local/bin/haproxy_stats.sh

# Adjusting firewall rules.
systemctl start firewalld && systemctl enable firewalld
firewall-cmd --add-port=9000/tcp --permanent
firewall-cmd --reload

# Restart Zabbix agent.
echo -e "\e[32m[🟡] Restarting Zabbix Agent...\e[0m"
systemctl restart zabbix-agent2

# Print end message.
echo -e "\e[33m[🟢] Import the HAProxy template and update template macros.\e[0m"
exit
