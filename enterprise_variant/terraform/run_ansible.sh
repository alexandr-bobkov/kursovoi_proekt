#!/bin/bash
set -e

# Переходим в папку ansible
cd "$(dirname "$0")/../ansible"
export ANSIBLE_HOST_KEY_CHECKING=False

# Локализируем ключ
KEY_PATH="$(pwd)/../terraform/id_ed25519"
if [ ! -f "$KEY_PATH" ]; then
    KEY_PATH="$(pwd)/id_ed25519"
fi
chmod 600 "$KEY_PATH" 2>/dev/null || true

# Запускаем ssh-agent и добавляем ключ (решает проблему с ProxyJump)
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s) >/dev/null
    ssh-add "$KEY_PATH" >/dev/null 2>&1
else
    ssh-add "$KEY_PATH" >/dev/null 2>&1 || true
fi

echo "=== [DevOps Auto-Pilot] Запуск пайплайна развертывания ==="

echo "--> [Этап 1/3] Ожидание готовности Бастиона..."
ansible bastion -i hosts.ini -m wait_for_connection -a "timeout=300 sleep=10"
echo "=== [OK] Бастион поднялся и готов принимать подключения! ==="

echo "--> [Этап 2/3] Ожидание готовности баз данных и логирования (через ProxyJump параллельно)..."
ansible kibana_host,grafana_host,logging_storage -i hosts.ini -m wait_for_connection -a "timeout=300 sleep=10" -f 5

echo "--> [Этап 3/3] Ожидание готовности веб-нод (через ProxyJump параллельно)..."
ansible web_nodes -i hosts.ini -m wait_for_connection -a "timeout=300 sleep=10" -f 5

echo "=== [OK] Все серверы готовы к конфигурированию! ==="
echo "=============================================================================="

# Запуск плейбуков
ansible-playbook -i hosts.ini playbook_logging.yml --limit 'all:!bastion'
ansible-playbook -i hosts.ini deploy_infra_logging.yml --limit 'all:!bastion'
ansible-playbook -i hosts.ini update_web.yml --limit 'all:!bastion'
ansible-playbook -i hosts.ini deploy_grafana.yml --limit 'all:!bastion'
ansible-playbook -i hosts.ini add_logs_to_others.yml

echo "=============================================================================="
echo "=== [HEALTH CHECK] АВТОМАТИЧЕСКАЯ ПРОВЕРКА СЕРВИСОВ ==="
echo "=============================================================================="

echo "--> Проверка Web-серверов (порт 80)..."
ansible web_nodes -i hosts.ini -m wait_for -a "port=80 timeout=30 state=started"

echo "--> Проверка Elasticsearch (порт 9200)..."
ansible logging_storage -i hosts.ini -m wait_for -a "port=9200 timeout=30 state=started"

echo "--> Проверка Kibana (порт 5601)..."
ansible kibana_host -i hosts.ini -m wait_for -a "port=5601 timeout=30 state=started"

echo "--> Проверка Grafana (порт 3000)..."
ansible grafana_host -i hosts.ini -m wait_for -a "port=3000 timeout=30 state=started"

echo "=============================================================================="
echo "=== ИНФРАСТРУКТУРА УСПЕШНО РАЗВЕРНУТА НА 100%! ==="
echo "=============================================================================="