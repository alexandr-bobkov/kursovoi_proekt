# ==============================================================================
# КОНФИГУРАЦИЯ ВИРТУАЛЬНЫХ МАШИН С КРАСИВЫМИ ИМЕНАМИ ХОСТОВ (HOSTNAME)
# Студент: Бобков А.К.
# ==============================================================================

# --- 1. КРАСИВЫЙ БАСТИОН-ХОСТ (SECURE JUMP HOST) ---
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-host"     # Имя машины в панели Yandex Cloud
  hostname    = "bastion-host"     # Внутреннее системное имя ОС Linux
  platform_id = "standard-v3"
  zone_id     = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd864g6cmjq6asstq68q" # Чистый Debian 13 Trixie
      size     = 10
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 2. ПЕРВЫЙ ОСНОВНОЙ ВЕБ-СЕРВЕР (WEB-1) ---
resource "yandex_compute_instance" "web_1" {
  name        = "web-server-1"     # Имя машины в панели Yandex Cloud
  hostname    = "web1"             # Внутреннее красивое имя ОС Linux
  platform_id = "standard-v3"
  zone_id     = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd864g6cmjq6asstq68q"
      size     = 15
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false # Полностью изолирован в приватной подсети
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- 3. ВТОРОЙ РЕЗЕРВНЫЙ ВЕБ-СЕРВЕР (WEB-2) ---
resource "yandex_compute_instance" "web_2" {
  name        = "web-server-2"     # Имя машины в панели Yandex Cloud
  hostname    = "web2"             # Внутреннее красивое имя ОС Linux
  platform_id = "standard-v3"
  zone_id     = "ru-central1-b"    # Отказоустойчивость: вынесен в другую зону данных

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd864g6cmjq6asstq68q"
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

# --- 4. СЕРВЕР МОНИТОРИНГА PROMETHEUS ---
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus-server" # Имя машины в панели Yandex Cloud
  hostname    = "prometheus-server" # Внутреннее красивое имя ОС Linux
  platform_id = "standard-v3"
  zone_id     = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd864g6cmjq6asstq68q"
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

# --- 5. БАЗА ДАННЫХ ЛОГОВ ELASTICSEARCH ---
resource "yandex_compute_instance" "opensearch" {
  name        = "elasticsearch-storage" # Имя машины в панели Yandex Cloud
  hostname    = "elasticsearch-storage" # Внутреннее красивое имя ОС Linux
  platform_id = "standard-v3"
  zone_id     = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4 # Выделено больше ОЗУ под тяжелую Java Virtual Machine базы логов
  }
  boot_disk {
    initialize_params {
      image_id = "fd864g6cmjq6asstq68q"
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

# --- 6. СЕРВЕР ВЕБ-ПАНЕЛЕЙ (GRAFANA / KIBANA) ---
resource "yandex_compute_instance" "grafana_kibana" {
  name        = "grafana-kibana-server" # Имя машины в панели Yandex Cloud
  hostname    = "grafana-kibana-server" # Внутреннее красивое имя ОС Linux
  platform_id = "standard-v3"
  zone_id     = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = "fd864g6cmjq6asstq68q"
      size     = 20
    }
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true # Нужен внешний IP для открытия веб-интерфейсов из интернета
    security_group_ids = [yandex_vpc_security_group.public_ui_sg.id]
  }
  metadata = {
    ssh-keys = "debian:${file("~/.ssh/id_rsa.pub")}"
  }
}

# --- АВТОМАТИЧЕСКИЙ ДЕПЛОЙ ИНФРАСТРУКТУРЫ ANSIBLE НА АВТОПИЛОТЕ ---
resource "null_resource" "ansible_auto_run" {
  depends_on = [
    yandex_compute_instance.bastion,
    yandex_compute_instance.web_1,
    yandex_compute_instance.web_2,
    yandex_compute_instance.prometheus,
    yandex_compute_instance.opensearch,
    yandex_compute_instance.grafana_kibana
  ]

  # Шаг А: Автоматически создаем и перезаписываем файл hosts.ini актуальными IP-адресами
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF > ../ansible/hosts.ini
[bastion]
bastion_host ansible_host=${yandex_compute_instance.bastion.network_interface.nat_ip_address} ansible_user=debian

[webservers]
web1 ansible_host=${yandex_compute_instance.web_1.network_interface.ip_address} ansible_user=debian
web2 ansible_host=${yandex_compute_instance.web_2.network_interface.ip_address} ansible_user=debian

[logging_storage]
elasticsearch_server ansible_host=${yandex_compute_instance.opensearch.network_interface.ip_address} ansible_user=debian

[prometheus_host]
prometheus_server ansible_host=${yandex_compute_instance.prometheus.network_interface.ip_address} ansible_user=debian

[public_mgmt]
grafana_kibana_server ansible_host=${yandex_compute_instance.grafana_kibana.network_interface.ip_address} ansible_user=debian
EOF
EOT
  }

  # Шаг Б: Даем облаку 15 секунд прогреть SSH-порты серверов и запускаем автоустановку
  provisioner "local-exec" {
    command = "sleep 15 && bash run_ansible.sh"
  }
}
