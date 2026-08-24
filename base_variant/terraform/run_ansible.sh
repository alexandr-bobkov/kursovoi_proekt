#!/bin/bash
set -e

cd "$(dirname "$0")/../ansible"
export ANSIBLE_HOST_KEY_CHECKING=False

# Подгружаем сгенерированный ключ в ssh-agent
KEY_PATH="$(pwd)/../terraform/id_ed25519"
chmod 600 "$KEY_PATH"

if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s) >/dev/null
    ssh-add "$KEY_PATH" >/dev/null 2>&1
else
    ssh-add "$KEY_PATH" >/dev/null 2>&1 || true
fi

BASTION_IP=$(grep 'bastion_host' hosts.ini | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

echo "--> Ожидание готовности SSH на Бастионе ($BASTION_IP)..."
until nc -z -w 5 "$BASTION_IP" 22 2>/dev/null; do
    sleep 5
done
echo "=== Бастион готов! ==="

echo "=== [1/5] Запуск базовой настройки и веб-серверов ==="
ansible-playbook -i hosts.ini playbook.yml

echo "=== [2/5] Запуск стека логирования (ELK) ==="
ansible-playbook -i hosts.ini playbook_logging.yml

echo "=== [3/5] Установка метрик и сборщиков Filebeat ==="
ansible-playbook -i hosts.ini update_web.yml

echo "=== [4/5] Настройка мониторинга (Prometheus) ==="
ansible-playbook -i hosts.ini deploy_prometheus.yml

echo "=== [5/5] Развертывание Grafana Enterprise ==="
ansible-playbook -i hosts.ini deploy_grafana.yml

echo "=== ВСЕ СЕРВИСЫ УСПЕШНО ЗАПУЩЕНЫ АВТОМАТОМ! ==="