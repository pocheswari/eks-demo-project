#!/bin/bash
mkdir -p /opt/vault/data
cd /opt/vault
wget https://releases.hashicorp.com/vault/1.2.3/vault_1.2.3_linux_amd64.zip
unzip vault_1.2.3_linux_amd64.zip
mv vault /usr/bin
mkdir /etc/vault
useradd -r vault
chown -R vault:vault /opt/vault
HOST=`curl http://169.254.169.254/latest/meta-data/public-ipv4`

cat <<EOF | sudo tee /etc/vault/config.hcl
disable_cache = true
disable_mlock = true
ui = true
listener "tcp" {
   address          = "0.0.0.0:8200"
   tls_disable      = 1
}
storage "file" {
   path  = "/opt/vault/data"
 }
api_addr         = "http://0.0.0.0:8200"
max_lease_ttl         = "10h"
default_lease_ttl    = "10h"
cluster_name         = "vault"
api_addr             = "http://0.0.0.0:8200"
cluster_addr = "https://0.0.0.0:8201"
EOF

echo "[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/config.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/vault.service
sudo systemctl enable vault.service
#sudo systemctl start vault.service
nohup vault server -config=/etc/vault/config.hcl &
sleep 10
export VAULT_ADDR=http://$HOST:8200
vault operator init -key-shares=3 -key-threshold=2 > unsealkeys.txt
sleep 5
KEY1=`cat unsealkeys.txt | grep -i "Unseal Key 1:" | awk '{print $4}'`
KEY2=`cat unsealkeys.txt | grep -i "Unseal Key 2:" | awk '{print $4}'`
vault operator unseal $KEY1
sleep 2
vault operator unseal $KEY2
sleep 2
vault status
echo "Vault server is initialized and unsealed"
export ROOT_TOKEN=`cat unsealkeys.txt | grep -i "Initial Root Token:" | awk '{print $4}'`
echo "Use the below URL http://$HOST:8200 to login"
echo "ROOT TOKEN for vault login ====> $ROOT_TOKEN"
