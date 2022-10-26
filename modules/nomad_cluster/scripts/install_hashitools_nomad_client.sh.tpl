#!/usr/bin/env bash

# install package

curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update
apt-get install -y consul=${consul_version}
apt-get install -y nomad=${nomad_version}
apt-get install -y docker.io

echo "Configuring system time"
timedatectl set-timezone UTC
sudo timedatectl set-timezone Europe/Amsterdam

echo "create directories for saving loggings to custom directory for Consul"
sudo mkdir -p /var/log/consul
sudo chmod -R 640 /var/log/consul

echo "add log-file and -log-level to indicate the logpath and the loglevel for errors."
cat << EOF > /lib/systemd/system/consul.service
[Unit]
Description="HashiCorp Consul - A service mesh solution"
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
EnvironmentFile=-/etc/consul.d/consul.env
User=root
Group=root
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d/ -log-file=/var/log/consul/ -log-level=err
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


echo "Starting deployment from AMI: ${ami}"
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
AVAILABILITY_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
LOCAL_IPV4=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`
#datacenter          = "${datacenter}"
cat << EOF > /etc/consul.d/consul.hcl
datacenter          = "dc1"
server              = false
data_dir            = "/opt/consul/data"
advertise_addr      = "$${LOCAL_IPV4}"
client_addr         = "0.0.0.0"
log_level           = "INFO"
ui                  = true
encrypt             = "${gossip_key}"


# AWS cloud join
retry_join          = ["provider=aws tag_key=Environment-Name tag_value=${environment_name}"]
EOF

chown -R consul:consul /etc/consul.d
chmod -R 640 /etc/consul.d/*

systemctl daemon-reload
systemctl enable consul
systemctl start consul

cat << EOF > /etc/nomad.d/nomad.hcl
data_dir = "/opt/nomad/data"
bind_addr = "0.0.0.0"

# Enable the client
client {
  enabled = true
}
telemetry {
 collection_interval = "1s"
 datadog_address = "localhost:8125"
 disable_hostname = true
 publish_allocation_metrics = true
 publish_node_metrics = true
 prometheus_metrics = true
}

consul {
  address = "127.0.0.1:8500"
  token   = "${master_token}"
}
EOF

chown -R nomad:nomad /etc/nomad.d
chmod -R 640 /etc/nomad.d/*

systemctl enable nomad
systemctl start nomad

DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=bebadafd41bf44d21226ab43ae6a220a DD_SITE="datadoghq.eu" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"
sudo ARCH=amd64 GCLOUD_STACK_ID="422709" GCLOUD_API_KEY="eyJrIjoiNDg4ZWQ4YzQ5YmJhYWVkMmU5ZGM3ZjI5MjgwOTc1YjA0ZGZjNTllYyIsIm4iOiJzdGFjay00MjI3MDktZWFzeXN0YXJ0LWdjb20iLCJpZCI6Njk4NDkxfQ==" GCLOUD_API_URL="https://integrations-api-us-central.grafana.net" /bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/grafana/agent/release/production/grafanacloud-install.sh)"
curl -O -L "https://github.com/grafana/agent/releases/latest/download/agent-linux-amd64.zip";
sudo apt -y install unzip
sudo unzip "agent-linux-amd64.zip";
chmod a+x agent-linux-amd64;
cat << EOF > /etc/grafana-agent.yaml
metrics:
  global:
    scrape_interval: 60s
  configs:
  - name: hosted-prometheus
    scrape_configs:
      - job_name: node
        static_configs:
        - targets: ['localhost:9100']
    remote_write:
      - url: https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push
        basic_auth:
          username: 546178
          password: eyJrIjoiZGRkODg2YWRhN2EwM2Y3MWRmZDJjOTkwZWIyODdhZDEyY2I1YWRlZiIsIm4iOiJ0ZXN0IiwiaWQiOjY5ODQ5MX0=
    - job_name: 'integrations/nomad'
      consul_sd_configs:
      - server: '127.0.0.1:8500'
        services: ['nomad-client', 'nomad']
      metrics_path: /v1/metrics
      params:
        format: ['prometheus']
      relabel_configs:
      - source_labels: ['__meta_consul_tags']
        regex: '(.*)http(.*)'
        action: keep
      - source_labels: [__meta_consul_node]
        target_label: instance
EOF
sudo systemctl restart grafana-agent.service

curl -LO https://github.com/grafana/loki/releases/download/v2.4.2/promtail-linux-amd64.zip
apt-get install -y unzip
unzip promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo mkdir /etc/promtail
sudo mkdir -p /data/promtail
sudo touch /etc/promtail/config.yaml

cat << EOF > /etc/promtail/config.yaml
server:
  http_listen_port: 0
  grpc_listen_port: 0
        
positions:
  filename: /tmp/positions.yaml
        
client:
  url: https://272059:eyJrIjoiZGRkODg2YWRhN2EwM2Y3MWRmZDJjOTkwZWIyODdhZDEyY2I1YWRlZiIsIm4iOiJ0ZXN0IiwiaWQiOjY5ODQ5MX0=@logs-prod3.grafana.net/api/prom/push
        
scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      host: $HOSTNAME
      job: varlogs
      __path__: /var/log/*.log
EOF

cat << EOF > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file /etc/promtail/config.yaml -config.expand-env=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start promtail.service
