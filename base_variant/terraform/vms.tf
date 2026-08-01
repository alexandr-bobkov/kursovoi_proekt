# ==============================================================================
# КОНФИГУРАЦИЯ ВИРТУАЛЬНЫХ МАШИН ДЛЯ КУРСОВОГО ПРОЕКТА (BASE VARIANT)
# ==============================================================================

# --- ДИНАМИЧЕСКИЙ СБОР ОБРАЗА DEBIAN 13 ИЗ МАРКЕТПЛЕЙСА ---
data "yandex_compute_image" "debian_13" {
  family = "debian-13"
}

# --- 1. БАСТИОН-ХОСТ (SECURE JUMP HOST) ---
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"
  hostname    = "bastion-host"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    
    # ИСПРАВЛЕНО layout ИБ: привязали Бастион к внешнему и внутреннему периметрам одновременно
    security_group_ids = [
      yandex_vpc_security_group.bastion_sg.id,
      yandex_vpc_security_group.internal_mgmt_sg.id
    ]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}


# --- 2. ВЫДЕЛЕННЫЙ ХОСТ GRAFANA ---
resource "yandex_compute_instance" "grafana" {
  name        = "grafana-host"
  hostname    = "grafana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.grafana_sg.id]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 3. ВЫДЕЛЕННЫЙ ХОСТ KIBANA ---
resource "yandex_compute_instance" "kibana" {
  name        = "kibana-host"
  hostname    = "kibana"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.kibana_sg.id]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 4. ПЕРВЫЙ ВЕБ-СЕРВЕР (WEB-1) ---
resource "yandex_compute_instance" "web_1" {
  name        = "web-server-1"
  hostname    = "web1"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 5. ВТОРОЙ ВЕБ-СЕРВЕР (WEB-2) ---
resource "yandex_compute_instance" "web_2" {
  name        = "web-server-2"
  hostname    = "web2"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 15
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 6. СЕРВЕР PROMETHEUS ---
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server"
  hostname    = "prometheus-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 7. БАЗА ДАННЫХ ЛОГОВ ELASTICSEARCH ---
resource "yandex_compute_instance" "opensearch" {
  name        = "elasticsearch-storage"
  hostname    = "elasticsearch-storage"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"
  
  allow_stopping_for_update = true
  
  resources {
    cores         = 2
    memory        = 8
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.debian_13.id
      size     = 25
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.internal_mgmt_sg.id]
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# ==============================================================================
# AUTOMATIC INVENTORY GENERATION AND DEPLOYMENT RUNNER (FULLY AUTONOMOUS)
# ==============================================================================
resource "null_resource" "ansible_auto_run" {
  depends_on = [
    yandex_compute_instance.bastion,
    yandex_compute_instance.grafana,
    yandex_compute_instance.kibana,
    yandex_compute_instance.web_1,
    yandex_compute_instance.web_2,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.opensearch
  ]

    # Шаг А: Создание hosts.ini (Исправленный чистый автомат Бобкова A.K.)
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > ../ansible/hosts.ini
[bastion]
bastion_host ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} ansible_user=debian

[webservers]
web1 ansible_host=${yandex_compute_instance.web_1.network_interface.0.ip_address} ansible_user=debian
web2 ansible_host=${yandex_compute_instance.web_2.network_interface.0.ip_address} ansible_user=debian

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.opensearch.network_interface.0.ip_address} ansible_user=debian

[prometheus_host]
prometheus_server ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address} ansible_user=debian

[grafana_host]
grafana_server ansible_host=${yandex_compute_instance.grafana.network_interface.0.ip_address} ansible_user=debian

[kibana_host]
kibana_server ansible_host=${yandex_compute_instance.kibana.network_interface.0.ip_address} ansible_user=debian

[all:vars]
ansible_user=debian
ansible_ssh_private_key_file=/home/user/.ssh/id_rsa
ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyJump=debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"

[bastion:vars]
ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
EOF
EOT
  }


        # Шаг 5: ПОЛНОСТЬЮ АВТОНОМНЫЙ ЗАПУСК БЕЗ КОНФЛИКТОВ ПЕРЕМЕННЫХ
  provisioner "local-exec" {
    command = <<EOT
echo "Ожидаем появления SSH на Бастионе..."
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address} "echo 'Bastion is alive'" 2>/dev/null; do
  sleep 5
done

echo "Бастион доступен! Запускаем первичный плейбук Ansible..."
export ANSIBLE_HOST_KEY_CHECKING=False
cd ../ansible

# Выводим таски первичной настройки на лету прямо в консоль Терраформа
ansible-playbook -i hosts.ini playbook.yml 2>&1 | tee /tmp/ansible_base_apply.log

echo "Бастион настроен! Динамически считываем новые IP приватных нод из hosts.ini..."
# Автоматика сама вытаскивает живые адреса из файла инвентаря Яндекса!
WEB1_IP=$(grep "web1" hosts.ini | awk -F'=' '{print $2}' | awk '{print $1}')
WEB2_IP=$(grep "web2" hosts.ini | awk -F'=' '{print $2}' | awk '{print $1}')
ELASTIC_IP=$(grep "elasticsearch_server" hosts.ini | awk -F'=' '{print $2}' | awk '{print $1}')
KIBANA_IP=$(grep "kibana_server" hosts.ini | awk -F'=' '{print $2}' | awk '{print $1}')

echo "Ожидаем готовности сетевых интерфейсов приватных нод..."
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa -o ProxyJump="debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}" debian@$WEB1_IP "echo 'Web 1 is alive'" 2>/dev/null; do sleep 5; done
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa -o ProxyJump="debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}" debian@$WEB2_IP "echo 'Web 2 is alive'" 2>/dev/null; do sleep 5; done
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa -o ProxyJump="debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}" debian@$ELASTIC_IP "echo 'Elasticsearch is alive'" 2>/dev/null; do sleep 5; done
until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa -o ProxyJump="debian@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}" debian@$KIBANA_IP "echo 'Kibana is alive'" 2>/dev/null; do sleep 5; done

echo "Все приватные ноды синхронизированы! Запускаем комплексный деплой всех сервисов..."
# Финальный накат логов и мониторинга выводится в реальном времени на лету!
./update_site.sh 2>&1 | tee /tmp/ansible_site_apply.log
EOT
  }
}

