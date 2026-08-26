#!/bin/bash
set -e

# Переходим в папку ansible
cd "$(dirname "$0")/../ansible" || exit 1

export ANSIBLE_HOST_KEY_CHECKING=False

echo "=== [DevOps Auto-Pilot] Запуск пайплайна развертывания ==="
echo "=============================================================================="

echo "--> Даем инфраструктуре 30 сек на инициализацию сетей..."
sleep 30

echo "--> Автоматическое знакомство с Бастионом (добавление в known_hosts)..."
mkdir -p ~/.ssh
# Вытаскиваем строго один IP — адрес Бастиона
BASTION_IP=$(grep -A 1 '\[bastion\]' hosts.ini | grep -oP 'ansible_host=\K[0-9.]+')
if [ ! -z "$BASTION_IP" ]; then
    ssh-keyscan -H "$BASTION_IP" >> ~/.ssh/known_hosts 2>/dev/null || true
fi

echo "--> Ожидание готовности Бастиона..."
ansible bastion -i hosts.ini -m wait_for_connection -a "timeout=300 sleep=20"
echo "=== [OK] Бастион поднялся и готов принимать подключения! ==="

echo "--> Ожидание готовности внутренних серверов (через ProxyCommand)..."
ansible internal -i hosts.ini -m wait_for_connection -a "timeout=300 sleep=10" -f 1
echo "=== [OK] Все серверы готовы к конфигурированию! ==="
echo "=============================================================================="

echo "=== [1/5] Запуск деплоя сайта ==="
ansible-playbook -i hosts.ini playbook.yml

echo "=== [2/5] Запуск стека логирования ELK ==="
ansible-playbook -i hosts.ini playbook_logging.yml

echo "=== [3/5] Установка exporter'ов ==="
ansible-playbook -i hosts.ini update_web.yml

echo "=== [4/5] Настройка Prometheus ==="
ansible-playbook -i hosts.ini deploy_prometheus.yml

echo "=== [5/5] Развертывание Grafana ==="
ansible-playbook -i hosts.ini deploy_grafana.yml

echo "=============================================================================="
echo "=== Обновление index.php (Hardware Stats) ==="
bash ./update_site.sh

echo "=============================================================================="
echo "=== ИНФРАСТРУКТУРА УСПЕШНО РАЗВЕРНУТА НА 100%! ==="
echo "=============================================================================="