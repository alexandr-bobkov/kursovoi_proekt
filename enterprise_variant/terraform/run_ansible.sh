#!/bin/bash
# ==============================================================================
# СКРИПТ АВТОМАТИЧЕСКОГО ХОЛОДНОГО СТАРТА (COLD START) КОНТУРА БОБКОВА А.К.
# ==============================================================================
# Автоматический проброс рабочего ключа ED25519 в память сессии
if [ -z "$SSH_AUTH_SOCK" ]; then
   eval $(ssh-agent -s) >/dev/null
   ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1
fi

# Жестко прыгаем в рабочую папку Ansible, чтобы пути до файлов не терялись
cd "$(dirname "$0")/../ansible"

# 1. Автоматически очищаем старый кэш SSH-ключей Linux, чтобы не было конфликтов IP
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "*" >/dev/null 2>&1
export ANSIBLE_HOST_KEY_CHECKING=False

# Динамически вытаскиваем IP-адреса ВСЕХ управляющих хостов из сгенерированного инвентаря
BASTION_IP=$(grep -oP 'ansible_host=\K[0-9.]+' hosts.ini | sed -n '1p')
KIBANA_IP=$(grep -A1 '\[kibana_host\]' hosts.ini | grep -oP 'ansible_host=\K[0-9.]+')
ELASTIC_IP=$(grep -A1 '\[logging_storage\]' hosts.ini | grep -oP 'ansible_host=\K[0-9.]+')
GRAFANA_IP=$(grep -A1 '\[grafana_host\]' hosts.ini | grep -oP 'ansible_host=\K[0-9.]+')

echo "=== [DevOps Auto-Pilot] Current working directory changed to: $(pwd) ==="
echo "=== [DevOps Auto-Pilot] Scanning cloud network topology... ==="

# 1. Сначала железно дожидаемся готовности самого Бастиона наружу
while ! nc -z -w3 "$BASTION_IP" 22; do
  echo "--> Waiting for Bastion Gateway (${BASTION_IP}:22) to respond..."
  sleep 4
done
echo "=== [SUCCESS] Bastion is online! Testing internal private perimeter via secure tunnel... ==="

# 2. АВТОМАТИЗАЦИЯ: Проверяем порты внутренних нод РУКАМИ БАСТИОНА через SSH-прыжок
for HOST_IP in "$ELASTIC_IP" "$KIBANA_IP" "$GRAFANA_IP"; do
  while ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 -q debian@$BASTION_IP "nc -z -w3 $HOST_IP 22"; do
    echo "--> Internal node ${HOST_IP}:22 is still warming up inside VPC. Retrying via Bastion..."
    sleep 4
  done
  echo "--> [OK] Node ${HOST_IP}:22 is reachable!"
done

echo "=== [SUCCESS] ALL Infrastructure Nodes are fully ready! Starting Pipeline... ==="
echo "=============================================================================="

# ШАГ 1: Разворачиваем Docker везде и ядро Elasticsearch на хостах хранения логов
ansible-playbook -i hosts.ini playbook_logging.yml --limit 'all:!bastion_host'
if [ $? -ne 0 ]; then echo "Step 1 Failed!"; exit 1; fi

# ШАГ 2: Конфигурируем СУБД PostgreSQL, Kibana и универсальный Filebeat
ansible-playbook -i hosts.ini deploy_infra_logging.yml --limit 'all:!bastion_host'
if [ $? -ne 0 ]; then echo "Step 2 (Logging Infrastructure) Failed!"; exit 1; fi

# ШАГ 3: Накатываем веб-стек (PHP 8.4, Nginx, Filebeat) на веб-ноды сайта
ansible-playbook -i hosts.ini update_web.yml --limit 'all:!bastion_host'
if [ $? -ne 0 ]; then echo "Step 3 (Web Nodes) Failed!"; exit 1; fi

# ШАГ 4: В самом конце включаем стек аналитики Grafana, Prometheus и Go-адаптер CrunchyData
ansible-playbook -i hosts.ini deploy_grafana.yml --limit 'all:!bastion_host'
if [ $? -ne 0 ]; then echo "Step 4 (Grafana) Failed!"; exit 1; fi

echo "=============================================================================="
echo "=== TRIUMF: VSYA INFRASTRUKTURA BOBKOVA RAZVERNUTA AVTOMATOM NA 100%! ==="
echo "=============================================================================="
