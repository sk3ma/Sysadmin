#!/usr/bin/env bash

set -euo pipefail

USERNAME="robanybody"
SSH_PORT="2222"
APP_DIR="/opt/openclaw"

if [[ "${EUID}" -ne "0" ]]; then
    echo
    echo "███████╗██████╗ ██████╗  ██████╗ ██████╗ "
    echo "██╔════╝██╔══██╗██╔══██╗██╔═══██╗██╔══██╗"
    echo "█████╗  ██████╔╝██████╔╝██║   ██║██████╔╝"
    echo "██╔══╝  ██╔══██╗██╔══██╗██║   ██║██╔══██╗"
    echo "███████╗██║  ██║██║  ██║╚██████╔╝██║  ██║"
    echo "╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝"
    echo
    echo "[🔴] You must be root, exiting."
    exit 1
fi

echo "[🟡] Updating system..."
apt update && apt upgrade -y


echo "[🟡] Installing packages..."
apt install curl wget ufw fail2ban ca-certificates gnupg git unattended-upgrades -y

echo "[🟡] Creating user..."
if id "${USERNAME}" &>/dev/null; then
    echo "[!] User already exists, skipping creation"
else
    adduser --disabled-password --gecos "" "${USERNAME}"
    usermod -aG sudo "${USERNAME}"
    echo "[✓] User created"
fi

echo "[🟡] Copying keys..."
if [[ ! -f /root/.ssh/authorized_keys ]]; then
    echo "[🔴] No SSH authorized_keys found in /root/.ssh/"
    echo "     Add your public key to /root/.ssh/authorized_keys first, then re-run."
    exit 1
fi

mkdir -p /home/${USERNAME}/.ssh
cp -v /root/.ssh/authorized_keys /home/${USERNAME}/.ssh/authorized_keys
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.ssh
chmod 700 /home/${USERNAME}/.ssh
chmod 600 /home/${USERNAME}/.ssh/authorized_keys
echo "[✓] SSH keys copied"

echo "[🟡] Hardening SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak"
echo "[✓] Backed up sshd_config to ${SSHD_CONFIG}.bak"

sed -i "s/^#\?Port.*/Port ${SSH_PORT}/" "${SSHD_CONFIG}"
sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" "${SSHD_CONFIG}"
sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" "${SSHD_CONFIG}"
sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" "${SSHD_CONFIG}"

echo "[🟡] Validating SSH..."
sshd -t && echo "[✓] SSH config is valid"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  IMPORTANT: Open a NEW terminal and test login:"
echo "  ssh -p ${SSH_PORT} ${USERNAME}@$(hostname -I | awk '{print $1}')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Press ENTER only after confirming login works..."

systemctl restart ssh
echo "[✓] SSH restarted on port ${SSH_PORT}"

echo "[🟡] Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}"/tcp
ufw --force enable
echo "[✓] UFW enabled : only port ${SSH_PORT} open"

echo "[🟡] Configuring Fail2ban..."
cat > /etc/fail2ban/jail.local << STOP
[sshd]
enabled  = true
port     = ${SSH_PORT}
maxretry = 5
bantime  = 1h
findtime = 10m
STOP

systemctl enable fail2ban
systemctl restart fail2ban
echo "[✓] Fail2ban active"

echo "[🟡] Enabling updates..."
dpkg-reconfigure -f noninteractive unattended-upgrades

UPGRADES_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
if grep -q "^//.*-security" "${UPGRADES_CONF}" 2>/dev/null; then
    sed -i 's|^//\(.*-security.*\)|\1|' "${UPGRADES_CONF}"
    echo "[✓] Security origin uncommented"
fi
echo "[✓] Unattended upgrades configured"

echo "[🟡] Setting timezone..."
timedatectl set-timezone UTC
echo "[✓] $(timedatectl | grep 'Time zone')"

echo "[🟡] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Run this command now and complete Tailscale"
echo "  login in your browser:"
echo
echo "  tailscale up"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Press ENTER after completing Tailscale login..."

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
if [[ -z "${TAILSCALE_IP}" ]]; then
    echo "[🔴] Tailscale doesn't appear connected. Did you run 'tailscale up'?"
    echo "     Run it now, complete login, then press ENTER."
    read -p "Press ENTER to continue..."
fi

echo "[🟡] Locking SSH..."
ufw allow in on tailscale0 to any port "${SSH_PORT}"
ufw delete allow "${SSH_PORT}"/tcp || true
ufw reload
echo "[✓] SSH only accessible via Tailscale"
ufw status

echo "[🟡] Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
apt install -y nodejs
echo "[✓] $(node -v) / npm $(npm -v)"
cat << "STOP"
   ____                    _____ _                
  / __ \                  / ____| |               
 | |  | |_ __   ___ _ __ | |    | | __ ___      __
 | |  | | '_ \ / _ \ '_ \| |    | |/ _` \ \ /\ / /
 | |__| | |_) |  __/ | | | |____| | (_| |\ V  V / 
  \____/| .__/ \___|_| |_|\_____|_|\__,_| \_/\_/  
        | |                                       
        |_|                                       
STOP

echo "[🟡] Installing OpenClaw..."
npm install -g openclaw@latest
echo "[✓] OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'version check : run openclaw --version')"

echo "[🟡] Creating directory..."
mkdir -p "${APP_DIR}"
chown "${USERNAME}":"${USERNAME}" "${APP_DIR}"
chmod 750 "${APP_DIR}"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Starting OpenClaw onboarding as '${USERNAME}'"
echo "  Follow the prompts to configure your assistant"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

sudo -u "${USERNAME}" bash << STOP
export HOME=/home/${USERNAME}
cd ${APP_DIR}
openclaw onboard --install-daemon
STOP

echo "[🟡] Checking service..."
systemctl daemon-reload

if systemctl is-active --quiet openclaw 2>/dev/null; then
    echo "[✓] OpenClaw service is running"
    systemctl status openclaw --no-pager
else
    echo "[!] Service not detected as 'openclaw', checking for openclaw user service..."
    sudo -u "${USERNAME}" systemctl --user status openclaw --no-pager 2>/dev/null || \
    echo "[!] Check 'openclaw status' or 'journalctl -u openclaw' manually"
fi

echo "[🟡] Recent logs:"
journalctl -u openclaw -n 20 --no-pager 2>/dev/null || \
    sudo -u "${USERNAME}" journalctl --user -u openclaw -n 20 --no-pager 2>/dev/null || \
    echo "[!] Run 'openclaw logs' to check logs"

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[🟢] Setup complete."
echo
echo "  Security summary:"
echo "  ✓ Root SSH login    : DISABLED"
echo "  ✓ Password auth     : DISABLED"
echo "  ✓ Public SSH        : REMOVED (Tailscale only)"
echo "  ✓ All public ports  : BLOCKED"
echo "  ✓ Fail2ban          : ACTIVE"
echo "  ✓ Auto updates      : ENABLED"
echo "  ✓ SSH port          : ${SSH_PORT} (Tailscale only)"
echo
echo "  Connect via:"
echo "  ssh -p ${SSH_PORT} ${USERNAME}@${TAILSCALE_IP:-<your-tailscale-ip>}"
echo
echo "  Useful commands:"
echo "  $ openclaw status"
echo "  $ openclaw logs"
echo "  $ openclaw update"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
