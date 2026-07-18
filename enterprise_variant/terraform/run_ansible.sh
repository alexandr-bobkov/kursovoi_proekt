#!/bin/bash
sleep 10

# YA zapuskayu predvaritelnyu ustanovku Docker dlya chistyh mashin
ansible -i ../ansible/hosts.ini logging_storage,bastion -m apt -a "name=docker.io,docker-compose state=present update_cache=yes" --become -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

# YA zapuskayu posledovatelnyj nakat vseh nastrojek dlya Enterprise varianta
ansible-playbook -i ../ansible/hosts.ini ../ansible/playbook.yml
ansible-playbook -i ../ansible/hosts.ini ../ansible/playbook_logging.yml
ansible-playbook -i ../ansible/hosts.ini ../ansible/update_web.yml
ansible-playbook -i ../ansible/hosts.ini ../ansible/deploy_prometheus.yml
ansible-playbook -i ../ansible/hosts.ini ../ansible/deploy_grafana.yml
