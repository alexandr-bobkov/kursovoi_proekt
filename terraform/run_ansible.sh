#!/bin/bash
# Переходим в папку с Ansible-конфигурациями
cd ../ansible

echo "=== [1/5] Zapusk deploymenta imennogo saita Bobkov A.K. ==="
ansible-playbook -i hosts.ini playbook.yml

echo "=== [2/5] Zapusk centralizovannogo steka logov ELK ==="
ansible-playbook -i hosts.ini playbook_logging.yml

echo "=== [3/5] Ustanovka modulya metrik stub_status i exporterov ==="
ansible-playbook -i hosts.ini update_web.yml

echo "=== [4/5] Zapusk i nastroika monitoringa Prometheus ==="
ansible-playbook -i hosts.ini deploy_prometheus.yml

echo "=== [5/5] Razvertyvanie vizualizacii Grafana Enterprise ==="
ansible-playbook -i hosts.ini deploy_grafana.yml

echo "=== VSE SERVISY USPESHNO ZAPUSHCHENY AVTOMATOM! ==="
