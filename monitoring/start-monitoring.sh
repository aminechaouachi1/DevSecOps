#!/bin/bash
set -e
cd "$(dirname "$0")"
TO="aminechaouachi30@gmail.com"
FROM="${SMTP_FROM:-$TO}"
CONF="$PWD/alertmanager.generated.yml"
cat > "$CONF" <<Y
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: '$FROM'
  smtp_auth_username: '$FROM'
  smtp_auth_password: '$SMTP_PASS'
  smtp_require_tls: true
route:
  receiver: mail
  group_wait: 10s
  repeat_interval: 1h
receivers:
  - name: mail
    email_configs:
      - to: '$TO'
        send_resolved: true
Y
chmod 644 "$CONF"
docker network create dso-mon 2>/dev/null || true
docker rm -f dso-blackbox dso-alertmanager dso-prometheus 2>/dev/null || true
docker run -d --name dso-blackbox --network dso-mon --add-host host.docker.internal:host-gateway --restart unless-stopped prom/blackbox-exporter:latest
docker run -d --name dso-alertmanager --network dso-mon -p 9093:9093 --restart unless-stopped -v "$CONF":/etc/alertmanager/alertmanager.yml:ro prom/alertmanager:latest
docker run -d --name dso-prometheus --network dso-mon -p 9090:9090 --restart unless-stopped -v "$PWD/prometheus.yml":/etc/prometheus/prometheus.yml:ro -v "$PWD/alerts.yml":/etc/prometheus/alerts.yml:ro prom/prometheus:latest
docker rm -f dso-grafana 2>/dev/null || true
docker run -d --name dso-grafana --network dso-mon -p 3000:3000 --restart unless-stopped \
    -e GF_AUTH_ANONYMOUS_ENABLED=true -e GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer \
    -e GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/prod.json \
    -v "$PWD/grafana/provisioning":/etc/grafana/provisioning:ro \
    -v "$PWD/grafana/dashboards":/var/lib/grafana/dashboards:ro \
    grafana/grafana-oss:latest || true
sleep 10
curl -fsS http://localhost:9090/-/ready
